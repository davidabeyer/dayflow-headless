import XCTest
@testable import DayflowHeadless

final class PathValidatorTests: XCTestCase {

    // MARK: - Shell Metacharacter Detection

    func testRejectsBackticks() {
        XCTAssertFalse(PathValidator.isValidPath("/usr/bin/`whoami`"))
    }

    func testRejectsDollarExpansion() {
        XCTAssertFalse(PathValidator.isValidPath("/usr/bin/$(whoami)"))
    }

    func testRejectsSemicolon() {
        XCTAssertFalse(PathValidator.isValidPath("/usr/bin/app; rm -rf /"))
    }

    func testRejectsPipe() {
        XCTAssertFalse(PathValidator.isValidPath("/usr/bin/app | cat /etc/passwd"))
    }

    func testRejectsAmpersand() {
        XCTAssertFalse(PathValidator.isValidPath("/usr/bin/app && malicious"))
    }

    func testRejectsNewline() {
        XCTAssertFalse(PathValidator.isValidPath("/usr/bin/app\nmalicious"))
    }

    // MARK: - Valid Paths

    func testAcceptsNormalPath() {
        XCTAssertTrue(PathValidator.isValidPath("/usr/local/bin/dayflow-headless"))
    }

    func testAcceptsPathWithHyphen() {
        XCTAssertTrue(PathValidator.isValidPath("/usr/bin/my-app"))
    }

    func testAcceptsPathWithUnderscore() {
        XCTAssertTrue(PathValidator.isValidPath("/usr/bin/my_app"))
    }

    func testAcceptsPathWithDot() {
        XCTAssertTrue(PathValidator.isValidPath("/usr/bin/app.v2"))
    }

    // MARK: - Path Traversal

    func testRejectsPathTraversal() {
        XCTAssertFalse(PathValidator.isValidPath("/usr/bin/../../../etc/passwd"))
    }

    func testRejectsRelativePath() {
        XCTAssertFalse(PathValidator.isValidPath("../bin/app"))
    }

    // MARK: - Edge Cases

    func testRejectsEmptyPath() {
        XCTAssertFalse(PathValidator.isValidPath(""))
    }

    func testRejectsNullByte() {
        XCTAssertFalse(PathValidator.isValidPath("/usr/bin/app\0malicious"))
    }
}
