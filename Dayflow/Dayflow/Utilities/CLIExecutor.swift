//
//  CLIExecutor.swift
//  Dayflow
//
//  CLI process execution utilities for running external commands
//

import Foundation

let cliSearchPaths: [String] = {
    let home = NSHomeDirectory()
    return [
        "/usr/local/bin",
        "/opt/homebrew/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin",
        "\(home)/.npm-global/bin",
        "\(home)/.local/bin",
        "\(home)/.cargo/bin",
        "\(home)/.bun/bin",
        "\(home)/.pyenv/bin",
        "\(home)/.pyenv/shims",
        "\(home)/.npm-global/lib/node_modules/@openai/codex/vendor/aarch64-apple-darwin/path",
        "\(home)/.codeium/windsurf/bin",
        "\(home)/.lmstudio/bin"
    ]
}()

struct CLIResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

/// Builds an enhanced environment with augmented PATH from cliSearchPaths
func buildCLIEnvironment(overrides: [String: String]? = nil) -> [String: String] {
    var environment = ProcessInfo.processInfo.environment
    if let overrides = overrides {
        environment.merge(overrides, uniquingKeysWith: { _, new in new })
    }

    var pathComponents: [String] = environment["PATH"]
        .map { $0.split(separator: ":").map { String($0) } } ?? []
    for rawPath in cliSearchPaths {
        let expanded = (rawPath as NSString).expandingTildeInPath
        if !pathComponents.contains(expanded) {
            pathComponents.append(expanded)
        }
    }
    environment["PATH"] = pathComponents.joined(separator: ":")
    environment["HOME"] = environment["HOME"] ?? NSHomeDirectory()
    return environment
}

/// Configures a Process with the given command, resolving executables and setting up environment
func configureCLIProcess(_ process: Process, command: String, args: [String], env: [String: String]?, cwd: URL?) {
    let expandedCommand = (command as NSString).expandingTildeInPath
    if expandedCommand.hasPrefix("/") {
        process.executableURL = URL(fileURLWithPath: expandedCommand)
        process.arguments = args
    } else {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [expandedCommand] + args
    }
    process.currentDirectoryURL = cwd
    process.environment = buildCLIEnvironment(overrides: env)
}

@discardableResult
func runCLI(
    _ command: String,
    args: [String] = [],
    env: [String: String]? = nil,
    cwd: URL? = nil
) throws -> CLIResult {
    let process = Process()
    let expandedCommand = (command as NSString).expandingTildeInPath
    if expandedCommand.hasPrefix("/") {
        guard FileManager.default.isExecutableFile(atPath: expandedCommand) else {
            throw NSError(domain: "CLIExecutor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Executable not found: \(expandedCommand)"])
        }
    }

    configureCLIProcess(process, command: command, args: args, env: env, cwd: cwd)

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()
    process.waitUntilExit()

    let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

    return CLIResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)
}

final class StreamingCLI {
    private var process: Process?
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()

    func cancel() {
        process?.terminate()
    }

    func run(
        command: String,
        args: [String],
        env: [String: String]? = nil,
        cwd: URL? = nil,
        onStdout: @escaping (String) -> Void,
        onStderr: @escaping (String) -> Void,
        onFinish: @escaping (Int32) -> Void
    ) {
        let proc = Process()
        process = proc

        let expandedCommand = (command as NSString).expandingTildeInPath
        if expandedCommand.hasPrefix("/") {
            guard FileManager.default.isExecutableFile(atPath: expandedCommand) else {
                DispatchQueue.main.async {
                    onStderr("Executable not found or not executable: \(expandedCommand)\n")
                    onFinish(-1)
                }
                return
            }
        }

        configureCLIProcess(proc, command: command, args: args, env: env, cwd: cwd)

        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                onStdout(chunk)
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                onStderr(chunk)
            }
        }

        do {
            try proc.run()
            proc.terminationHandler = { process in
                self.stdoutPipe.fileHandleForReading.readabilityHandler = nil
                self.stderrPipe.fileHandleForReading.readabilityHandler = nil
                DispatchQueue.main.async {
                    onFinish(process.terminationStatus)
                }
            }
        } catch {
            DispatchQueue.main.async {
                onStderr("Failed to start \(command): \(error.localizedDescription)")
                onFinish(-1)
            }
        }
    }
}

// MARK: - CLI Detection

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
