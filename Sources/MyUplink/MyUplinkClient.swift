import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession

/// Base URL of the public myUplink API. The published spec has no `servers`
/// entry, so it is provided here.
public enum MyUplinkServer {
    public static let production = URL(string: "https://api.myuplink.com")!
}

/// Adds an `Authorization: Bearer <token>` header to every request.
public struct BearerTokenMiddleware: ClientMiddleware {
    private let token: @Sendable () async throws -> String

    /// - Parameter token: Called per request, so it can return a refreshed token.
    public init(token: @escaping @Sendable () async throws -> String) {
        self.token = token
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.authorization] = "Bearer \(try await token())"
        return try await next(request, body, baseURL)
    }
}

extension Client {
    /// Creates a client for the myUplink API using `URLSession`.
    public static func myUplink(
        serverURL: URL = MyUplinkServer.production,
        session: URLSession = .shared,
        token: @escaping @Sendable () async throws -> String
    ) -> Client {
        Client(
            serverURL: serverURL,
            transport: URLSessionTransport(configuration: .init(session: session)),
            middlewares: [BearerTokenMiddleware(token: token)]
        )
    }
}
