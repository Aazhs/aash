# T16 · Keychain store

Phase 3 · Target: AashAI · Risk: low · Detail: full

## Goal

`KeychainStore` reads, writes and deletes a string (the Gemini key) as a generic password in the
login Keychain. Its tests prove that against a separate test service and clean up after themselves,
without a Keychain prompt.

## Read first

- `docs/patterns.md#keychain`: the read code to copy
- `docs/ai.md#keychain`: service and account names
- `docs/decisions.md`: the 18 Oct 2026 row on Keychain flags

## Files

- create `Sources/AashAI/KeychainStore.swift`
- create `Tests/AashAITests/KeychainStoreTests.swift`

## Interfaces

```swift
import Foundation
import Security

/// Stores short secrets (API keys) as generic passwords in the login Keychain.
public struct KeychainStore: Sendable {
    /// A Keychain call failed with this status.
    public enum Error: Swift.Error, Equatable { case unexpected(OSStatus) }
    /// The Keychain service name; tests use their own so they never touch the real key.
    public init(service: String = "me.aarshj.aash")
    /// The saved string for `account`, or nil when nothing is saved.
    public func read(_ account: String) throws -> String?
    /// Saves `value` for `account`, replacing any earlier value.
    public func write(_ value: String, for account: String) throws
    /// Removes the item for `account`; removing a missing item is not an error.
    public func delete(_ account: String) throws
}
```

## Steps

1. `let service: String` stored property, set by `init(service:)`.
2. A private helper `baseQuery(_ account: String) -> [String: Any]` with `kSecClass` =
   `kSecClassGenericPassword`, `kSecAttrService` = `service`, `kSecAttrAccount` = `account`. Use it in
   all three methods.
3. `read`: the code in `docs/patterns.md#keychain`, adding `kSecReturnData: true` and
   `kSecMatchLimit: kSecMatchLimitOne` to `baseQuery`.
4. `write`: `let data = Data(value.utf8)`. Call `SecItemUpdate(baseQuery(account) as CFDictionary,
   [kSecValueData as String: data] as CFDictionary)`. On `errSecItemNotFound`, `SecItemAdd` with
   `baseQuery` plus `kSecValueData`. Any other non-success status throws `.unexpected(status)`.
5. `delete`: `SecItemDelete(baseQuery(account))`; `errSecSuccess` and `errSecItemNotFound` are fine,
   anything else throws `.unexpected(status)`.
6. Tests, as listed below. Each test makes `KeychainStore(service: "me.aarshj.aash.tests")`, uses a
   unique account (`"test-" + UUID().uuidString`), and ends with `defer { try? store.delete(account) }`
   placed right after the account is created, so a failing `#expect` still cleans up.

## Rules

- **Do not** set `kSecUseDataProtectionKeychain` or `kSecAttrSynchronizable`. Without a provisioning
  profile and entitlements that path fails with `errSecMissingEntitlement` (-34018). The plain
  file-based login Keychain needs neither.
- Never log or print a value (`patterns.md#logging`). This file doesn't need a `Logger`.
- Value type, `Sendable`, no AppKit. No `!`, no `try!` outside tests.
- The real service `me.aarshj.aash` is never used in tests.

## Done when

- [ ] `./scripts/check.sh` prints `CHECK PASS` with 0 warnings, and no Keychain dialog appeared
- [ ] Tests (suite `KeychainStoreTests`, one `@Test` each):
  - `writeThenReadReturnsTheValue`: write `"secret-1"` → read == `"secret-1"`
  - `overwriteReplacesTheValue`: write `"a"`, write `"b"` → read == `"b"`
  - `deleteRemovesTheValue`: write, delete → read == nil
  - `deletingTwiceDoesNotThrow`: delete a missing account twice → no error
  - `readingAMissingAccountReturnsNil`: read a fresh unique account → nil
  - `servicesAreSeparate`: write under service `"me.aarshj.aash.tests"`, read the same account from
    `KeychainStore(service: "me.aarshj.aash.tests.other")` → nil
  - `nonASCIIValuesSurvive`: write `"kéy-✓"` → read equals it
- [ ] `security find-generic-password -s me.aarshj.aash.tests` finds nothing afterwards

## Manual check

None. If a Keychain dialog does appear during the test run, don't click Always Allow in an unattended
run: report `RESULT: blocked` with "Keychain prompt during tests" so the user can decide.

## Out of scope

- Reading the key in `GeminiProvider`: the app reads it and passes it in (`docs/ai.md#keychain`).
- The settings UI: T18.

## Notes

- The item's access list names the app that created it. A build signed with the stable "Aash Local"
  certificate keeps access across rebuilds; with ad-hoc signing macOS may ask once after a rebuild.
  That is why `docs/WORKFLOW.md#signing` comes first.
