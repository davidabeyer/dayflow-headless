import Foundation

/// Formats activity data as Markdown for webhook payloads
public final class MarkdownFormatter {
    
    public init() {}
    
    /// Format activities as markdown summary
    public func format(activities: [Activity]) -> String {
        var lines: [String] = []
        
        lines.append("# Activity Summary")
        lines.append("")
        
        if activities.isEmpty {
            lines.append("No activities recorded.")
            return lines.joined(separator: "\n")
        }
        
        // Group by category
        let grouped = Dictionary(grouping: activities, by: { $0.category })
        let sortedCategories = grouped.keys.sorted()
        
        for category in sortedCategories {
            guard let categoryActivities = grouped[category] else { continue }
            
            lines.append("## \(category)")
            lines.append("")
            
            for activity in categoryActivities {
                let duration = formatDuration(activity.duration)
                lines.append("- **\(activity.appName)**: \(activity.windowTitle) (\(duration))")
            }
            lines.append("")
        }
        
        // Total duration
        let totalSeconds = activities.reduce(0) { $0 + $1.duration }
        lines.append("---")
        lines.append("**Total: \(formatDuration(totalSeconds))**")
        
        return lines.joined(separator: "\n")
    }
    
    /// Format duration as human-readable string
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}
