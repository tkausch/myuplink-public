import Foundation

/// An access token issued by the myUplink token endpoint.
public struct OAuthToken: Sendable, Equatable {
    public let accessToken: String
    public let tokenType: String
    public let expiresAt: Date
    public let scope: String?
}

public enum OAuthError: Error, Sendable {
    /// The token endpoint answered with a non-2xx status. `body` is the raw response text.
    case tokenRequestFailed(status: Int, body: String)
    /// The response was not a valid token response.
    case invalidResponse
}

/// Fetches access tokens with the OAuth 2.0 client credentials grant and caches
/// them until shortly before they expire.
///
/// ```swift
/// let oauth = OAuthClient(clientID: id, clientSecret: secret)
/// let client = Client.myUplink(token: { try await oauth.accessToken() })
/// ```
public actor OAuthClient {
    public static let productionTokenURL = URL(string: "https://api.myuplink.com/oauth/token")!

    private let clientID: String
    private let clientSecret: String
    private let scopes: [String]
    private let tokenURL: URL
    private let session: URLSession
    private let expiryLeeway: TimeInterval
    private let now: @Sendable () -> Date

    private var cached: OAuthToken?
    private var inFlight: Task<OAuthToken, Error>?

    /// - Parameters:
    ///   - scopes: `READSYSTEM` for GET methods, `WRITESYSTEM` for PUT, POST, PATCH and DELETE.
    ///   - expiryLeeway: A cached token is renewed this many seconds before it expires.
    public init(
        clientID: String,
        clientSecret: String,
        scopes: [String] = ["READSYSTEM"],
        tokenURL: URL = OAuthClient.productionTokenURL,
        session: URLSession = .shared,
        expiryLeeway: TimeInterval = 60,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.scopes = scopes
        self.tokenURL = tokenURL
        self.session = session
        self.expiryLeeway = expiryLeeway
        self.now = now
    }

    /// Returns a valid access token, requesting a new one when none is cached or it is about to expire.
    public func accessToken() async throws -> String {
        try await token().accessToken
    }

    /// Like ``accessToken()``, but returns the whole token.
    public func token() async throws -> OAuthToken {
        if let cached, cached.expiresAt.timeIntervalSince(now()) > expiryLeeway {
            return cached
        }
        if let inFlight {
            return try await inFlight.value
        }
        let task = Task { try await requestToken() }
        inFlight = task
        defer { inFlight = nil }
        let token = try await task.value
        cached = token
        return token
    }

    /// Drops the cached token, so the next call requests a new one.
    public func invalidate() {
        cached = nil
    }

    private func requestToken() async throws -> OAuthToken {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var form = [
            ("grant_type", "client_credentials"),
            ("client_id", clientID),
            ("client_secret", clientSecret),
        ]
        if !scopes.isEmpty {
            form.append(("scope", scopes.joined(separator: " ")))
        }
        request.httpBody = Data(form.map { "\(Self.encode($0.0))=\(Self.encode($0.1))" }
            .joined(separator: "&").utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OAuthError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw OAuthError.tokenRequestFailed(
                status: http.statusCode, body: String(decoding: data, as: UTF8.self))
        }

        struct Payload: Decodable {
            let access_token: String
            let token_type: String?
            let expires_in: Double?
            let scope: String?
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            throw OAuthError.invalidResponse
        }
        return OAuthToken(
            accessToken: payload.access_token,
            tokenType: payload.token_type ?? "Bearer",
            expiresAt: now().addingTimeInterval(payload.expires_in ?? 3600),
            scope: payload.scope
        )
    }

    /// Percent-encodes a form value; only unreserved characters stay as they are.
    private static func encode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
