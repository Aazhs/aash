# T16 · Keychain store

Phase 3 · Target: AashAI · Risk: low · Detail: outline

## Goal

`KeychainStore` reads, writes and deletes the Gemini key as a generic password, and tests prove it
against a separate test service that they clean up.

## Read first

- `docs/patterns.md#keychain`
- `docs/ai.md#keychain`

## Files (expected)

- create `Sources/AashAI/KeychainStore.swift`
- create `Tests/AashAITests/KeychainStoreTests.swift`

## Sketch

```swift
public struct KeychainStore: Sendable {
    public enum Error: Swift.Error, Equatable { case unexpected(OSStatus) }
    public init(service: String = "me.aarshj.aash")
    public func read(_ account: String) throws -> String?
    public func write(_ value: String, for account: String) throws
    public func delete(_ account: String) throws
}
```

## Done when (to be detailed by /plan-phase 3)

- [ ] Tests use service `me.aarshj.aash.tests`: write → read equals; overwrite → read gets the new
  value; delete → read is nil; delete twice doesn't throw. Each test deletes what it wrote.
- [ ] `./scripts/check.sh` prints `CHECK PASS`

## Notes

- If the test run triggers a Keychain prompt, the card must say how to avoid it (for example
  `kSecUseDataProtectionKeychain`), because prompts block unattended runs.
