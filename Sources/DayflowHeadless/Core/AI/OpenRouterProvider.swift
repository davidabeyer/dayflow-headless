//
//  OpenRouterProvider.swift
//  DayflowHeadless
//
//  OpenRouter API provider using Gemini models
//

import Foundation

final class OpenRouterProvider: LLMProvider {
    private let apiKey: String
    private let model: String
    private let baseURL = "https://openrouter.ai/api/v1/chat/completions"
    
    init(apiKey: String, model: String = "google/gemini-2.5-pro") {
        self.apiKey = apiKey
        self.model = model
    }
    
    func transcribeVideo(videoData: Data, mimeType: String, prompt: String, batchStartTime: Date, videoDuration: TimeInterval, batchId: Int64?) async throws -> (observations: [Observation], log: LLMCall) {
        let callStart = Date()
        
        // Encode video as base64
        let base64Video = videoData.base64EncodedString()
        let dataURL = "data:\(mimeType);base64,\(base64Video)"
        
        // Build the transcription prompt
        let promptSections = GeminiPromptSections(overrides: GeminiPromptPreferences.load())
        let transcriptionPrompt = """
        You are analyzing a screen recording. Describe what the user is doing in detail.
        
        \(promptSections.detailedSummary)
        
        For each distinct activity segment, provide:
        - Start timestamp (MM:SS from video start)
        - End timestamp (MM:SS from video start)
        - Detailed description of the activity
        
        Format your response as JSON array:
        [
          {
            "start": "00:00",
            "end": "00:30",
            "observation": "User opened VS Code and edited file.swift"
          }
        ]
        """
        
        // Build request
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": transcriptionPrompt],
                        ["type": "video_url", "video_url": ["url": dataURL]]
                    ]
                ]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("dayflow-headless/1.0", forHTTPHeaderField: "HTTP-Referer")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let latency = Date().timeIntervalSince(callStart)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenRouter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        let responseString = String(data: data, encoding: .utf8) ?? ""
        
        let log = LLMCall(
            timestamp: Date(),
            latency: latency,
            input: transcriptionPrompt,
            output: responseString
        )
        
        guard httpResponse.statusCode == 200 else {
            print("❌ [OpenRouter] Error \(httpResponse.statusCode): \(responseString)")
            throw NSError(domain: "OpenRouter", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: responseString])
        }
        
        // Parse response
        let observations = try parseTranscriptionResponse(responseString, batchStartTime: batchStartTime, videoDuration: videoDuration, batchId: batchId)
        
        print("✅ [OpenRouter] Transcribed \(observations.count) observations in \(String(format: "%.1f", latency))s")
        
        return (observations, log)
    }
    
    private func parseTranscriptionResponse(_ response: String, batchStartTime: Date, videoDuration: TimeInterval, batchId: Int64?) throws -> [Observation] {
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return []
        }
        
        // Extract JSON array from content (may be wrapped in markdown)
        var jsonContent = content
        if let start = content.range(of: "["), let end = content.range(of: "]", options: .backwards) {
            jsonContent = String(content[start.lowerBound...end.upperBound])
        }
        
        guard let jsonData = jsonContent.data(using: .utf8),
              let segments = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            // If can't parse as JSON, return single observation with full content
            let batchStartTs = Int(batchStartTime.timeIntervalSince1970)
            let batchEndTs = batchStartTs + Int(videoDuration)
            return [Observation(
                id: nil,
                batchId: batchId ?? 0,
                startTs: batchStartTs,
                endTs: batchEndTs,
                observation: content,
                metadata: nil,
                llmModel: model,
                createdAt: Date()
            )]
        }
        
        var observations: [Observation] = []
        let batchStartTs = Int(batchStartTime.timeIntervalSince1970)
        
        for segment in segments {
            guard let startStr = segment["start"] as? String,
                  let endStr = segment["end"] as? String,
                  let observation = segment["observation"] as? String else { continue }
            
            let startOffset = parseVideoTimestamp(startStr)
            let endOffset = parseVideoTimestamp(endStr)
            
            observations.append(Observation(
                id: nil,
                batchId: batchId ?? 0,
                startTs: batchStartTs + startOffset,
                endTs: batchStartTs + endOffset,
                observation: observation,
                metadata: nil,
                llmModel: model,
                createdAt: Date()
            ))
        }
        
        return observations
    }
    
    func generateActivityCards(observations: [Observation], context: ActivityGenerationContext, batchId: Int64?) async throws -> (cards: [ActivityCardData], log: LLMCall) {
        let callStart = Date()
        
        // Convert observations to text
        let transcriptText = observations.map { obs in
            let startTime = formatTimestampForPrompt(obs.startTs)
            let endTime = formatTimestampForPrompt(obs.endTs)
            return "[\(startTime) - \(endTime)]: \(obs.observation)"
        }.joined(separator: "\n")
        
        let promptSections = GeminiPromptSections(overrides: GeminiPromptPreferences.load())
        
        // Existing cards as JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let existingCardsJSON = try encoder.encode(context.existingCards)
        let existingCardsString = String(data: existingCardsJSON, encoding: .utf8) ?? "[]"
        
        let prompt = """
        You are a digital anthropologist synthesizing activity logs into timeline cards.
        
        \(promptSections.title)
        
        \(promptSections.summary)
        
        \(promptSections.detailedSummary)
        
        Previous cards: \(existingCardsString)
        New observations: \(transcriptText)
        
        Return ONLY a JSON array with this structure:
        [
          {
            "startTime": "1:12 AM",
            "endTime": "1:30 AM",
            "category": "",
            "subcategory": "",
            "title": "",
            "summary": "",
            "detailedSummary": "",
            "distractions": [],
            "appSites": {"primary": "", "secondary": ""}
          }
        ]
        """
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let latency = Date().timeIntervalSince(callStart)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenRouter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        let responseString = String(data: data, encoding: .utf8) ?? ""
        
        let log = LLMCall(
            timestamp: Date(),
            latency: latency,
            input: prompt,
            output: responseString
        )
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "OpenRouter", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: responseString])
        }
        
        // Parse cards from response
        guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = jsonResponse["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return ([], log)
        }
        
        // Extract JSON array
        var jsonContent = content
        if let start = content.range(of: "["), let end = content.range(of: "]", options: .backwards) {
            jsonContent = String(content[start.lowerBound...end.upperBound])
        }
        
        guard let cardsData = jsonContent.data(using: .utf8) else {
            return ([], log)
        }
        
        let cards = try JSONDecoder().decode([ActivityCardData].self, from: cardsData)
        
        print("✅ [OpenRouter] Generated \(cards.count) cards in \(String(format: "%.1f", latency))s")
        
        return (cards, log)
    }
    
    func generateText(prompt: String) async throws -> (text: String, log: LLMCall) {
        let callStart = Date()
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let latency = Date().timeIntervalSince(callStart)
        
        let responseString = String(data: data, encoding: .utf8) ?? ""
        
        let log = LLMCall(
            timestamp: Date(),
            latency: latency,
            input: prompt,
            output: responseString
        )
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return ("", log)
        }
        
        return (content, log)
    }
}
