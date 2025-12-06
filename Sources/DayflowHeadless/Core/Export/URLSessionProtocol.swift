import Foundation

/// Protocol for abstracting URLSession to enable testing with mocks
public protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}
