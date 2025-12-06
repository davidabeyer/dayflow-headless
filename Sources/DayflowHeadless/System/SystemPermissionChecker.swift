import Foundation
import ScreenCaptureKit

/// Production implementation of ScreenCapturePermissionChecker
/// Uses ScreenCaptureKit's async API to check screen recording permission
public struct SystemPermissionChecker: ScreenCapturePermissionChecker {
    public init() {}

    /// Check if Screen Recording permission is currently granted
    /// Returns false if an error occurs (permission denied)
    public func checkPermission() async -> Bool {
        do {
            let _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            return true
        } catch {
            // Permission denied or other error
            return false
        }
    }
}
