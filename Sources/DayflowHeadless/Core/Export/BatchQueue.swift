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
    /// Uses UUID suffix to prevent filename collisions
    public func enqueue(payload: String) throws {
        let timestamp = Date().timeIntervalSince1970
        let uuid = UUID().uuidString.prefix(8)
        let filename = String(format: "%.6f-%@.json", timestamp, String(uuid))
        let filePath = directory.appendingPathComponent(filename)
        try payload.write(to: filePath, atomically: true, encoding: .utf8)
    }

    /// Retrieve and remove all queued payloads (FIFO order)
    /// Uses atomic rename-based claim pattern to prevent race conditions
    /// and duplicate processing in concurrent scenarios.
    ///
    /// Implementation uses POSIX rename(2) atomicity:
    /// 1. Claim phase: Rename files with .claimed- prefix (atomic operation)
    /// 2. Read phase: Read all claimed files
    /// 3. Delete phase: Remove claimed files
    ///
    /// If another process claims a file first, we get fileNoSuchFile and skip.
    public func dequeueAll() throws -> [String] {
        let files = try getQueueFiles()
        var claimed: [URL] = []
        var payloads: [String] = []

        // Phase 1: Claim files by renaming (ATOMIC via POSIX rename)
        // moveItem() calls rename(2) which is atomic on same filesystem
        for file in files {
            let claimedPath = file.deletingLastPathComponent()
                .appendingPathComponent(".claimed-\(UUID().uuidString)")
            do {
                try fileManager.moveItem(at: file, to: claimedPath)
                claimed.append(claimedPath)
            } catch CocoaError.fileNoSuchFile {
                // Already claimed by another concurrent process, skip
                continue
            } catch {
                // Log but continue with remaining files
                print("Warning: Failed to claim \(file.lastPathComponent): \(error)")
                continue
            }
        }

        // Phase 2: Read claimed files
        for file in claimed {
            do {
                payloads.append(try String(contentsOf: file, encoding: .utf8))
            } catch CocoaError.fileNoSuchFile {
                // File was deleted externally during claim window, skip
                print("Warning: Claimed file was deleted externally: \(file.lastPathComponent)")
                continue
            } catch {
                // Log but continue with remaining files
                print("Warning: Failed to read claimed file: \(error)")
            }
        }

        // Phase 3: Delete claimed files
        for file in claimed {
            try? fileManager.removeItem(at: file)
        }

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
    /// Excludes claimed files (those with .claimed- prefix)
    private func getQueueFiles() throws -> [URL] {
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: []  // Don't skip hidden files so we can filter claimed ones explicitly
        )

        return contents
            .filter { !$0.lastPathComponent.hasPrefix(".claimed-") }
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
