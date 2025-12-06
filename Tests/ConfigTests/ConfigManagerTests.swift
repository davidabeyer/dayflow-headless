import XCTest
@testable import DayflowHeadless

final class ConfigManagerTests: XCTestCase {

    var testConfigPath: URL!

    override func setUpWithError() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dayflow-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        testConfigPath = tempDir.appendingPathComponent("config.json")
    }

    override func tearDownWithError() throws {
        if let path = testConfigPath?.deletingLastPathComponent() {
            try? FileManager.default.removeItem(at: path)
        }
    }

    func testLoadValidConfig() throws {
        let validConfig = """
        {
            "geminiApiKey": "test-key-12345",
            "webhook": {
                "url": "https://example.com/hook"
            }
        }
        """
        try validConfig.write(to: testConfigPath, atomically: true, encoding: .utf8)

        let config = try ConfigManager.load(from: testConfigPath)
        XCTAssertEqual(config.geminiApiKey, "test-key-12345")
        XCTAssertEqual(config.webhook.url, "https://example.com/hook")
    }

    func testInvalidJson() throws {
        let invalidJson = "{ this is not valid json }"
        try invalidJson.write(to: testConfigPath, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try ConfigManager.load(from: testConfigPath))
    }

    func testDefaultValues() throws {
        let minimalConfig = """
        {
            "geminiApiKey": "test-key",
            "webhook": {
                "url": "https://example.com/hook"
            }
        }
        """
        try minimalConfig.write(to: testConfigPath, atomically: true, encoding: .utf8)

        let config = try ConfigManager.load(from: testConfigPath)
        XCTAssertEqual(config.recording.fps, 1, "Default FPS should be 1")
        XCTAssertEqual(config.recording.resolution, "low", "Default resolution should be low")
        XCTAssertEqual(config.webhook.retryStrategy.initialDelaySeconds, 5)
        XCTAssertTrue(config.database.walMode, "Default WAL mode should be true")
    }

    func testEnvOverrideGeminiKey() throws {
        let configWithPlaceholder = """
        {
            "geminiApiKey": "placeholder",
            "webhook": {
                "url": "https://example.com/hook"
            }
        }
        """
        try configWithPlaceholder.write(to: testConfigPath, atomically: true, encoding: .utf8)

        setenv("GEMINI_API_KEY", "env-override-key", 1)
        defer { unsetenv("GEMINI_API_KEY") }

        let config = try ConfigManager.load(from: testConfigPath)
        XCTAssertEqual(config.geminiApiKey, "env-override-key", "Environment variable should override config")
    }

    // MARK: - Header Validation Tests

    func testRejectsInvalidHeaderValue() throws {
        let configWithCRLF = """
        {
            "geminiApiKey": "test-key",
            "webhook": {
                "url": "https://example.com/hook",
                "headers": {
                    "X-Custom": "value\\r\\nX-Injected: evil"
                }
            }
        }
        """
        try configWithCRLF.write(to: testConfigPath, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try ConfigManager.load(from: testConfigPath)) { error in
            guard case ConfigError.invalidHeaderValue(key: _) = error else {
                XCTFail("Expected invalidHeaderValue error, got: \(error)")
                return
            }
        }
    }
}
