import Foundation

/// Where tokens live. Never `UserDefaults`: it is a plain plist inside the
/// app container and ends up in backups. Features depend on this protocol;
/// the App target hands them `KeychainSecretStore`, tests hand them
/// `InMemorySecretStore`.
public protocol SecretStore: Sendable {
    /// Returns the stored bytes for `key`, or nil when nothing is stored.
    func read(_ key: SecretKey) throws -> Data?
    /// Stores `value` under `key`, replacing any previous value.
    func write(_ value: Data, for key: SecretKey) throws
    /// Removes `key`. Removing an absent key is not an error.
    func remove(_ key: SecretKey) throws
}

/// A typed name for a secret so call sites cannot misspell one.
public struct SecretKey: Hashable, Sendable, RawRepresentable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let accessToken = SecretKey(rawValue: "auth.accessToken")
    public static let refreshToken = SecretKey(rawValue: "auth.refreshToken")
}

public extension SecretStore {
    /// Convenience for string secrets such as bearer tokens.
    func readString(_ key: SecretKey) throws -> String? {
        try read(key).flatMap { String(data: $0, encoding: .utf8) }
    }

    func write(_ value: String, for key: SecretKey) throws {
        try write(Data(value.utf8), for: key)
    }
}

/// A `SecretStore` that forgets on process exit. For tests and previews only.
public final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [SecretKey: Data] = [:]

    public init() {}

    public func read(_ key: SecretKey) throws -> Data? {
        lock.lock(); defer { lock.unlock() }
        return values[key]
    }

    public func write(_ value: Data, for key: SecretKey) throws {
        lock.lock(); defer { lock.unlock() }
        values[key] = value
    }

    public func remove(_ key: SecretKey) throws {
        lock.lock(); defer { lock.unlock() }
        values[key] = nil
    }
}

#if canImport(Security)
    import Security

    /// The real store, backed by the iOS Keychain as generic passwords scoped
    /// to one service name. Items are `AfterFirstUnlockThisDeviceOnly`: they
    /// survive a relaunch, never migrate to another device through backup.
    public struct KeychainSecretStore: SecretStore {
        private let service: String

        /// `service` is normally the bundle identifier.
        public init(service: String) {
            self.service = service
        }

        public func read(_ key: SecretKey) throws -> Data? {
            var query = baseQuery(key)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            switch status {
            case errSecSuccess:
                return item as? Data
            case errSecItemNotFound:
                return nil
            default:
                throw AppError.keychain(status: status)
            }
        }

        public func write(_ value: Data, for key: SecretKey) throws {
            let query = baseQuery(key)
            let update: [String: Any] = [kSecValueData as String: value]
            let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
            if status == errSecItemNotFound {
                var insert = query
                insert[kSecValueData as String] = value
                insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                let added = SecItemAdd(insert as CFDictionary, nil)
                guard added == errSecSuccess else { throw AppError.keychain(status: added) }
            } else if status != errSecSuccess {
                throw AppError.keychain(status: status)
            }
        }

        public func remove(_ key: SecretKey) throws {
            let status = SecItemDelete(baseQuery(key) as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw AppError.keychain(status: status)
            }
        }

        private func baseQuery(_ key: SecretKey) -> [String: Any] {
            [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key.rawValue,
            ]
        }
    }
#endif
