import Foundation

struct GeminiPromptOverrides: Codable, Equatable {
    var titleBlock: String?
    var summaryBlock: String?
    var detailedBlock: String?

    var isEmpty: Bool {
        let values = [titleBlock, summaryBlock, detailedBlock]
        return values.allSatisfy { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty
        }
    }
}

enum GeminiPromptPreferences {
    private static let overridesKey = "geminiPromptOverrides"
    private static let store = UserDefaults.standard

    static func load() -> GeminiPromptOverrides {
        guard let data = store.data(forKey: overridesKey) else {
            return GeminiPromptOverrides()
        }
        guard let overrides = try? JSONDecoder().decode(GeminiPromptOverrides.self, from: data) else {
            return GeminiPromptOverrides()
        }
        return overrides
    }

    static func save(_ overrides: GeminiPromptOverrides) {
        guard let data = try? JSONEncoder().encode(overrides) else { return }
        store.set(data, forKey: overridesKey)
    }

    static func reset() {
        store.removeObject(forKey: overridesKey)
    }
}

enum GeminiPromptDefaults {
    static let titleBlock = """
TITLES

Write titles like you'd answer "what were you doing?"

Formula: [Main thing] + optional quick context

Good:
- "Prepped Mia's Duke interview"
- "Japan flights with Evan"
- "Nick Fuentes interview, then UI diagrams"
- "Debugged auth flow in React"
- "League game, checked DayFlow between"
- "Watched Succession finale"
- "Booked Denver flights on Expedia"

Bad:
- "Twitter scrolling, YouTube video, and UI diagrams" (laundry list)
- "Duke interview prep and DayFlow code review" (unrelated things jammed together)
- "Extended browsing session" (vague, formal)
- "Random browsing and activities" (says nothing)
- "Worked on DayFlow project" (what specifically?)
- "Early morning digital drift" (poetic fluff)

If there's a secondary thing, make it context not a co-headline:
- "Prepped Duke interview, League between" ✓
- "Duke interview prep and League of Legends" ✗
"""

    static let summaryBlock = """
SUMMARIES

2-3 sentences max. First person without "I". Just state what happened.

Good:
- "Refactored user auth module in React, added OAuth support. Hit CORS issues with the backend API."
- "Designed landing page mockups in Figma. Exported assets and started implementing in Next.js."
- "Searched flights to Tokyo, coordinated dates with Evan and Anthony over Messages. Looked at Shibuya apartments on Blueground."

Bad:
- "Kicked off the morning by diving into design work before transitioning to development tasks." (filler, vague)
- "Started with refactoring before moving on to debugging some issues." (wordy, no specifics)
- "The session involved multiple context switches between different parts of the application." (says nothing)

Never use:
- "kicked off", "dove into", "started with", "began by"
- Third person ("The session", "The work")
- Mental states or assumptions about intent
"""

    static let detailedSummaryBlock = """
DETAILED SUMMARY

Ultra-granular forensic log. Capture EVERYTHING visible on screen with maximum specificity. This is the "reconstruct exactly what happened, keystroke by keystroke" view.

Format each line:
[H:MM:SS] [action verb] [exact target] in [app] — [observable details]

EXTRACTION PRIORITIES (in order):

1. CODE WORK - Maximum detail required:
   - File paths: "src/components/Auth.tsx" not "auth file"
   - Function/class names: "refactored validateToken()" not "worked on validation"
   - Line numbers if visible: "editing line 47-52"
   - Terminal commands verbatim: `git commit -m "fix auth bug"` not "committed code"
   - Error messages exact text: "TypeError: Cannot read property 'user' of undefined"
   - Test output: "3 tests passing, 1 failing: AuthService.test.ts:42"
   - Git operations: branch names, commit messages, PR numbers

2. BROWSER/RESEARCH - Capture the actual content:
   - Full page titles: "Stack Overflow: How to fix CORS errors in React"
   - Search queries verbatim: searched "python asyncio timeout handling"
   - URLs when meaningful: "reading docs at react.dev/reference/hooks"
   - Tab switches: "switched from GitHub PR #234 to Linear issue DAY-156"

3. COMMUNICATION - Who, what channel, topic:
   - Slack: "#engineering with @mike about deployment blockers"
   - Email: "composing reply to sarah@company.com re: Q4 roadmap"
   - Messages: "texting John about dinner plans"

4. DOCUMENTS - Be specific:
   - Document titles: "editing 'Q4 Launch Plan' in Notion"
   - Section being edited: "added row to 'Timeline' table"
   - Spreadsheet: "Google Sheets 'Budget 2024', cell D15"

5. CONTEXT SWITCHES - Note every one:
   - "switched from VS Code to Chrome"
   - "returned to terminal after Slack notification"
   - "cmd+tab to Figma"

TEMPORAL PRECISION:
- Use seconds when actions are rapid: 7:15:00, 7:15:12, 7:15:30
- Group only when genuinely continuous on same task
- Never summarize 5+ minutes into one line unless truly uninterrupted

GOOD EXAMPLE:
"11:42:00 opened VS Code, file hooks/lib/worker.py
11:42:15 scrolled to line 89, function process_batch()
11:42:30 added try/except block around db.execute()
11:43:00 terminal: ran `pytest tests/test_worker.py -v`
11:43:45 test failed: AssertionError at test_worker.py:56
11:44:00 switched to Chrome, searched "pytest fixture teardown not running"
11:44:30 reading Stack Overflow answer about yield fixtures
11:45:00 back to VS Code, modified conftest.py line 12
11:45:30 terminal: `pytest tests/test_worker.py -v` — all 4 tests passing
11:46:00 terminal: `git add -p` reviewing diff
11:46:30 terminal: `git commit -m "fix: ensure db connection cleanup in worker"`
11:47:00 switched to Linear, updated DAY-423 status to "In Review"
11:47:15 added comment: "Fixed worker cleanup, ready for review""

BAD EXAMPLE:
"11:42 - 11:47 fixed a bug in the worker code, ran tests, committed"
(Missing: which file, what function, what error, what fix, what tests, what commit message)

GOAL: A developer could replay your exact session from this log. Every file touched, every command run, every search made, every message sent.
"""
}

struct GeminiPromptSections {
    let title: String
    let summary: String
    let detailedSummary: String

    init(overrides: GeminiPromptOverrides) {
        self.title = GeminiPromptSections.compose(defaultBlock: GeminiPromptDefaults.titleBlock, custom: overrides.titleBlock)
        self.summary = GeminiPromptSections.compose(defaultBlock: GeminiPromptDefaults.summaryBlock, custom: overrides.summaryBlock)
        self.detailedSummary = GeminiPromptSections.compose(defaultBlock: GeminiPromptDefaults.detailedSummaryBlock, custom: overrides.detailedBlock)
    }

    private static func compose(defaultBlock: String, custom: String?) -> String {
        let trimmed = custom?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? defaultBlock : trimmed
    }
}
