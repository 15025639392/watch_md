import Foundation

public struct GeoCoordinate: Codable, Equatable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct GeoBounds: Codable, Equatable, Sendable {
    public var minLatitude: Double
    public var minLongitude: Double
    public var maxLatitude: Double
    public var maxLongitude: Double

    public init(minLatitude: Double, minLongitude: Double, maxLatitude: Double, maxLongitude: Double) {
        self.minLatitude = minLatitude
        self.minLongitude = minLongitude
        self.maxLatitude = maxLatitude
        self.maxLongitude = maxLongitude
    }

    public static func enclosing(_ coordinates: [GeoCoordinate]) throws -> GeoBounds {
        guard let first = coordinates.first else { throw RouteValidationError.emptyRoute }
        return coordinates.dropFirst().reduce(
            GeoBounds(
                minLatitude: first.latitude,
                minLongitude: first.longitude,
                maxLatitude: first.latitude,
                maxLongitude: first.longitude
            )
        ) { bounds, coordinate in
            GeoBounds(
                minLatitude: min(bounds.minLatitude, coordinate.latitude),
                minLongitude: min(bounds.minLongitude, coordinate.longitude),
                maxLatitude: max(bounds.maxLatitude, coordinate.latitude),
                maxLongitude: max(bounds.maxLongitude, coordinate.longitude)
            )
        }
    }
}

public enum RouteSource: String, Codable, Sendable {
    case remoteCatalog
    case gpxImport
    case manual
    case shared
    case watchRemoteFetch
}

public enum RouteVariantKind: String, Codable, Sendable {
    case original
    case simplifiedForWatch
    case preview
}

public enum RouteQualityStatus: String, Codable, Sendable {
    case normal
    case sparsePoints
    case missingElevation
    case needsReview
}

public enum LocalRouteStatus: String, Codable, Sendable {
    case notDownloaded
    case downloaded
    case hasUpdate
    case syncedToWatch
}

public struct RoutePoint: Codable, Equatable, Sendable {
    public var index: Int
    public var latitude: Double
    public var longitude: Double
    public var elevationMeters: Double?
    public var distanceFromStartMeters: Double
    public var timestamp: Date?

    public init(index: Int, latitude: Double, longitude: Double, elevationMeters: Double?, distanceFromStartMeters: Double, timestamp: Date? = nil) {
        self.index = index
        self.latitude = latitude
        self.longitude = longitude
        self.elevationMeters = elevationMeters
        self.distanceFromStartMeters = distanceFromStartMeters
        self.timestamp = timestamp
    }

    public var coordinate: GeoCoordinate {
        GeoCoordinate(latitude: latitude, longitude: longitude)
    }
}

public struct RouteVariant: Codable, Equatable, Sendable {
    public var variantId: String
    public var routeId: String
    public var routeVersion: Int
    public var kind: RouteVariantKind
    public var points: [RoutePoint]
    public var pointCount: Int
    public var distanceMeters: Double
    public var simplificationToleranceMeters: Double?
    public var checksum: String

    public init(variantId: String, routeId: String, routeVersion: Int, kind: RouteVariantKind, points: [RoutePoint], simplificationToleranceMeters: Double? = nil, checksum: String) {
        self.variantId = variantId
        self.routeId = routeId
        self.routeVersion = routeVersion
        self.kind = kind
        self.points = points
        self.pointCount = points.count
        self.distanceMeters = points.last?.distanceFromStartMeters ?? 0
        self.simplificationToleranceMeters = simplificationToleranceMeters
        self.checksum = checksum
    }
}

public enum WaypointKind: String, Codable, Sendable {
    case start
    case end
    case water
    case camp
    case risk
    case viewpoint
    case custom
}

public struct Waypoint: Codable, Equatable, Sendable {
    public var waypointId: String
    public var routeId: String
    public var name: String
    public var kind: WaypointKind
    public var coordinate: GeoCoordinate
    public var distanceFromStartMeters: Double?
    public var note: String?
    public var alertEnabled: Bool
    public var alertDistanceMeters: Double?

    public init(waypointId: String, routeId: String, name: String, kind: WaypointKind, coordinate: GeoCoordinate, distanceFromStartMeters: Double?, note: String? = nil, alertEnabled: Bool = true, alertDistanceMeters: Double? = nil) {
        self.waypointId = waypointId
        self.routeId = routeId
        self.name = name
        self.kind = kind
        self.coordinate = coordinate
        self.distanceFromStartMeters = distanceFromStartMeters
        self.note = note
        self.alertEnabled = alertEnabled
        self.alertDistanceMeters = alertDistanceMeters
    }
}

public enum TurnDirection: String, Codable, Sendable {
    case left
    case right
    case sharpLeft
    case sharpRight
    case uTurn
}

public struct TurnPoint: Codable, Equatable, Sendable {
    public var turnPointId: String
    public var routeId: String
    public var routeVersion: Int
    public var routePointIndex: Int
    public var coordinate: GeoCoordinate
    public var distanceFromStartMeters: Double
    public var turnAngleDegrees: Double
    public var direction: TurnDirection
    public var alertDistanceMeters: Double

    public init(turnPointId: String, routeId: String, routeVersion: Int, routePointIndex: Int, coordinate: GeoCoordinate, distanceFromStartMeters: Double, turnAngleDegrees: Double, direction: TurnDirection, alertDistanceMeters: Double = 50) {
        self.turnPointId = turnPointId
        self.routeId = routeId
        self.routeVersion = routeVersion
        self.routePointIndex = routePointIndex
        self.coordinate = coordinate
        self.distanceFromStartMeters = distanceFromStartMeters
        self.turnAngleDegrees = turnAngleDegrees
        self.direction = direction
        self.alertDistanceMeters = alertDistanceMeters
    }
}

public struct HikingRoute: Codable, Equatable, Sendable {
    public var routeId: String
    public var version: Int
    public var name: String
    public var source: RouteSource
    public var remoteRouteId: String?
    public var remoteVersion: String?
    public var sourceProvider: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var distanceMeters: Double
    public var ascentMeters: Double?
    public var descentMeters: Double?
    public var estimatedDurationSeconds: Int?
    public var bounds: GeoBounds
    public var startPoint: GeoCoordinate
    public var endPoint: GeoCoordinate
    public var originalPointCount: Int
    public var simplifiedPointCount: Int
    public var hasElevation: Bool
    public var checksum: String
}

public struct RemoteRouteSummary: Codable, Equatable, Sendable {
    public var remoteRouteId: String
    public var remoteVersion: String
    public var name: String
    public var regionName: String?
    public var distanceMeters: Double
    public var ascentMeters: Double?
    public var estimatedDurationSeconds: Int?
    public var bounds: GeoBounds?
    public var startName: String?
    public var endName: String?
    public var qualityStatus: RouteQualityStatus
    public var updatedAt: Date
    public var checksum: String
    public var localStatus: LocalRouteStatus
}

public struct InstalledRoute: Codable, Equatable, Sendable {
    public var route: HikingRoute
    public var original: RouteVariant
    public var simplifiedForWatch: RouteVariant
    public var waypoints: [Waypoint]
    public var turnPoints: [TurnPoint]
}

public enum RouteValidationError: Error, Equatable {
    case emptyRoute
    case tooFewPoints
    case invalidCoordinate(index: Int)
    case checksumMismatch
}
