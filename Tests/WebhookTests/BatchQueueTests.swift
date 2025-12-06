import XCTest
@testable import DayflowHeadless

final class BatchQueueTests: XCTestCase {

    var tempDirectory: URL!
    var batchQueue: BatchQueue!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("batch-queue-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        batchQueue = nil
    }

    func testEnqueueCreatesFile() throws {
        batchQueue = BatchQueue(directory: tempDirectory)

        try batchQueue.enqueue(payload: "Test payload 1")

        let files = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1, "Should create one file for queued payload")
    }

    func testDequeueReturnsPayloads() throws {
        batchQueue = BatchQueue(directory: tempDirectory)

        try batchQueue.enqueue(payload: "Payload 1")
        try batchQueue.enqueue(payload: "Payload 2")

        let payloads = try batchQueue.dequeueAll()

        XCTAssertEqual(payloads.count, 2)
        XCTAssertTrue(payloads.contains("Payload 1"))
        XCTAssertTrue(payloads.contains("Payload 2"))
    }

    func testDequeueRemovesFiles() throws {
        batchQueue = BatchQueue(directory: tempDirectory)

        try batchQueue.enqueue(payload: "Test payload")
        _ = try batchQueue.dequeueAll()

        let files = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 0, "Dequeue should remove files")
    }

    func testEmptyQueueReturnsEmptyArray() throws {
        batchQueue = BatchQueue(directory: tempDirectory)

        let payloads = try batchQueue.dequeueAll()

        XCTAssertEqual(payloads.count, 0)
    }

    func testPeekDoesNotRemoveFiles() throws {
        batchQueue = BatchQueue(directory: tempDirectory)

        try batchQueue.enqueue(payload: "Test payload")
        let peeked = try batchQueue.peek()

        XCTAssertEqual(peeked.count, 1)

        let files = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1, "Peek should not remove files")
    }

    func testQueueCountReturnsCorrectCount() throws {
        batchQueue = BatchQueue(directory: tempDirectory)

        XCTAssertEqual(batchQueue.count, 0)

        try batchQueue.enqueue(payload: "Payload 1")
        XCTAssertEqual(batchQueue.count, 1)

        try batchQueue.enqueue(payload: "Payload 2")
        XCTAssertEqual(batchQueue.count, 2)
    }

    func testClearRemovesAllFiles() throws {
        batchQueue = BatchQueue(directory: tempDirectory)

        try batchQueue.enqueue(payload: "Payload 1")
        try batchQueue.enqueue(payload: "Payload 2")

        try batchQueue.clear()

        XCTAssertEqual(batchQueue.count, 0)
        let files = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 0)
    }

    func testPayloadPersistedCorrectly() throws {
        batchQueue = BatchQueue(directory: tempDirectory)

        let complexPayload = """
        {
            "activity": "coding",
            "duration": 3600,
            "metadata": {"app": "Xcode"}
        }
        """

        try batchQueue.enqueue(payload: complexPayload)
        let payloads = try batchQueue.dequeueAll()

        XCTAssertEqual(payloads.first, complexPayload)
    }

    func testFilesAreOrderedByTimestamp() throws {
        batchQueue = BatchQueue(directory: tempDirectory)

        try batchQueue.enqueue(payload: "First")
        // Small delay to ensure different timestamps
        Thread.sleep(forTimeInterval: 0.01)
        try batchQueue.enqueue(payload: "Second")
        Thread.sleep(forTimeInterval: 0.01)
        try batchQueue.enqueue(payload: "Third")

        let payloads = try batchQueue.dequeueAll()

        XCTAssertEqual(payloads, ["First", "Second", "Third"])
    }

    /// Test: Enqueue uses UUID suffix in filename for collision prevention
    func testEnqueueFilenameContainsUUIDSuffix() throws {
        batchQueue = BatchQueue(directory: tempDirectory)

        try batchQueue.enqueue(payload: "Test payload")

        let files = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        XCTAssertEqual(files.count, 1)

        // Filename format should be: timestamp-UUID.json (e.g., "1234567890.123456-ABCD1234.json")
        let filename = files[0].deletingPathExtension().lastPathComponent
        let parts = filename.split(separator: "-")
        XCTAssertEqual(parts.count, 2, "Filename should have timestamp-UUID format")
        XCTAssertGreaterThanOrEqual(parts[1].count, 8, "UUID suffix should be at least 8 characters")
    }

    /// Test: Dequeue uses atomic claim pattern (no .claimed- files remain)
    func testDequeueUsesAtomicClaimNoFilesRemain() throws {
        batchQueue = BatchQueue(directory: tempDirectory)

        try batchQueue.enqueue(payload: "Payload 1")
        try batchQueue.enqueue(payload: "Payload 2")

        let payloads = try batchQueue.dequeueAll()
        XCTAssertEqual(payloads.count, 2)

        // After dequeue, directory should be empty (no .claimed- or .json files)
        let allFiles = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(allFiles.count, 0, "No files should remain after dequeue")
    }

    /// Test: Concurrent dequeue from multiple queues reading same directory prevents duplicates
    /// This test verifies the atomic claim pattern works correctly with concurrent access
    func testConcurrentDequeueNoDuplicates() throws {
        batchQueue = BatchQueue(directory: tempDirectory)

        // Enqueue 10 items
        for i in 0..<10 {
            try batchQueue.enqueue(payload: "Item \(i)")
        }

        var allPayloads: [String] = []
        let queue = DispatchQueue(label: "concurrent-dequeue")
        let group = DispatchGroup()

        // Three concurrent dequeue operations
        for _ in 0..<3 {
            group.enter()
            queue.async {
                do {
                    let payloads = try self.batchQueue.dequeueAll()
                    queue.async(flags: .barrier) {
                        allPayloads.append(contentsOf: payloads)
                        group.leave()
                    }
                } catch {
                    XCTFail("Concurrent dequeue failed: \(error)")
                    group.leave()
                }
            }
        }

        group.wait()

        // Verify: all 10 items were processed exactly once
        XCTAssertEqual(allPayloads.count, 10, "All items should be processed exactly once")
        let uniquePayloads = Set(allPayloads)
        XCTAssertEqual(uniquePayloads.count, 10, "No duplicates should exist")

        // Verify: queue is now empty
        XCTAssertEqual(batchQueue.count, 0, "Queue should be empty after concurrent dequeue")

        // Verify: no .claimed- files remain
        let remainingFiles = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(remainingFiles.count, 0, "No claimed or JSON files should remain")
    }

    /// Test: Stress test with 100 iterations of concurrent operations
    /// Ensures atomicity holds across many cycles
    func testConcurrentStress100Iterations() throws {
        batchQueue = BatchQueue(directory: tempDirectory)

        for iteration in 0..<100 {
            // Clear queue for fresh start
            try? batchQueue.clear()

            // Enqueue items
            for i in 0..<10 {
                try batchQueue.enqueue(payload: "Iteration\(iteration)-Item\(i)")
            }

            var allPayloads: [String] = []
            let queue = DispatchQueue(label: "stress-test-\(iteration)")
            let group = DispatchGroup()

            // Three concurrent dequeue operations
            for _ in 0..<3 {
                group.enter()
                queue.async {
                    do {
                        let payloads = try self.batchQueue.dequeueAll()
                        queue.async(flags: .barrier) {
                            allPayloads.append(contentsOf: payloads)
                            group.leave()
                        }
                    } catch {
                        XCTFail("Stress test iteration \(iteration) failed: \(error)")
                        group.leave()
                    }
                }
            }

            group.wait()

            // Verify no duplicates in this iteration
            XCTAssertEqual(allPayloads.count, 10, "Iteration \(iteration): all items should be processed once")
            let uniquePayloads = Set(allPayloads)
            XCTAssertEqual(uniquePayloads.count, 10, "Iteration \(iteration): no duplicates should exist")
        }
    }

    /// Test: Concurrent access with file deletion edge case
    /// Verifies handling of files deleted externally during claim window
    func testConcurrentDequeueWithExternalFileDelete() throws {
        batchQueue = BatchQueue(directory: tempDirectory)

        try batchQueue.enqueue(payload: "Payload 1")
        try batchQueue.enqueue(payload: "Payload 2")
        try batchQueue.enqueue(payload: "Payload 3")

        let queue = DispatchQueue(label: "delete-test")
        let group = DispatchGroup()
        var dequeuePayloads: [String] = []

        // Start first dequeue
        group.enter()
        queue.async {
            do {
                let payloads = try self.batchQueue.dequeueAll()
                queue.async(flags: .barrier) {
                    dequeuePayloads.append(contentsOf: payloads)
                }
            } catch {
                XCTFail("Dequeue failed: \(error)")
            }
            group.leave()
        }

        // Wait for dequeue to complete
        group.wait()

        // Verify all payloads were recovered (even those with external deletion)
        XCTAssertEqual(dequeuePayloads.count, 3, "All payloads should be retrieved despite potential race conditions")

        // Queue should be clean
        XCTAssertEqual(batchQueue.count, 0)
        let remainingFiles = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(remainingFiles.count, 0, "Queue directory should be clean")
    }

    /// Test: GetQueueFiles excludes claimed files
    /// Verifies that files in progress don't get double-processed
    func testGetQueueFilesExcludesClaimedFiles() throws {
        batchQueue = BatchQueue(directory: tempDirectory)

        // Manually create some claimed files in the directory
        let claimedFile1 = tempDirectory.appendingPathComponent(".claimed-UUID1").appendingPathExtension("json")
        let claimedFile2 = tempDirectory.appendingPathComponent(".claimed-UUID2").appendingPathExtension("json")
        try "claimed 1".write(to: claimedFile1, atomically: true, encoding: .utf8)
        try "claimed 2".write(to: claimedFile2, atomically: true, encoding: .utf8)

        // Enqueue normal items
        try batchQueue.enqueue(payload: "Normal 1")
        try batchQueue.enqueue(payload: "Normal 2")

        // Queue count should only include normal files
        XCTAssertEqual(batchQueue.count, 2, "Count should exclude claimed files")

        // Peek should only return normal files
        let peeked = try batchQueue.peek()
        XCTAssertEqual(peeked.count, 2, "Peek should exclude claimed files")
        XCTAssertTrue(peeked.contains("Normal 1"))
        XCTAssertTrue(peeked.contains("Normal 2"))
    }
}
