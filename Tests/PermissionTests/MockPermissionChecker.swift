import Foundation
@testable import DayflowHeadless

/// Mock implementation for testing PermissionMonitor
/// Allows control of permission state and tracks check count
public final class MockPermissionChecker: ScreenCapturePermissionChecker {
    public var permissionGranted = true
    public var checkCount = 0

    public init() {}

    public func checkPermission() async -> Bool {
        checkCount += 1
        return permissionGranted
    }
}
