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
}
