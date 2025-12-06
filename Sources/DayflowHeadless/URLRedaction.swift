import Foundation

/// Redacts sensitive data from URLs for safe logging
/// Removes: query parameters, fragments, credentials (user:password)
/// Preserves: scheme, host, port, path
/// - Parameter urlString: The URL string to redact
/// - Returns: Redacted URL string, or "[invalid URL]" if parsing fails
public func redactURL(_ urlString: String) -> String {
    guard let components = URLComponents(string: urlString) else {
        return "[invalid URL]"
    }

    var redacted = URLComponents()
    redacted.scheme = components.scheme
    redacted.host = components.host
    redacted.port = components.port
    redacted.path = components.path

    return redacted.string ?? "[URL]"
}
