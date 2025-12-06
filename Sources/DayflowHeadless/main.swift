import Foundation

// MARK: - Main Entry Point

func main() {
    print("dayflow-headless starting...")

    // Create coordinator first
    let coordinator = DaemonCoordinator()

    // Set up async-signal-safe signal handler for graceful shutdown
    let signalHandler = SignalHandler {
        print("\nReceived shutdown signal, cleaning up...")
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

    // Load configuration
    let config: Config
    do {
        config = try ConfigManager.loadDefault()
        print("✓ Configuration loaded")
    } catch {
        print("❌ Failed to load configuration: \(error)")
        print("   Create ~/.dayflow/config.json with geminiApiKey and webhook.url")
        exit(1)
    }

    print("✓ Gemini API key configured")
    print("✓ Webhook URL: \(redactURL(config.webhook.url))")

    // Start recording
    coordinator.setRecording(true)
    print("✓ Recording started at \(config.recording.fps) FPS (\(config.recording.resolution) resolution)")

    // Keep the daemon running
    // Note: signalHandler is retained here to keep dispatch sources alive
    _ = signalHandler
    print("\ndayflow-headless is running. Press Ctrl+C to stop.")
    RunLoop.main.run()
}

main()
