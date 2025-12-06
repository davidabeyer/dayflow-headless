import Foundation

// MARK: - Signal Handling

var coordinator: DaemonCoordinator?

func handleSignal(_ signal: Int32) {
    print("\nReceived signal \(signal), shutting down...")
    coordinator?.shutdown()
    exit(0)
}

// MARK: - Main Entry Point

func main() {
    print("dayflow-headless starting...")

    // Set up signal handlers for graceful shutdown
    signal(SIGTERM, handleSignal)
    signal(SIGINT, handleSignal)

    // Create coordinator
    coordinator = DaemonCoordinator()

    // Check macOS version
    if coordinator!.isRunningOnSequoia() {
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
    print("✓ Webhook URL: \(config.webhook.url)")

    // Start recording
    coordinator!.setRecording(true)
    print("✓ Recording started at \(config.recording.fps) FPS (\(config.recording.resolution) resolution)")

    // Keep the daemon running
    print("\ndayflow-headless is running. Press Ctrl+C to stop.")
    RunLoop.main.run()
}

main()
