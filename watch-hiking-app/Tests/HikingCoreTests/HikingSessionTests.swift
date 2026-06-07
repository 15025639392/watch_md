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

    @Test("Recorder writes low-power evidence JSONL beside the stored session")
    func recorderWritesEvidenceJsonl() async throws {
        let route = try await sampleInstalledRoute()
        let store = try await makeStore()
        let recorder = HikingSessionRecorder(store: store)
        let start = Date(timeIntervalSince1970: 1_800_000_500)

        let session = try await recorder.start(route: route, watchDeviceId: "watch-evidence-test", now: start)
        _ = try await recorder.appendLocation(
            latitude: 37.0,
            longitude: -122.0,
            elevationMeters: 10,
            horizontalAccuracyMeters: 8,
            verticalAccuracyMeters: 12,
            speedMetersPerSecond: 1.2,
            courseDegrees: 35,
            timestamp: start.addingTimeInterval(5)
        )
        var barometer = EvidenceBarometerWindowAccumulator(windowSeconds: 6, minAltitudeStepMeters: 0.5)
        _ = barometer.append(EvidenceBarometerSample(elapsedRealtimeNanos: 0, relativeAltitudeMeters: 0, pressureKpa: 95.4))
        _ = barometer.append(EvidenceBarometerSample(elapsedRealtimeNanos: 3_000_000_000, relativeAltitudeMeters: 5, pressureKpa: 95.3))
        let pendingBarometerWindow = barometer.append(
            EvidenceBarometerSample(elapsedRealtimeNanos: 6_000_000_000, relativeAltitudeMeters: 0, pressureKpa: 95.4)
        )
        let barometerWindow = try #require(pendingBarometerWindow)
        try await recorder.appendBarometerWindow(barometerWindow, timestamp: start.addingTimeInterval(6))
        var motion = EvidenceDeviceMotionWindowAccumulator(windowSeconds: 2)
        _ = motion.append(EvidenceDeviceMotionSample(
            elapsedRealtimeNanos: 0,
            userAccelerationXMps2: 0,
            userAccelerationYMps2: 0,
            userAccelerationZMps2: 0,
            rotationRateXRadps: 0,
            rotationRateYRadps: 0,
            rotationRateZRadps: 0
        ))
        _ = motion.append(EvidenceDeviceMotionSample(
            elapsedRealtimeNanos: 1_000_000_000,
            userAccelerationXMps2: 3,
            userAccelerationYMps2: 4,
            userAccelerationZMps2: 0,
            rotationRateXRadps: 0,
            rotationRateYRadps: 0,
            rotationRateZRadps: 2
        ))
        let pendingMotionWindow = motion.append(EvidenceDeviceMotionSample(
            elapsedRealtimeNanos: 2_000_000_000,
            userAccelerationXMps2: 0,
            userAccelerationYMps2: 0,
            userAccelerationZMps2: 0,
            rotationRateXRadps: 0,
            rotationRateYRadps: 0,
            rotationRateZRadps: 0
        ))
        let motionWindow = try #require(pendingMotionWindow)
        try await recorder.appendDeviceMotionWindow(motionWindow, timestamp: start.addingTimeInterval(7))
        try await recorder.pause(now: start.addingTimeInterval(10))
        _ = try await recorder.appendLocation(
            latitude: 37.0001,
            longitude: -122.0,
            horizontalAccuracyMeters: 20,
            timestamp: start.addingTimeInterval(15)
        )
        try await recorder.resume(now: start.addingTimeInterval(20))
        _ = try await recorder.finish(now: start.addingTimeInterval(30))

        let events = try await evidenceEvents(from: store.evidenceLogURL(sessionId: session.sessionId))
        let eventNames = events.compactMap { $0["event"] as? String }

        #expect(eventNames.contains("session_metadata"))
        #expect(eventNames.filter { $0 == "sampling_policy" }.count == 4)
        #expect(eventNames.filter { $0 == "raw_location" }.count == 2)
        #expect(eventNames.filter { $0 == "barometer_window" }.count == 1)
        #expect(eventNames.filter { $0 == "device_motion_window" }.count == 1)
        #expect(eventNames.contains("session_event"))
        #expect(events.first?["strategyVersion"] as? String == EvidenceLogger.strategyVersion)

        let rawLocations = events.filter { $0["event"] as? String == "raw_location" }
        #expect(rawLocations.first?["samplingEpochId"] as? Int == 1)
        #expect(rawLocations.first?["accuracy"] as? Double == 8)
        #expect(rawLocations.last?["isPaused"] as? Bool == true)
        #expect(rawLocations.last?["samplingState"] as? String == "PAUSED")

        let barometerWindows = events.filter { $0["event"] as? String == "barometer_window" }
        #expect(barometerWindows.first?["windowAscentMeters"] as? Double == 5)
        #expect(barometerWindows.first?["windowDescentMeters"] as? Double == 5)
        #expect(barometerWindows.first?["deltaRelativeAltitudeMeters"] as? Double == 0)

        let motionWindows = events.filter { $0["event"] as? String == "device_motion_window" }
        #expect(motionWindows.first?["accelerometerDynamicMaxMps2"] as? Double == 5)
        #expect(motionWindows.first?["gyroscopeMaxRadps"] as? Double == 2)
        #expect(motionWindows.first?["sampleCount"] as? Int == 3)
    }

    @Test("Recovered recorder continues evidence sequence ids")
    func recoveredRecorderContinuesEvidenceSequences() async throws {
        let route = try await sampleInstalledRoute()
        let store = try await makeStore()
        let start = Date(timeIntervalSince1970: 1_800_000_600)

        let firstRecorder = HikingSessionRecorder(store: store)
        let session = try await firstRecorder.start(route: route, now: start)
        _ = try await firstRecorder.appendLocation(
            latitude: 37.0,
            longitude: -122.0,
            timestamp: start.addingTimeInterval(5)
        )

        let recoveredRecorder = HikingSessionRecorder(store: store)
        let recovered = try await recoveredRecorder.recoverOpenSession()
        #expect(recovered?.sessionId == session.sessionId)
        _ = try await recoveredRecorder.appendLocation(
            latitude: 37.0001,
            longitude: -122.0,
            timestamp: start.addingTimeInterval(10)
        )

        let events = try await evidenceEvents(from: store.evidenceLogURL(sessionId: session.sessionId))
        let rawPointIds = events
            .filter { $0["event"] as? String == "raw_location" }
            .compactMap { $0["rawPointId"] as? Int }
        let samplingEpochIds = events
            .filter { $0["event"] as? String == "sampling_policy" }
            .compactMap { $0["samplingEpochId"] as? Int }

        #expect(rawPointIds == [1, 2])
        #expect(samplingEpochIds == [1, 2])
    }

    @Test("Barometer windows accumulate ascent and descent inside the window")
    func barometerWindowsAccumulateInsideWindow() throws {
        var accumulator = EvidenceBarometerWindowAccumulator(windowSeconds: 6, minAltitudeStepMeters: 0.5)
        #expect(accumulator.append(EvidenceBarometerSample(elapsedRealtimeNanos: 0, relativeAltitudeMeters: 100)) == nil)
        #expect(accumulator.append(EvidenceBarometerSample(elapsedRealtimeNanos: 3_000_000_000, relativeAltitudeMeters: 105)) == nil)

        let pendingWindow = accumulator.append(
            EvidenceBarometerSample(elapsedRealtimeNanos: 6_000_000_000, relativeAltitudeMeters: 100)
        )
        let window = try #require(pendingWindow)

        #expect(window.deltaRelativeAltitudeMeters == 0)
        #expect(window.windowAscentMeters == 5)
        #expect(window.windowDescentMeters == 5)
        #expect(window.sessionBarometerAscentMeters == 5)
        #expect(window.sessionBarometerDescentMeters == 5)
        #expect(window.sampleCount == 3)
    }

    @Test("Device motion windows summarize dynamic acceleration and rotation")
    func deviceMotionWindowsSummarizeMotion() throws {
        var accumulator = EvidenceDeviceMotionWindowAccumulator(windowSeconds: 2)
        #expect(accumulator.append(EvidenceDeviceMotionSample(
            elapsedRealtimeNanos: 0,
            userAccelerationXMps2: 0,
            userAccelerationYMps2: 0,
            userAccelerationZMps2: 0,
            rotationRateXRadps: 0,
            rotationRateYRadps: 0,
            rotationRateZRadps: 0
        )) == nil)
        #expect(accumulator.append(EvidenceDeviceMotionSample(
            elapsedRealtimeNanos: 1_000_000_000,
            userAccelerationXMps2: 3,
            userAccelerationYMps2: 4,
            userAccelerationZMps2: 0,
            rotationRateXRadps: 0,
            rotationRateYRadps: 0,
            rotationRateZRadps: 2
        )) == nil)
        let pendingWindow = accumulator.append(EvidenceDeviceMotionSample(
            elapsedRealtimeNanos: 2_000_000_000,
            userAccelerationXMps2: 0,
            userAccelerationYMps2: 0,
            userAccelerationZMps2: 0,
            rotationRateXRadps: 0,
            rotationRateYRadps: 0,
            rotationRateZRadps: 0
        ))
        let window = try #require(pendingWindow)

        #expect(window.accelerometerDynamicMaxMps2 == 5)
        #expect(window.gyroscopeMaxRadps == 2)
        #expect(abs(window.accelerometerDynamicRmsMps2 - sqrt(25.0 / 3.0)) < 0.000001)
        #expect(abs(window.gyroscopeRmsRadps - sqrt(4.0 / 3.0)) < 0.000001)
        #expect(window.sampleCount == 3)
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

    private func evidenceEvents(from url: URL) throws -> [[String: Any]] {
        let text = try String(contentsOf: url, encoding: .utf8)
        return try text
            .split(separator: "\n")
            .map { line in
                let data = Data(line.utf8)
                return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            }
    }
}
