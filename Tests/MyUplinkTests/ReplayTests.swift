import Foundation
import Replay
import Testing
@testable import MyUplink

/// Exercises the generated client end to end over `URLSession`, against HTTP
/// traffic recorded in `Replays/*.har`.
///
/// Playback needs no network or credentials. To re-record against the live API,
/// set `MYUPLINK_TOKEN` and run e.g.
/// `REPLAY_RECORD_MODE=rewrite swift test --filter ReplayTests.systemsAndPoints`.
/// The `Authorization` header is stripped before anything is written.
/// Don't re-record `patchPoints`: it changes a setting on a real device.
/// Keeps access tokens out of recorded archives.
let stripAuth: [Filter] = [.headers(removing: ["Authorization"])]

@Suite(.playbackIsolated(replaysFrom: Bundle.module))
struct ReplayTests {
    /// Sessions from `Replay.session` route to this test's archive, so tests can run in parallel.
    private func makeClient() -> Client {
        let token = ProcessInfo.processInfo.environment["MYUPLINK_TOKEN"] ?? "replay-token"
        return .myUplink(session: Replay.session, token: { token })
    }

    @Test(.replay("systemsAndPoints", matching: [.method, .path, .query], filters: stripAuth, scope: .test))
    func systemsAndPoints() async throws {
        let client = makeClient()

        let systems = try await client.getV2SystemsMe(query: .init(page: 1, itemsPerPage: 10)).ok.body.json
        let system = try #require(systems.systems?.first)
        let device = try #require(system.devices?.first)
        let deviceId = try #require(device.id)
        #expect(system.securityLevel == .admin)
        #expect(device.connectionState == .connected)

        let points = try await client.getV2DevicesDeviceIdPoints(
            path: .init(deviceId: deviceId),
            query: .init(parameters: "40004,47011")
        ).ok.body.json
        #expect(points.map(\.parameterId) == ["40004", "47011"])
        #expect(points.allSatisfy { $0.timestamp != nil })
    }

    @Test(.replay("patchPoints", matching: [.method, .path], filters: stripAuth, scope: .test))
    func patchPoints() async throws {
        let response = try await makeClient().patchV2DevicesDeviceIdPoints(
            path: .init(deviceId: "emmy-r-000000-20260101-000000000000-00-00-00-00-00-00"),
            body: .json(.init(additionalProperties: ["47011": "-1"]))
        )

        #expect(try response.ok.body.json.additionalProperties == ["47011": "-1"])
    }

    @Test(.replay("unauthorized", matching: [.method, .path], filters: stripAuth, scope: .test))
    func unauthorizedIsSurfaced() async throws {
        let response = try await makeClient().getV2SystemsMe()

        guard case .unauthorized = response else {
            Issue.record("expected 401, got \(response)")
            return
        }
    }
}
