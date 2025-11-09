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

    // Normalize category name to match from available descriptors
    func normalizeCategory(_ raw: String, descriptors: [LLMCategoryDescriptor]) -> String {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return descriptors.first?.name ?? "" }
        let normalized = cleaned.lowercased()

        // Try exact match first
        if let match = descriptors.first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }) {
            return match.name
        }

        // Check for idle category variations
        if let idle = descriptors.first(where: { $0.isIdle }) {
            let idleLabels = ["idle", "idle time", idle.name.lowercased()]
            if idleLabels.contains(normalized) {
                return idle.name
            }
        }

        // Fallback to first category or cleaned input
        return descriptors.first?.name ?? cleaned
    }

    // Parse JSON response, attempting to extract JSON from markdown code blocks or surrounding text
    func parseJSONResponse<T: Codable>(_ type: T.Type, from data: Data) throws -> T {
        // First try direct parsing
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            // Try to extract JSON from the response (handles cases where LLM wraps JSON in text)
            guard let responseString = String(data: data, encoding: .utf8) else {
                throw error
            }

            // Look for JSON object between curly braces
            if let startIndex = responseString.firstIndex(of: "{"),
               let endIndex = responseString.lastIndex(of: "}") {
                let jsonSubstring = responseString[startIndex...endIndex]
                if let jsonData = jsonSubstring.data(using: .utf8) {
                    return try JSONDecoder().decode(type, from: jsonData)
                }
            }

            // Look for JSON array between square brackets
            if let startIndex = responseString.firstIndex(of: "["),
               let endIndex = responseString.lastIndex(of: "]") {
                let jsonSubstring = responseString[startIndex...endIndex]
                if let jsonData = jsonSubstring.data(using: .utf8) {
                    return try JSONDecoder().decode(type, from: jsonData)
                }
            }

            throw error
        }
    }

    // Calculate exponential backoff delay for retries
    func exponentialBackoffDelay(attempt: Int, baseDelay: TimeInterval = 2.0) -> TimeInterval {
        return pow(2.0, Double(attempt)) * baseDelay
    }
}
