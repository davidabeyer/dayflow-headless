import Foundation

public enum ConfigError: Error, Equatable {
    case fileNotFound(String)
    case invalidJson
    case missingRequiredField(String)
    case invalidHeaderName(String)
    case invalidHeaderValue(key: String)
}

public final class ConfigManager {

    /// Load configuration from a file path
    public static func load(from path: URL) throws -> Config {
        let data: Data
        do {
            data = try Data(contentsOf: path)
        } catch {
            throw ConfigError.fileNotFound(path.path)
        }

        let decoder = JSONDecoder()
        var config: Config

        do {
            config = try decoder.decode(Config.self, from: data)
        } catch {
            throw error
        }

        // Validate webhook headers
        for (key, value) in config.webhook.headers {
            guard HeaderValidator.isValidName(key) else {
                throw ConfigError.invalidHeaderName(key)
            }
            guard HeaderValidator.isValidValue(value) else {
                throw ConfigError.invalidHeaderValue(key: key)
            }
        }

        // Check for environment variable override
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
            config = Config(
                geminiApiKey: envKey,
                webhook: config.webhook,
                recording: config.recording,
                analysis: config.analysis,
                database: config.database
            )
        }

        return config
    }

    /// Load configuration from default path (~/.dayflow/config.json)
    public static func loadDefault() throws -> Config {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".dayflow/config.json")
        return try load(from: configPath)
    }
}
