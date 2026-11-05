import Foundation

enum AccountKeys {
    static let ownerUid = "rally.account.ownerUid"
    static let displayName = "rally.account.displayName"
    static let email = "rally.account.email"
    static let providers = "rally.account.providers"
    static let welcomeSeen = "rally.welcomeSeen"
    static let dayCoachPending = "rally.dayCoachPending"
    static let outbox = "rally.sync.outbox.v1"
    /// When true, Mixpanel must not initialize or send events.
    static let analyticsOptOut = "rally.analytics.optOut"
    static let schemaVersion = 1
}
