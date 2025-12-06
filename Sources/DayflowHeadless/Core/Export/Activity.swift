import Foundation

/// Represents a tracked activity period
public struct Activity: Codable, Identifiable {
    public let id: UUID
    public let appName: String
    public let windowTitle: String
    public let startTime: Date
    public let duration: TimeInterval  // seconds
    public let category: String
    
    public init(
        id: UUID = UUID(),
        appName: String,
        windowTitle: String,
        startTime: Date,
        duration: TimeInterval,
        category: String
    ) {
        self.id = id
        self.appName = appName
        self.windowTitle = windowTitle
        self.startTime = startTime
        self.duration = duration
        self.category = category
    }
}
