import Foundation

public enum URLValidator {
    /// Allowed URL schemes for webhook endpoints
    private static let allowedSchemes: Set<String> = ["http", "https"]

    /// Validates a URL for use as a webhook endpoint
    /// - Parameter urlString: URL string to validate
    /// - Returns: true if URL is safe for webhook use, false otherwise
    public static func isValidWebhookURL(_ urlString: String) -> Bool {
        // Reject empty strings
        guard !urlString.isEmpty else { return false }

        // Parse URL
        guard let url = URL(string: urlString) else { return false }

        // Must have a scheme
        guard let scheme = url.scheme?.lowercased() else { return false }

        // Scheme must be in whitelist
        guard allowedSchemes.contains(scheme) else { return false }

        // Must have a host
        guard let host = url.host, !host.isEmpty else { return false }

        // Reject embedded credentials (user:pass@host or user@host)
        if url.user != nil || url.password != nil {
            return false
        }

        return true
    }
}
