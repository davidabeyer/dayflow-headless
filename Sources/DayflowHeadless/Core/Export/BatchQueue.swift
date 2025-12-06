import Foundation

/// Persistent queue for storing failed webhook payloads
/// Files are named with timestamp for ordering
public final class BatchQueue {
    private let directory: URL
    private let fileManager = FileManager.default
    
    public init(directory: URL) {
        self.directory = directory
        createDirectoryIfNeeded()
    }
    
    /// Default queue location in ~/.dayflow/queue/
    public convenience init() {
        let defaultDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".dayflow/queue")
        self.init(directory: defaultDir)
    }
    
    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
    
    /// Add a payload to the queue
    public func enqueue(payload: String) throws {
        let timestamp = Date().timeIntervalSince1970
        let filename = String(format: "%.6f.json", timestamp)
        let filePath = directory.appendingPathComponent(filename)
        try payload.write(to: filePath, atomically: true, encoding: .utf8)
    }
    
    /// Retrieve and remove all queued payloads (FIFO order)
    public func dequeueAll() throws -> [String] {
        let payloads = try peek()
        try clear()
        return payloads
    }
    
    /// View queued payloads without removing them (FIFO order)
    public func peek() throws -> [String] {
        let files = try getQueueFiles()
        return try files.map { try String(contentsOf: $0, encoding: .utf8) }
    }
    
    /// Number of items in the queue
    public var count: Int {
        return (try? getQueueFiles().count) ?? 0
    }
    
    /// Remove all items from the queue
    public func clear() throws {
        let files = try getQueueFiles()
        for file in files {
            try fileManager.removeItem(at: file)
        }
    }
    
    /// Get queue files sorted by timestamp (FIFO)
    private func getQueueFiles() throws -> [URL] {
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )
        
        return contents
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
