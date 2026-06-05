import CryptoKit
import Foundation

public struct RouteBuildOptions: Sendable {
    public var watchSimplificationToleranceMeters: Double
    public var turnAngleThresholdDegrees: Double
    public var minimumTurnSpacingMeters: Double

    public init(watchSimplificationToleranceMeters: Double = 12, turnAngleThresholdDegrees: Double = 40, minimumTurnSpacingMeters: Double = 25) {
        self.watchSimplificationToleranceMeters = watchSimplificationToleranceMeters
        self.turnAngleThresholdDegrees = turnAngleThresholdDegrees
        self.minimumTurnSpacingMeters = minimumTurnSpacingMeters
    }
}

public enum RouteBuilder {
    public static func buildRoute(
        name: String,
        source: RouteSource,
        rawPoints: [GPXTrackPoint],
        remoteRouteId: String? = nil,
        remoteVersion: String? = nil,
        sourceProvider: String? = nil,
        estimatedDurationSeconds: Int? = nil,
        options: RouteBuildOptions = RouteBuildOptions()
    ) throws -> InstalledRoute {
        guard rawPoints.count >= 2 else { throw RouteValidationError.tooFewPoints }
        let routeId = stableRouteId(name: name, source: source, remoteRouteId: remoteRouteId, rawPoints: rawPoints)
        let version = 1
        let originalPoints = makeRoutePoints(rawPoints)
        let simplifiedRaw = simplify(rawPoints, toleranceMeters: options.watchSimplificationToleranceMeters)
        let simplifiedPoints = makeRoutePoints(simplifiedRaw)
        let coordinates = originalPoints.map(\.coordinate)
        let bounds = try GeoBounds.enclosing(coordinates)
        let checksum = checksumFor(points: originalPoints)
        let now = Date()
        let ascentDescent = elevationGainLoss(rawPoints)
        let original = RouteVariant(
            variantId: "\(routeId)-original-v\(version)",
            routeId: routeId,
            routeVersion: version,
            kind: .original,
            points: originalPoints,
            checksum: checksum
        )
        let simplified = RouteVariant(
            variantId: "\(routeId)-watch-v\(version)",
            routeId: routeId,
            routeVersion: version,
            kind: .simplifiedForWatch,
            points: simplifiedPoints,
            simplificationToleranceMeters: options.watchSimplificationToleranceMeters,
            checksum: checksumFor(points: simplifiedPoints)
        )
        let route = HikingRoute(
            routeId: routeId,
            version: version,
            name: name,
            source: source,
            remoteRouteId: remoteRouteId,
            remoteVersion: remoteVersion,
            sourceProvider: sourceProvider,
            createdAt: now,
            updatedAt: now,
            distanceMeters: original.distanceMeters,
            ascentMeters: ascentDescent.ascent,
            descentMeters: ascentDescent.descent,
            estimatedDurationSeconds: estimatedDurationSeconds,
            bounds: bounds,
            startPoint: originalPoints[0].coordinate,
            endPoint: originalPoints[originalPoints.count - 1].coordinate,
            originalPointCount: originalPoints.count,
            simplifiedPointCount: simplifiedPoints.count,
            hasElevation: rawPoints.contains { $0.elevationMeters != nil },
            checksum: checksum
        )
        let waypoints = [
            Waypoint(waypointId: "\(routeId)-start", routeId: routeId, name: "起点", kind: .start, coordinate: route.startPoint, distanceFromStartMeters: 0),
            Waypoint(waypointId: "\(routeId)-end", routeId: routeId, name: "终点", kind: .end, coordinate: route.endPoint, distanceFromStartMeters: route.distanceMeters)
        ]
        let turns = generateTurnPoints(routeId: routeId, routeVersion: version, points: simplifiedPoints, options: options)
        return InstalledRoute(route: route, original: original, simplifiedForWatch: simplified, waypoints: waypoints, turnPoints: turns)
    }

    public static func makeRoutePoints(_ rawPoints: [GPXTrackPoint]) -> [RoutePoint] {
        let distances = GeoMath.cumulativeDistances(for: rawPoints.map(\.coordinate))
        return rawPoints.enumerated().map { index, point in
            RoutePoint(
                index: index,
                latitude: point.latitude,
                longitude: point.longitude,
                elevationMeters: point.elevationMeters,
                distanceFromStartMeters: distances[index],
                timestamp: point.timestamp
            )
        }
    }

    public static func generateTurnPoints(routeId: String, routeVersion: Int, points: [RoutePoint], options: RouteBuildOptions = RouteBuildOptions()) -> [TurnPoint] {
        guard points.count >= 3 else { return [] }
        var turns: [TurnPoint] = []
        var lastTurnDistance = -Double.greatestFiniteMagnitude
        for index in 1..<(points.count - 1) {
            let previousBearing = GeoMath.bearingDegrees(from: points[index - 1].coordinate, to: points[index].coordinate)
            let nextBearing = GeoMath.bearingDegrees(from: points[index].coordinate, to: points[index + 1].coordinate)
            let delta = GeoMath.angularDeltaDegrees(from: previousBearing, to: nextBearing)
            let angle = abs(delta)
            guard angle >= options.turnAngleThresholdDegrees else { continue }
            guard points[index].distanceFromStartMeters - lastTurnDistance >= options.minimumTurnSpacingMeters else { continue }
            lastTurnDistance = points[index].distanceFromStartMeters
            let direction: TurnDirection
            if angle >= 150 {
                direction = .uTurn
            } else if delta < 0 {
                direction = angle >= 90 ? .sharpLeft : .left
            } else {
                direction = angle >= 90 ? .sharpRight : .right
            }
            turns.append(TurnPoint(
                turnPointId: "\(routeId)-turn-\(index)",
                routeId: routeId,
                routeVersion: routeVersion,
                routePointIndex: points[index].index,
                coordinate: points[index].coordinate,
                distanceFromStartMeters: points[index].distanceFromStartMeters,
                turnAngleDegrees: angle,
                direction: direction
            ))
        }
        return turns
    }

    public static func simplify(_ points: [GPXTrackPoint], toleranceMeters: Double) -> [GPXTrackPoint] {
        guard points.count > 2 else { return points }
        let first = points[0]
        let last = points[points.count - 1]
        var maxDistance = 0.0
        var maxIndex = 0
        for index in 1..<(points.count - 1) {
            let distance = perpendicularDistanceMeters(point: points[index].coordinate, lineStart: first.coordinate, lineEnd: last.coordinate)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = index
            }
        }
        if maxDistance > toleranceMeters {
            let left = simplify(Array(points[0...maxIndex]), toleranceMeters: toleranceMeters)
            let right = simplify(Array(points[maxIndex...]), toleranceMeters: toleranceMeters)
            return left.dropLast() + right
        }
        return [first, last]
    }

    public static func checksumFor(points: [RoutePoint]) -> String {
        let body = points.map { point in
            "\(point.index):\(point.latitude):\(point.longitude):\(point.elevationMeters ?? -9999)"
        }.joined(separator: "|")
        let digest = SHA256.hash(data: Data(body.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func stableRouteId(name: String, source: RouteSource, remoteRouteId: String?, rawPoints: [GPXTrackPoint]) -> String {
        if let remoteRouteId {
            return "remote-\(remoteRouteId)"
        }
        let seed = "\(source.rawValue):\(name):\(rawPoints.first?.latitude ?? 0):\(rawPoints.first?.longitude ?? 0):\(rawPoints.count)"
        let digest = SHA256.hash(data: Data(seed.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        return "route-\(digest)"
    }

    private static func elevationGainLoss(_ points: [GPXTrackPoint]) -> (ascent: Double?, descent: Double?) {
        guard points.contains(where: { $0.elevationMeters != nil }) else { return (nil, nil) }
        var ascent = 0.0
        var descent = 0.0
        for index in 1..<points.count {
            guard let previous = points[index - 1].elevationMeters, let current = points[index].elevationMeters else { continue }
            let delta = current - previous
            if delta > 0 { ascent += delta } else { descent += abs(delta) }
        }
        return (ascent, descent)
    }

    private static func perpendicularDistanceMeters(point: GeoCoordinate, lineStart: GeoCoordinate, lineEnd: GeoCoordinate) -> Double {
        let metersPerDegreeLatitude = 111_320.0
        let latitudeScale = cos(GeoMath.degreesToRadians((lineStart.latitude + lineEnd.latitude) / 2))
        func xy(_ coordinate: GeoCoordinate) -> (x: Double, y: Double) {
            (
                x: coordinate.longitude * metersPerDegreeLatitude * latitudeScale,
                y: coordinate.latitude * metersPerDegreeLatitude
            )
        }
        let p = xy(point)
        let a = xy(lineStart)
        let b = xy(lineEnd)
        let dx = b.x - a.x
        let dy = b.y - a.y
        guard dx != 0 || dy != 0 else { return GeoMath.distanceMeters(from: point, to: lineStart) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / (dx * dx + dy * dy)))
        let projection = (x: a.x + t * dx, y: a.y + t * dy)
        return hypot(p.x - projection.x, p.y - projection.y)
    }
}
