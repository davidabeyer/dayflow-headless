import XCTest
@testable import DayflowHeadless

final class URLValidatorTests: XCTestCase {

    // MARK: - Scheme Whitelist

    func testAcceptsHttps() {
        XCTAssertTrue(URLValidator.isValidWebhookURL("https://example.com/webhook"))
    }

    func testAcceptsHttp() {
        XCTAssertTrue(URLValidator.isValidWebhookURL("http://example.com/webhook"))
    }

    func testRejectsFileScheme() {
        XCTAssertFalse(URLValidator.isValidWebhookURL("file:///etc/passwd"))
    }

    func testRejectsFtpScheme() {
        XCTAssertFalse(URLValidator.isValidWebhookURL("ftp://example.com/file"))
    }

    func testRejectsJavascriptScheme() {
        XCTAssertFalse(URLValidator.isValidWebhookURL("javascript:alert(1)"))
    }

    func testRejectsDataScheme() {
        XCTAssertFalse(URLValidator.isValidWebhookURL("data:text/html,<script>alert(1)</script>"))
    }

    // MARK: - Credential Rejection

    func testRejectsEmbeddedCredentials() {
        XCTAssertFalse(URLValidator.isValidWebhookURL("https://user:pass@example.com/webhook"))
    }

    func testRejectsUsernameOnly() {
        XCTAssertFalse(URLValidator.isValidWebhookURL("https://user@example.com/webhook"))
    }

    // MARK: - Valid URLs

    func testAcceptsURLWithPort() {
        XCTAssertTrue(URLValidator.isValidWebhookURL("https://example.com:8443/webhook"))
    }

    func testAcceptsURLWithPath() {
        XCTAssertTrue(URLValidator.isValidWebhookURL("https://api.example.com/v1/webhook"))
    }

    func testAcceptsURLWithQueryParams() {
        XCTAssertTrue(URLValidator.isValidWebhookURL("https://example.com/webhook?token=abc"))
    }

    // MARK: - Edge Cases

    func testRejectsEmptyString() {
        XCTAssertFalse(URLValidator.isValidWebhookURL(""))
    }

    func testRejectsMalformedURL() {
        XCTAssertFalse(URLValidator.isValidWebhookURL("not a url"))
    }

    func testRejectsURLWithoutHost() {
        XCTAssertFalse(URLValidator.isValidWebhookURL("https:///path"))
    }
}
