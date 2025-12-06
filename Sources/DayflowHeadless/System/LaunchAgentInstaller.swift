import Foundation

/// Generates and installs launchd plist for auto-start at login
public final class LaunchAgentInstaller {

    public static let plistName = "com.dayflow.headless.plist"
    public static let label = "com.dayflow.headless"

    /// Generate plist data for the LaunchAgent
    public static func generatePlist(executablePath: String = "/usr/local/bin/dayflow-headless") -> Data {
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": true,
            "StandardOutPath": "/tmp/dayflow-headless.log",
            "StandardErrorPath": "/tmp/dayflow-headless.log",
            "EnvironmentVariables": [
                "HOME": NSHomeDirectory()
            ]
        ]

        return try! PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
    }

    /// Install plist to ~/Library/LaunchAgents/
    public static func install(executablePath: String = "/usr/local/bin/dayflow-headless") throws {
        let launchAgentsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")

        // Create LaunchAgents directory if needed
        try FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)

        let plistPath = launchAgentsDir.appendingPathComponent(plistName)
        let data = generatePlist(executablePath: executablePath)
        try data.write(to: plistPath)

        print("Installed: \(plistPath.path)")
        print("Load with: launchctl load \(plistPath.path)")
    }

    /// Uninstall plist from ~/Library/LaunchAgents/
    public static func uninstall() throws {
        let plistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
            .appendingPathComponent(plistName)

        if FileManager.default.fileExists(atPath: plistPath.path) {
            try FileManager.default.removeItem(at: plistPath)
            print("Uninstalled: \(plistPath.path)")
        } else {
            print("Not installed: \(plistPath.path)")
        }
    }

    /// Get the plist path
    public static var plistPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
            .appendingPathComponent(plistName)
    }
}
