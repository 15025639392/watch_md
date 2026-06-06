import Foundation

public struct SessionStatusPayload: Codable, Equatable, Sendable {
    public var sessionId: String
    public var routeId: String
    public var routeVersion: Int
    public var status: HikingSessionStatus
    public var lastUpdatedAt: Date
    public var trackPointCount: Int
    public var eventCount: Int
    public var syncStatus: SessionSyncStatus

    public init(storedSession: StoredHikingSession) {
        sessionId = storedSession.session.sessionId
        routeId = storedSession.session.routeId
        routeVersion = storedSession.session.routeVersion
        status = storedSession.session.status
        lastUpdatedAt = storedSession.session.lastUpdatedAt
        trackPointCount = storedSession.trackPoints.count
        eventCount = storedSession.events.count
        syncStatus = storedSession.session.syncStatus
    }
}

public struct TrackChunk: Codable, Equatable, Sendable {
    public var sessionId: String
    public var chunkId: String
    public var startSequence: Int
    public var endSequence: Int
    public var isFinal: Bool
    public var points: [TrackPoint]
    public var pointsChecksum: String

    public init(sessionId: String, chunkId: String = UUID().uuidString, startSequence: Int, endSequence: Int, isFinal: Bool, points: [TrackPoint], pointsChecksum: String) {
        self.sessionId = sessionId
        self.chunkId = chunkId
        self.startSequence = startSequence
        self.endSequence = endSequence
        self.isFinal = isFinal
        self.points = points
        self.pointsChecksum = pointsChecksum
    }
}

public struct LiveTrackSnapshot: Codable, Equatable, Sendable {
    public enum RouteMatchStatus: String, Codable, Sendable {
        case unknown
        case onRoute
        case suspectedOffRoute
        case offRoute
        case locationUnreliable
        case paused
    }

    public var sessionId: String
    public var routeId: String
    public var routeVersion: Int
    public var status: HikingSessionStatus
    public var updatedAt: Date
    public var trackPointCount: Int
    public var currentPoint: TrackPoint?
    public var recentPoints: [TrackPoint]
    public var heartRateBpm: Double?
    public var activeEnergyKilocalories: Double?
    public var workoutDistanceMeters: Double?
    public var routeMatchStatus: RouteMatchStatus
    public var distanceFromRouteMeters: Double?
    public var routeProgressMeters: Double?
    public var projectedRouteCoordinate: GeoCoordinate?
    public var bearingToRouteDegrees: Double?

    public init(
        sessionId: String,
        routeId: String,
        routeVersion: Int,
        status: HikingSessionStatus,
        updatedAt: Date,
        trackPointCount: Int,
        currentPoint: TrackPoint?,
        recentPoints: [TrackPoint],
        heartRateBpm: Double? = nil,
        activeEnergyKilocalories: Double? = nil,
        workoutDistanceMeters: Double? = nil,
        routeMatchStatus: RouteMatchStatus = .unknown,
        distanceFromRouteMeters: Double? = nil,
        routeProgressMeters: Double? = nil,
        projectedRouteCoordinate: GeoCoordinate? = nil,
        bearingToRouteDegrees: Double? = nil
    ) {
        self.sessionId = sessionId
        self.routeId = routeId
        self.routeVersion = routeVersion
        self.status = status
        self.updatedAt = updatedAt
        self.trackPointCount = trackPointCount
        self.currentPoint = currentPoint
        self.recentPoints = recentPoints
        self.heartRateBpm = heartRateBpm
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.workoutDistanceMeters = workoutDistanceMeters
        self.routeMatchStatus = routeMatchStatus
        self.distanceFromRouteMeters = distanceFromRouteMeters
        self.routeProgressMeters = routeProgressMeters
        self.projectedRouteCoordinate = projectedRouteCoordinate
        self.bearingToRouteDegrees = bearingToRouteDegrees
    }
}

public struct EventChunk: Codable, Equatable, Sendable {
    public var sessionId: String
    public var chunkId: String
    public var sequence: Int
    public var isFinal: Bool
    public var events: [SessionEvent]

    public init(sessionId: String, chunkId: String = UUID().uuidString, sequence: Int, isFinal: Bool, events: [SessionEvent]) {
        self.sessionId = sessionId
        self.chunkId = chunkId
        self.sequence = sequence
        self.isFinal = isFinal
        self.events = events
    }
}

public enum SessionSyncError: Error, Equatable {
    case missingSummary
    case trackChecksumMismatch
    case trackChunkSequenceMismatch
    case eventChunkSessionMismatch
    case unexpectedAck(SyncAck)
}

public enum SessionSyncCodec {
    public static func makeStatusEnvelope(for storedSession: StoredHikingSession) throws -> SyncEnvelope<SessionStatusPayload> {
        let payload = SessionStatusPayload(storedSession: storedSession)
        let data = try RouteSyncCodec.encoder.encode(payload)
        return SyncEnvelope(
            sender: .watch,
            kind: .sessionStatus,
            entityId: payload.sessionId,
            entityVersion: storedSession.session.routeVersion,
            payloadChecksum: RouteSyncCodec.checksum(data: data),
            payload: payload
        )
    }

    public static func makeTrackChunkEnvelopes(for storedSession: StoredHikingSession, chunkSize: Int = 50) throws -> [SyncEnvelope<TrackChunk>] {
        guard !storedSession.trackPoints.isEmpty else { return [] }
        let chunks = storedSession.trackPoints.chunked(into: max(1, chunkSize))
        return try chunks.enumerated().map { index, points in
            let data = try RouteSyncCodec.encoder.encode(points)
            let chunk = TrackChunk(
                sessionId: storedSession.session.sessionId,
                startSequence: points.first?.sequence ?? 0,
                endSequence: points.last?.sequence ?? 0,
                isFinal: index == chunks.count - 1,
                points: points,
                pointsChecksum: RouteSyncCodec.checksum(data: data)
            )
            let chunkData = try RouteSyncCodec.encoder.encode(chunk)
            return SyncEnvelope(
                sender: .watch,
                kind: .trackChunk,
                entityId: storedSession.session.sessionId,
                entityVersion: storedSession.session.routeVersion,
                sequence: index,
                isFinal: chunk.isFinal,
                payloadChecksum: RouteSyncCodec.checksum(data: chunkData),
                payload: chunk
            )
        }
    }

    public static func makeLiveTrackSnapshotEnvelope(
        session: HikingSession,
        trackPoints: [TrackPoint],
        heartRateBpm: Double? = nil,
        activeEnergyKilocalories: Double? = nil,
        workoutDistanceMeters: Double? = nil,
        routeMatchStatus: LiveTrackSnapshot.RouteMatchStatus = .unknown,
        distanceFromRouteMeters: Double? = nil,
        routeProgressMeters: Double? = nil,
        projectedRouteCoordinate: GeoCoordinate? = nil,
        bearingToRouteDegrees: Double? = nil,
        recentPointLimit: Int = 80
    ) throws -> SyncEnvelope<LiveTrackSnapshot> {
        let recentPoints = Array(trackPoints.sorted { $0.sequence < $1.sequence }.suffix(max(1, recentPointLimit)))
        let payload = LiveTrackSnapshot(
            sessionId: session.sessionId,
            routeId: session.routeId,
            routeVersion: session.routeVersion,
            status: session.status,
            updatedAt: session.lastUpdatedAt,
            trackPointCount: trackPoints.count,
            currentPoint: recentPoints.last,
            recentPoints: recentPoints,
            heartRateBpm: heartRateBpm,
            activeEnergyKilocalories: activeEnergyKilocalories,
            workoutDistanceMeters: workoutDistanceMeters,
            routeMatchStatus: routeMatchStatus,
            distanceFromRouteMeters: distanceFromRouteMeters,
            routeProgressMeters: routeProgressMeters,
            projectedRouteCoordinate: projectedRouteCoordinate,
            bearingToRouteDegrees: bearingToRouteDegrees
        )
        let data = try RouteSyncCodec.encoder.encode(payload)
        return SyncEnvelope(
            sender: .watch,
            kind: .liveTrackSnapshot,
            entityId: session.sessionId,
            entityVersion: session.routeVersion,
            isFinal: false,
            payloadChecksum: RouteSyncCodec.checksum(data: data),
            payload: payload
        )
    }

    public static func makeEventChunkEnvelopes(for storedSession: StoredHikingSession, chunkSize: Int = 20) throws -> [SyncEnvelope<EventChunk>] {
        guard !storedSession.events.isEmpty else { return [] }
        let chunks = storedSession.events.chunked(into: max(1, chunkSize))
        return try chunks.enumerated().map { index, events in
            let chunk = EventChunk(
                sessionId: storedSession.session.sessionId,
                sequence: index,
                isFinal: index == chunks.count - 1,
                events: events
            )
            let data = try RouteSyncCodec.encoder.encode(chunk)
            return SyncEnvelope(
                sender: .watch,
                kind: .eventChunk,
                entityId: storedSession.session.sessionId,
                entityVersion: storedSession.session.routeVersion,
                sequence: index,
                isFinal: chunk.isFinal,
                payloadChecksum: RouteSyncCodec.checksum(data: data),
                payload: chunk
            )
        }
    }

    public static func makeSummaryEnvelope(for storedSession: StoredHikingSession) throws -> SyncEnvelope<SessionSummary> {
        guard let summary = storedSession.summary else { throw SessionSyncError.missingSummary }
        let data = try RouteSyncCodec.encoder.encode(summary)
        return SyncEnvelope(
            sender: .watch,
            kind: .sessionSummary,
            entityId: summary.sessionId,
            entityVersion: storedSession.session.routeVersion,
            payloadChecksum: RouteSyncCodec.checksum(data: data),
            payload: summary
        )
    }
}

public struct SessionUploadPlan: Equatable, Sendable {
    public var status: SyncEnvelope<SessionStatusPayload>
    public var trackChunks: [SyncEnvelope<TrackChunk>]
    public var eventChunks: [SyncEnvelope<EventChunk>]
    public var summary: SyncEnvelope<SessionSummary>
}

public enum SessionUploadPlanner {
    public static func makeUploadPlan(for storedSession: StoredHikingSession, trackChunkSize: Int = 50, eventChunkSize: Int = 20) throws -> SessionUploadPlan {
        SessionUploadPlan(
            status: try SessionSyncCodec.makeStatusEnvelope(for: storedSession),
            trackChunks: try SessionSyncCodec.makeTrackChunkEnvelopes(for: storedSession, chunkSize: trackChunkSize),
            eventChunks: try SessionSyncCodec.makeEventChunkEnvelopes(for: storedSession, chunkSize: eventChunkSize),
            summary: try SessionSyncCodec.makeSummaryEnvelope(for: storedSession)
        )
    }
}

public actor PendingSessionUploadQueue {
    private var pendingEnvelopeIds: Set<String> = []

    public init() {}

    public func enqueue(_ plan: SessionUploadPlan) {
        pendingEnvelopeIds.insert(plan.status.envelopeId)
        pendingEnvelopeIds.formUnion(plan.trackChunks.map(\.envelopeId))
        pendingEnvelopeIds.formUnion(plan.eventChunks.map(\.envelopeId))
        pendingEnvelopeIds.insert(plan.summary.envelopeId)
    }

    public func handleAck(_ ack: SyncAck) throws {
        guard let envelopeId = ack.ackForEnvelopeId else { return }
        switch ack.status {
        case .ok, .alreadyReceived:
            pendingEnvelopeIds.remove(envelopeId)
        case .missingData:
            break
        case .rejected, .failed:
            throw SessionSyncError.unexpectedAck(ack)
        }
    }

    public func isPending(envelopeId: String) -> Bool {
        pendingEnvelopeIds.contains(envelopeId)
    }

    public var pendingCount: Int {
        pendingEnvelopeIds.count
    }
}

public struct ReceivedSessionRecord: Codable, Equatable, Sendable {
    public var sessionId: String
    public var status: SessionStatusPayload?
    public var summary: SessionSummary?
    public var trackPoints: [TrackPoint]
    public var events: [SessionEvent]
    public var syncStatus: SessionSyncStatus
}

public actor iPhoneSessionSyncReceiver {
    private var receivedEnvelopeKeys: Set<String> = []
    private var statuses: [String: SessionStatusPayload] = [:]
    private var summaries: [String: SessionSummary] = [:]
    private var trackPointsBySession: [String: [Int: TrackPoint]] = [:]
    private var eventsBySession: [String: [String: SessionEvent]] = [:]
    private var finalTrackSequenceBySession: [String: Int] = [:]
    private var finalEventChunkSeen: Set<String> = []

    public init() {}

    public func receiveStatus(_ envelope: SyncEnvelope<SessionStatusPayload>) throws -> SyncEnvelope<SyncAck> {
        let payload = envelope.payload
        statuses[payload.sessionId] = payload
        return try ackEnvelope(for: envelope, status: .ok, action: .sessionStatusReceived)
    }

    public func receiveTrackChunk(_ envelope: SyncEnvelope<TrackChunk>) throws -> SyncEnvelope<SyncAck> {
        let key = envelopeKey(envelope)
        if receivedEnvelopeKeys.contains(key) {
            return try ackEnvelope(for: envelope, status: .alreadyReceived, action: .trackChunkReceived)
        }

        let chunk = envelope.payload
        guard chunk.points.allSatisfy({ $0.sessionId == chunk.sessionId }),
              chunk.points.first?.sequence == chunk.startSequence,
              chunk.points.last?.sequence == chunk.endSequence else {
            return try ackEnvelope(for: envelope, status: .rejected, action: .missingRangesRequested, message: "Track chunk sequence mismatch.")
        }
        let pointsData = try RouteSyncCodec.encoder.encode(chunk.points)
        guard RouteSyncCodec.checksum(data: pointsData) == chunk.pointsChecksum else {
            throw SessionSyncError.trackChecksumMismatch
        }

        var points = trackPointsBySession[chunk.sessionId, default: [:]]
        for point in chunk.points {
            points[point.sequence] = point
        }
        trackPointsBySession[chunk.sessionId] = points
        receivedEnvelopeKeys.insert(key)
        if chunk.isFinal {
            finalTrackSequenceBySession[chunk.sessionId] = chunk.endSequence
        }

        let missing = missingTrackRanges(sessionId: chunk.sessionId)
        if missing.isEmpty {
            return try ackEnvelope(for: envelope, status: .ok, action: .trackChunkReceived)
        }
        return try ackEnvelope(for: envelope, status: .missingData, action: .missingRangesRequested, missingRanges: missing)
    }

    public func receiveEventChunk(_ envelope: SyncEnvelope<EventChunk>) throws -> SyncEnvelope<SyncAck> {
        let key = envelopeKey(envelope)
        if receivedEnvelopeKeys.contains(key) {
            return try ackEnvelope(for: envelope, status: .alreadyReceived, action: .eventChunkReceived)
        }

        let chunk = envelope.payload
        guard chunk.events.allSatisfy({ $0.sessionId == chunk.sessionId }) else {
            throw SessionSyncError.eventChunkSessionMismatch
        }
        var events = eventsBySession[chunk.sessionId, default: [:]]
        for event in chunk.events {
            events[event.eventId] = event
        }
        eventsBySession[chunk.sessionId] = events
        receivedEnvelopeKeys.insert(key)
        if chunk.isFinal {
            finalEventChunkSeen.insert(chunk.sessionId)
        }
        return try ackEnvelope(for: envelope, status: .ok, action: .eventChunkReceived)
    }

    public func receiveSummary(_ envelope: SyncEnvelope<SessionSummary>) throws -> SyncEnvelope<SyncAck> {
        let summary = envelope.payload
        summaries[summary.sessionId] = summary
        let missing = missingTrackRanges(sessionId: summary.sessionId, expectedFinalSequence: summary.trackPointCount - 1)
        if missing.isEmpty, isComplete(sessionId: summary.sessionId) {
            return try ackEnvelope(for: envelope, status: .ok, action: .sessionComplete)
        }
        return try ackEnvelope(for: envelope, status: .missingData, action: .missingRangesRequested, missingRanges: missing)
    }

    public func record(sessionId: String) -> ReceivedSessionRecord? {
        guard statuses[sessionId] != nil || summaries[sessionId] != nil || trackPointsBySession[sessionId] != nil else {
            return nil
        }
        let points = trackPointsBySession[sessionId, default: [:]]
            .sorted { $0.key < $1.key }
            .map(\.value)
        let events = eventsBySession[sessionId, default: [:]]
            .values
            .sorted { $0.timestamp < $1.timestamp }
        let syncStatus: SessionSyncStatus = isComplete(sessionId: sessionId) ? .synced : .syncing
        var summary = summaries[sessionId]
        summary?.syncStatus = syncStatus
        return ReceivedSessionRecord(
            sessionId: sessionId,
            status: statuses[sessionId],
            summary: summary,
            trackPoints: points,
            events: events,
            syncStatus: syncStatus
        )
    }

    private func isComplete(sessionId: String) -> Bool {
        guard let summary = summaries[sessionId] else { return false }
        let trackCount = trackPointsBySession[sessionId, default: [:]].count
        return trackCount == summary.trackPointCount && finalEventChunkSeen.contains(sessionId)
    }

    private func missingTrackRanges(sessionId: String, expectedFinalSequence: Int? = nil) -> [SequenceRange] {
        let points = trackPointsBySession[sessionId, default: [:]]
        let finalSequence = expectedFinalSequence ?? finalTrackSequenceBySession[sessionId]
        guard let finalSequence, finalSequence >= 0 else { return [] }
        var ranges: [SequenceRange] = []
        var rangeStart: Int?
        for sequence in 0...finalSequence {
            if points[sequence] == nil {
                rangeStart = rangeStart ?? sequence
            } else if let start = rangeStart {
                ranges.append(SequenceRange(startSequence: start, endSequence: sequence - 1))
                rangeStart = nil
            }
        }
        if let start = rangeStart {
            ranges.append(SequenceRange(startSequence: start, endSequence: finalSequence))
        }
        return ranges
    }

    private func ackEnvelope<Payload: Codable & Sendable & Equatable>(
        for envelope: SyncEnvelope<Payload>,
        status: SyncAckStatus,
        action: SyncAckAction,
        missingRanges: [SequenceRange] = [],
        message: String? = nil
    ) throws -> SyncEnvelope<SyncAck> {
        try RouteSyncCodec.makeAckEnvelope(
            SyncAck(
                ackForEnvelopeId: envelope.envelopeId,
                status: status,
                action: action,
                entityId: envelope.entityId,
                entityVersion: envelope.entityVersion,
                missingRanges: missingRanges,
                message: message
            ),
            sender: .iphone
        )
    }

    private func envelopeKey<Payload>(_ envelope: SyncEnvelope<Payload>) -> String {
        "\(envelope.entityId)-\(envelope.kind.rawValue)-\(envelope.sequence ?? -1)-\(envelope.payloadChecksum)"
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
