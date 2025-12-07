import Foundation

// MARK: - Global State (kept alive for daemon lifetime)

/// Global screen recorder - must be retained for daemon lifetime
@MainActor var globalRecorder: ScreenRecorder?

// MARK: - Main Entry Point

func main() {
    print("dayflow-headless starting...")

    // Load configuration first
    let config: Config
    do {
        config = try ConfigManager.loadDefault()
        print("✓ Configuration loaded")
    } catch {
        print("❌ Failed to load configuration: \(error)")
        print("   Create ~/.dayflow/config.json with geminiApiKey and webhook.url")
        exit(1)
    }

    // Wire up API key for Gemini provider
    SharedConfig.geminiApiKey = config.geminiApiKey
    print("✓ Gemini API key configured")
    print("✓ Webhook URL: \(redactURL(config.webhook.url))")

    // Create coordinator
    let coordinator = DaemonCoordinator()

    // Set up async-signal-safe signal handler for graceful shutdown
    let signalHandler = SignalHandler {
        print("\nReceived shutdown signal, cleaning up...")
        Task { @MainActor in
            AppState.shared.isRecording = false
            globalRecorder = nil
        }
        AnalysisManager.shared.stopAnalysisJob()
        coordinator.shutdown()
        exit(0)
    }
    signalHandler.start()

    // Check macOS version
    if coordinator.isRunningOnSequoia() {
        print("⚠️  Warning: Running on macOS 15 (Sequoia)")
        print("   Screen Recording permission requires weekly re-authorization.")
        print("   See: docs/sequoia-notes.md for details.")
    }

    // Initialize screen recorder on main actor
    Task { @MainActor in
        // Create screen recorder and store globally to prevent deallocation
        globalRecorder = ScreenRecorder(autoStart: false)

        // Start recording via AppState
        AppState.shared.isRecording = true
        print("✓ Recording started at \(config.recording.fps) FPS (\(config.recording.resolution) resolution)")

        // Start analysis manager
        AnalysisManager.shared.startAnalysisJob()
        print("✓ Analysis pipeline started (15-minute batches)")
    }

    // Keep the daemon running
    _ = signalHandler
    print("\ndayflow-headless is running. Press Ctrl+C to stop.")
    RunLoop.main.run()
}

main()
