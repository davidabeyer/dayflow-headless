import XCTest
@testable import DayflowHeadless

final class HeaderValidatorTests: XCTestCase {

    func testIsValidName_AcceptsAlphanumeric() {
        XCTAssertTrue(HeaderValidator.isValidName("ContentType"))
    }

    func testIsValidName_RejectsEmpty() {
        XCTAssertFalse(HeaderValidator.isValidName(""))
    }

    // MARK: - Value Validation Tests

    func testIsValidValue_RejectsCRLF() {
        XCTAssertFalse(HeaderValidator.isValidValue("value\r\nX-Injected: evil"))
    }

    func testIsValidValue_RejectsNonASCII() {
        XCTAssertFalse(HeaderValidator.isValidValue("café"))
    }

    func testIsValidValue_RejectsOverlyLong() {
        let longValue = String(repeating: "a", count: 8193)  // > 8KB
        XCTAssertFalse(HeaderValidator.isValidValue(longValue))
    }

    func testIsValidValue_AcceptsMaxLength() {
        let maxValue = String(repeating: "a", count: 8192)  // Exactly 8KB
        XCTAssertTrue(HeaderValidator.isValidValue(maxValue))
    }

    func testIsValidValue_AcceptsNormalText() {
        XCTAssertTrue(HeaderValidator.isValidValue("Bearer token123"))
        XCTAssertTrue(HeaderValidator.isValidValue("application/json"))
        XCTAssertTrue(HeaderValidator.isValidValue(""))  // Empty value is valid per RFC
    }

    // MARK: - Additional Edge Cases

    func testIsValidName_AcceptsTokenSpecialChars() {
        XCTAssertTrue(HeaderValidator.isValidName("X-Custom-Header"))
        XCTAssertTrue(HeaderValidator.isValidName("Content.Type"))
        XCTAssertTrue(HeaderValidator.isValidName("X_Custom_Header"))
    }

    func testIsValidValue_RejectsSoloCR() {
        XCTAssertFalse(HeaderValidator.isValidValue("value\rbad"))
    }

    func testIsValidValue_RejectsSoloLF() {
        XCTAssertFalse(HeaderValidator.isValidValue("value\nbad"))
    }

    func testIsValidValue_RejectsNullByte() {
        XCTAssertFalse(HeaderValidator.isValidValue("value\0bad"))
    }

    func testIsValidValue_AcceptsTab() {
        // Tabs are allowed in header values per RFC 7230
        XCTAssertTrue(HeaderValidator.isValidValue("value\twith\ttabs"))
    }
}
