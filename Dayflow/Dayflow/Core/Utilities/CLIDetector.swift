//
//  CLIDetector.swift
//  Dayflow
//
//  CLI tool detection and validation
//

import Foundation

enum CLITool: String, CaseIterable {
    case codex
    case claude

    var displayName: String {
        switch self {
        case .codex: return "ChatGPT (Codex CLI)"
        case .claude: return "Claude Code"
        }
    }

    var shortName: String {
        switch self {
        case .codex: return "ChatGPT"
        case .claude: return "Claude"
        }
    }

    var subtitle: String {
        switch self {
        case .codex:
            return "OpenAI's ChatGPT desktop tooling with codex CLI"
        case .claude:
            return "Anthropic's Claude Code command-line helper"
        }
    }

    var executableName: String {
        switch self {
        case .codex: return "codex"
        case .claude: return "claude"
        }
    }

    var versionCommand: String {
        "\(executableName) --version"
    }

    var installURL: URL? {
        switch self {
        case .codex:
            return URL(string: "https://github.com/a16z-infra/codex#installation")
        case .claude:
            return URL(string: "https://docs.anthropic.com/en/docs/claude-code/setup")
        }
    }

    var iconName: String {
        switch self {
        case .codex: return "terminal"
        case .claude: return "bolt.horizontal.circle"
        }
    }
}

enum CLIDetectionState: Equatable {
    case unknown
    case checking
    case installed(version: String)
    case notFound
    case failed(message: String)

    var isInstalled: Bool {
        if case .installed = self { return true }
        return false
    }

    var statusLabel: String {
        switch self {
        case .unknown:
            return "Not checked"
        case .checking:
            return "Checking…"
        case .installed:
            return "Installed"
        case .notFound:
            return "Not installed"
        case .failed:
            return "Error"
        }
    }

    var detailMessage: String? {
        switch self {
        case .installed(let version):
            return version.trimmingCharacters(in: .whitespacesAndNewlines)
        case .failed(let message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        default:
            return nil
        }
    }
}

struct CLIDetectionReport {
    let state: CLIDetectionState
    let resolvedPath: String?
    let stdout: String?
    let stderr: String?
}

struct CLIDetector {
    static var searchPaths: [String] { cliSearchPaths }

    static func detect(tool: CLITool) async -> CLIDetectionReport {
        guard let executablePath = resolveExecutablePath(for: tool) else {
            return CLIDetectionReport(state: .notFound, resolvedPath: nil, stdout: nil, stderr: nil)
        }
        do {
            let result = try runCLI(executablePath, args: ["--version"])
            if result.exitCode == 0 {
                let trimmed = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
                let summary = firstLine.isEmpty ? "\(tool.shortName) detected" : firstLine
                return CLIDetectionReport(state: .installed(version: summary), resolvedPath: executablePath, stdout: result.stdout, stderr: result.stderr)
            }
            if result.exitCode == 127 || result.stderr.contains("not found") {
                return CLIDetectionReport(state: .notFound, resolvedPath: executablePath, stdout: result.stdout, stderr: result.stderr)
            }
            let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if message.isEmpty {
                return CLIDetectionReport(state: .failed(message: "Exit code \(result.exitCode)"), resolvedPath: executablePath, stdout: result.stdout, stderr: result.stderr)
            }
            return CLIDetectionReport(state: .failed(message: message), resolvedPath: executablePath, stdout: result.stdout, stderr: result.stderr)
        } catch {
            return CLIDetectionReport(state: .failed(message: error.localizedDescription), resolvedPath: executablePath, stdout: nil, stderr: nil)
        }
    }

    static func resolveExecutablePath(for tool: CLITool) -> String? {
        resolveExecutablePath(named: tool.executableName)
    }

    private static func resolveExecutablePath(named name: String) -> String? {
        let fileManager = FileManager.default
        var searchDirectories: [String] = []
        if let envPath = ProcessInfo.processInfo.environment["PATH"] {
            searchDirectories.append(contentsOf: envPath.split(separator: ":").map { String($0) })
        }
        searchDirectories.append(contentsOf: cliSearchPaths)
        var seen = Set<String>()
        for directory in searchDirectories {
            let expanded = (directory as NSString).expandingTildeInPath
            if !seen.insert(expanded).inserted {
                continue
            }
            let candidate = (expanded as NSString).appendingPathComponent(name)
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    static func runDebugCommand(_ command: String) -> CLIResult {
        do {
            return try runCLI("bash", args: ["-lc", command])
        } catch {
            return CLIResult(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }
    }
}
