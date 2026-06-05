import Foundation
import Testing
@testable import HikingCore

@Suite("Slice 1 route import and catalog")
struct RouteImportTests {
    @Test("GPX import builds app-owned route, variants, waypoints, and turns")
    func gpxImportBuildsRoute() throws {
        let url = try #require(Bundle.module.url(forResource: "sample-route", withExtension: "gpx"))
        let data = try Data(contentsOf: url)
        let route = try RouteImportService().importGPX(data: data, routeName: "Sample Ridge")

        #expect(route.route.name == "Sample Ridge")
        #expect(route.route.source == .gpxImport)
        #expect(route.route.originalPointCount == 5)
        #expect(route.route.simplifiedPointCount >= 3)
        #expect(route.route.distanceMeters > 400)
        #expect(route.route.hasElevation)
        #expect(route.route.ascentMeters == 46)
        #expect(route.original.points.first?.distanceFromStartMeters == 0)
        #expect(route.original.points.last?.distanceFromStartMeters == route.route.distanceMeters)
        #expect(route.waypoints.map(\.kind) == [.start, .end])
        #expect(route.turnPoints.isEmpty == false)
    }

    @Test("Mock remote client searches summaries and downloads installable detail")
    func mockRemoteClientProvidesMVPServerShape() async throws {
        let client = try MockRemoteRouteClient.sample()

        let all = try await client.fetchRouteSummaries(query: nil)
        #expect(all.count == 1)
        #expect(all[0].remoteRouteId == "mock-ggr-001")
        #expect(all[0].localStatus == .notDownloaded)

        let filtered = try await client.fetchRouteSummaries(query: "ridge")
        #expect(filtered.count == 1)

        let detail = try await client.fetchRouteDetail(remoteRouteId: "mock-ggr-001")
        #expect(detail.route.source == .remoteCatalog)
        #expect(detail.simplifiedForWatch.kind == .simplifiedForWatch)
        #expect(detail.route.remoteVersion == "2026.06.05")
    }

    @Test("Route store persists before later sync work touches reliable transfer")
    func routeStorePersistsInstalledRoute() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RouteStoreTests-\(UUID().uuidString)", isDirectory: true)
        let store = try RouteStore(directoryURL: url)
        let client = try MockRemoteRouteClient.sample()
        let detail = try await client.fetchRouteDetail(remoteRouteId: "mock-ggr-001")

        try await store.save(detail)
        let loaded = try await store.load(routeId: detail.route.routeId)
        let listed = try await store.listRoutes()

        #expect(loaded.route.routeId == detail.route.routeId)
        #expect(loaded.route.version == detail.route.version)
        #expect(loaded.route.checksum == detail.route.checksum)
        #expect(loaded.original.points == detail.original.points)
        #expect(loaded.simplifiedForWatch.points == detail.simplifiedForWatch.points)
        #expect(listed.map(\.route.routeId) == [detail.route.routeId])
    }

    @Test("Invalid GPX coordinates are rejected")
    func invalidCoordinatesAreRejected() throws {
        let data = Data("""
        <gpx><trk><trkseg><trkpt lat="120" lon="1"></trkpt></trkseg></trk></gpx>
        """.utf8)
        #expect(throws: RouteValidationError.invalidCoordinate(index: 0)) {
            _ = try GPXParser().parse(data: data)
        }
    }
}
