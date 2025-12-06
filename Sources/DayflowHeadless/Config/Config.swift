import Foundation

public struct Config: Codable {
    public var geminiApiKey: String
    public let webhook: WebhookConfig
    public var recording: RecordingConfig
    public var analysis: AnalysisConfig
    public var database: DatabaseConfig

    public init(
        geminiApiKey: String,
        webhook: WebhookConfig,
        recording: RecordingConfig = RecordingConfig(),
        analysis: AnalysisConfig = AnalysisConfig(),
        database: DatabaseConfig = DatabaseConfig()
    ) {
        self.geminiApiKey = geminiApiKey
        self.webhook = webhook
        self.recording = recording
        self.analysis = analysis
        self.database = database
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        geminiApiKey = try container.decode(String.self, forKey: .geminiApiKey)
        webhook = try container.decode(WebhookConfig.self, forKey: .webhook)
        recording = try container.decodeIfPresent(RecordingConfig.self, forKey: .recording) ?? RecordingConfig()
        analysis = try container.decodeIfPresent(AnalysisConfig.self, forKey: .analysis) ?? AnalysisConfig()
        database = try container.decodeIfPresent(DatabaseConfig.self, forKey: .database) ?? DatabaseConfig()
    }
}

public struct WebhookConfig: Codable {
    public let url: String
    public var retryStrategy: RetryStrategy
    public var sendJson: Bool
    public var sendMarkdown: Bool
    public var headers: [String: String]

    public init(
        url: String,
        retryStrategy: RetryStrategy = RetryStrategy(),
        sendJson: Bool = true,
        sendMarkdown: Bool = true,
        headers: [String: String] = [:]
    ) {
        self.url = url
        self.retryStrategy = retryStrategy
        self.sendJson = sendJson
        self.sendMarkdown = sendMarkdown
        self.headers = headers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decode(String.self, forKey: .url)
        retryStrategy = try container.decodeIfPresent(RetryStrategy.self, forKey: .retryStrategy) ?? RetryStrategy()
        sendJson = try container.decodeIfPresent(Bool.self, forKey: .sendJson) ?? true
        sendMarkdown = try container.decodeIfPresent(Bool.self, forKey: .sendMarkdown) ?? true
        headers = try container.decodeIfPresent([String: String].self, forKey: .headers) ?? [:]
    }
}

public struct RetryStrategy: Codable {
    public var initialDelaySeconds: Int
    public var maxDelaySeconds: Int
    public var multiplier: Int
    public var maxAttempts: Int

    public init(
        initialDelaySeconds: Int = 5,
        maxDelaySeconds: Int = 300,
        multiplier: Int = 2,
        maxAttempts: Int = 10
    ) {
        self.initialDelaySeconds = initialDelaySeconds
        self.maxDelaySeconds = maxDelaySeconds
        self.multiplier = multiplier
        self.maxAttempts = maxAttempts
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        initialDelaySeconds = try container.decodeIfPresent(Int.self, forKey: .initialDelaySeconds) ?? 5
        maxDelaySeconds = try container.decodeIfPresent(Int.self, forKey: .maxDelaySeconds) ?? 300
        multiplier = try container.decodeIfPresent(Int.self, forKey: .multiplier) ?? 2
        maxAttempts = try container.decodeIfPresent(Int.self, forKey: .maxAttempts) ?? 10
    }
}

public struct RecordingConfig: Codable {
    public var fps: Int
    public var resolution: String

    public init(fps: Int = 1, resolution: String = "low") {
        self.fps = fps
        self.resolution = resolution
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fps = try container.decodeIfPresent(Int.self, forKey: .fps) ?? 1
        resolution = try container.decodeIfPresent(String.self, forKey: .resolution) ?? "low"
    }
}

public struct AnalysisConfig: Codable {
    public var batchIntervalMinutes: Int

    public init(batchIntervalMinutes: Int = 15) {
        self.batchIntervalMinutes = batchIntervalMinutes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        batchIntervalMinutes = try container.decodeIfPresent(Int.self, forKey: .batchIntervalMinutes) ?? 15
    }
}

public struct DatabaseConfig: Codable {
    public var walMode: Bool

    public init(walMode: Bool = true) {
        self.walMode = walMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        walMode = try container.decodeIfPresent(Bool.self, forKey: .walMode) ?? true
    }
}
