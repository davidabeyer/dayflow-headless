import Foundation
import ScreenCaptureKit

/// Protocol for receiving permission revocation notifications
public protocol PermissionMonitorDelegate: AnyObject {
    func permissionRevoked()
}

/// Monitors Screen Recording TCC permission and notifies on revocation
public final class PermissionMonitor {

    public weak var delegate: PermissionMonitorDelegate?
    private var checkTimer: Timer?

    public init() {}

    /// Check if Screen Recording permission is currently granted
    public func hasScreenRecordingPermission() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var hasPermission = false

        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { content, error in
            hasPermission = (content != nil && error == nil)
            semaphore.signal()
        }

        semaphore.wait()
        return hasPermission
    }

    /// Start continuous permission monitoring
    public func startMonitoring(interval: TimeInterval = 30) {
        stopMonitoring()

        checkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if !self.hasScreenRecordingPermission() {
                self.delegate?.permissionRevoked()
            }
        }
    }

    /// Stop permission monitoring
    public func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
}
