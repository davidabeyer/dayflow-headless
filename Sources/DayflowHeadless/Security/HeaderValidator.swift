import Foundation

public enum HeaderValidator {
    private static let tokenChars = CharacterSet(charactersIn: "!#$%&'*+-.^_`|~")
        .union(.alphanumerics)
    private static let maxValueLength = 8192

    public static func isValidName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        return name.unicodeScalars.allSatisfy { tokenChars.contains($0) }
    }

    public static func isValidValue(_ value: String) -> Bool {
        // Check length first (most efficient)
        guard value.count <= maxValueLength else { return false }

        // Check at scalar level to catch CRLF grapheme clusters
        let forbiddenScalars: [Unicode.Scalar] = ["\r", "\n", "\0"]
        for scalar in value.unicodeScalars {
            if forbiddenScalars.contains(scalar) {
                return false
            }
            // ASCII only (0-127)
            if scalar.value > 127 {
                return false
            }
        }
        return true
    }
}
