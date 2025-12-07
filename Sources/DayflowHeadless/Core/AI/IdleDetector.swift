import Foundation

/// Detects idle periods based on video file size
/// Static screens compress heavily - same frame repeated = tiny file
enum IdleDetector {
    /// Threshold below which we consider the batch to be idle
    static let idleThresholdBytes = 500_000 // 500 KB

    /// Minimum duration before idle detection applies
    static let minimumDurationSeconds: Double = 60

    /// Check if a video batch represents an idle period
    static func isIdlePeriod(videoSizeBytes: Int, durationSeconds: Double) -> Bool {
        return videoSizeBytes < idleThresholdBytes && durationSeconds > minimumDurationSeconds
    }

    /// Calculate bytes per minute for logging
    static func bytesPerMinute(videoSizeBytes: Int, durationSeconds: Double) -> Double {
        return Double(videoSizeBytes) / (durationSeconds / 60.0)
    }
}
