//
//  Stubs.swift
//  DayflowHeadless
//
//  Stub implementations for UI/analytics components not needed in headless daemon.
//

import Foundation

// MARK: - Shared Config Holder

/// Holds the loaded config for use by stubs that need API key
enum SharedConfig {
    static var geminiApiKey: String?
}

// MARK: - AppState Replacement

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    @Published var isRecording: Bool = false
    private init() {}
    func enablePersistence() {}
    func getSavedPreference() -> Bool? { nil }
}

// MARK: - Analytics Stubs

final class AnalyticsService: @unchecked Sendable {
    static let shared = AnalyticsService()
    func capture(_ event: String, _ properties: [String: Any]? = nil) {}
    func withSampling(probability: Double, _ action: () -> Void) {}
    func secondsBucket(_ seconds: Double) -> String { "\(Int(seconds))s" }
}

// MARK: - Sentry Stubs

enum SentryHelper {
    static func addBreadcrumb(_ breadcrumb: Any) {}
    static func captureError(_ error: Error) {
        print("[Sentry stub] Error: \(error.localizedDescription)")
    }
}

// MARK: - Storage Stubs

struct StoragePreferences {
    static func load() -> StoragePreferences { StoragePreferences() }
    var maxStorageGB: Int { 50 }
    var retentionDays: Int { 30 }
    static var recordingsLimitBytes: Int64 {
        get { 50 * 1024 * 1024 * 1024 }
        set { /* ignore */ }
    }
}

final class TimelapseStorageManager {
    static let shared = TimelapseStorageManager()
    func cleanupOldFiles() {}
    func purgeIfNeeded() {}
}

enum StoragePathMigrator {
    static func migrateIfNeeded() {}
}

enum UserDefaultsMigrator {
    static func migrateIfNeeded() {}
}

struct CategoryPersistence {
    static func loadCategories() -> [LLMCategoryDescriptor] { [] }
    static func loadPersistedCategories() -> [LLMCategoryDescriptor] { [] }
}

enum CategoryStore {
    static func loadCategories() -> [LLMCategoryDescriptor] { [] }
    static func descriptorsForLLM() -> [LLMCategoryDescriptor] { [] }
}

// MARK: - Security Stubs

final class KeychainManager {
    static let shared = KeychainManager()
    
    func getGeminiAPIKey() -> String? {
        SharedConfig.geminiApiKey
    }
    
    func retrieve(for key: String) -> String? {
        if key == "gemini" {
            return SharedConfig.geminiApiKey
        }
        return nil
    }
}

// MARK: - Provider Stubs (only using GeminiDirect)

final class DayflowBackendProvider: LLMProvider {
    init(token: String? = nil, endpoint: String = "") {}
    func transcribeVideo(videoData: Data, mimeType: String, prompt: String, batchStartTime: Date, videoDuration: TimeInterval, batchId: Int64?) async throws -> (observations: [Observation], log: LLMCall) {
        fatalError("DayflowBackendProvider not supported in headless")
    }
    func generateActivityCards(observations: [Observation], context: ActivityGenerationContext, batchId: Int64?) async throws -> (cards: [ActivityCardData], log: LLMCall) {
        fatalError("DayflowBackendProvider not supported in headless")
    }
    func generateText(prompt: String) async throws -> (text: String, log: LLMCall) {
        fatalError("DayflowBackendProvider not supported in headless")
    }
}

final class OllamaProvider: LLMProvider {
    init(endpoint: String = "") {}
    func transcribeVideo(videoData: Data, mimeType: String, prompt: String, batchStartTime: Date, videoDuration: TimeInterval, batchId: Int64?) async throws -> (observations: [Observation], log: LLMCall) {
        fatalError("OllamaProvider not supported in headless")
    }
    func generateActivityCards(observations: [Observation], context: ActivityGenerationContext, batchId: Int64?) async throws -> (cards: [ActivityCardData], log: LLMCall) {
        fatalError("OllamaProvider not supported in headless")
    }
    func generateText(prompt: String) async throws -> (text: String, log: LLMCall) {
        fatalError("OllamaProvider not supported in headless")
    }
}

enum ChatCLITool: String, Codable {
    case chatgpt
    case claude
    case codex
}

final class ChatCLIProvider: LLMProvider {
    init(tool: ChatCLITool) {}
    func transcribeVideo(videoData: Data, mimeType: String, prompt: String, batchStartTime: Date, videoDuration: TimeInterval, batchId: Int64?) async throws -> (observations: [Observation], log: LLMCall) {
        fatalError("ChatCLIProvider not supported in headless")
    }
    func generateActivityCards(observations: [Observation], context: ActivityGenerationContext, batchId: Int64?) async throws -> (cards: [ActivityCardData], log: LLMCall) {
        fatalError("ChatCLIProvider not supported in headless")
    }
    func generateText(prompt: String) async throws -> (text: String, log: LLMCall) {
        fatalError("ChatCLIProvider not supported in headless")
    }
}

// MARK: - LLM Types

struct LLMCategoryDescriptor: Codable {
    let name: String
    let description: String?
    let isIdle: Bool
    init(name: String, description: String? = nil, isIdle: Bool = false) {
        self.name = name
        self.description = description
        self.isIdle = isIdle
    }
}
