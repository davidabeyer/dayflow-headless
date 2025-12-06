import Foundation

public enum WebhookError: Error {
    case invalidURL
    case unsafeURL
    case invalidHeader(key: String)
    case networkError(Error)
    case httpError(Int)
}

public struct WebhookResult {
    public let success: Bool
    public let statusCode: Int?
    public let error: Error?
    public let attemptCount: Int
    
    public init(success: Bool, statusCode: Int? = nil, error: Error? = nil, attemptCount: Int = 1) {
        self.success = success
        self.statusCode = statusCode
        self.error = error
        self.attemptCount = attemptCount
    }
}

public final class WebhookService {
    private let config: WebhookConfig
    private let session: any URLSessionProtocol
    
    public init(config: WebhookConfig, session: any URLSessionProtocol = URLSession.shared) {
        self.config = config
        self.session = session
    }
    
    public func send(payload: String) async throws -> WebhookResult {
        guard let url = URL(string: config.url), !config.url.isEmpty else {
            throw WebhookError.invalidURL
        }

        // Validate URL scheme and reject embedded credentials
        guard URLValidator.isValidWebhookURL(config.url) else {
            throw WebhookError.unsafeURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Validate and add custom headers from config
        for (key, value) in config.headers {
            guard HeaderValidator.isValidName(key), HeaderValidator.isValidValue(value) else {
                throw WebhookError.invalidHeader(key: key)
            }
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Create JSON body
        let body: [String: Any] = ["payload": payload, "timestamp": ISO8601DateFormatter().string(from: Date())]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        var lastError: Error?
        var lastStatusCode: Int?
        
        for attempt in 1...config.retryStrategy.maxAttempts {
            do {
                let (_, response) = try await session.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    lastStatusCode = httpResponse.statusCode
                    
                    if (200..<300).contains(httpResponse.statusCode) {
                        return WebhookResult(success: true, statusCode: httpResponse.statusCode, attemptCount: attempt)
                    }
                    
                    lastError = WebhookError.httpError(httpResponse.statusCode)
                }
            } catch {
                lastError = WebhookError.networkError(error)
            }
            
            // Don't delay after the last attempt
            if attempt < config.retryStrategy.maxAttempts {
                let delay = calculateDelay(attempt: attempt)
                if delay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                }
            }
        }
        
        return WebhookResult(
            success: false,
            statusCode: lastStatusCode,
            error: lastError,
            attemptCount: config.retryStrategy.maxAttempts
        )
    }
    
    private func calculateDelay(attempt: Int) -> Int {
        let delay = config.retryStrategy.initialDelaySeconds * Int(pow(Double(config.retryStrategy.multiplier), Double(attempt - 1)))
        return min(delay, config.retryStrategy.maxDelaySeconds)
    }
}
