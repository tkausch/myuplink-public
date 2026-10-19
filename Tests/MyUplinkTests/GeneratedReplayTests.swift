import Foundation
import OpenAPIRuntime
import Replay
import Testing
@testable import MyUplink

/// One test per operation, played back from the archives written by
/// `scripts/generate-replays.py`. Each archive holds a schema-shaped success
/// response, so these tests check that every generated decoder accepts a fully
/// populated payload. Path values match `PATH_VALUES` in the script.
@Suite(.playbackIsolated(replaysFrom: Bundle.module))
struct GeneratedReplayTests {
    private let deviceId = "device-1"
    private let systemId = "00000000-0000-0000-0000-000000000001"
    private let client = Client.myUplink(session: Replay.session, token: { "replay-token" })

    // MARK: Devices

    @Test(.replay("getV2DevicesDeviceId", matching: [.method, .path], filters: stripAuth, scope: .test))
    func getDevice() async throws {
        let device = try await client.getV2DevicesDeviceId(path: .init(deviceId: deviceId)).ok.body.json
        #expect(device.availableFeatures != nil)
    }

    @Test(.replay("getV2DevicesDeviceIdAidMode", matching: [.method, .path], filters: stripAuth, scope: .test))
    func getAidMode() async throws {
        let body = try await client.getV2DevicesDeviceIdAidMode(path: .init(deviceId: deviceId)).ok.body.json
        #expect(body.aidMode?.rawValue == 0)
    }

    @Test(.replay("getV2DevicesDeviceIdSmartHomeCategories", matching: [.method, .path], filters: stripAuth, scope: .test))
    func getSmartHomeCategories() async throws {
        _ = try await client.getV2DevicesDeviceIdSmartHomeCategories(path: .init(deviceId: deviceId)).ok.body.json
    }

    @Test(.replay("getV2DevicesDeviceIdSmartHomeZones", matching: [.method, .path], filters: stripAuth, scope: .test))
    func getSmartHomeZones() async throws {
        let zones = try await client.getV2DevicesDeviceIdSmartHomeZones(path: .init(deviceId: deviceId)).ok.body.json
        #expect(zones.count == 1)
    }

    @Test(.replay("getV2DevicesDeviceIdPoints", matching: [.method, .path], filters: stripAuth, scope: .test))
    func getPointsV2() async throws {
        let points = try await client.getV2DevicesDeviceIdPoints(path: .init(deviceId: deviceId)).ok.body.json
        #expect(points.count == 1)
    }

    @Test(.replay("getV3DevicesDeviceIdPoints", matching: [.method, .path], filters: stripAuth, scope: .test))
    func getPointsV3() async throws {
        let points = try await client.getV3DevicesDeviceIdPoints(path: .init(deviceId: deviceId)).ok.body.json
        #expect(points.count == 1)
    }

    @Test(.replay("patchV2DevicesDeviceIdPoints", matching: [.method, .path], filters: stripAuth, scope: .test))
    func patchPoints() async throws {
        let response = try await client.patchV2DevicesDeviceIdPoints(
            path: .init(deviceId: deviceId),
            body: .json(.init(additionalProperties: ["54321": "30", "12346": "-10"]))
        )
        #expect(try response.ok.body.json.additionalProperties.count == 2)
    }

    @Test(.replay("patchV2DevicesDeviceIdZonesZoneId", matching: [.method, .path], filters: stripAuth, scope: .test))
    func patchZone() async throws {
        let response = try await client.patchV2DevicesDeviceIdZonesZoneId(
            path: .init(deviceId: deviceId, zoneId: 1),
            body: .json(.init(setpointHeat: 21))
        )
        _ = try response.ok.body.json
    }

    @Test(.replay("getV2DevicesDeviceIdFirmwareInfo", matching: [.method, .path], filters: stripAuth, scope: .test))
    func getFirmwareInfo() async throws {
        let info = try await client.getV2DevicesDeviceIdFirmwareInfo(path: .init(deviceId: deviceId)).ok.body.json
        #expect(info.currentFwVersion != nil)
    }

    // MARK: Firmware

    @Test(.replay("getV2FirmwareFirmwareTypeIdVersionVersionDownload", matching: [.method, .path], filters: stripAuth, scope: .test))
    func downloadFirmware() async throws {
        let body = try await client.getV2FirmwareFirmwareTypeIdVersionVersionDownload(
            path: .init(firmwareTypeId: "1", version: "1.0.0")
        ).ok.body.binary
        #expect(try await String(collecting: body, upTo: 1024) == "firmware")
    }

    @Test(.replay("getV2BrandsBrandIdFirmwareFirmwareTypeIdVersionVersionDownload", matching: [.method, .path], filters: stripAuth, scope: .test))
    func downloadBrandFirmware() async throws {
        let body = try await client.getV2BrandsBrandIdFirmwareFirmwareTypeIdVersionVersionDownload(
            path: .init(brandId: "brand-1", firmwareTypeId: "1", version: "1.0.0")
        ).ok.body.binary
        #expect(try await String(collecting: body, upTo: 1024) == "firmware")
    }

    // MARK: Ping

    @Test(.replay("getV2Ping", matching: [.method, .path], filters: stripAuth, scope: .test))
    func ping() async throws {
        _ = try await client.getV2Ping().noContent
    }

    @Test(.replay("getV2ProtectedPing", matching: [.method, .path], filters: stripAuth, scope: .test))
    func protectedPing() async throws {
        _ = try await client.getV2ProtectedPing().noContent
    }

    // MARK: Systems

    @Test(.replay("getV2SystemsMe", matching: [.method, .path], filters: stripAuth, scope: .test))
    func getSystems() async throws {
        let page = try await client.getV2SystemsMe().ok.body.json
        #expect(page.systems?.first?.devices?.count == 1)
    }

    @Test(.replay("getV2SystemsSystemIdNotifications", matching: [.method, .path], filters: stripAuth, scope: .test))
    func getNotifications() async throws {
        let page = try await client.getV2SystemsSystemIdNotifications(path: .init(systemId: systemId)).ok.body.json
        #expect(page.notifications?.count == 1)
    }

    @Test(.replay("getV2SystemsSystemIdNotificationsActive", matching: [.method, .path], filters: stripAuth, scope: .test))
    func getActiveNotifications() async throws {
        let page = try await client.getV2SystemsSystemIdNotificationsActive(path: .init(systemId: systemId)).ok.body.json
        #expect(page.notifications?.count == 1)
    }

    @Test(.replay("getV2SystemsSystemIdSubscriptions", matching: [.method, .path], filters: stripAuth, scope: .test))
    func getSubscriptions() async throws {
        let subscriptions = try await client.getV2SystemsSystemIdSubscriptions(path: .init(systemId: systemId)).ok.body.json
        #expect(subscriptions.count == 1)
    }

    @Test(.replay("getV2SystemsSystemIdSmartHomeMode", matching: [.method, .path], filters: stripAuth, scope: .test))
    func getSmartHomeMode() async throws {
        let mode = try await client.getV2SystemsSystemIdSmartHomeMode(path: .init(systemId: systemId)).ok.body.json
        #expect(mode.smartHomeMode == ._default)
    }

    @Test(.replay("putV2SystemsSystemIdSmartHomeMode", matching: [.method, .path], filters: stripAuth, scope: .test))
    func putSmartHomeMode() async throws {
        _ = try await client.putV2SystemsSystemIdSmartHomeMode(
            path: .init(systemId: systemId),
            body: .json(.init(smartHomeMode: .away))
        ).noContent
    }
}
