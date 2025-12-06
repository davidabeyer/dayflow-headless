import XCTest
@testable import DayflowHeadless

final class MarkdownFormatterTests: XCTestCase {
    
    var formatter: MarkdownFormatter!
    
    override func setUp() {
        super.setUp()
        formatter = MarkdownFormatter()
    }
    
    override func tearDown() {
        formatter = nil
        super.tearDown()
    }
    
    func testFormatSingleActivity() {
        let activity = Activity(
            id: UUID(),
            appName: "Xcode",
            windowTitle: "MyProject.swift",
            startTime: Date(),
            duration: 3600,
            category: "Development"
        )
        
        let result = formatter.format(activities: [activity])
        
        XCTAssertTrue(result.contains("Xcode"))
        XCTAssertTrue(result.contains("MyProject.swift"))
        XCTAssertTrue(result.contains("1h"))
    }
    
    func testFormatMultipleActivities() {
        let activity1 = Activity(
            id: UUID(),
            appName: "Xcode",
            windowTitle: "Code.swift",
            startTime: Date(),
            duration: 1800,
            category: "Development"
        )
        let activity2 = Activity(
            id: UUID(),
            appName: "Safari",
            windowTitle: "Stack Overflow",
            startTime: Date(),
            duration: 900,
            category: "Research"
        )
        
        let result = formatter.format(activities: [activity1, activity2])
        
        XCTAssertTrue(result.contains("Xcode"))
        XCTAssertTrue(result.contains("Safari"))
        XCTAssertTrue(result.contains("30m"))
        XCTAssertTrue(result.contains("15m"))
    }
    
    func testFormatEmptyActivities() {
        let result = formatter.format(activities: [])
        
        XCTAssertTrue(result.contains("No activities"))
    }
    
    func testFormatIncludesHeader() {
        let activity = Activity(
            id: UUID(),
            appName: "Terminal",
            windowTitle: "bash",
            startTime: Date(),
            duration: 600,
            category: "Development"
        )
        
        let result = formatter.format(activities: [activity])
        
        XCTAssertTrue(result.hasPrefix("# Activity Summary"))
    }
    
    func testDurationFormattingMinutes() {
        let activity = Activity(
            id: UUID(),
            appName: "Notes",
            windowTitle: "Ideas",
            startTime: Date(),
            duration: 300, // 5 minutes
            category: "Writing"
        )
        
        let result = formatter.format(activities: [activity])
        
        XCTAssertTrue(result.contains("5m"))
    }
    
    func testDurationFormattingHoursAndMinutes() {
        let activity = Activity(
            id: UUID(),
            appName: "Figma",
            windowTitle: "Design",
            startTime: Date(),
            duration: 5400, // 1h 30m
            category: "Design"
        )
        
        let result = formatter.format(activities: [activity])
        
        XCTAssertTrue(result.contains("1h 30m"))
    }
    
    func testCategoryGrouping() {
        let dev1 = Activity(id: UUID(), appName: "Xcode", windowTitle: "A", startTime: Date(), duration: 600, category: "Development")
        let dev2 = Activity(id: UUID(), appName: "Terminal", windowTitle: "B", startTime: Date(), duration: 300, category: "Development")
        let research = Activity(id: UUID(), appName: "Safari", windowTitle: "C", startTime: Date(), duration: 450, category: "Research")
        
        let result = formatter.format(activities: [dev1, dev2, research])
        
        XCTAssertTrue(result.contains("## Development"))
        XCTAssertTrue(result.contains("## Research"))
    }
    
    func testTotalDurationIncluded() {
        let activity1 = Activity(id: UUID(), appName: "App1", windowTitle: "W1", startTime: Date(), duration: 1800, category: "Work")
        let activity2 = Activity(id: UUID(), appName: "App2", windowTitle: "W2", startTime: Date(), duration: 1800, category: "Work")
        
        let result = formatter.format(activities: [activity1, activity2])
        
        XCTAssertTrue(result.contains("Total: 1h"))
    }
}
