import XCTest
@testable import DayflowHeadless

final class LaunchAgentInstallerTests: XCTestCase {

    func testPlistGeneration() throws {
        let plistData = try LaunchAgentInstaller.generatePlist()
        XCTAssertNotNil(plistData)
        XCTAssertGreaterThan(plistData.count, 0)
    }

    func testPlistContainsLabel() throws {
        let plistData = try LaunchAgentInstaller.generatePlist()
        let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as! [String: Any]

        XCTAssertEqual(plist["Label"] as? String, "com.dayflow.headless")
    }

    func testPlistRunAtLoad() throws {
        let plistData = try LaunchAgentInstaller.generatePlist()
        let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as! [String: Any]

        XCTAssertTrue(plist["RunAtLoad"] as? Bool ?? false, "RunAtLoad should be true")
    }

    func testPlistKeepAlive() throws {
        let plistData = try LaunchAgentInstaller.generatePlist()
        let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as! [String: Any]

        XCTAssertTrue(plist["KeepAlive"] as? Bool ?? false, "KeepAlive should be true")
    }

    func testPlistHomeEnv() throws {
        let plistData = try LaunchAgentInstaller.generatePlist()
        let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as! [String: Any]

        let envVars = plist["EnvironmentVariables"] as? [String: String]
        XCTAssertNotNil(envVars?["HOME"], "HOME env var should be set")
    }

    func testPlistPathCorrect() throws {
        let path = LaunchAgentInstaller.plistPath
        XCTAssertTrue(path.path.contains("Library/LaunchAgents"))
        XCTAssertTrue(path.path.contains("com.dayflow.headless.plist"))
    }

    func testGeneratePlistWithCustomPath() throws {
        let customPath = "/custom/path/dayflow-headless"
        let plistData = try LaunchAgentInstaller.generatePlist(executablePath: customPath)
        let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as! [String: Any]

        let args = plist["ProgramArguments"] as? [String]
        XCTAssertEqual(args?[0], customPath, "Should use custom executable path")
    }
}
