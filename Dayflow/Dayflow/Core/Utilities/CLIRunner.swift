//
//  CLIRunner.swift
//  Dayflow
//
//  Unified CLI process execution with shared environment configuration
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

/// Configures process environment with expanded PATH
func configureCLIEnvironment(_ process: Process, overrides: [String: String]? = nil) {
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
    process.environment = environment
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
            throw NSError(domain: "StreamingCLI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Executable not found: \(expandedCommand)"])
        }
        process.executableURL = URL(fileURLWithPath: expandedCommand)
        process.arguments = args
    } else {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [expandedCommand] + args
    }
    process.currentDirectoryURL = cwd
    configureCLIEnvironment(process, overrides: env)

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
            proc.executableURL = URL(fileURLWithPath: expandedCommand)
            proc.arguments = args
        } else {
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            proc.arguments = [expandedCommand] + args
        }
        proc.currentDirectoryURL = cwd
        configureCLIEnvironment(proc, overrides: env)

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
