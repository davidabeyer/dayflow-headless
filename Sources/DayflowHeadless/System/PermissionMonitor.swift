import Foundation
import ScreenCaptureKit
import Clocks

/// Protocol for receiving permission revocation notifications
public protocol PermissionMonitorDelegate: AnyObject {
    func permissionRevoked()
}

/// Monitors Screen Recording TCC permission and notifies on revocation
/// Generic over Clock type for testable timing control
public final class PermissionMonitor<C: Clock> where C.Duration == Duration {

    public weak var delegate: PermissionMonitorDelegate?
    private var monitoringTask: Task<Void, Never>?
    private let checker: ScreenCapturePermissionChecker
    private let clock: C

    public init(checker: ScreenCapturePermissionChecker = SystemPermissionChecker(), clock: C) {
        self.checker = checker
        self.clock = clock
    }

    /// Start continuous permission monitoring using async/await with injected clock
    public func startMonitoring(interval: TimeInterval = 30) {
        stopMonitoring()

        monitoringTask = Task {
            var previousPermission = await checker.checkPermission()

            while !Task.isCancelled {
                do {
                    try await clock.sleep(for: .seconds(interval))
                } catch {
                    // Clock sleep was cancelled
                    break
                }

                let currentPermission = await checker.checkPermission()

                // Notify delegate only if permission changed to false
                if previousPermission && !currentPermission {
                    delegate?.permissionRevoked()
                }

                previousPermission = currentPermission
            }
        }
    }

    /// Stop permission monitoring
    public func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }
}
