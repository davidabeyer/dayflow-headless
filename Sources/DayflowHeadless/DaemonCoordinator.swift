import Foundation

public final class DaemonCoordinator {
    private let stateQueue = DispatchQueue(label: "com.dayflow.state")
    private var _isRecording = false

    public var isRecording: Bool {
        stateQueue.sync { _isRecording }
    }

    public init() {}

    public func setRecording(_ value: Bool) {
        stateQueue.sync { _isRecording = value }
    }

    public func shutdown() {
        setRecording(false)
    }

    /// Returns true if running on macOS 15 (Sequoia) or later
    public func isRunningOnSequoia() -> Bool {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return version.majorVersion >= 15
    }
}
