import CryptoKit
import Foundation

public enum SyncEndpoint: String, Codable, Sendable {
    case iphone
    case watch
}

public enum SyncEnvelopeKind: String, Codable, Sendable {
    case routeManifest
    case routePayload
    case syncAck
}

public enum SyncAckStatus: String, Codable, Sendable {
    case ok
    case alreadyReceived
    case rejected
    case failed
}

public enum SyncAckAction: String, Codable, Sendable {
    case readyForPayload
    case routeAlreadyInstalled
    case routeManifestRejected
    case routeInstalled
    case routePayloadRejected
}

public enum RouteSyncState: String, Codable, Sendable {
    case notSynced
    case manifestSent
    case readyForPayload
    case payloadTransferred
    case installed
    case failed
}

public struct SyncEnvelope<Payload: Codable & Sendable>: Codable, Equatable, Sendable where Payload: Equatable {
    public var envelopeId: String
    public var schemaVersion: Int
    public var createdAt: Date
    public var sender: SyncEndpoint
    public var kind: SyncEnvelopeKind
    public var entityId: String
    public var entityVersion: Int?
    public var sequence: Int?
    public var isFinal: Bool
    public var payloadChecksum: String
    public var payload: Payload

    public init(
        envelopeId: String = UUID().uuidString,
        schemaVersion: Int = 1,
        createdAt: Date = Date(),
        sender: SyncEndpoint,
        kind: SyncEnvelopeKind,
        entityId: String,
        entityVersion: Int? = nil,
        sequence: Int? = nil,
        isFinal: Bool = true,
        payloadChecksum: String,
        payload: Payload
    ) {
        self.envelopeId = envelopeId
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.sender = sender
        self.kind = kind
        self.entityId = entityId
        self.entityVersion = entityVersion
        self.sequence = sequence
        self.isFinal = isFinal
        self.payloadChecksum = payloadChecksum
        self.payload = payload
    }
}

public struct RouteManifest: Codable, Equatable, Sendable {
    public var routeId: String
    public var routeVersion: Int
    public var name: String
    public var distanceMeters: Double
    public var bounds: GeoBounds
    public var simplifiedPointCount: Int
    public var turnPointCount: Int
    public var waypointCount: Int
    public var payloadChecksum: String
    public var payloadSizeBytes: Int

    public init(routeId: String, routeVersion: Int, name: String, distanceMeters: Double, bounds: GeoBounds, simplifiedPointCount: Int, turnPointCount: Int, waypointCount: Int, payloadChecksum: String, payloadSizeBytes: Int) {
        self.routeId = routeId
        self.routeVersion = routeVersion
        self.name = name
        self.distanceMeters = distanceMeters
        self.bounds = bounds
        self.simplifiedPointCount = simplifiedPointCount
        self.turnPointCount = turnPointCount
        self.waypointCount = waypointCount
        self.payloadChecksum = payloadChecksum
        self.payloadSizeBytes = payloadSizeBytes
    }
}

public struct AlertConfiguration: Codable, Equatable, Sendable {
    public var offRouteThresholdMeters: Double
    public var returnThresholdMeters: Double
    public var locationWeakAccuracyMeters: Double
    public var confirmPointCount: Int
    public var turnAlertDistanceMeters: Double

    public init(offRouteThresholdMeters: Double = 30, returnThresholdMeters: Double = 20, locationWeakAccuracyMeters: Double = 50, confirmPointCount: Int = 3, turnAlertDistanceMeters: Double = 50) {
        self.offRouteThresholdMeters = offRouteThresholdMeters
        self.returnThresholdMeters = returnThresholdMeters
        self.locationWeakAccuracyMeters = locationWeakAccuracyMeters
        self.confirmPointCount = confirmPointCount
        self.turnAlertDistanceMeters = turnAlertDistanceMeters
    }
}

public struct RoutePayload: Codable, Equatable, Sendable {
    public var route: HikingRoute
    public var simplifiedForWatch: RouteVariant
    public var turnPoints: [TurnPoint]
    public var waypoints: [Waypoint]
    public var alertConfiguration: AlertConfiguration

    public init(route: HikingRoute, simplifiedForWatch: RouteVariant, turnPoints: [TurnPoint], waypoints: [Waypoint], alertConfiguration: AlertConfiguration = AlertConfiguration()) {
        self.route = route
        self.simplifiedForWatch = simplifiedForWatch
        self.turnPoints = turnPoints
        self.waypoints = waypoints
        self.alertConfiguration = alertConfiguration
    }
}

public struct SyncAck: Codable, Equatable, Sendable {
    public var status: SyncAckStatus
    public var action: SyncAckAction
    public var entityId: String
    public var entityVersion: Int?
    public var message: String?

    public init(status: SyncAckStatus, action: SyncAckAction, entityId: String, entityVersion: Int?, message: String? = nil) {
        self.status = status
        self.action = action
        self.entityId = entityId
        self.entityVersion = entityVersion
        self.message = message
    }
}

public enum RouteSyncError: Error, Equatable {
    case manifestRejected(String)
    case payloadChecksumMismatch
    case payloadRouteMismatch
    case payloadMissingRequiredData
    case unexpectedAck(SyncAck)
}

public enum RouteSyncCodec {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public static func routePayload(from installedRoute: InstalledRoute, alertConfiguration: AlertConfiguration = AlertConfiguration()) -> RoutePayload {
        RoutePayload(
            route: installedRoute.route,
            simplifiedForWatch: installedRoute.simplifiedForWatch,
            turnPoints: installedRoute.turnPoints,
            waypoints: installedRoute.waypoints,
            alertConfiguration: alertConfiguration
        )
    }

    public static func payloadData(_ payload: RoutePayload) throws -> Data {
        try encoder.encode(payload)
    }

    public static func checksum(data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func makeManifest(for installedRoute: InstalledRoute, alertConfiguration: AlertConfiguration = AlertConfiguration()) throws -> RouteManifest {
        let payload = routePayload(from: installedRoute, alertConfiguration: alertConfiguration)
        let data = try payloadData(payload)
        return RouteManifest(
            routeId: installedRoute.route.routeId,
            routeVersion: installedRoute.route.version,
            name: installedRoute.route.name,
            distanceMeters: installedRoute.route.distanceMeters,
            bounds: installedRoute.route.bounds,
            simplifiedPointCount: installedRoute.route.simplifiedPointCount,
            turnPointCount: installedRoute.turnPoints.count,
            waypointCount: installedRoute.waypoints.count,
            payloadChecksum: checksum(data: data),
            payloadSizeBytes: data.count
        )
    }

    public static func makeManifestEnvelope(for installedRoute: InstalledRoute, alertConfiguration: AlertConfiguration = AlertConfiguration()) throws -> SyncEnvelope<RouteManifest> {
        let manifest = try makeManifest(for: installedRoute, alertConfiguration: alertConfiguration)
        let manifestData = try encoder.encode(manifest)
        return SyncEnvelope(
            sender: .iphone,
            kind: .routeManifest,
            entityId: manifest.routeId,
            entityVersion: manifest.routeVersion,
            payloadChecksum: checksum(data: manifestData),
            payload: manifest
        )
    }

    public static func makePayloadEnvelope(for installedRoute: InstalledRoute, alertConfiguration: AlertConfiguration = AlertConfiguration()) throws -> SyncEnvelope<RoutePayload> {
        let payload = routePayload(from: installedRoute, alertConfiguration: alertConfiguration)
        let data = try payloadData(payload)
        return SyncEnvelope(
            sender: .iphone,
            kind: .routePayload,
            entityId: payload.route.routeId,
            entityVersion: payload.route.version,
            payloadChecksum: checksum(data: data),
            payload: payload
        )
    }

    public static func makeAckEnvelope(_ ack: SyncAck, sender: SyncEndpoint = .watch) throws -> SyncEnvelope<SyncAck> {
        let data = try encoder.encode(ack)
        return SyncEnvelope(
            sender: sender,
            kind: .syncAck,
            entityId: ack.entityId,
            entityVersion: ack.entityVersion,
            payloadChecksum: checksum(data: data),
            payload: ack
        )
    }
}

public actor WatchRouteInstaller {
    private let routeStore: RouteStore
    private var installedKeys: Set<String> = []
    private var expectedManifests: [String: RouteManifest] = [:]

    public init(routeStore: RouteStore) {
        self.routeStore = routeStore
    }

    public func receiveManifest(_ envelope: SyncEnvelope<RouteManifest>) async throws -> SyncEnvelope<SyncAck> {
        let manifest = envelope.payload
        let key = installKey(routeId: manifest.routeId, version: manifest.routeVersion, checksum: manifest.payloadChecksum)
        if installedKeys.contains(key) {
            return try RouteSyncCodec.makeAckEnvelope(SyncAck(
                status: .alreadyReceived,
                action: .routeAlreadyInstalled,
                entityId: manifest.routeId,
                entityVersion: manifest.routeVersion
            ))
        }
        guard manifest.simplifiedPointCount >= 2, manifest.waypointCount >= 2 else {
            return try RouteSyncCodec.makeAckEnvelope(SyncAck(
                status: .rejected,
                action: .routeManifestRejected,
                entityId: manifest.routeId,
                entityVersion: manifest.routeVersion,
                message: "Route payload is missing required watch data."
            ))
        }
        expectedManifests[manifest.routeId] = manifest
        return try RouteSyncCodec.makeAckEnvelope(SyncAck(
            status: .ok,
            action: .readyForPayload,
            entityId: manifest.routeId,
            entityVersion: manifest.routeVersion
        ))
    }

    public func receivePayload(_ envelope: SyncEnvelope<RoutePayload>) async throws -> SyncEnvelope<SyncAck> {
        let payload = envelope.payload
        guard let manifest = expectedManifests[payload.route.routeId] else {
            return try RouteSyncCodec.makeAckEnvelope(SyncAck(
                status: .rejected,
                action: .routePayloadRejected,
                entityId: payload.route.routeId,
                entityVersion: payload.route.version,
                message: "Route manifest was not accepted before payload."
            ))
        }
        let data = try RouteSyncCodec.payloadData(payload)
        guard RouteSyncCodec.checksum(data: data) == manifest.payloadChecksum,
              envelope.payloadChecksum == manifest.payloadChecksum else {
            return try RouteSyncCodec.makeAckEnvelope(SyncAck(
                status: .rejected,
                action: .routePayloadRejected,
                entityId: payload.route.routeId,
                entityVersion: payload.route.version,
                message: "Route payload checksum mismatch."
            ))
        }
        guard payload.route.routeId == manifest.routeId,
              payload.route.version == manifest.routeVersion,
              payload.simplifiedForWatch.kind == .simplifiedForWatch,
              payload.simplifiedForWatch.points.count == manifest.simplifiedPointCount,
              payload.waypoints.count == manifest.waypointCount,
              payload.turnPoints.count == manifest.turnPointCount else {
            return try RouteSyncCodec.makeAckEnvelope(SyncAck(
                status: .rejected,
                action: .routePayloadRejected,
                entityId: payload.route.routeId,
                entityVersion: payload.route.version,
                message: "Route payload fields do not match manifest."
            ))
        }
        let installed = InstalledRoute(
            route: payload.route,
            original: RouteVariant(
                variantId: "\(payload.route.routeId)-watch-original-placeholder-v\(payload.route.version)",
                routeId: payload.route.routeId,
                routeVersion: payload.route.version,
                kind: .original,
                points: [],
                checksum: payload.route.checksum
            ),
            simplifiedForWatch: payload.simplifiedForWatch,
            waypoints: payload.waypoints,
            turnPoints: payload.turnPoints
        )
        try await routeStore.save(installed)
        installedKeys.insert(installKey(routeId: manifest.routeId, version: manifest.routeVersion, checksum: manifest.payloadChecksum))
        expectedManifests.removeValue(forKey: manifest.routeId)
        return try RouteSyncCodec.makeAckEnvelope(SyncAck(
            status: .ok,
            action: .routeInstalled,
            entityId: payload.route.routeId,
            entityVersion: payload.route.version
        ))
    }

    public func installedRouteIds() async throws -> [String] {
        try await routeStore.listRoutes().map(\.route.routeId)
    }

    private func installKey(routeId: String, version: Int, checksum: String) -> String {
        "\(routeId)-v\(version)-\(checksum)"
    }
}

public actor RouteSyncCoordinator {
    private(set) public var state: RouteSyncState = .notSynced

    public init() {}

    public func handleManifestAck(_ ack: SyncAck) throws {
        switch (ack.status, ack.action) {
        case (.ok, .readyForPayload):
            state = .readyForPayload
        case (.alreadyReceived, .routeAlreadyInstalled):
            state = .installed
        case (.rejected, .routeManifestRejected):
            state = .failed
            throw RouteSyncError.manifestRejected(ack.message ?? "Route manifest rejected.")
        default:
            state = .failed
            throw RouteSyncError.unexpectedAck(ack)
        }
    }

    public func markManifestSent() {
        state = .manifestSent
    }

    public func markPayloadTransferred() {
        state = .payloadTransferred
    }

    public func handlePayloadAck(_ ack: SyncAck) throws {
        switch (ack.status, ack.action) {
        case (.ok, .routeInstalled), (.alreadyReceived, .routeAlreadyInstalled):
            state = .installed
        default:
            state = .failed
            throw RouteSyncError.unexpectedAck(ack)
        }
    }
}
