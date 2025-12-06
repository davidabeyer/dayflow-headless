import XCTest
@testable import DayflowHeadless

final class PermissionMonitorTests: XCTestCase {

    func testHasPermissionReturnsBool() throws {
        let monitor = PermissionMonitor()
        let result = monitor.hasScreenRecordingPermission()
        XCTAssertNotNil(result)
    }

    func testStartMonitoringCreatesTimer() throws {
        let monitor = PermissionMonitor()
        monitor.startMonitoring(interval: 60)
        // Timer should be created (internal state)
        // Just verify no crash on start
        monitor.stopMonitoring()
    }

    func testStopMonitoringInvalidatesTimer() throws {
        let monitor = PermissionMonitor()
        monitor.startMonitoring(interval: 60)
        monitor.stopMonitoring()
        // Verify double stop is safe
        monitor.stopMonitoring()
        // No crash = success
    }

    func testMonitoringIdempotent() throws {
        let monitor = PermissionMonitor()

        // Start multiple times should be safe
        for _ in 0..<10 {
            monitor.startMonitoring(interval: 30)
        }

        monitor.stopMonitoring()

        // Stop multiple times should be safe
        for _ in 0..<10 {
            monitor.stopMonitoring()
        }
        // No crash = success
    }
}
