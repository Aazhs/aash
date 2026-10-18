import Foundation
import Security

/// Stores short secrets (API keys) as generic passwords in the login Keychain.
public struct KeychainStore: Sendable {
    /// A Keychain call failed with this status.
    public enum Error: Swift.Error, Equatable { case unexpected(OSStatus) }

    let service: String

    /// The Keychain service name; tests use their own so they never touch the real key.
    public init(service: String = "me.aarshj.aash") {
        self.service = service
    }

    /// The saved string for `account`, or nil when nothing is saved.
    public func read(_ account: String) throws -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw Error.unexpected(status) }
        return String(data: data, encoding: .utf8)
    }

    /// Saves `value` for `account`, replacing any earlier value.
    public func write(_ value: String, for account: String) throws {
        let data = Data(value.utf8)
        let status = SecItemUpdate(baseQuery(account) as CFDictionary,
                                   [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw Error.unexpected(status) }
        var query = baseQuery(account)
        query[kSecValueData as String] = data
        let added = SecItemAdd(query as CFDictionary, nil)
        guard added == errSecSuccess else { throw Error.unexpected(added) }
    }

    /// Removes the item for `account`; removing a missing item is not an error.
    public func delete(_ account: String) throws {
        let status = SecItemDelete(baseQuery(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Error.unexpected(status)
        }
    }

    /// The attributes that identify one item. No data-protection or sync flags: those need entitlements.
    private func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
