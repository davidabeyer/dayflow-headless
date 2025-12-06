import Foundation

/// Async-signal-safe signal handler using DispatchSourceSignal.
///
/// Unlike the C signal() function, this implementation:
/// - Uses GCD dispatch sources for signal handling
/// - Calls handlers on a dispatch queue (not from signal context)
/// - Allows any code in the shutdown handler (including non-async-signal-safe code)
///
/// This avoids undefined behavior from calling Swift/Objective-C code in signal handlers.
public final class SignalHandler {
    private let shutdownHandler: () -> Void
    private var sigintSource: DispatchSourceSignal?
    private var sigtermSource: DispatchSourceSignal?
    private let queue = DispatchQueue(label: "com.dayflow.signal-handler")

    /// Initialize with a shutdown handler that will be called on SIGINT or SIGTERM.
    /// - Parameter shutdownHandler: Closure to call when shutdown signal is received
    public init(shutdownHandler: @escaping () -> Void) {
        self.shutdownHandler = shutdownHandler
    }

    /// Start listening for SIGINT and SIGTERM signals.
    public func start() {
        // Ignore default signal handling - we'll handle via dispatch source
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)

        // Create dispatch sources for signals
        sigintSource = createSignalSource(for: SIGINT)
        sigtermSource = createSignalSource(for: SIGTERM)

        sigintSource?.resume()
        sigtermSource?.resume()
    }

    /// Stop listening for signals.
    public func stop() {
        sigintSource?.cancel()
        sigtermSource?.cancel()
        sigintSource = nil
        sigtermSource = nil

        // Restore default signal handling
        signal(SIGINT, SIG_DFL)
        signal(SIGTERM, SIG_DFL)
    }

    private func createSignalSource(for sig: Int32) -> DispatchSourceSignal {
        let source = DispatchSource.makeSignalSource(signal: sig, queue: queue)
        source.setEventHandler { [weak self] in
            self?.shutdownHandler()
        }
        return source
    }

    deinit {
        stop()
    }
}
