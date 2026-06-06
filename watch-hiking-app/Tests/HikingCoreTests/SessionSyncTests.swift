import Foundation
import Testing
@testable import HikingCore

@Suite("Slice 5 session sync")
struct SessionSyncTests {
    @Test("Watch session upload reaches complete ACK on iPhone")
    func sessionUploadCompletes() async throws {
        let stored = try await finishedSession(pointCount: 5)
        let plan = try SessionUploadPlanner.makeUploadPlan(for: stored, trackChunkSize: 2, eventChunkSize: 2)
        let receiver = iPhoneSessionSyncReceiver()

        let statusAck = try await receiver.receiveStatus(plan.status)
        #expect(statusAck.payload.action == .sessionStatusReceived)

        for chunk in plan.trackChunks {
            let ack = try await receiver.receiveTrackChunk(chunk)
            #expect(ack.payload.action == .trackChunkReceived)
        }
        for chunk in plan.eventChunks {
            let ack = try await receiver.receiveEventChunk(chunk)
            #expect(ack.payload.action == .eventChunkReceived)
        }
        let summaryAck = try await receiver.receiveSummary(plan.summary)
        let record = await receiver.record(sessionId: stored.session.sessionId)

        #expect(summaryAck.payload.status == .ok)
        #expect(summaryAck.payload.action == .sessionComplete)
        #expect(record?.trackPoints.count == 5)
        #expect(record?.events.count == stored.events.count)
        #expect(record?.syncStatus == .synced)
        #expect(record?.summary?.syncStatus == .synced)
    }

    @Test("Duplicate track chunk is idempotent")
    func duplicateTrackChunkDoesNotDuplicatePoints() async throws {
        let stored = try await finishedSession(pointCount: 3)
        let plan = try SessionUploadPlanner.makeUploadPlan(for: stored, trackChunkSize: 3)
        let receiver = iPhoneSessionSyncReceiver()

        let firstAck = try await receiver.receiveTrackChunk(plan.trackChunks[0])
        let duplicateAck = try await receiver.receiveTrackChunk(plan.trackChunks[0])
        let record = await receiver.record(sessionId: stored.session.sessionId)

        #expect(firstAck.payload.status == .ok)
        #expect(duplicateAck.payload.status == .alreadyReceived)
        #expect(duplicateAck.payload.action == .trackChunkReceived)
        #expect(record?.trackPoints.map(\.sequence) == [0, 1, 2])
    }

    @Test("Out-of-order final track chunk requests missing ranges")
    func missingTrackRangeRequested() async throws {
        let stored = try await finishedSession(pointCount: 5)
        let plan = try SessionUploadPlanner.makeUploadPlan(for: stored, trackChunkSize: 2)
        let receiver = iPhoneSessionSyncReceiver()

        let finalAck = try await receiver.receiveTrackChunk(plan.trackChunks[2])
        #expect(finalAck.payload.status == .missingData)
        #expect(finalAck.payload.action == .missingRangesRequested)
        #expect(finalAck.payload.missingRanges == [SequenceRange(startSequence: 0, endSequence: 3)])

        _ = try await receiver.receiveTrackChunk(plan.trackChunks[0])
        let filledAck = try await receiver.receiveTrackChunk(plan.trackChunks[1])
        #expect(filledAck.payload.status == .ok)
        #expect(filledAck.payload.missingRanges.isEmpty)
    }

    @Test("Pending upload queue keeps chunks until ACK arrives")
    func pendingQueueClearsOnlyAckedEnvelopes() async throws {
        let stored = try await finishedSession(pointCount: 2)
        let plan = try SessionUploadPlanner.makeUploadPlan(for: stored, trackChunkSize: 1, eventChunkSize: 1)
        let queue = PendingSessionUploadQueue()
        await queue.enqueue(plan)

        #expect(await queue.pendingCount == 1 + plan.trackChunks.count + plan.eventChunks.count + 1)
        try await queue.handleAck(SyncAck(
            ackForEnvelopeId: plan.trackChunks[0].envelopeId,
            status: .ok,
            action: .trackChunkReceived,
            entityId: stored.session.sessionId,
            entityVersion: stored.session.routeVersion
        ))

        #expect(await queue.isPending(envelopeId: plan.trackChunks[0].envelopeId) == false)
        #expect(await queue.isPending(envelopeId: plan.trackChunks[1].envelopeId) == true)
    }

    private func finishedSession(pointCount: Int) async throws -> StoredHikingSession {
        let route = try await MockRemoteRouteClient.sample().fetchRouteDetail(remoteRouteId: "mock-ggr-001")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SessionSyncTests-\(UUID().uuidString)", isDirectory: true)
        let recorder = try HikingSessionRecorder(store: HikingSessionStore(directoryURL: url))
        let start = Date(timeIntervalSince1970: 1_800_010_000)

        _ = try await recorder.start(route: route, watchDeviceId: "watch-sync-test", now: start)
        for index in 0..<pointCount {
            _ = try await recorder.appendLocation(
                latitude: 37.0 + Double(index) * 0.001,
                longitude: -122.0,
                elevationMeters: 10 + Double(index),
                timestamp: start.addingTimeInterval(Double(index + 1) * 5)
            )
        }
        _ = try await recorder.appendEvent(
            type: .offRouteStarted,
            coordinate: GeoCoordinate(latitude: 37.0, longitude: -122.0),
            severity: .warning,
            timestamp: start.addingTimeInterval(40)
        )
        _ = try await recorder.finish(now: start.addingTimeInterval(60))
        return try await recorder.storedSnapshot()
    }
}
