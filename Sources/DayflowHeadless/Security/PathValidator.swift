import Foundation

public enum PathValidator {
    /// Shell metacharacters that could enable command injection
    private static let shellMetacharacters = CharacterSet(charactersIn: "`$;|&\n\r\0")

    /// Valid path characters (alphanumerics + safe punctuation)
    private static let validPathChars = CharacterSet.alphanumerics.union(
        CharacterSet(charactersIn: "/-_.")
    )

    /// Validates a path for use in launchd ProgramArguments
    /// - Parameter path: Path to validate
    /// - Returns: true if path is safe, false if it contains dangerous characters
    public static func isValidPath(_ path: String) -> Bool {
        // Reject empty paths
        guard !path.isEmpty else { return false }

        // Must be absolute path (starts with /)
        guard path.hasPrefix("/") else { return false }

        // Check for path traversal patterns
        if path.contains("..") {
            return false
        }

        // Check at unicode scalar level for shell metacharacters
        for scalar in path.unicodeScalars {
            if shellMetacharacters.contains(scalar) {
                return false
            }
        }

        // Verify all characters are in the allowed set
        for scalar in path.unicodeScalars {
            if !validPathChars.contains(scalar) {
                return false
            }
        }

        return true
    }
}
