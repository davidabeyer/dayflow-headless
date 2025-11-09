//
//  LocalLLMTestView.swift
//  Dayflow
//
//  Local LLM testing and engine selection
//

import SwiftUI
import Foundation

enum LocalEngine: String {
    case ollama
    case lmstudio
    case custom
}

struct LocalLLMTestView: View {
    @Binding var baseURL: String
    @Binding var modelId: String
    let engine: LocalEngine
    var showInputs: Bool = true
    let onTestComplete: (Bool) -> Void

    private let accentColor = Color(red: 0.25, green: 0.17, blue: 0)
    private let successAccentColor = Color(red: 0.34, green: 1, blue: 0.45)

    @State private var isTesting = false
    @State private var resultMessage: String?
    @State private var success: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showInputs {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Base URL")
                        .font(.custom("Nunito", size: 13))
                        .foregroundColor(.black.opacity(0.6))
                    TextField(engine == .lmstudio ? "http://localhost:1234" : "http://localhost:11434", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Model ID")
                        .font(.custom("Nunito", size: 13))
                        .foregroundColor(.black.opacity(0.6))
                    TextField(engine == .lmstudio ? "qwen2.5-vl-3b-instruct" : "qwen2.5vl:3b", text: $modelId)
                        .textFieldStyle(.roundedBorder)
                }
            }

            DayflowSurfaceButton(
                action: runTest,
                content: {
                    HStack(spacing: 8) {
                        if isTesting {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: success ? "checkmark.circle.fill" : "bolt.fill").font(.system(size: 14))
                        }
                        Text(isTesting ? "Testing..." : (success ? "Test Successful!" : "Test Local API")).font(.custom("Nunito", size: 14)).fontWeight(.semibold)
                    }
                },
                background: success ? successAccentColor.opacity(0.2) : accentColor,
                foreground: success ? .black : .white,
                borderColor: success ? successAccentColor.opacity(0.3) : .clear,
                cornerRadius: 8,
                horizontalPadding: 24,
                verticalPadding: 12,
                showOverlayStroke: !success
            )
            .disabled(isTesting)

            if let msg = resultMessage {
                Text(msg)
                    .font(.custom("Nunito", size: 13))
                    .foregroundColor(success ? .black.opacity(0.7) : Color(hex: "E91515"))
                    .padding(.vertical, 6)
                if !success {
                    Text("If you get stuck here, you can go back and choose the 'Bring your own key' option — it only takes a minute to set up.")
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.black.opacity(0.55))
                        .padding(.top, 2)
                }
            }
        }
    }

    private func runTest() {
        guard !isTesting else { return }
        isTesting = true
        success = false
        resultMessage = nil

        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            resultMessage = "Invalid base URL"
            isTesting = false
            onTestComplete(false)
            return
        }

        struct Req: Codable { let model: String; let messages: [Msg]; let max_tokens: Int }
        struct Msg: Codable { let role: String; let content: String }
        let req = Req(model: modelId, messages: [Msg(role: "user", content: "Say 'hello' and your model name.")], max_tokens: 50)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if engine == .lmstudio { request.setValue("Bearer lm-studio", forHTTPHeaderField: "Authorization") }
        request.httpBody = try? JSONEncoder().encode(req)
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.resultMessage = error.localizedDescription
                    self.isTesting = false
                    self.onTestComplete(false)
                    return
                }
                guard let http = response as? HTTPURLResponse, let data = data else {
                    self.resultMessage = "No response"; self.isTesting = false; self.onTestComplete(false); return
                }
                if http.statusCode == 200 {
                    // Success: don't print raw response body; keep UI clean
                    self.resultMessage = nil
                    self.success = true
                    self.isTesting = false
                    self.onTestComplete(true)
                } else {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    self.resultMessage = "HTTP \(http.statusCode): \(body)"
                    self.isTesting = false
                    self.onTestComplete(false)
                }
            }
        }.resume()
    }
}
