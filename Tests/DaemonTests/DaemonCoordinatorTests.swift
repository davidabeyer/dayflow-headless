import XCTest
@testable import DayflowHeadless

final class DaemonCoordinatorTests: XCTestCase {

    func testInitialStateNotRecording() throws {
        let coordinator = DaemonCoordinator()
        XCTAssertFalse(coordinator.isRecording, "Coordinator should not be recording on init")
    }

    func testSetRecordingTrue() throws {
        let coordinator = DaemonCoordinator()
        coordinator.setRecording(true)
        XCTAssertTrue(coordinator.isRecording, "Coordinator should be recording after setRecording(true)")
    }

    func testShutdownSetsRecordingFalse() throws {
        let coordinator = DaemonCoordinator()
        coordinator.setRecording(true)
        coordinator.shutdown()
        XCTAssertFalse(coordinator.isRecording, "Coordinator should not be recording after shutdown")
    }

    func testStateAccessThreadSafe() throws {
        let coordinator = DaemonCoordinator()
        let expectation = XCTestExpectation(description: "Concurrent access completes")
        expectation.expectedFulfillmentCount = 1000

        DispatchQueue.concurrentPerform(iterations: 500) { _ in
            _ = coordinator.isRecording
            expectation.fulfill()
        }

        DispatchQueue.concurrentPerform(iterations: 500) { i in
            coordinator.setRecording(i % 2 == 0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
    }

    func testIsRunningOnSequoia() throws {
        let coordinator = DaemonCoordinator()
        let result = coordinator.isRunningOnSequoia()
        XCTAssertNotNil(result)
    }
}
