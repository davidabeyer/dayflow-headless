import XCTest
@testable import DayflowHeadless

// Mock URLSession for testing
final class MockURLSession: URLSessionProtocol {
    var responses: [(Data, URLResponse)] = []
    var errors: [Error] = []
    var requestsMade: [URLRequest] = []
    private var callIndex = 0
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requestsMade.append(request)
        let index = callIndex
        callIndex += 1
        
        if index < errors.count && errors.count > 0 {
            throw errors[index]
        }
        
        if index < responses.count {
            return responses[index]
        }
        
        // Default success response
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(), response)
    }
}

final class WebhookServiceTests: XCTestCase {
    
    var mockSession: MockURLSession!
    var webhookService: WebhookService!
    
    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
    }
    
    override func tearDown() {
        mockSession = nil
        webhookService = nil
        super.tearDown()
    }
    
    func testSendSuccess200() async throws {
        let config = WebhookConfig(
            url: "https://example.com/webhook",
            retryStrategy: RetryStrategy()
        )
        webhookService = WebhookService(config: config, session: mockSession)
        
        let response = HTTPURLResponse(
            url: URL(string: config.url)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        mockSession.responses = [(Data(), response)]
        
        let result = try await webhookService.send(payload: "Test payload")
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(mockSession.requestsMade.count, 1)
    }
    
    func testSendFailure500RetriesOnce() async throws {
        let config = WebhookConfig(
            url: "https://example.com/webhook",
            retryStrategy: RetryStrategy(initialDelaySeconds: 0, maxAttempts: 2)
        )
        webhookService = WebhookService(config: config, session: mockSession)
        
        let failResponse = HTTPURLResponse(
            url: URL(string: config.url)!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )!
        let successResponse = HTTPURLResponse(
            url: URL(string: config.url)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        mockSession.responses = [(Data(), failResponse), (Data(), successResponse)]
        
        let result = try await webhookService.send(payload: "Test payload")
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(mockSession.requestsMade.count, 2, "Should retry once after failure")
    }
    
    func testSendExhaustsRetries() async throws {
        let config = WebhookConfig(
            url: "https://example.com/webhook",
            retryStrategy: RetryStrategy(initialDelaySeconds: 0, maxAttempts: 3)
        )
        webhookService = WebhookService(config: config, session: mockSession)
        
        let failResponse = HTTPURLResponse(
            url: URL(string: config.url)!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )!
        // All responses fail
        mockSession.responses = [
            (Data(), failResponse),
            (Data(), failResponse),
            (Data(), failResponse)
        ]
        
        let result = try await webhookService.send(payload: "Test payload")
        
        XCTAssertFalse(result.success)
        XCTAssertEqual(mockSession.requestsMade.count, 3, "Should make all retry attempts")
    }
    
    func testSendSetsCorrectHeaders() async throws {
        let config = WebhookConfig(
            url: "https://example.com/webhook",
            retryStrategy: RetryStrategy()
        )
        webhookService = WebhookService(config: config, session: mockSession)
        
        _ = try await webhookService.send(payload: "Test payload")
        
        let request = mockSession.requestsMade.first!
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }
    
    func testSendPayloadInBody() async throws {
        let config = WebhookConfig(
            url: "https://example.com/webhook",
            retryStrategy: RetryStrategy()
        )
        webhookService = WebhookService(config: config, session: mockSession)
        
        let payload = "Test payload content"
        _ = try await webhookService.send(payload: payload)
        
        let request = mockSession.requestsMade.first!
        let bodyData = request.httpBody!
        let bodyString = String(data: bodyData, encoding: .utf8)!
        
        XCTAssertTrue(bodyString.contains(payload))
    }
    
    func testInvalidURLThrowsError() async throws {
        let config = WebhookConfig(
            url: "",
            retryStrategy: RetryStrategy()
        )
        webhookService = WebhookService(config: config, session: mockSession)
        
        do {
            _ = try await webhookService.send(payload: "Test")
            XCTFail("Should throw error for invalid URL")
        } catch {
            XCTAssertTrue(error is WebhookError)
        }
    }
    
    func testCustomHeadersAreIncluded() async throws {
        let config = WebhookConfig(
            url: "https://example.com/webhook",
            retryStrategy: RetryStrategy(),
            headers: ["X-Custom-Header": "custom-value", "Authorization": "Bearer token123"]
        )
        webhookService = WebhookService(config: config, session: mockSession)
        
        _ = try await webhookService.send(payload: "Test payload")
        
        let request = mockSession.requestsMade.first!
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Custom-Header"), "custom-value")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token123")
    }
}
