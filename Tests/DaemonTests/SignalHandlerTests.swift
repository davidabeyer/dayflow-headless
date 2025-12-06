import XCTest
@testable import DayflowHeadless

final class SignalHandlerTests: XCTestCase {

    var signalHandler: SignalHandler!
    var shutdownCalled: Bool = false

    override func setUp() {
        super.setUp()
        shutdownCalled = false
    }

    override func tearDown() {
        signalHandler?.stop()
        signalHandler = nil
        super.tearDown()
    }

    func testSignalHandlerCallsShutdownOnSIGTERM() {
        let expectation = expectation(description: "Shutdown called")

        signalHandler = SignalHandler { [weak self] in
            self?.shutdownCalled = true
            expectation.fulfill()
        }
        signalHandler.start()

        // Send SIGTERM to ourselves
        kill(getpid(), SIGTERM)

        waitForExpectations(timeout: 1.0) { _ in
            XCTAssertTrue(self.shutdownCalled, "Shutdown handler should be called")
        }
    }

    func testSignalHandlerCallsShutdownOnSIGINT() {
        let expectation = expectation(description: "Shutdown called")

        signalHandler = SignalHandler { [weak self] in
            self?.shutdownCalled = true
            expectation.fulfill()
        }
        signalHandler.start()

        // Send SIGINT to ourselves
        kill(getpid(), SIGINT)

        waitForExpectations(timeout: 1.0) { _ in
            XCTAssertTrue(self.shutdownCalled, "Shutdown handler should be called")
        }
    }

    func testSignalHandlerCanBeStoppedWithoutCrash() {
        signalHandler = SignalHandler { [weak self] in
            self?.shutdownCalled = true
        }
        signalHandler.start()

        // Stopping should not crash and should clean up resources
        signalHandler.stop()

        // Verify handler is nil after stop (no crash)
        XCTAssertFalse(shutdownCalled, "Handler should not be called just from stop()")
    }

    func testMultipleStartStopCycles() {
        signalHandler = SignalHandler { [weak self] in
            self?.shutdownCalled = true
        }

        // Should handle multiple start/stop cycles without issues
        signalHandler.start()
        signalHandler.stop()
        signalHandler.start()
        signalHandler.stop()

        XCTAssertFalse(shutdownCalled, "Handler should not be called during start/stop cycles")
    }
}
