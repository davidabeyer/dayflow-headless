import XCTest
import Clocks
@testable import DayflowHeadless

// MARK: - Mock Delegate for Testing

final class MockPermissionDelegate: PermissionMonitorDelegate {
    var revokedCallCount = 0

    func permissionRevoked() {
        revokedCallCount += 1
    }
}

// MARK: - Tests

final class PermissionMonitorTests: XCTestCase {

    /// Test: Delegate called when permission changes from granted to revoked
    func testDelegateCalledWhenPermissionRevoked() async throws {
        let mockChecker = MockPermissionChecker()
        let mockDelegate = MockPermissionDelegate()
        let testClock = TestClock()

        let monitor = PermissionMonitor(checker: mockChecker, clock: testClock)
        monitor.delegate = mockDelegate

        // Permission starts as granted
        mockChecker.permissionGranted = true

        // Start monitoring
        monitor.startMonitoring(interval: 1.0)

        // Advance clock to trigger first interval
        try await testClock.advance(by: .seconds(1))

        // Should not have called delegate yet (permission still granted)
        XCTAssertEqual(mockDelegate.revokedCallCount, 0)

        // Revoke permission
        mockChecker.permissionGranted = false

        // Advance clock to trigger next check
        try await testClock.advance(by: .seconds(1))

        // Delegate should have been called exactly once
        XCTAssertEqual(mockDelegate.revokedCallCount, 1)

        monitor.stopMonitoring()
    }

    /// Test: Monitoring interval is respected
    func testMonitoringIntervalRespected() async throws {
        let mockChecker = MockPermissionChecker()
        let testClock = TestClock()

        let monitor = PermissionMonitor(checker: mockChecker, clock: testClock)
        mockChecker.permissionGranted = true

        monitor.startMonitoring(interval: 2.0)

        // Advance by less than interval
        try await testClock.advance(by: .milliseconds(500))
        let initialCheckCount = mockChecker.checkCount

        // Advance to complete first interval
        try await testClock.advance(by: .milliseconds(1500))
        XCTAssertGreaterThan(mockChecker.checkCount, initialCheckCount, "Should check after interval")

        monitor.stopMonitoring()
    }

    /// Test: No duplicate delegate calls for same state
    func testPermissionStateChangeTriggersDelegateOnce() async throws {
        let mockChecker = MockPermissionChecker()
        let mockDelegate = MockPermissionDelegate()
        let testClock = TestClock()

        let monitor = PermissionMonitor(checker: mockChecker, clock: testClock)
        monitor.delegate = mockDelegate

        mockChecker.permissionGranted = true
        monitor.startMonitoring(interval: 1.0)

        // Advance once to let monitor capture initial state
        try await testClock.advance(by: .seconds(1))
        XCTAssertEqual(mockDelegate.revokedCallCount, 0, "Permission still granted")

        // Revoke permission
        mockChecker.permissionGranted = false

        // Trigger check - should call delegate
        try await testClock.advance(by: .seconds(1))
        XCTAssertEqual(mockDelegate.revokedCallCount, 1)

        // Advance again without changing permission
        try await testClock.advance(by: .seconds(1))

        // Should not call delegate again (permission state unchanged)
        XCTAssertEqual(mockDelegate.revokedCallCount, 1)

        monitor.stopMonitoring()
    }

    /// Test: Monitoring stops on task cancellation
    func testMonitoringStopsOnTaskCancellation() async throws {
        let mockChecker = MockPermissionChecker()
        let testClock = TestClock()

        let monitor = PermissionMonitor(checker: mockChecker, clock: testClock)
        mockChecker.permissionGranted = true

        monitor.startMonitoring(interval: 1.0)

        try await testClock.advance(by: .milliseconds(500))
        let checkCountBefore = mockChecker.checkCount

        // Stop monitoring
        monitor.stopMonitoring()

        // Advance clock - should not trigger checks
        try await testClock.advance(by: .seconds(2))

        // Check count should not have increased
        XCTAssertEqual(mockChecker.checkCount, checkCountBefore, "Should not check after stopping")
    }
}
