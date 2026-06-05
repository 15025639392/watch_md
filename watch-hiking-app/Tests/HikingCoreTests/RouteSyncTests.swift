import Foundation
import Testing
@testable import HikingCore

@Suite("Slice 2 route sync")
struct RouteSyncTests {
    @Test("Route manifest and payload install route on Watch after ACK flow")
    func routeSyncInstallsRoute() async throws {
        let installedRoute = try await sampleInstalledRoute()
        let installer = try await makeInstaller()
        let coordinator = RouteSyncCoordinator()

        let manifestEnvelope = try RouteSyncCodec.makeManifestEnvelope(for: installedRoute)
        await coordinator.markManifestSent()
        let manifestAck = try await installer.receiveManifest(manifestEnvelope)
        try await coordinator.handleManifestAck(manifestAck.payload)

        #expect(await coordinator.state == .readyForPayload)
        #expect(manifestAck.payload.status == .ok)
        #expect(manifestAck.payload.action == .readyForPayload)

        let payloadEnvelope = try RouteSyncCodec.makePayloadEnvelope(for: installedRoute)
        await coordinator.markPayloadTransferred()
        let payloadAck = try await installer.receivePayload(payloadEnvelope)
        try await coordinator.handlePayloadAck(payloadAck.payload)

        #expect(await coordinator.state == .installed)
        #expect(payloadAck.payload.status == .ok)
        #expect(payloadAck.payload.action == .routeInstalled)
        #expect(try await installer.installedRouteIds() == [installedRoute.route.routeId])
    }

    @Test("Duplicate route manifest returns already installed without replacing route")
    func duplicateManifestIsIdempotent() async throws {
        let installedRoute = try await sampleInstalledRoute()
        let installer = try await makeInstaller()
        let manifest = try RouteSyncCodec.makeManifestEnvelope(for: installedRoute)
        let payload = try RouteSyncCodec.makePayloadEnvelope(for: installedRoute)

        _ = try await installer.receiveManifest(manifest)
        _ = try await installer.receivePayload(payload)
        let duplicateAck = try await installer.receiveManifest(manifest)

        #expect(duplicateAck.payload.status == .alreadyReceived)
        #expect(duplicateAck.payload.action == .routeAlreadyInstalled)
        #expect(try await installer.installedRouteIds() == [installedRoute.route.routeId])
    }

    @Test("Checksum mismatch rejects payload and keeps previous route available")
    func checksumMismatchDoesNotInstallNewRoute() async throws {
        let firstRoute = try await sampleInstalledRoute()
        let newRoute = try RouteBuilder.buildRoute(
            name: "Broken Payload Route",
            source: .remoteCatalog,
            rawPoints: [
                GPXTrackPoint(latitude: 37.0, longitude: -122.0),
                GPXTrackPoint(latitude: 37.1, longitude: -122.0),
                GPXTrackPoint(latitude: 37.1, longitude: -122.1)
            ],
            remoteRouteId: "mock-broken-002",
            remoteVersion: "2026.06.06"
        )
        let installer = try await makeInstaller()
        _ = try await installer.receiveManifest(try RouteSyncCodec.makeManifestEnvelope(for: firstRoute))
        _ = try await installer.receivePayload(try RouteSyncCodec.makePayloadEnvelope(for: firstRoute))

        let newManifest = try RouteSyncCodec.makeManifestEnvelope(for: newRoute)
        _ = try await installer.receiveManifest(newManifest)
        var tamperedPayload = try RouteSyncCodec.makePayloadEnvelope(for: newRoute)
        tamperedPayload.payload.route.name = "Tampered After Manifest"
        let rejected = try await installer.receivePayload(tamperedPayload)

        #expect(rejected.payload.status == .rejected)
        #expect(rejected.payload.action == .routePayloadRejected)
        #expect(try await installer.installedRouteIds() == [firstRoute.route.routeId])
    }

    @Test("Manifest exposes complete Watch route payload counts")
    func manifestContainsWatchRequiredCounts() async throws {
        let installedRoute = try await sampleInstalledRoute()
        let manifest = try RouteSyncCodec.makeManifest(for: installedRoute)

        #expect(manifest.routeId == installedRoute.route.routeId)
        #expect(manifest.simplifiedPointCount == installedRoute.simplifiedForWatch.points.count)
        #expect(manifest.turnPointCount == installedRoute.turnPoints.count)
        #expect(manifest.waypointCount == installedRoute.waypoints.count)
        #expect(manifest.payloadSizeBytes > 0)
        #expect(manifest.payloadChecksum.isEmpty == false)
    }

    private func sampleInstalledRoute() async throws -> InstalledRoute {
        try await MockRemoteRouteClient.sample().fetchRouteDetail(remoteRouteId: "mock-ggr-001")
    }

    private func makeInstaller() async throws -> WatchRouteInstaller {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("WatchRouteInstallerTests-\(UUID().uuidString)", isDirectory: true)
        return try WatchRouteInstaller(routeStore: RouteStore(directoryURL: url))
    }
}
