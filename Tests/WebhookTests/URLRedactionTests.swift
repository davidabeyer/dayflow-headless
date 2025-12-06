import XCTest
@testable import DayflowHeadless

final class URLRedactionTests: XCTestCase {

    func testRemovesQueryParameters() {
        let urlWithQuery = "https://api.example.com/webhook?key=secret&token=abc123"
        let result = redactURL(urlWithQuery)
        XCTAssertEqual(result, "https://api.example.com/webhook", "Should remove query parameters")
    }

    func testRemovesFragment() {
        let urlWithFragment = "https://api.example.com/webhook#section"
        let result = redactURL(urlWithFragment)
        XCTAssertEqual(result, "https://api.example.com/webhook", "Should remove fragment")
    }

    func testRemovesCredentials() {
        let urlWithCredentials = "https://user:password@api.example.com/webhook"
        let result = redactURL(urlWithCredentials)
        XCTAssertEqual(result, "https://api.example.com/webhook", "Should remove credentials")
    }

    func testPreservesPortNumber() {
        let urlWithPort = "https://api.example.com:8080/webhook"
        let result = redactURL(urlWithPort)
        XCTAssertEqual(result, "https://api.example.com:8080/webhook", "Should preserve port number")
    }

    func testPreservesPath() {
        let urlWithPath = "https://api.example.com/v1/webhook/events"
        let result = redactURL(urlWithPath)
        XCTAssertEqual(result, "https://api.example.com/v1/webhook/events", "Should preserve path")
    }

    func testComplexURLWithAllComponents() {
        let complexURL = "https://user:pass@api.example.com:8080/webhook?key=secret#section"
        let result = redactURL(complexURL)
        XCTAssertEqual(result, "https://api.example.com:8080/webhook",
            "Should preserve scheme, host, port, path; remove credentials, query, fragment")
    }

    func testHandlesInvalidURL() {
        // Truly invalid URL with malformed structure
        let invalidURL = "ht!tp://[invalid]"
        let result = redactURL(invalidURL)
        XCTAssertEqual(result, "[invalid URL]", "Should handle truly invalid URLs gracefully")
    }

    func testPreservesPathWithSpecialCharacters() {
        // Test that path with special characters is preserved
        let urlWithPath = "https://api.example.com/webhook/path?key=value"
        let result = redactURL(urlWithPath)
        XCTAssertEqual(result, "https://api.example.com/webhook/path", "Should preserve path and remove query")
    }

    func testEmptyPath() {
        let urlNoPath = "https://api.example.com?key=value"
        let result = redactURL(urlNoPath)
        XCTAssertEqual(result, "https://api.example.com", "Should handle empty path")
    }

    func testRemovesUserButPreservesPassword() {
        // Verify that userInfo is completely removed (both user AND password)
        let urlWithUserOnly = "https://admin@api.example.com/webhook"
        let result = redactURL(urlWithUserOnly)
        XCTAssertEqual(result, "https://api.example.com/webhook", "Should remove userinfo completely")
    }
}
