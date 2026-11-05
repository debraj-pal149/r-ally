import Foundation
import AuthenticationServices
import CryptoKit
@preconcurrency import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

enum AuthProviderKind: String, Sendable {
    case google
    case apple
}

struct AuthUserSnapshot: Sendable, Equatable {
    var uid: String
    var email: String?
    var displayName: String?
    var providers: [AuthProviderKind]
}

enum AuthServiceError: LocalizedError {
    case missingRootViewController
    case missingGoogleClientID
    case missingAppleToken
    case missingGoogleToken
    case notSignedIn
    case recentLoginRequired
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .missingRootViewController: return "Could not find a window to present sign-in."
        case .missingGoogleClientID: return "Google Sign-In is not configured."
        case .missingAppleToken: return "Apple did not return an identity token."
        case .missingGoogleToken: return "Google did not return an ID token."
        case .notSignedIn: return "You are not signed in."
        case .recentLoginRequired: return "Apple needs a fresh sign-in before deleting the account."
        case .underlying(let message): return message
        }
    }
}

@MainActor
final class AuthService: NSObject {
    static let shared = AuthService()

    private(set) var current: AuthUserSnapshot?
    private var appleContinuation: CheckedContinuation<AuthUserSnapshot, Error>?
    private var currentNonce: String?

    private override init() {
        super.init()
    }

    func configureIfNeeded() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        refreshFromFirebase()
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.apply(user)
            }
        }
    }

    func refreshFromFirebase() {
        apply(Auth.auth().currentUser)
    }

    var isSignedIn: Bool { current != nil }

    func signInWithGoogle() async throws -> AuthUserSnapshot {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthServiceError.missingGoogleClientID
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        guard let root = Self.topViewController() else {
            throw AuthServiceError.missingRootViewController
        }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: root)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthServiceError.missingGoogleToken
        }
        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        let authResult = try await Auth.auth().signIn(with: credential)
        let snap = snapshot(from: authResult.user)
        apply(authResult.user)
        return snap
    }

    func signInWithApple() async throws -> AuthUserSnapshot {
        let nonce = randomNonce()
        currentNonce = nonce
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<AuthUserSnapshot, Error>) in
            appleContinuation = cont
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    /// Re-auth with Apple when Firebase requires recent login for account deletion.
    func reauthenticateWithApple() async throws {
        let nonce = randomNonce()
        currentNonce = nonce
        _ = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<AuthUserSnapshot, Error>) in
            appleContinuation = cont
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        current = nil
        clearAccountDefaults()
    }

    func deleteFirebaseUser() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthServiceError.notSignedIn
        }
        do {
            nonisolated(unsafe) let unsafeUser = user
            try await unsafeUser.delete()
        } catch {
            let ns = error as NSError
            if ns.code == AuthErrorCode.requiresRecentLogin.rawValue {
                throw AuthServiceError.recentLoginRequired
            }
            throw AuthServiceError.underlying(error.localizedDescription)
        }
        GIDSignIn.sharedInstance.signOut()
        current = nil
        clearAccountDefaults()
    }

    func reauthenticateWithGoogle() async throws {
        _ = try await signInWithGoogle()
    }

    private func apply(_ user: User?) {
        current = user.map(snapshot(from:))
        if let current {
            UserDefaults.standard.set(current.uid, forKey: AccountKeys.ownerUid)
            UserDefaults.standard.set(current.displayName, forKey: AccountKeys.displayName)
            UserDefaults.standard.set(current.email, forKey: AccountKeys.email)
            UserDefaults.standard.set(current.providers.map(\.rawValue), forKey: AccountKeys.providers)
        }
    }

    private func clearAccountDefaults() {
        UserDefaults.standard.removeObject(forKey: AccountKeys.ownerUid)
        UserDefaults.standard.removeObject(forKey: AccountKeys.displayName)
        UserDefaults.standard.removeObject(forKey: AccountKeys.email)
        UserDefaults.standard.removeObject(forKey: AccountKeys.providers)
    }

    private func snapshot(from user: User) -> AuthUserSnapshot {
        let providers: [AuthProviderKind] = user.providerData.compactMap { info in
            switch info.providerID {
            case "google.com": return .google
            case "apple.com": return .apple
            default: return nil
            }
        }
        return AuthUserSnapshot(
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
            providers: providers
        )
    }

    private static func topViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController
    ) -> UIViewController? {
        if let nav = base as? UINavigationController { return topViewController(base: nav.visibleViewController) }
        if let tab = base as? UITabBarController { return topViewController(base: tab.selectedViewController) }
        if let presented = base?.presentedViewController { return topViewController(base: presented) }
        return base
    }

    private func randomNonce(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

extension AuthService: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let cont = appleContinuation else { return }
        appleContinuation = nil
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              let nonce = currentNonce else {
            cont.resume(throwing: AuthServiceError.missingAppleToken)
            return
        }
        let fullName = credential.fullName
        Task { @MainActor in
            do {
                let oauth = OAuthProvider.appleCredential(
                    withIDToken: idToken,
                    rawNonce: nonce,
                    fullName: fullName
                )
                let wantsReauth = Auth.auth().currentUser?.providerData.contains(where: { $0.providerID == "apple.com" }) == true
                if wantsReauth {
                    // Prefer reauth when already signed in with Apple (delete flow).
                    do {
                        guard let current = Auth.auth().currentUser else {
                            throw AuthServiceError.notSignedIn
                        }
                        nonisolated(unsafe) let unsafeUser = current
                        _ = try await unsafeUser.reauthenticate(with: oauth)
                        if let refreshed = Auth.auth().currentUser {
                            let snap = snapshot(from: refreshed)
                            apply(refreshed)
                            cont.resume(returning: snap)
                            return
                        }
                    } catch {
                        // Fall through to sign-in.
                    }
                }
                let result = try await Auth.auth().signIn(with: oauth)
                let snap = snapshot(from: result.user)
                apply(result.user)
                cont.resume(returning: snap)
            } catch {
                cont.resume(throwing: AuthServiceError.underlying(error.localizedDescription))
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard let cont = appleContinuation else { return }
        appleContinuation = nil
        cont.resume(throwing: AuthServiceError.underlying(error.localizedDescription))
    }
}
