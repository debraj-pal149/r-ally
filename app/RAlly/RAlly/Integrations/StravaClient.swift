import Foundation
import AuthenticationServices
#if os(iOS)
import UIKit
#endif

@MainActor
final class StravaClient: NSObject, ASWebAuthenticationPresentationContextProviding {
    private static let accessAccount = "strava.access"
    private static let refreshAccount = "strava.refresh"
    private static let legacyAccessDefaultsKey = "strava.access"
    private static let legacyRefreshDefaultsKey = "strava.refresh"

    static var clientId: String {
        cleanedInfo("STRAVA_CLIENT_ID")
    }

    /// HTTPS Cloud Function that performs Strava token exchange (secret stays server-side).
    static var oauthProxyURL: String {
        cleanedInfo("STRAVA_OAUTH_PROXY_URL")
    }

    static var isConfigured: Bool {
        !clientId.isEmpty && !oauthProxyURL.isEmpty
    }

    var isConnected: Bool { accessToken != nil }

    private var accessToken: String? {
        migrateLegacyTokensIfNeeded()
        return KeychainStore.get(account: Self.accessAccount)
    }

    private var refreshToken: String? {
        migrateLegacyTokensIfNeeded()
        return KeychainStore.get(account: Self.refreshAccount)
    }

    func connect() async throws {
        guard Self.isConfigured else { throw URLError(.unsupportedURL) }
        let url = URL(string: "https://www.strava.com/oauth/mobile/authorize?client_id=\(Self.clientId)&redirect_uri=rally://strava/callback&response_type=code&approval_prompt=auto&scope=activity:write,activity:read_all&redirect_uri=rally://strava/callback")!
        let code: String = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "rally") { callback, error in
                if let error { cont.resume(throwing: error); return }
                guard let callback, let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems,
                      let code = items.first(where: { $0.name == "code" })?.value else {
                    cont.resume(throwing: URLError(.badServerResponse))
                    return
                }
                cont.resume(returning: code)
            }
            session.presentationContextProvider = self
            session.start()
        }
        try await exchange(code: code)
    }

    func disconnect() {
        KeychainStore.remove(account: Self.accessAccount)
        KeychainStore.remove(account: Self.refreshAccount)
        UserDefaults.standard.removeObject(forKey: Self.legacyAccessDefaultsKey)
        UserDefaults.standard.removeObject(forKey: Self.legacyRefreshDefaultsKey)
    }

    func upload(session: WorkoutSessionRecord) async throws {
        let data = TCXExporter.tcx(session: session)
        var req = URLRequest(url: URL(string: "https://www.strava.com/api/v3/uploads")!)
        req.httpMethod = "POST"
        let boundary = UUID().uuidString
        if let token = accessToken {
            req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".data(using: .utf8)!)
        }
        field("data_type", "tcx")
        field("name", "r-ally \(session.activity.title)")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"rally.tcx\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/xml\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        let (respData, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            try await refresh()
            try await upload(session: session)
            return
        }
        struct UploadAck: Codable { var id: Int?; var status: String? }
        let ack = try? JSONDecoder().decode(UploadAck.self, from: respData)
        if let id = ack?.id {
            try await pollUpload(id: id)
        }
    }

    private func pollUpload(id: Int) async throws {
        struct Status: Codable { var id: Int?; var status: String?; var error: String? }
        for _ in 0..<20 {
            try await Task.sleep(for: .seconds(2))
            var req = URLRequest(url: URL(string: "https://www.strava.com/api/v3/uploads/\(id)")!)
            if let token = accessToken {
                req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
                try await refresh()
                continue
            }
            let st = try JSONDecoder().decode(Status.self, from: data)
            if st.error != nil { throw URLError(.cannotParseResponse) }
            let ready = (st.status ?? "").lowercased().contains("ready")
            if ready { return }
        }
    }

    private func exchange(code: String) async throws {
        try await postToProxy([
            "grant_type": "authorization_code",
            "code": code,
        ])
    }

    private func refresh() async throws {
        guard let refresh = refreshToken else {
            throw URLError(.userAuthenticationRequired)
        }
        try await postToProxy([
            "grant_type": "refresh_token",
            "refresh_token": refresh,
        ])
    }

    private func postToProxy(_ payload: [String: String]) async throws {
        guard let url = URL(string: Self.oauthProxyURL) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONEncoder().encode(payload)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.userAuthenticationRequired)
        }
        try storeTokens(data)
    }

    private func storeTokens(_ data: Data) throws {
        struct Tok: Codable { var access_token: String; var refresh_token: String }
        let t = try JSONDecoder().decode(Tok.self, from: data)
        KeychainStore.set(t.access_token, account: Self.accessAccount)
        KeychainStore.set(t.refresh_token, account: Self.refreshAccount)
        UserDefaults.standard.removeObject(forKey: Self.legacyAccessDefaultsKey)
        UserDefaults.standard.removeObject(forKey: Self.legacyRefreshDefaultsKey)
    }

    /// One-time move of pre-P1 tokens out of UserDefaults.
    private func migrateLegacyTokensIfNeeded() {
        let defaults = UserDefaults.standard
        if let access = defaults.string(forKey: Self.legacyAccessDefaultsKey), !access.isEmpty,
           KeychainStore.get(account: Self.accessAccount) == nil {
            KeychainStore.set(access, account: Self.accessAccount)
            defaults.removeObject(forKey: Self.legacyAccessDefaultsKey)
        }
        if let refresh = defaults.string(forKey: Self.legacyRefreshDefaultsKey), !refresh.isEmpty,
           KeychainStore.get(account: Self.refreshAccount) == nil {
            KeychainStore.set(refresh, account: Self.refreshAccount)
            defaults.removeObject(forKey: Self.legacyRefreshDefaultsKey)
        }
    }

    private static func cleanedInfo(_ key: String) -> String {
        let raw = (Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? ""
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("$") else { return "" }
        return value
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}
