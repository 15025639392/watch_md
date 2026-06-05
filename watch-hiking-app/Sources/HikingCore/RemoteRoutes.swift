import Foundation

public protocol RemoteRouteClient: Sendable {
    func fetchRouteSummaries(query: String?) async throws -> [RemoteRouteSummary]
    func fetchRouteDetail(remoteRouteId: String) async throws -> InstalledRoute
}

public actor MockRemoteRouteClient: RemoteRouteClient {
    private let routes: [String: InstalledRoute]

    public init(routes: [InstalledRoute]) {
        self.routes = Dictionary(uniqueKeysWithValues: routes.map { ($0.route.remoteRouteId ?? $0.route.routeId, $0) })
    }

    public static func sample() throws -> MockRemoteRouteClient {
        let points = [
            GPXTrackPoint(latitude: 37.8044, longitude: -122.4776, elevationMeters: 12),
            GPXTrackPoint(latitude: 37.8050, longitude: -122.4758, elevationMeters: 18),
            GPXTrackPoint(latitude: 37.8062, longitude: -122.4740, elevationMeters: 31),
            GPXTrackPoint(latitude: 37.8074, longitude: -122.4745, elevationMeters: 45),
            GPXTrackPoint(latitude: 37.8086, longitude: -122.4764, elevationMeters: 58)
        ]
        let installed = try RouteBuilder.buildRoute(
            name: "Golden Gate Ridge Sample",
            source: .remoteCatalog,
            rawPoints: points,
            remoteRouteId: "mock-ggr-001",
            remoteVersion: "2026.06.05",
            sourceProvider: "mock-local-fixture",
            estimatedDurationSeconds: 3600
        )
        return MockRemoteRouteClient(routes: [installed])
    }

    public func fetchRouteSummaries(query: String? = nil) async throws -> [RemoteRouteSummary] {
        let summaries = routes.values.map { installed in
            RemoteRouteSummary(
                remoteRouteId: installed.route.remoteRouteId ?? installed.route.routeId,
                remoteVersion: installed.route.remoteVersion ?? "\(installed.route.version)",
                name: installed.route.name,
                regionName: "Mock Catalog",
                distanceMeters: installed.route.distanceMeters,
                ascentMeters: installed.route.ascentMeters,
                estimatedDurationSeconds: installed.route.estimatedDurationSeconds,
                bounds: installed.route.bounds,
                startName: "起点",
                endName: "终点",
                qualityStatus: installed.route.hasElevation ? .normal : .missingElevation,
                updatedAt: installed.route.updatedAt,
                checksum: installed.route.checksum,
                localStatus: .notDownloaded
            )
        }
        guard let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return summaries.sorted { $0.name < $1.name }
        }
        let lowered = query.lowercased()
        return summaries.filter {
            $0.name.lowercased().contains(lowered)
                || $0.remoteRouteId.lowercased().contains(lowered)
                || ($0.regionName?.lowercased().contains(lowered) ?? false)
        }.sorted { $0.name < $1.name }
    }

    public func fetchRouteDetail(remoteRouteId: String) async throws -> InstalledRoute {
        guard let route = routes[remoteRouteId] else {
            throw CocoaError(.fileNoSuchFile)
        }
        return route
    }
}
