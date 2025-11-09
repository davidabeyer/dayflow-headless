//
//  ChatCLIDetectionViews.swift
//  Dayflow
//
//  Views for ChatGPT/Claude CLI detection and testing
//

import SwiftUI
import Foundation

struct ChatCLIDetectionStepView<NextButton: View>: View {
    let codexStatus: CLIDetectionState
    let codexReport: CLIDetectionReport?
    let claudeStatus: CLIDetectionState
    let claudeReport: CLIDetectionReport?
    let isChecking: Bool
    let onRetry: () -> Void
    let onInstall: (CLITool) -> Void
    @Binding var debugCommand: String
    let debugOutput: String
    let isRunningDebug: Bool
    let onRunDebug: () -> Void
    @Binding var cliPrompt: String
    let codexOutput: String
    let claudeOutput: String
    let isRunningCodex: Bool
    let isRunningClaude: Bool
    let onRunCodex: () -> Void
    let onCancelCodex: () -> Void
    let onRunClaude: () -> Void
    let onCancelClaude: () -> Void
    @ViewBuilder let nextButton: () -> NextButton

    @State private var showCodexDebug = false
    @State private var showClaudeDebug = false

    private let accentColor = Color(red: 0.25, green: 0.17, blue: 0)

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Check ChatGPT or Claude")
                    .font(.custom("Nunito", size: 24))
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.9))
                Text("Dayflow can talk to ChatGPT (via the Codex CLI) or Claude Code. You only need one installed and signed in on this Mac.")
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(.black.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 14) {
                ChatCLIToolStatusRow(
                    tool: .codex,
                    status: codexStatus,
                    report: codexReport,
                    showDebug: $showCodexDebug,
                    onInstall: { onInstall(.codex) }
                )
                ChatCLIToolStatusRow(
                    tool: .claude,
                    status: claudeStatus,
                    report: claudeReport,
                    showDebug: $showClaudeDebug,
                    onInstall: { onInstall(.claude) }
                )
            }

            Text("Tip: Once both are installed, you can choose which assistant Dayflow uses from Settings → AI Provider.")
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.black.opacity(0.5))

            DebugCommandConsole(
                command: $debugCommand,
                output: debugOutput,
                isRunning: isRunningDebug,
                runAction: {
                    onRunDebug()
                }
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("Try a sample prompt")
                    .font(.custom("Nunito", size: 13))
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.7))
                TextField("Ask ChatGPT or Claude…", text: $cliPrompt)
                    .textFieldStyle(.roundedBorder)
                    .font(.custom("Nunito", size: 13))
                HStack(spacing: 12) {
                    DayflowSurfaceButton(
                        action: {
                            if isRunningCodex {
                                onCancelCodex()
                            } else if codexStatus.isInstalled || codexReport?.resolvedPath != nil {
                                onRunCodex()
                            }
                        },
                        content: {
                            HStack(spacing: 6) {
                                Image(systemName: isRunningCodex ? "stop.fill" : "play.fill").font(.system(size: 12, weight: .semibold))
                                Text(isRunningCodex ? "Stop Codex" : "Run Codex")
                                    .font(.custom("Nunito", size: 13))
                                    .fontWeight(.semibold)
                            }
                        },
                        background: Color(red: 0.25, green: 0.17, blue: 0),
                        foreground: .white,
                        borderColor: .clear,
                        cornerRadius: 8,
                        horizontalPadding: 16,
                        verticalPadding: 10,
                        showOverlayStroke: true
                    )
                    .disabled(!(codexStatus.isInstalled || codexReport?.resolvedPath != nil) && !isRunningCodex)

                    DayflowSurfaceButton(
                        action: {
                            if isRunningClaude {
                                onCancelClaude()
                            } else if claudeStatus.isInstalled || claudeReport?.resolvedPath != nil {
                                onRunClaude()
                            }
                        },
                        content: {
                            HStack(spacing: 6) {
                                Image(systemName: isRunningClaude ? "stop.fill" : "play.fill").font(.system(size: 12, weight: .semibold))
                                Text(isRunningClaude ? "Stop Claude" : "Run Claude")
                                    .font(.custom("Nunito", size: 13))
                                    .fontWeight(.semibold)
                            }
                        },
                        background: Color(red: 0.25, green: 0.17, blue: 0),
                        foreground: .white,
                        borderColor: .clear,
                        cornerRadius: 8,
                        horizontalPadding: 16,
                        verticalPadding: 10,
                        showOverlayStroke: true
                    )
                    .disabled(!(claudeStatus.isInstalled || claudeReport?.resolvedPath != nil) && !isRunningClaude)
                }
                if !codexOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    DebugField(label: "Codex output", value: codexOutput)
                }
                if !claudeOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    DebugField(label: "Claude output", value: claudeOutput)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.55))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )

            HStack {
                DayflowSurfaceButton(
                    action: {
                        if !isChecking {
                            onRetry()
                        }
                    },
                    content: {
                        HStack(spacing: 8) {
                            if isChecking {
                                ProgressView().scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.clockwise").font(.system(size: 13, weight: .semibold))
                            }
                            Text(isChecking ? "Checking…" : "Re-check")
                                .font(.custom("Nunito", size: 14))
                                .fontWeight(.semibold)
                        }
                    },
                    background: accentColor,
                    foreground: .white,
                    borderColor: .clear,
                    cornerRadius: 8,
                    horizontalPadding: 20,
                    verticalPadding: 10,
                    showOverlayStroke: true
                )
                .disabled(isChecking)

                Spacer()

                nextButton()
                    .opacity(canContinue ? 1.0 : 0.5)
                    .allowsHitTesting(canContinue)
            }
        }
    }

    private var canContinue: Bool {
        codexStatus.isInstalled || claudeStatus.isInstalled
    }
}

struct ChatCLIToolStatusRow: View {
    let tool: CLITool
    let status: CLIDetectionState
    let report: CLIDetectionReport?
    @Binding var showDebug: Bool
    let onInstall: () -> Void

    private let accentColor = Color(red: 0.25, green: 0.17, blue: 0)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: tool.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black.opacity(0.75))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.7))
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(tool.displayName)
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(.black.opacity(0.9))
                    Text(tool.subtitle)
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.black.opacity(0.55))
                }

                Spacer()

                statusView
            }

            if let detail = status.detailMessage, !detail.isEmpty {
                Text(detail)
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.black.opacity(0.6))
                    .padding(.leading, 48)
            }

            if let report {
                Button(action: { withAnimation { showDebug.toggle() } }) {
                    HStack(spacing: 6) {
                        Image(systemName: showDebug ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                        Text(showDebug ? "Hide debug info" : "Show debug info")
                            .font(.custom("Nunito", size: 12))
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 48)
                .pointingHandCursor()

                if showDebug {
                    VStack(alignment: .leading, spacing: 6) {
                        if let path = report.resolvedPath {
                            DebugField(label: "Resolved path", value: path)
                        }
                        if let stdout = report.stdout, !stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            DebugField(label: "stdout", value: stdout)
                        }
                        if let stderr = report.stderr, !stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            DebugField(label: "stderr", value: stderr)
                        }
                        if (report.stdout?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) && (report.stderr?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
                            DebugField(label: "Note", value: "No output captured from --version")
                        }
                    }
                    .padding(.leading, 48)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            if shouldShowInstallButton {
                DayflowSurfaceButton(
                    action: onInstall,
                    content: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill").font(.system(size: 13, weight: .semibold))
                            Text(installLabel)
                                .font(.custom("Nunito", size: 13))
                                .fontWeight(.semibold)
                        }
                    },
                    background: .white.opacity(0.85),
                    foreground: accentColor,
                    borderColor: accentColor.opacity(0.35),
                    cornerRadius: 8,
                    horizontalPadding: 16,
                    verticalPadding: 8,
                    showOverlayStroke: true
                )
                .padding(.leading, 48)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.6))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .checking, .unknown:
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.55)
                Text(status.statusLabel)
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(accentColor.opacity(0.12))
            .cornerRadius(999)
        case .installed:
            Text(status.statusLabel)
                .font(.custom("Nunito", size: 12))
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.13, green: 0.7, blue: 0.23))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(red: 0.13, green: 0.7, blue: 0.23).opacity(0.17))
                .cornerRadius(999)
        case .notFound:
            Text(status.statusLabel)
                .font(.custom("Nunito", size: 12))
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: "E91515"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "FFD1D1"))
                .cornerRadius(999)
        case .failed:
            Text(status.statusLabel)
                .font(.custom("Nunito", size: 12))
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.91, green: 0.34, blue: 0.16))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(red: 0.91, green: 0.34, blue: 0.16).opacity(0.18))
                .cornerRadius(999)
        }
    }

    private var shouldShowInstallButton: Bool {
        switch status {
        case .notFound, .failed:
            return tool.installURL != nil
        default:
            return false
        }
    }

    private var installLabel: String {
        switch status {
        case .failed:
            return "Open setup guide"
        default:
            return "Install \(tool.shortName)"
        }
    }
}

struct DebugField: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Nunito", size: 11))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.55))
            ScrollView(.vertical, showsIndicators: true) {
                Text(value)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(.black.opacity(0.75))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.white.opacity(0.85))
                    .cornerRadius(6)
            }
            .frame(maxHeight: 100)
        }
    }
}

struct DebugCommandConsole: View {
    @Binding var command: String
    let output: String
    let isRunning: Bool
    let runAction: () -> Void

    private let accentColor = Color(red: 0.25, green: 0.17, blue: 0)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Run a command as Dayflow")
                .font(.custom("Nunito", size: 13))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.7))
            Text("Helpful for checking PATH differences. We run using the same environment as the detection step.")
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.black.opacity(0.55))
            HStack(spacing: 10) {
                TextField("Command", text: $command)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                DayflowSurfaceButton(
                    action: runAction,
                    content: {
                        HStack(spacing: 6) {
                            if isRunning {
                                ProgressView().scaleEffect(0.7)
                            } else {
                                Image(systemName: "play.fill").font(.system(size: 12, weight: .semibold))
                            }
                            Text(isRunning ? "Running..." : "Run")
                                .font(.custom("Nunito", size: 13))
                                .fontWeight(.semibold)
                        }
                    },
                    background: accentColor,
                    foreground: .white,
                    borderColor: .clear,
                    cornerRadius: 8,
                    horizontalPadding: 14,
                    verticalPadding: 10,
                    showOverlayStroke: true
                )
                .disabled(isRunning)
            }
            ScrollView {
                Text(output.isEmpty ? "Output will appear here" : output)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(.black.opacity(output.isEmpty ? 0.4 : 0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.white.opacity(0.85))
                    .cornerRadius(8)
            }
            .frame(maxHeight: 160)
        }
        .padding(16)
        .background(Color.white.opacity(0.55))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}
