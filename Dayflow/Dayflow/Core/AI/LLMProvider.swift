//
//  LLMProvider.swift
//  Dayflow
//

import Foundation

protocol LLMProvider {
    func transcribeVideo(videoData: Data, mimeType: String, prompt: String, batchStartTime: Date, videoDuration: TimeInterval, batchId: Int64?) async throws -> (observations: [Observation], log: LLMCall)
    func generateActivityCards(observations: [Observation], context: ActivityGenerationContext, batchId: Int64?) async throws -> (cards: [ActivityCardData], log: LLMCall)
}

struct ActivityGenerationContext {
    let batchObservations: [Observation]
    let existingCards: [ActivityCardData]  // Cards that overlap with current analysis window
    let currentTime: Date  // Current time to prevent future timestamps
    let categories: [LLMCategoryDescriptor]
}

enum LLMProviderType: Codable {
    case geminiDirect
    case dayflowBackend(endpoint: String = "https://api.dayflow.app")
    case ollamaLocal(endpoint: String = "http://localhost:11434")
    case chatGPTClaude
}


struct AppSites: Codable {
    let primary: String?
    let secondary: String?
}

struct ActivityCardData: Codable {
    let startTime: String
    let endTime: String
    let category: String
    let subcategory: String
    let title: String
    let summary: String
    let detailedSummary: String
    let distractions: [Distraction]?
    let appSites: AppSites?
}

// Distraction is defined in StorageManager.swift
// LLMCall is defined in StorageManager.swift


extension LLMProvider {
    // Convert "MM:SS" or "HH:MM:SS" to seconds from video start
    func parseVideoTimestamp(_ timestamp: String) -> Int {
        let components = timestamp.components(separatedBy: ":")

        if components.count == 3 {
            // HH:MM:SS format
            guard let hours = Int(components[0]),
                  let minutes = Int(components[1]),
                  let seconds = Int(components[2]) else {
                return 0
            }
            return hours * 3600 + minutes * 60 + seconds
        } else if components.count == 2 {
            // MM:SS format
            guard let minutes = Int(components[0]),
                  let seconds = Int(components[1]) else {
                return 0
            }
            return minutes * 60 + seconds
        }

        return 0
    }

    // Convert Unix timestamp to "h:mm a" for prompts
    func formatTimestampForPrompt(_ unixTime: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(unixTime))
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    // Normalize a raw category string to match one of the configured categories
    func normalizeCategory(_ raw: String, descriptors: [LLMCategoryDescriptor]) -> String {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return descriptors.first?.name ?? "" }
        let normalized = cleaned.lowercased()
        if let match = descriptors.first(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized }) {
            return match.name
        }
        if let idle = descriptors.first(where: { $0.isIdle }) {
            let idleLabels = ["idle", "idle time", idle.name.lowercased()]
            if idleLabels.contains(normalized) {
                return idle.name
            }
        }
        return descriptors.first?.name ?? cleaned
    }

    // Format category descriptors as a prompt section
    func formatCategoriesSection(from descriptors: [LLMCategoryDescriptor]) -> String {
        guard !descriptors.isEmpty else {
            return "USER CATEGORIES: No categories configured. Use consistent labels based on the activity story."
        }

        let allowed = descriptors.map { "\"\($0.name)\"" }.joined(separator: ", ")
        var lines: [String] = ["USER CATEGORIES (choose exactly one label):"]

        for (index, descriptor) in descriptors.enumerated() {
            var desc = descriptor.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if descriptor.isIdle && desc.isEmpty {
                desc = "Use when the user is idle for most of this period."
            }
            let suffix = desc.isEmpty ? "" : " — \(desc)"
            lines.append("\(index + 1). \"\(descriptor.name)\"\(suffix)")
        }

        if let idle = descriptors.first(where: { $0.isIdle }) {
            lines.append("Only use \"\(idle.name)\" when the user is idle for more than half of the timeframe. Otherwise pick the closest non-idle label.")
        }

        lines.append("Return the category exactly as written. Allowed values: [\(allowed)].")
        return lines.joined(separator: "\n")
    }
}
