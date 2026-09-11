import XCTest
@testable import ClipboardCore

final class OpenRouterKeychainTests: XCTestCase {
    func testKeyCanBeSavedReplacedAndRemovedWithoutUsingUserCredentials() throws {
        let store = OpenRouterKeychain(service: "com.emiel.CopyToTranslate.Tests.\(UUID().uuidString)")
        defer { try? store.remove() }
        XCTAssertThrowsError(try store.load())
        try store.save("test-first-secret")
        XCTAssertEqual(try store.load(), "test-first-secret")
        try store.save("test-replacement-secret")
        XCTAssertEqual(try store.load(), "test-replacement-secret")
        XCTAssertThrowsError(try store.save(""))
        XCTAssertEqual(try store.load(), "test-replacement-secret")
        try store.remove()
        XCTAssertThrowsError(try store.load())
        XCTAssertNoThrow(try store.remove())
    }
}
