import os

enum Log {
    static let app = Logger(subsystem: "com.rally.RAlly", category: "app")
    static let engine = Logger(subsystem: "com.rally.RAlly", category: "engine")
    static let net = Logger(subsystem: "com.rally.RAlly", category: "net")
}
