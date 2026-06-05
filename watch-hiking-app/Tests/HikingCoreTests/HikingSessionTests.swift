import Foundation
import Testing
@testable import HikingCore

@Suite("Slice 3 Watch hiking session")
struct HikingSessionTests {
    @Test("Watch starts session only after route is installed and records track points")
    func startSessionAndAppendTrackPoints() async throws {
        let route = try await sampleInstalledRoute()
        let recorder = try await makeRecorder()
        let start = Date(timeIntervalSince1970: 1_800_000_000)

        let session = try await recorder.start(route: route, watchDeviceId: "watch-test", now: start)
        let first = try await recorder.appendLocation(
            latitude: 37.0,
            longitude: -122.0,
            elevationMeters: 10,
            timestamp: start.addingTimeInterval(5)
        )
        let second = try await recorder.appendLocation(
            latitude: 37.001,
            longitude: -122.0,
            elevationMeters: 16,
            timestamp: start.addingTimeInterval(10)
        )
        let snapshot = try await recorder.storedSnapshot()

        #expect(session.status == .active)
        #expect(session.routeId == route.route.routeId)
        #expect(first?.sequence == 0)
        #expect(second?.sequence == 1)
        #expect(snapshot.trackPoints.count == 2)
        #expect(snapshot.events.map(\.type) == [.sessionStarted])
    }

    @Test("Paused session does not write formal track points")
    func pauseSkipsFormalTrackPoints() async throws {
        let route = try await sampleInstalledRoute()
        let recorder = try await makeRecorder()
        let start = Date(timeIntervalSince1970: 1_800_000_100)

        _ = try await recorder.start(route: route, now: start)
        _ = try await recorder.appendLocation(latitude: 37.0, longitude: -122.0, timestamp: start.addingTimeInterval(5))
        try await recorder.pause(now: start.addingTimeInterval(10))
        let skipped = try await recorder.appendLocation(latitude: 37.01, longitude: -122.0, timestamp: start.addingTimeInterval(15))
        try await recorder.resume(now: start.addingTimeInterval(20))
        let resumed = try await recorder.appendLocation(latitude: 37.02, longitude: -122.0, timestamp: start.addingTimeInterval(25))
        let snapshot = try await recorder.storedSnapshot()

        #expect(skipped == nil)
        #expect(resumed?.sequence == 1)
        #expect(snapshot.trackPoints.count == 2)
        #expect(snapshot.events.map(\.type) == [.sessionStarted, .sessionPaused, .sessionResumed])
    }

    @Test("Finishing session creates summary and blocks further samples")
    func finishCreatesSummary() async throws {
        let route = try await sampleInstalledRoute()
        let recorder = try await makeRecorder()
        let start = Date(timeIntervalSince1970: 1_800_000_200)

        let session = try await recorder.start(route: route, now: start)
        _ = try await recorder.appendLocation(latitude: 37.0, longitude: -122.0, elevationMeters: 10, heartRateBpm: 100, timestamp: start.addingTimeInterval(5))
        _ = try await recorder.appendLocation(latitude: 37.001, longitude: -122.0, elevationMeters: 20, heartRateBpm: 120, timestamp: start.addingTimeInterval(15))
        let summary = try await recorder.finish(now: start.addingTimeInterval(30))
        let snapshot = try await recorder.storedSnapshot()

        #expect(summary.sessionId == session.sessionId)
        #expect(summary.routeName == route.route.name)
        #expect(summary.durationSeconds == 30)
        #expect(summary.trackPointCount == 2)
        #expect(summary.distanceMeters > 100)
        #expect(summary.ascentMeters == 10)
        #expect(summary.averageHeartRateBpm == 110)
        #expect(summary.syncStatus == .pendingUpload)
        #expect(snapshot.session.status == .finished)
        #expect(snapshot.events.map(\.type).contains(.sessionFinished))
        await #expect(throws: HikingSessionError.sessionAlreadyFinished) {
            try await recorder.appendLocation(latitude: 37.002, longitude: -122.0)
        }
    }

    @Test("Recorder can recover an active session from local store")
    func recoverOpenSession() async throws {
        let route = try await sampleInstalledRoute()
        let store = try await makeStore()
        let recorder = HikingSessionRecorder(store: store)
        let start = Date(timeIntervalSince1970: 1_800_000_300)

        let original = try await recorder.start(route: route, now: start)
        _ = try await recorder.appendLocation(latitude: 37.0, longitude: -122.0, timestamp: start.addingTimeInterval(5))

        let newRecorder = HikingSessionRecorder(store: store)
        let recovered = try await newRecorder.recoverOpenSession()
        let resumedPoint = try await newRecorder.appendLocation(latitude: 37.001, longitude: -122.0, timestamp: start.addingTimeInterval(10))
        let snapshot = try await newRecorder.storedSnapshot()

        #expect(recovered?.sessionId == original.sessionId)
        #expect(resumedPoint?.sequence == 1)
        #expect(snapshot.trackPoints.count == 2)
    }

    @Test("Recorder persists off-route events for later review")
    func appendOffRouteEvents() async throws {
        let route = try await sampleInstalledRoute()
        let recorder = try await makeRecorder()
        let start = Date(timeIntervalSince1970: 1_800_000_400)

        _ = try await recorder.start(route: route, now: start)
        _ = try await recorder.appendEvent(
            type: .offRouteStarted,
            coordinate: GeoCoordinate(latitude: 37.0, longitude: -122.0),
            routeProgressMeters: 120,
            severity: .warning,
            payload: ["distanceFromRouteMeters": "42"],
            timestamp: start.addingTimeInterval(10)
        )
        _ = try await recorder.appendEvent(
            type: .offRouteEnded,
            coordinate: GeoCoordinate(latitude: 37.001, longitude: -122.0),
            routeProgressMeters: 180,
            timestamp: start.addingTimeInterval(20)
        )
        let summary = try await recorder.finish(now: start.addingTimeInterval(30))
        let snapshot = try await recorder.storedSnapshot()

        #expect(snapshot.events.map(\.type) == [.sessionStarted, .offRouteStarted, .offRouteEnded, .sessionFinished])
        #expect(snapshot.events[1].severity == .warning)
        #expect(snapshot.events[1].payload["distanceFromRouteMeters"] == "42")
        #expect(summary.offRouteEventCount == 1)
    }

    private func sampleInstalledRoute() async throws -> InstalledRoute {
        try await MockRemoteRouteClient.sample().fetchRouteDetail(remoteRouteId: "mock-ggr-001")
    }

    private func makeRecorder() async throws -> HikingSessionRecorder {
        try await HikingSessionRecorder(store: makeStore())
    }

    private func makeStore() async throws -> HikingSessionStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HikingSessionTests-\(UUID().uuidString)", isDirectory: true)
        return try HikingSessionStore(directoryURL: url)
    }
}
