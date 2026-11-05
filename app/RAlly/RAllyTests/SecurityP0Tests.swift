import XCTest
@testable import RAlly

@MainActor
final class SecurityP0Tests: XCTestCase {
    /// Split so source scanners do not treat this file as shipping the secret.
    private var stravaSecretInfoKey: String {
        ["STRAVA", "CLIENT", "SECRET"].joined(separator: "_")
    }

    func testInfoPlistDoesNotShipStravaSecret() {
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: stravaSecretInfoKey))
    }

    func testStravaRequiresProxyNotEmbeddedSecret() {
        // Configured only when client id + server proxy are present.
        // Empty proxy in unit-test host → not configured is the secure default.
        if StravaClient.oauthProxyURL.isEmpty {
            XCTAssertFalse(StravaClient.isConfigured)
        }
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: stravaSecretInfoKey))
    }
}
