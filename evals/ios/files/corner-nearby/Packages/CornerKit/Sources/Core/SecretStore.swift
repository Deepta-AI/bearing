import Foundation
#if canImport(Security)
    import Security
#endif

/// Where tokens live. The app uses the Keychain; tests use the in-memory store.
public protocol SecretStore: Sendable {
    func read(_ key: String) throws -> String?
    func write(_ value: String, for key: String) throws
    func delete(_ key: String) throws
}

/// Test and preview store.
public final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    // Protected by `lock`.
    private var values: [String: String]
    private let lock = NSLock()

    public init(_ values: [String: String] = [:]) { self.values = values }

    public func read(_ key: String) throws -> String? { lock.withLock { values[key] } }
    public func write(_ value: String, for key: String) throws { lock.withLock { values[key] = value } }
    public func delete(_ key: String) throws { lock.withLock { values[key] = nil } }
}

#if canImport(Security)
    /// Keychain store, service name = bundle id, AfterFirstUnlockThisDeviceOnly.
    public struct KeychainSecretStore: SecretStore {
        let service: String

        public init(service: String) { self.service = service }

        public func read(_ key: String) throws -> String? {
            var query = base(key)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            if status == errSecItemNotFound { return nil }
            guard status == errSecSuccess, let data = item as? Data else { throw AppError.unknown }
            return String(data: data, encoding: .utf8)
        }

        public func write(_ value: String, for key: String) throws {
            try delete(key)
            var query = base(key)
            query[kSecValueData as String] = Data(value.utf8)
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else { throw AppError.unknown }
        }

        public func delete(_ key: String) throws {
            let status = SecItemDelete(base(key) as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw AppError.unknown }
        }

        private func base(_ key: String) -> [String: Any] {
            [kSecClass as String: kSecClassGenericPassword,
             kSecAttrService as String: service,
             kSecAttrAccount as String: key]
        }
    }
#endif
