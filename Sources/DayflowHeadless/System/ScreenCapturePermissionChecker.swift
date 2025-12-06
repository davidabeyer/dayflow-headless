import Foundation

/// Protocol for checking screen capture permission
/// This abstraction allows testing PermissionMonitor without system interaction
public protocol ScreenCapturePermissionChecker: Sendable {
    /// Check if Screen Recording permission is currently granted
    /// - Returns: true if permission is granted, false otherwise
    func checkPermission() async -> Bool
}
