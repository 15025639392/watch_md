import Foundation

public enum HikingSessionStatus: String, Codable, Sendable {
    case planned
    case active
    case paused
    case finished
    case abandoned
}

public enum SessionSyncStatus: String, Codable, Sendable {
    case localOnly
    case pendingUpload
    case syncing
    case synced
    case failed
}

public enum SessionEventType: String, Codable, Sendable {
    case sessionStarted
    case sessionPaused
    case sessionResumed
    case sessionFinished
    case offRouteStarted
    case offRouteUpdated
    case offRouteEnded
    case turnAlertTriggered
    case waypointAlertTriggered
    case locationAccuracyPoor
    case locationRecovered
    case lowBattery
    case appRecovered
    case syncFailed
}

public enum SessionEventSeverity: String, Codable, Sendable {
    case info
    case warning
    case critical
}

public struct HikingSession: Codable, Equatable, Sendable {
    public var sessionId: String
    public var routeId: String
    public var routeVersion: Int
    public var routeName: String
    public var watchDeviceId: String?
    public var status: HikingSessionStatus
    public var startedAt: Date?
    public var endedAt: Date?
    public var lastUpdatedAt: Date
    public var healthKitWorkoutId: String?
    public var syncStatus: SessionSyncStatus

    public init(
        sessionId: String = UUID().uuidString,
        routeId: String,
        routeVersion: Int,
        routeName: String,
        watchDeviceId: String? = nil,
        status: HikingSessionStatus = .planned,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        lastUpdatedAt: Date = Date(),
        healthKitWorkoutId: String? = nil,
        syncStatus: SessionSyncStatus = .localOnly
    ) {
        self.sessionId = sessionId
        self.routeId = routeId
        self.routeVersion = routeVersion
        self.routeName = routeName
        self.watchDeviceId = watchDeviceId
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.lastUpdatedAt = lastUpdatedAt
        self.healthKitWorkoutId = healthKitWorkoutId
        self.syncStatus = syncStatus
    }
}

public struct TrackPoint: Codable, Equatable, Sendable {
    public var trackPointId: String
    public var sessionId: String
    public var sequence: Int
    public var timestamp: Date
    public var latitude: Double
    public var longitude: Double
    public var elevationMeters: Double?
    public var horizontalAccuracyMeters: Double?
    public var verticalAccuracyMeters: Double?
    public var speedMetersPerSecond: Double?
    public var courseDegrees: Double?
    public var heartRateBpm: Double?
    public var isPaused: Bool
    public var nearestRouteDistanceMeters: Double?
    public var routeProgressMeters: Double?

    public init(
        trackPointId: String? = nil,
        sessionId: String,
        sequence: Int,
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        elevationMeters: Double? = nil,
        horizontalAccuracyMeters: Double? = nil,
        verticalAccuracyMeters: Double? = nil,
        speedMetersPerSecond: Double? = nil,
        courseDegrees: Double? = nil,
        heartRateBpm: Double? = nil,
        isPaused: Bool,
        nearestRouteDistanceMeters: Double? = nil,
        routeProgressMeters: Double? = nil
    ) {
        self.trackPointId = trackPointId ?? "\(sessionId)-track-\(sequence)"
        self.sessionId = sessionId
        self.sequence = sequence
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.elevationMeters = elevationMeters
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.verticalAccuracyMeters = verticalAccuracyMeters
        self.speedMetersPerSecond = speedMetersPerSecond
        self.courseDegrees = courseDegrees
        self.heartRateBpm = heartRateBpm
        self.isPaused = isPaused
        self.nearestRouteDistanceMeters = nearestRouteDistanceMeters
        self.routeProgressMeters = routeProgressMeters
    }

    public var coordinate: GeoCoordinate {
        GeoCoordinate(latitude: latitude, longitude: longitude)
    }
}

public struct SessionEvent: Codable, Equatable, Sendable {
    public var eventId: String
    public var sessionId: String
    public var type: SessionEventType
    public var timestamp: Date
    public var coordinate: GeoCoordinate?
    public var routeProgressMeters: Double?
    public var severity: SessionEventSeverity
    public var payload: [String: String]

    public init(
        eventId: String = UUID().uuidString,
        sessionId: String,
        type: SessionEventType,
        timestamp: Date,
        coordinate: GeoCoordinate? = nil,
        routeProgressMeters: Double? = nil,
        severity: SessionEventSeverity = .info,
        payload: [String: String] = [:]
    ) {
        self.eventId = eventId
        self.sessionId = sessionId
        self.type = type
        self.timestamp = timestamp
        self.coordinate = coordinate
        self.routeProgressMeters = routeProgressMeters
        self.severity = severity
        self.payload = payload
    }
}

public struct SessionSummary: Codable, Equatable, Sendable {
    public var sessionId: String
    public var routeId: String
    public var routeName: String
    public var startedAt: Date
    public var endedAt: Date
    public var durationSeconds: Int
    public var movingDurationSeconds: Int?
    public var distanceMeters: Double
    public var ascentMeters: Double?
    public var averageSpeedMetersPerSecond: Double?
    public var maxElevationMeters: Double?
    public var minElevationMeters: Double?
    public var averageHeartRateBpm: Double?
    public var offRouteEventCount: Int
    public var trackPointCount: Int
    public var syncStatus: SessionSyncStatus
}

public struct StoredHikingSession: Codable, Equatable, Sendable {
    public var session: HikingSession
    public var trackPoints: [TrackPoint]
    public var events: [SessionEvent]
    public var summary: SessionSummary?
}

public enum HikingSessionError: Error, Equatable {
    case noActiveSession
    case sessionAlreadyFinished
    case invalidTransition(from: HikingSessionStatus, to: HikingSessionStatus)
    case missingStartTime
}

public actor HikingSessionStore {
    private let directoryURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(directoryURL: URL) throws {
        self.directoryURL = directoryURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    public func save(_ storedSession: StoredHikingSession) throws {
        let data = try encoder.encode(storedSession)
        let sessionURL = directoryURL.appendingPathComponent("\(storedSession.session.sessionId).json")
        let temporaryURL = directoryURL.appendingPathComponent("\(storedSession.session.sessionId).tmp")
        try data.write(to: temporaryURL, options: [.atomic])
        if FileManager.default.fileExists(atPath: sessionURL.path) {
            try FileManager.default.removeItem(at: sessionURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: sessionURL)
    }

    public func evidenceLogURL(sessionId: String) -> URL {
        directoryURL.appendingPathComponent("\(sessionId).evidence.jsonl")
    }

    public func load(sessionId: String) throws -> StoredHikingSession {
        let data = try Data(contentsOf: directoryURL.appendingPathComponent("\(sessionId).json"))
        return try decoder.decode(StoredHikingSession.self, from: data)
    }

    public func listSessions() throws -> [StoredHikingSession] {
        let urls = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        return try urls.map { try decoder.decode(StoredHikingSession.self, from: Data(contentsOf: $0)) }
            .sorted { $0.session.lastUpdatedAt > $1.session.lastUpdatedAt }
    }

    public func recoverOpenSession() throws -> StoredHikingSession? {
        try listSessions().first { stored in
            stored.session.status == .active || stored.session.status == .paused
        }
    }

    public func updateSyncStatus(sessionId: String, syncStatus: SessionSyncStatus) throws -> StoredHikingSession {
        var stored = try load(sessionId: sessionId)
        stored.session.syncStatus = syncStatus
        stored.session.lastUpdatedAt = Date()
        if var summary = stored.summary {
            summary.syncStatus = syncStatus
            stored.summary = summary
        }
        try save(stored)
        return stored
    }
}

public actor HikingSessionRecorder {
    private let store: HikingSessionStore
    private var storedSession: StoredHikingSession?
    private var evidenceLogger: EvidenceLogger?

    public init(store: HikingSessionStore) {
        self.store = store
    }

    public var currentSession: HikingSession? {
        storedSession?.session
    }

    public func recoverOpenSession() async throws -> HikingSession? {
        if let recovered = try await store.recoverOpenSession() {
            storedSession = recovered
            let logger = try EvidenceLogger(fileURL: await store.evidenceLogURL(sessionId: recovered.session.sessionId))
            evidenceLogger = logger
            let policy: EvidenceSamplingPolicy = recovered.session.status == .paused ? .paused : .movingStandard
            try await logger.logSamplingPolicy(
                sessionId: recovered.session.sessionId,
                policy: policy,
                now: Date()
            )
            return recovered.session
        }
        return nil
    }

    public func start(route: InstalledRoute, watchDeviceId: String? = nil, now: Date = Date()) async throws -> HikingSession {
        let session = HikingSession(
            routeId: route.route.routeId,
            routeVersion: route.route.version,
            routeName: route.route.name,
            watchDeviceId: watchDeviceId,
            status: .active,
            startedAt: now,
            lastUpdatedAt: now,
            syncStatus: .localOnly
        )
        let event = SessionEvent(sessionId: session.sessionId, type: .sessionStarted, timestamp: now)
        let stored = StoredHikingSession(session: session, trackPoints: [], events: [event], summary: nil)
        try await store.save(stored)
        storedSession = stored
        let logger = try EvidenceLogger(fileURL: await store.evidenceLogURL(sessionId: session.sessionId))
        evidenceLogger = logger
        try await logger.logSessionMetadata(session: session, route: route, watchDeviceId: watchDeviceId, now: now)
        try await logger.logSamplingPolicy(sessionId: session.sessionId, policy: .movingStandard, now: now)
        try await logger.logSessionEvent(
            sessionId: session.sessionId,
            type: .sessionStarted,
            coordinate: nil,
            routeProgressMeters: nil,
            severity: .info,
            payload: [:],
            timestamp: now
        )
        return session
    }

    public func pause(now: Date = Date()) async throws {
        try await transition(to: .paused, eventType: .sessionPaused, now: now)
    }

    public func resume(now: Date = Date()) async throws {
        try await transition(to: .active, eventType: .sessionResumed, now: now)
    }

    public func appendLocation(
        latitude: Double,
        longitude: Double,
        elevationMeters: Double? = nil,
        horizontalAccuracyMeters: Double? = nil,
        verticalAccuracyMeters: Double? = nil,
        speedMetersPerSecond: Double? = nil,
        courseDegrees: Double? = nil,
        heartRateBpm: Double? = nil,
        nearestRouteDistanceMeters: Double? = nil,
        routeProgressMeters: Double? = nil,
        timestamp: Date = Date(),
        evidenceTiming: EvidenceLocationTiming = EvidenceLocationTiming()
    ) async throws -> TrackPoint? {
        guard var stored = storedSession else { throw HikingSessionError.noActiveSession }
        guard stored.session.status != .finished, stored.session.status != .abandoned else {
            throw HikingSessionError.sessionAlreadyFinished
        }
        try await evidenceLogger?.logRawLocation(
            sessionId: stored.session.sessionId,
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            elevationMeters: elevationMeters,
            horizontalAccuracyMeters: horizontalAccuracyMeters,
            verticalAccuracyMeters: verticalAccuracyMeters,
            speedMetersPerSecond: speedMetersPerSecond,
            courseDegrees: courseDegrees,
            isPaused: stored.session.status == .paused,
            timing: evidenceTiming
        )
        guard stored.session.status == .active else {
            stored.session.lastUpdatedAt = timestamp
            try await store.save(stored)
            storedSession = stored
            return nil
        }

        let nextSequence = (stored.trackPoints.last?.sequence ?? -1) + 1
        let point = TrackPoint(
            sessionId: stored.session.sessionId,
            sequence: nextSequence,
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            elevationMeters: elevationMeters,
            horizontalAccuracyMeters: horizontalAccuracyMeters,
            verticalAccuracyMeters: verticalAccuracyMeters,
            speedMetersPerSecond: speedMetersPerSecond,
            courseDegrees: courseDegrees,
            heartRateBpm: heartRateBpm,
            isPaused: false,
            nearestRouteDistanceMeters: nearestRouteDistanceMeters,
            routeProgressMeters: routeProgressMeters
        )
        stored.trackPoints.append(point)
        stored.session.lastUpdatedAt = timestamp
        try await store.save(stored)
        storedSession = stored
        return point
    }

    public func appendEvent(
        type: SessionEventType,
        coordinate: GeoCoordinate? = nil,
        routeProgressMeters: Double? = nil,
        severity: SessionEventSeverity = .info,
        payload: [String: String] = [:],
        timestamp: Date = Date()
    ) async throws -> SessionEvent {
        guard var stored = storedSession else { throw HikingSessionError.noActiveSession }
        guard stored.session.status != .finished, stored.session.status != .abandoned else {
            throw HikingSessionError.sessionAlreadyFinished
        }
        let event = SessionEvent(
            sessionId: stored.session.sessionId,
            type: type,
            timestamp: timestamp,
            coordinate: coordinate,
            routeProgressMeters: routeProgressMeters,
            severity: severity,
            payload: payload
        )
        stored.events.append(event)
        stored.session.lastUpdatedAt = timestamp
        try await store.save(stored)
        storedSession = stored
        try await evidenceLogger?.logSessionEvent(
            sessionId: stored.session.sessionId,
            type: type,
            coordinate: coordinate,
            routeProgressMeters: routeProgressMeters,
            severity: severity,
            payload: payload,
            timestamp: timestamp
        )
        return event
    }

    public func appendBarometerWindow(_ window: EvidenceBarometerWindow, timestamp: Date = Date()) async throws {
        guard let stored = storedSession else { throw HikingSessionError.noActiveSession }
        guard stored.session.status == .active else { return }
        try await evidenceLogger?.logBarometerWindow(
            sessionId: stored.session.sessionId,
            window: window,
            timestamp: timestamp
        )
    }

    public func appendDeviceMotionWindow(_ window: EvidenceDeviceMotionWindow, timestamp: Date = Date()) async throws {
        guard let stored = storedSession else { throw HikingSessionError.noActiveSession }
        guard stored.session.status == .active else { return }
        try await evidenceLogger?.logDeviceMotionWindow(
            sessionId: stored.session.sessionId,
            window: window,
            timestamp: timestamp
        )
    }

    public func finish(now: Date = Date()) async throws -> SessionSummary {
        guard var stored = storedSession else { throw HikingSessionError.noActiveSession }
        guard stored.session.status != .finished, stored.session.status != .abandoned else {
            throw HikingSessionError.sessionAlreadyFinished
        }
        guard let startedAt = stored.session.startedAt else { throw HikingSessionError.missingStartTime }

        stored.session.status = .finished
        stored.session.endedAt = now
        stored.session.lastUpdatedAt = now
        stored.session.syncStatus = .pendingUpload
        let finishEvent = SessionEvent(sessionId: stored.session.sessionId, type: .sessionFinished, timestamp: now)
        stored.events.append(finishEvent)

        let summary = makeSummary(session: stored.session, startedAt: startedAt, endedAt: now, trackPoints: stored.trackPoints, events: stored.events)
        stored.summary = summary
        try await store.save(stored)
        storedSession = stored
        try await evidenceLogger?.logSessionEvent(
            sessionId: stored.session.sessionId,
            type: finishEvent.type,
            coordinate: finishEvent.coordinate,
            routeProgressMeters: finishEvent.routeProgressMeters,
            severity: finishEvent.severity,
            payload: finishEvent.payload,
            timestamp: finishEvent.timestamp
        )
        try await evidenceLogger?.logSamplingPolicy(
            sessionId: stored.session.sessionId,
            policy: .finished,
            now: now
        )
        return summary
    }

    public func storedSnapshot() throws -> StoredHikingSession {
        guard let storedSession else { throw HikingSessionError.noActiveSession }
        return storedSession
    }

    private func transition(to status: HikingSessionStatus, eventType: SessionEventType, now: Date) async throws {
        guard var stored = storedSession else { throw HikingSessionError.noActiveSession }
        guard stored.session.status != .finished, stored.session.status != .abandoned else {
            throw HikingSessionError.sessionAlreadyFinished
        }
        switch (stored.session.status, status) {
        case (.active, .paused), (.paused, .active):
            stored.session.status = status
            stored.session.lastUpdatedAt = now
            let event = SessionEvent(sessionId: stored.session.sessionId, type: eventType, timestamp: now)
            stored.events.append(event)
            try await store.save(stored)
            storedSession = stored
            try await evidenceLogger?.logSessionEvent(
                sessionId: stored.session.sessionId,
                type: event.type,
                coordinate: event.coordinate,
                routeProgressMeters: event.routeProgressMeters,
                severity: event.severity,
                payload: event.payload,
                timestamp: event.timestamp
            )
            try await evidenceLogger?.logSamplingPolicy(
                sessionId: stored.session.sessionId,
                policy: status == .paused ? .paused : .movingStandard,
                now: now
            )
        default:
            throw HikingSessionError.invalidTransition(from: stored.session.status, to: status)
        }
    }

    private func makeSummary(
        session: HikingSession,
        startedAt: Date,
        endedAt: Date,
        trackPoints: [TrackPoint],
        events: [SessionEvent]
    ) -> SessionSummary {
        let distance = actualDistanceMeters(trackPoints)
        let duration = max(0, Int(endedAt.timeIntervalSince(startedAt)))
        let elevations = trackPoints.compactMap(\.elevationMeters)
        let heartRates = trackPoints.compactMap(\.heartRateBpm)
        let movingDuration = movingDurationSeconds(trackPoints)
        return SessionSummary(
            sessionId: session.sessionId,
            routeId: session.routeId,
            routeName: session.routeName,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: duration,
            movingDurationSeconds: movingDuration,
            distanceMeters: distance,
            ascentMeters: ascentMeters(elevations),
            averageSpeedMetersPerSecond: movingDuration > 0 ? distance / Double(movingDuration) : nil,
            maxElevationMeters: elevations.max(),
            minElevationMeters: elevations.min(),
            averageHeartRateBpm: average(heartRates),
            offRouteEventCount: events.filter { $0.type == .offRouteStarted }.count,
            trackPointCount: trackPoints.count,
            syncStatus: session.syncStatus
        )
    }

    private func actualDistanceMeters(_ trackPoints: [TrackPoint]) -> Double {
        guard trackPoints.count > 1 else { return 0 }
        return zip(trackPoints, trackPoints.dropFirst()).reduce(0) { partial, pair in
            partial + GeoMath.distanceMeters(from: pair.0.coordinate, to: pair.1.coordinate)
        }
    }

    private func movingDurationSeconds(_ trackPoints: [TrackPoint]) -> Int {
        guard trackPoints.count > 1 else { return 0 }
        return zip(trackPoints, trackPoints.dropFirst()).reduce(0) { partial, pair in
            partial + max(0, Int(pair.1.timestamp.timeIntervalSince(pair.0.timestamp)))
        }
    }

    private func ascentMeters(_ elevations: [Double]) -> Double? {
        guard elevations.count > 1 else { return elevations.isEmpty ? nil : 0 }
        let ascent = zip(elevations, elevations.dropFirst()).reduce(0) { partial, pair in
            partial + max(0, pair.1 - pair.0)
        }
        return ascent
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
