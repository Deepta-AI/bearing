import Foundation
#if canImport(OSLog)
    import OSLog
#endif

/// App logging. Messages are public so they show in Console and in the
/// support log export.
public enum Log {
    #if canImport(OSLog)
        private static let network = Logger(subsystem: "com.example.corner", category: "network")
    #endif

    public static func request(_ message: String) {
        #if canImport(OSLog)
            network.info("\(message, privacy: .public)")
        #else
            print("[network] \(message)")
        #endif
    }
}
