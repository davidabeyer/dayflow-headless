import XCTest
@testable import DayflowHeadless

final class IdleDetectionTests: XCTestCase {

    func testSmallVideoFileSizeIndicatesIdlePeriod() {
        // A 15-minute batch with static screen should compress to < 500 KB
        let isIdle = IdleDetector.isIdlePeriod(videoSizeBytes: 300_000, durationSeconds: 900)
        XCTAssertTrue(isIdle, "Video under 500KB for 15 min should be detected as idle")
    }

    func testLargeVideoFileSizeIndicatesActivity() {
        let isIdle = IdleDetector.isIdlePeriod(videoSizeBytes: 2_000_000, durationSeconds: 900)
        XCTAssertFalse(isIdle, "Video over 500KB should not be detected as idle")
    }

    func testShortDurationNotMarkedAsIdle() {
        let isIdle = IdleDetector.isIdlePeriod(videoSizeBytes: 50_000, durationSeconds: 30)
        XCTAssertFalse(isIdle, "Short durations under 60s should not be marked idle")
    }
}
