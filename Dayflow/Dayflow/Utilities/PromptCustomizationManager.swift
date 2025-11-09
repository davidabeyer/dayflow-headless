//
//  PromptCustomizationManager.swift
//  Dayflow
//
//  Generic prompt customization state to eliminate code duplication
//  between Gemini and Ollama prompt handling.
//

import Foundation
import SwiftUI

/// Represents the state for a single prompt customization field
struct PromptFieldState {
    var isEnabled: Bool
    var text: String
    let defaultText: String

    init(isEnabled: Bool = false, text: String = "", defaultText: String) {
        self.isEnabled = isEnabled
        self.text = text.isEmpty ? defaultText : text
        self.defaultText = defaultText
    }
}

/// Protocol for prompt override types (GeminiPromptOverrides, OllamaPromptOverrides)
protocol PromptOverrides {
    var isEmpty: Bool { get }
}

extension GeminiPromptOverrides: PromptOverrides {}
extension OllamaPromptOverrides: PromptOverrides {}

/// Generic manager for prompt customization state and persistence
struct PromptCustomizationState<Overrides: PromptOverrides & Codable> {
    var isLoaded: Bool = false
    var isUpdating: Bool = false
    var fields: [String: PromptFieldState] = [:]

    private let userDefaultsKey: String

    init(userDefaultsKey: String) {
        self.userDefaultsKey = userDefaultsKey
    }

    mutating func load<T>(
        _ overridesType: T.Type,
        extractFields: (T) -> [String: PromptFieldState]
    ) where T == Overrides {
        guard !isLoaded else { return }
        isUpdating = true

        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let overrides = try? JSONDecoder().decode(overridesType, from: data) {
            fields = extractFields(overrides)
        }

        isUpdating = false
        isLoaded = true
    }

    func persist<T>(_ overridesType: T.Type, createOverrides: ([String: PromptFieldState]) -> T) where T == Overrides {
        guard isLoaded, !isUpdating else { return }

        let overrides = createOverrides(fields)

        if overrides.isEmpty {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        } else {
            if let data = try? JSONEncoder().encode(overrides) {
                UserDefaults.standard.set(data, forKey: userDefaultsKey)
            }
        }
    }

    mutating func reset(defaultFields: [String: PromptFieldState]) {
        isUpdating = true
        fields = defaultFields
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        isUpdating = false
        isLoaded = true
    }
}

/// Helper to normalize override values
func normalizedPromptOverride(text: String, enabled: Bool) -> String? {
    guard enabled else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

/// Configuration for a prompt field in the UI
struct PromptFieldConfig {
    let key: String
    let heading: String
    let description: String
}

// MARK: - Provider-specific configurations

enum GeminiPromptConfig {
    static let userDefaultsKey = "geminiPromptOverrides"

    static let fields: [PromptFieldConfig] = [
        PromptFieldConfig(
            key: "title",
            heading: "Card titles",
            description: "Shape how card titles read and tweak the example list."
        ),
        PromptFieldConfig(
            key: "summary",
            heading: "Card summaries",
            description: "Control tone and style for the summary field."
        ),
        PromptFieldConfig(
            key: "detailed",
            heading: "Detailed summaries",
            description: "Define the minute-by-minute breakdown format and examples."
        )
    ]

    static func defaultFields() -> [String: PromptFieldState] {
        [
            "title": PromptFieldState(defaultText: GeminiPromptDefaults.titleBlock),
            "summary": PromptFieldState(defaultText: GeminiPromptDefaults.summaryBlock),
            "detailed": PromptFieldState(defaultText: GeminiPromptDefaults.detailedSummaryBlock)
        ]
    }

    static func extractFields(from overrides: GeminiPromptOverrides) -> [String: PromptFieldState] {
        var fields = defaultFields()

        if let title = overrides.titleBlock?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            fields["title"] = PromptFieldState(isEnabled: true, text: title, defaultText: GeminiPromptDefaults.titleBlock)
        }
        if let summary = overrides.summaryBlock?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
            fields["summary"] = PromptFieldState(isEnabled: true, text: summary, defaultText: GeminiPromptDefaults.summaryBlock)
        }
        if let detailed = overrides.detailedBlock?.trimmingCharacters(in: .whitespacesAndNewlines), !detailed.isEmpty {
            fields["detailed"] = PromptFieldState(isEnabled: true, text: detailed, defaultText: GeminiPromptDefaults.detailedSummaryBlock)
        }

        return fields
    }

    static func createOverrides(from fields: [String: PromptFieldState]) -> GeminiPromptOverrides {
        GeminiPromptOverrides(
            titleBlock: normalizedPromptOverride(
                text: fields["title"]?.text ?? "",
                enabled: fields["title"]?.isEnabled ?? false
            ),
            summaryBlock: normalizedPromptOverride(
                text: fields["summary"]?.text ?? "",
                enabled: fields["summary"]?.isEnabled ?? false
            ),
            detailedBlock: normalizedPromptOverride(
                text: fields["detailed"]?.text ?? "",
                enabled: fields["detailed"]?.isEnabled ?? false
            )
        )
    }
}

enum OllamaPromptConfig {
    static let userDefaultsKey = "ollamaPromptOverrides"

    static let fields: [PromptFieldConfig] = [
        PromptFieldConfig(
            key: "summary",
            heading: "Timeline summaries",
            description: "Control how the local model writes its 2-3 sentence card summaries."
        ),
        PromptFieldConfig(
            key: "title",
            heading: "Card titles",
            description: "Adjust the tone and examples for local title generation."
        )
    ]

    static func defaultFields() -> [String: PromptFieldState] {
        [
            "summary": PromptFieldState(defaultText: OllamaPromptDefaults.summaryBlock),
            "title": PromptFieldState(defaultText: OllamaPromptDefaults.titleBlock)
        ]
    }

    static func extractFields(from overrides: OllamaPromptOverrides) -> [String: PromptFieldState] {
        var fields = defaultFields()

        if let summary = overrides.summaryBlock?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
            fields["summary"] = PromptFieldState(isEnabled: true, text: summary, defaultText: OllamaPromptDefaults.summaryBlock)
        }
        if let title = overrides.titleBlock?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            fields["title"] = PromptFieldState(isEnabled: true, text: title, defaultText: OllamaPromptDefaults.titleBlock)
        }

        return fields
    }

    static func createOverrides(from fields: [String: PromptFieldState]) -> OllamaPromptOverrides {
        OllamaPromptOverrides(
            summaryBlock: normalizedPromptOverride(
                text: fields["summary"]?.text ?? "",
                enabled: fields["summary"]?.isEnabled ?? false
            ),
            titleBlock: normalizedPromptOverride(
                text: fields["title"]?.text ?? "",
                enabled: fields["title"]?.isEnabled ?? false
            )
        )
    }
}
