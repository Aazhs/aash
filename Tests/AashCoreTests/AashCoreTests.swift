import Testing
@testable import AashCore

@Test func versionIsSet() {
    #expect(!AashCore.version.isEmpty)
}
