import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing
@testable import MyUplink

/// Returns a canned response and records the request it received.
private final class StubTransport: ClientTransport, @unchecked Sendable {
    var lastRequest: HTTPRequest?
    let status: HTTPResponse.Status
    let json: String

    init(status: HTTPResponse.Status = .ok, json: String) {
        self.status = status
        self.json = json
    }

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        lastRequest = request
        var response = HTTPResponse(status: status)
        response.headerFields[.contentType] = "application/json"
        return (response, HTTPBody(json))
    }
}

@Test func addsBearerTokenAndDecodesResponse() async throws {
    let transport = StubTransport(json: #"{"aidMode":1}"#)
    let client = Client(
        serverURL: MyUplinkServer.production,
        transport: transport,
        middlewares: [BearerTokenMiddleware { "secret" }]
    )

    let response = try await client.getV2DevicesDeviceIdAidMode(path: .init(deviceId: "dev-1"))

    #expect(transport.lastRequest?.headerFields[.authorization] == "Bearer secret")
    #expect(transport.lastRequest?.path == "/v2/devices/dev-1/aidMode")
    #expect(try response.ok.body.json.aidMode?.rawValue == 1)
}

@Test func unauthorizedIsSurfaced() async throws {
    let transport = StubTransport(status: .unauthorized, json: "")
    let client = Client(serverURL: MyUplinkServer.production, transport: transport)

    let response = try await client.getV2DevicesDeviceIdAidMode(path: .init(deviceId: "dev-1"))

    guard case .unauthorized = response else {
        Issue.record("expected 401, got \(response)")
        return
    }
}
