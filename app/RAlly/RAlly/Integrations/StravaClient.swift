import Foundation
import AuthenticationServices
#if os(iOS)
import UIKit
#endif

@MainActor
final class StravaClient: NSObject, ASWebAuthenticationPresentationContextProviding {
    static var clientId: String {
        (Bundle.main.object(forInfoDictionaryKey: "STRAVA_CLIENT_ID") as? String) ?? ""
    }
    static var clientSecret: String {
        (Bundle.main.object(forInfoDictionaryKey: "STRAVA_CLIENT_SECRET") as? String) ?? ""
    }
    static var isConfigured: Bool {
        !clientId.isEmpty && !clientSecret.isEmpty
    }

    private let defaults = UserDefaults.standard
    var isConnected: Bool { defaults.string(forKey: "strava.access") != nil }

    func connect() async throws {
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
        defaults.removeObject(forKey: "strava.access")
        defaults.removeObject(forKey: "strava.refresh")
    }

    func upload(session: WorkoutSessionRecord) async throws {
        var token = defaults.string(forKey: "strava.access") ?? ""
        let data = TCXExporter.tcx(session: session)
        var req = URLRequest(url: URL(string: "https://www.strava.com/api/v3/uploads")!)
        req.httpMethod = "POST"
        let boundary = UUID().uuidString
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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
            if let token = defaults.string(forKey: "strava.access") {
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
        var req = URLRequest(url: URL(string: "https://www.strava.com/oauth/token")!)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "content-type")
        let payload = [
            "client_id": Self.clientId,
            "client_secret": Self.clientSecret,
            "code": code,
            "grant_type": "authorization_code",
        ]
        req.httpBody = try JSONEncoder().encode(payload)
        let (data, _) = try await URLSession.shared.data(for: req)
        try storeTokens(data)
    }

    private func refresh() async throws {
        guard let refresh = defaults.string(forKey: "strava.refresh") else { throw URLError(.userAuthenticationRequired) }
        var req = URLRequest(url: URL(string: "https://www.strava.com/oauth/token")!)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "content-type")
        let payload = [
            "client_id": Self.clientId,
            "client_secret": Self.clientSecret,
            "refresh_token": refresh,
            "grant_type": "refresh_token",
        ]
        req.httpBody = try JSONEncoder().encode(payload)
        let (data, _) = try await URLSession.shared.data(for: req)
        try storeTokens(data)
    }

    private func storeTokens(_ data: Data) throws {
        struct Tok: Codable { var access_token: String; var refresh_token: String }
        let t = try JSONDecoder().decode(Tok.self, from: data)
        defaults.set(t.access_token, forKey: "strava.access")
        defaults.set(t.refresh_token, forKey: "strava.refresh")
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}
