import Foundation
import Testing
@testable import AashAI

@Suite struct KeychainStoreTests {
    @Test func writeThenReadReturnsTheValue() throws {
        let store = KeychainStore(service: "me.aarshj.aash.tests")
        let account = "test-" + UUID().uuidString
        defer { try? store.delete(account) }
        try store.write("secret-1", for: account)
        #expect(try store.read(account) == "secret-1")
    }

    @Test func overwriteReplacesTheValue() throws {
        let store = KeychainStore(service: "me.aarshj.aash.tests")
        let account = "test-" + UUID().uuidString
        defer { try? store.delete(account) }
        try store.write("a", for: account)
        try store.write("b", for: account)
        #expect(try store.read(account) == "b")
    }

    @Test func deleteRemovesTheValue() throws {
        let store = KeychainStore(service: "me.aarshj.aash.tests")
        let account = "test-" + UUID().uuidString
        defer { try? store.delete(account) }
        try store.write("gone", for: account)
        try store.delete(account)
        #expect(try store.read(account) == nil)
    }

    @Test func deletingTwiceDoesNotThrow() throws {
        let store = KeychainStore(service: "me.aarshj.aash.tests")
        let account = "test-" + UUID().uuidString
        defer { try? store.delete(account) }
        try store.delete(account)
        try store.delete(account)
    }

    @Test func readingAMissingAccountReturnsNil() throws {
        let store = KeychainStore(service: "me.aarshj.aash.tests")
        let account = "test-" + UUID().uuidString
        defer { try? store.delete(account) }
        #expect(try store.read(account) == nil)
    }

    @Test func servicesAreSeparate() throws {
        let store = KeychainStore(service: "me.aarshj.aash.tests")
        let other = KeychainStore(service: "me.aarshj.aash.tests.other")
        let account = "test-" + UUID().uuidString
        defer { try? store.delete(account) }
        try store.write("only-here", for: account)
        #expect(try other.read(account) == nil)
    }

    @Test func nonASCIIValuesSurvive() throws {
        let store = KeychainStore(service: "me.aarshj.aash.tests")
        let account = "test-" + UUID().uuidString
        defer { try? store.delete(account) }
        try store.write("kéy-✓", for: account)
        #expect(try store.read(account) == "kéy-✓")
    }
}
