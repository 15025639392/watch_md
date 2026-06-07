import Foundation

public enum EvidenceLoggingError: Error, Equatable {
    case invalidJSONObject
}

public struct EvidenceSamplingPolicy: Equatable, Sendable {
    public var state: String
    public var desiredAccuracy: String?
    public var distanceFilterMeters: Double?
    public var allowsBackgroundLocationUpdates: Bool?
    public var barometerWindowSeconds: Double?
    public var motionWindowSeconds: Double?
    public var powerMode: String?

    public init(
        state: String,
        desiredAccuracy: String? = nil,
        distanceFilterMeters: Double? = nil,
        allowsBackgroundLocationUpdates: Bool? = nil,
        barometerWindowSeconds: Double? = nil,
        motionWindowSeconds: Double? = nil,
        powerMode: String? = nil
    ) {
        self.state = state
        self.desiredAccuracy = desiredAccuracy
        self.distanceFilterMeters = distanceFilterMeters
        self.allowsBackgroundLocationUpdates = allowsBackgroundLocationUpdates
        self.barometerWindowSeconds = barometerWindowSeconds
        self.motionWindowSeconds = motionWindowSeconds
        self.powerMode = powerMode
    }

    public static let movingStandard = EvidenceSamplingPolicy(
        state: "MOVING_STANDARD",
        desiredAccuracy: "best",
        distanceFilterMeters: 5,
        allowsBackgroundLocationUpdates: true,
        barometerWindowSeconds: 10,
        motionWindowSeconds: 10,
        powerMode: "standard"
    )

    public static let paused = EvidenceSamplingPolicy(
        state: "PAUSED",
        desiredAccuracy: "best",
        distanceFilterMeters: 60,
        allowsBackgroundLocationUpdates: true,
        barometerWindowSeconds: nil,
        motionWindowSeconds: nil,
        powerMode: "paused"
    )

    public static let finished = EvidenceSamplingPolicy(
        state: "FINISHED",
        desiredAccuracy: nil,
        distanceFilterMeters: nil,
        allowsBackgroundLocationUpdates: false,
        barometerWindowSeconds: nil,
        motionWindowSeconds: nil,
        powerMode: "finished"
    )
}

public struct EvidenceLocationTiming: Equatable, Sendable {
    public var estimatedFixElapsedRealtimeNanos: Int64?
    public var receivedElapsedRealtimeNanos: Int64?
    public var callbackDelayNanos: Int64?

    public init(
        estimatedFixElapsedRealtimeNanos: Int64? = nil,
        receivedElapsedRealtimeNanos: Int64? = nil,
        callbackDelayNanos: Int64? = nil
    ) {
        self.estimatedFixElapsedRealtimeNanos = estimatedFixElapsedRealtimeNanos
        self.receivedElapsedRealtimeNanos = receivedElapsedRealtimeNanos
        self.callbackDelayNanos = callbackDelayNanos
    }
}

public struct EvidenceBarometerSample: Equatable, Sendable {
    public var elapsedRealtimeNanos: Int64
    public var relativeAltitudeMeters: Double
    public var pressureKpa: Double?

    public init(
        elapsedRealtimeNanos: Int64,
        relativeAltitudeMeters: Double,
        pressureKpa: Double? = nil
    ) {
        self.elapsedRealtimeNanos = elapsedRealtimeNanos
        self.relativeAltitudeMeters = relativeAltitudeMeters
        self.pressureKpa = pressureKpa
    }
}

public struct EvidenceBarometerWindow: Equatable, Sendable {
    public var barometerWindowId: Int64
    public var startElapsedRealtimeNanos: Int64
    public var endElapsedRealtimeNanos: Int64
    public var sampleCount: Int
    public var startRelativeAltitudeMeters: Double
    public var endRelativeAltitudeMeters: Double
    public var minRelativeAltitudeMeters: Double
    public var maxRelativeAltitudeMeters: Double
    public var avgRelativeAltitudeMeters: Double
    public var deltaRelativeAltitudeMeters: Double
    public var windowAscentMeters: Double
    public var windowDescentMeters: Double
    public var sessionBarometerAscentMeters: Double
    public var sessionBarometerDescentMeters: Double
    public var startPressureKpa: Double?
    public var endPressureKpa: Double?
    public var minPressureKpa: Double?
    public var maxPressureKpa: Double?
    public var avgPressureKpa: Double?
}

public struct EvidenceDeviceMotionSample: Equatable, Sendable {
    public var elapsedRealtimeNanos: Int64
    public var userAccelerationXMps2: Double
    public var userAccelerationYMps2: Double
    public var userAccelerationZMps2: Double
    public var rotationRateXRadps: Double
    public var rotationRateYRadps: Double
    public var rotationRateZRadps: Double

    public init(
        elapsedRealtimeNanos: Int64,
        userAccelerationXMps2: Double,
        userAccelerationYMps2: Double,
        userAccelerationZMps2: Double,
        rotationRateXRadps: Double,
        rotationRateYRadps: Double,
        rotationRateZRadps: Double
    ) {
        self.elapsedRealtimeNanos = elapsedRealtimeNanos
        self.userAccelerationXMps2 = userAccelerationXMps2
        self.userAccelerationYMps2 = userAccelerationYMps2
        self.userAccelerationZMps2 = userAccelerationZMps2
        self.rotationRateXRadps = rotationRateXRadps
        self.rotationRateYRadps = rotationRateYRadps
        self.rotationRateZRadps = rotationRateZRadps
    }
}

public struct EvidenceDeviceMotionWindow: Equatable, Sendable {
    public var deviceMotionWindowId: Int64
    public var startElapsedRealtimeNanos: Int64
    public var endElapsedRealtimeNanos: Int64
    public var accelerometerDynamicRmsMps2: Double
    public var accelerometerDynamicMaxMps2: Double
    public var gyroscopeRmsRadps: Double
    public var gyroscopeMaxRadps: Double
    public var stepCounterDelta: Int?
    public var sampleCount: Int
}

public struct EvidenceDeviceMotionWindowAccumulator: Sendable {
    public var windowSeconds: Double

    private var windowId: Int64 = 0
    private var samples: [EvidenceDeviceMotionSample] = []

    public init(windowSeconds: Double = 10) {
        self.windowSeconds = windowSeconds
    }

    public mutating func append(_ sample: EvidenceDeviceMotionSample) -> EvidenceDeviceMotionWindow? {
        if samples.isEmpty {
            samples = [sample]
            return nil
        }
        samples.append(sample)

        let elapsedSeconds = secondsBetween(samples[0].elapsedRealtimeNanos, sample.elapsedRealtimeNanos)
        guard elapsedSeconds >= windowSeconds else { return nil }
        return closeWindow()
    }

    public mutating func flush() -> EvidenceDeviceMotionWindow? {
        guard !samples.isEmpty else { return nil }
        return closeWindow()
    }

    private mutating func closeWindow() -> EvidenceDeviceMotionWindow? {
        guard let first = samples.first, let last = samples.last else { return nil }
        windowId += 1

        let accelerationMagnitudes = samples.map { sample in
            vectorMagnitude(
                x: sample.userAccelerationXMps2,
                y: sample.userAccelerationYMps2,
                z: sample.userAccelerationZMps2
            )
        }
        let rotationMagnitudes = samples.map { sample in
            vectorMagnitude(
                x: sample.rotationRateXRadps,
                y: sample.rotationRateYRadps,
                z: sample.rotationRateZRadps
            )
        }

        let window = EvidenceDeviceMotionWindow(
            deviceMotionWindowId: windowId,
            startElapsedRealtimeNanos: first.elapsedRealtimeNanos,
            endElapsedRealtimeNanos: last.elapsedRealtimeNanos,
            accelerometerDynamicRmsMps2: rootMeanSquare(accelerationMagnitudes),
            accelerometerDynamicMaxMps2: accelerationMagnitudes.max() ?? 0,
            gyroscopeRmsRadps: rootMeanSquare(rotationMagnitudes),
            gyroscopeMaxRadps: rotationMagnitudes.max() ?? 0,
            stepCounterDelta: nil,
            sampleCount: samples.count
        )

        samples.removeAll(keepingCapacity: true)
        samples.append(last)
        return window
    }
}

public struct EvidenceBarometerWindowAccumulator: Sendable {
    public var windowSeconds: Double
    public var minAltitudeStepMeters: Double
    public var maxSampleGapSeconds: Double
    public var maxVerticalSpeedMetersPerSecond: Double

    private var windowId: Int64 = 0
    private var samples: [EvidenceBarometerSample] = []
    private var previousAcceptedSample: EvidenceBarometerSample?
    private var currentWindowAscentMeters = 0.0
    private var currentWindowDescentMeters = 0.0
    private var sessionAscentMeters = 0.0
    private var sessionDescentMeters = 0.0

    public init(
        windowSeconds: Double = 10,
        minAltitudeStepMeters: Double = 0.5,
        maxSampleGapSeconds: Double = 30,
        maxVerticalSpeedMetersPerSecond: Double = 2
    ) {
        self.windowSeconds = windowSeconds
        self.minAltitudeStepMeters = minAltitudeStepMeters
        self.maxSampleGapSeconds = maxSampleGapSeconds
        self.maxVerticalSpeedMetersPerSecond = maxVerticalSpeedMetersPerSecond
    }

    public mutating func append(_ sample: EvidenceBarometerSample) -> EvidenceBarometerWindow? {
        if samples.isEmpty {
            samples = [sample]
            previousAcceptedSample = sample
            return nil
        }

        accumulateVerticalChange(to: sample)
        samples.append(sample)

        let elapsedSeconds = secondsBetween(samples[0].elapsedRealtimeNanos, sample.elapsedRealtimeNanos)
        guard elapsedSeconds >= windowSeconds else { return nil }
        return closeWindow()
    }

    public mutating func flush() -> EvidenceBarometerWindow? {
        guard !samples.isEmpty else { return nil }
        return closeWindow()
    }

    private mutating func accumulateVerticalChange(to sample: EvidenceBarometerSample) {
        guard let previous = previousAcceptedSample else {
            previousAcceptedSample = sample
            return
        }

        let elapsedSeconds = secondsBetween(previous.elapsedRealtimeNanos, sample.elapsedRealtimeNanos)
        guard elapsedSeconds > 0, elapsedSeconds <= maxSampleGapSeconds else {
            previousAcceptedSample = sample
            return
        }

        let delta = sample.relativeAltitudeMeters - previous.relativeAltitudeMeters
        let verticalSpeed = abs(delta) / elapsedSeconds
        guard verticalSpeed <= maxVerticalSpeedMetersPerSecond else {
            previousAcceptedSample = sample
            return
        }

        if delta >= minAltitudeStepMeters {
            currentWindowAscentMeters += delta
            sessionAscentMeters += delta
            previousAcceptedSample = sample
        } else if delta <= -minAltitudeStepMeters {
            let descent = abs(delta)
            currentWindowDescentMeters += descent
            sessionDescentMeters += descent
            previousAcceptedSample = sample
        }
    }

    private mutating func closeWindow() -> EvidenceBarometerWindow? {
        guard let first = samples.first, let last = samples.last else { return nil }
        windowId += 1

        let relativeAltitudes = samples.map(\.relativeAltitudeMeters)
        let pressures = samples.compactMap(\.pressureKpa)
        let window = EvidenceBarometerWindow(
            barometerWindowId: windowId,
            startElapsedRealtimeNanos: first.elapsedRealtimeNanos,
            endElapsedRealtimeNanos: last.elapsedRealtimeNanos,
            sampleCount: samples.count,
            startRelativeAltitudeMeters: first.relativeAltitudeMeters,
            endRelativeAltitudeMeters: last.relativeAltitudeMeters,
            minRelativeAltitudeMeters: relativeAltitudes.min() ?? first.relativeAltitudeMeters,
            maxRelativeAltitudeMeters: relativeAltitudes.max() ?? first.relativeAltitudeMeters,
            avgRelativeAltitudeMeters: average(relativeAltitudes),
            deltaRelativeAltitudeMeters: last.relativeAltitudeMeters - first.relativeAltitudeMeters,
            windowAscentMeters: currentWindowAscentMeters,
            windowDescentMeters: currentWindowDescentMeters,
            sessionBarometerAscentMeters: sessionAscentMeters,
            sessionBarometerDescentMeters: sessionDescentMeters,
            startPressureKpa: first.pressureKpa,
            endPressureKpa: last.pressureKpa,
            minPressureKpa: pressures.min(),
            maxPressureKpa: pressures.max(),
            avgPressureKpa: pressures.isEmpty ? nil : average(pressures)
        )

        samples.removeAll(keepingCapacity: true)
        currentWindowAscentMeters = 0
        currentWindowDescentMeters = 0
        samples.append(last)
        previousAcceptedSample = last
        return window
    }
}

public actor EvidenceLogger {
    public static let strategyVersion = "watchos-evidence-v0.1"

    private let fileURL: URL
    private var eventSeq: Int64 = 0
    private var rawPointSeq: Int64 = 0
    private var samplingEpochSeq: Int64 = 0
    private var activeSamplingEpoch: (id: Int64, policy: EvidenceSamplingPolicy)?

    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        let sequences = try Self.restoredSequences(from: fileURL)
        eventSeq = sequences.eventSeq
        rawPointSeq = sequences.rawPointSeq
        samplingEpochSeq = sequences.samplingEpochSeq
    }

    public func logSessionMetadata(
        session: HikingSession,
        route: InstalledRoute,
        watchDeviceId: String?,
        now: Date
    ) throws {
        var event = baseEvent(name: "session_metadata", sessionId: session.sessionId, now: now)
        event["createdWallTimeMillis"] = milliseconds(now)
        event["createdElapsedRealtimeNanos"] = monotonicNanos()
        event["strategyVersion"] = Self.strategyVersion
        event["platform"] = "watchOS"
        event["deviceModel"] = watchDeviceId ?? "Apple Watch"
        event["routeId"] = route.route.routeId
        event["routeVersion"] = route.route.version
        event["routeName"] = route.route.name
        event["sessionMode"] = route.route.remoteRouteId == "watch-free-recording"
            || route.route.sourceProvider == "watch-free-recording"
            ? "freeRecording"
            : "plannedRoute"
        try append(event)
    }

    @discardableResult
    public func logSamplingPolicy(
        sessionId: String,
        policy: EvidenceSamplingPolicy,
        now: Date
    ) throws -> Int64 {
        samplingEpochSeq += 1
        activeSamplingEpoch = (samplingEpochSeq, policy)
        var event = baseEvent(name: "sampling_policy", sessionId: sessionId, now: now)
        event["samplingEpochId"] = samplingEpochSeq
        event["state"] = policy.state
        event["locationProvider"] = "core_location"
        putOptional(policy.desiredAccuracy, key: "desiredAccuracy", into: &event)
        putOptional(policy.distanceFilterMeters, key: "distanceFilterMeters", into: &event)
        putOptional(policy.allowsBackgroundLocationUpdates, key: "allowsBackgroundLocationUpdates", into: &event)
        putOptional(policy.barometerWindowSeconds, key: "barometerWindowSeconds", into: &event)
        putOptional(policy.motionWindowSeconds, key: "motionWindowSeconds", into: &event)
        putOptional(policy.powerMode, key: "powerMode", into: &event)
        try append(event)
        return samplingEpochSeq
    }

    public func logSessionEvent(
        sessionId: String,
        type: SessionEventType,
        coordinate: GeoCoordinate?,
        routeProgressMeters: Double?,
        severity: SessionEventSeverity,
        payload: [String: String],
        timestamp: Date
    ) throws {
        var event = baseEvent(name: "session_event", sessionId: sessionId, now: timestamp)
        event["type"] = type.rawValue
        event["severity"] = severity.rawValue
        if let coordinate {
            event["lat"] = coordinate.latitude
            event["lng"] = coordinate.longitude
        }
        putOptional(routeProgressMeters, key: "routeProgressMeters", into: &event)
        if !payload.isEmpty {
            event["payload"] = payload
        }
        try append(event)
    }

    public func logRawLocation(
        sessionId: String,
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        elevationMeters: Double?,
        horizontalAccuracyMeters: Double?,
        verticalAccuracyMeters: Double?,
        speedMetersPerSecond: Double?,
        courseDegrees: Double?,
        isPaused: Bool,
        timing: EvidenceLocationTiming = EvidenceLocationTiming()
    ) throws {
        rawPointSeq += 1
        var event = baseEvent(name: "raw_location", sessionId: sessionId, now: Date())
        event["rawPointId"] = rawPointSeq
        event["provider"] = "core_location"
        event["lat"] = latitude
        event["lng"] = longitude
        event["timeMillis"] = milliseconds(timestamp)
        event["isPaused"] = isPaused
        putOptional(elevationMeters, key: "altitude", into: &event)
        putOptional(horizontalAccuracyMeters, key: "accuracy", into: &event)
        putOptional(verticalAccuracyMeters, key: "verticalAccuracy", into: &event)
        putOptional(speedMetersPerSecond, key: "speed", into: &event)
        putOptional(courseDegrees, key: "bearing", into: &event)
        putOptional(timing.estimatedFixElapsedRealtimeNanos, key: "estimatedFixElapsedRealtimeNanos", into: &event)
        putOptional(timing.receivedElapsedRealtimeNanos, key: "receivedElapsedRealtimeNanos", into: &event)
        putOptional(timing.callbackDelayNanos, key: "callbackDelayNanos", into: &event)
        if let activeSamplingEpoch {
            event["samplingEpochId"] = activeSamplingEpoch.id
            event["samplingState"] = activeSamplingEpoch.policy.state
            putOptional(activeSamplingEpoch.policy.desiredAccuracy, key: "desiredAccuracy", into: &event)
            putOptional(activeSamplingEpoch.policy.distanceFilterMeters, key: "distanceFilterMeters", into: &event)
        }
        try append(event)
    }

    public func logBarometerWindow(
        sessionId: String,
        window: EvidenceBarometerWindow,
        powerMode: String = "standard",
        timestamp: Date = Date()
    ) throws {
        var event = baseEvent(name: "barometer_window", sessionId: sessionId, now: timestamp)
        event["barometerWindowId"] = window.barometerWindowId
        event["startElapsedRealtimeNanos"] = window.startElapsedRealtimeNanos
        event["endElapsedRealtimeNanos"] = window.endElapsedRealtimeNanos
        event["sampleCount"] = window.sampleCount
        event["startRelativeAltitudeMeters"] = window.startRelativeAltitudeMeters
        event["endRelativeAltitudeMeters"] = window.endRelativeAltitudeMeters
        event["minRelativeAltitudeMeters"] = window.minRelativeAltitudeMeters
        event["maxRelativeAltitudeMeters"] = window.maxRelativeAltitudeMeters
        event["avgRelativeAltitudeMeters"] = window.avgRelativeAltitudeMeters
        event["deltaRelativeAltitudeMeters"] = window.deltaRelativeAltitudeMeters
        event["windowAscentMeters"] = window.windowAscentMeters
        event["windowDescentMeters"] = window.windowDescentMeters
        event["sessionBarometerAscentMeters"] = window.sessionBarometerAscentMeters
        event["sessionBarometerDescentMeters"] = window.sessionBarometerDescentMeters
        putOptional(window.startPressureKpa, key: "startPressureKpa", into: &event)
        putOptional(window.endPressureKpa, key: "endPressureKpa", into: &event)
        putOptional(window.minPressureKpa, key: "minPressureKpa", into: &event)
        putOptional(window.maxPressureKpa, key: "maxPressureKpa", into: &event)
        putOptional(window.avgPressureKpa, key: "avgPressureKpa", into: &event)
        event["powerMode"] = powerMode
        try append(event)
    }

    public func logDeviceMotionWindow(
        sessionId: String,
        window: EvidenceDeviceMotionWindow,
        powerMode: String = "standard",
        timestamp: Date = Date()
    ) throws {
        var event = baseEvent(name: "device_motion_window", sessionId: sessionId, now: timestamp)
        event["deviceMotionWindowId"] = window.deviceMotionWindowId
        event["startElapsedRealtimeNanos"] = window.startElapsedRealtimeNanos
        event["endElapsedRealtimeNanos"] = window.endElapsedRealtimeNanos
        event["accelerometerDynamicRmsMps2"] = window.accelerometerDynamicRmsMps2
        event["accelerometerDynamicMaxMps2"] = window.accelerometerDynamicMaxMps2
        event["gyroscopeRmsRadps"] = window.gyroscopeRmsRadps
        event["gyroscopeMaxRadps"] = window.gyroscopeMaxRadps
        putOptional(window.stepCounterDelta, key: "stepCounterDelta", into: &event)
        event["sampleCount"] = window.sampleCount
        event["powerMode"] = powerMode
        try append(event)
    }

    private func baseEvent(name: String, sessionId: String, now: Date) -> [String: Any] {
        eventSeq += 1
        return [
            "event": name,
            "sessionId": sessionId,
            "eventSeq": eventSeq,
            "eventWallTimeMillis": milliseconds(now),
            "eventElapsedRealtimeNanos": monotonicNanos()
        ]
    }

    private func append(_ event: [String: Any]) throws {
        guard JSONSerialization.isValidJSONObject(event) else {
            throw EvidenceLoggingError.invalidJSONObject
        }
        var line = try JSONSerialization.data(withJSONObject: event, options: [.sortedKeys])
        line.append(0x0A)
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
    }

    private static func restoredSequences(from fileURL: URL) throws -> (eventSeq: Int64, rawPointSeq: Int64, samplingEpochSeq: Int64) {
        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return (0, 0, 0) }
        var eventSeq: Int64 = 0
        var rawPointSeq: Int64 = 0
        var samplingEpochSeq: Int64 = 0
        for line in text.split(separator: "\n") {
            guard
                let lineData = String(line).data(using: .utf8),
                let event = try JSONSerialization.jsonObject(with: lineData) as? [String: Any]
            else { continue }
            if let value = int64Value(event["eventSeq"]) {
                eventSeq = max(eventSeq, value)
            }
            if let value = int64Value(event["rawPointId"]) {
                rawPointSeq = max(rawPointSeq, value)
            }
            if let value = int64Value(event["samplingEpochId"]) {
                samplingEpochSeq = max(samplingEpochSeq, value)
            }
        }
        return (eventSeq, rawPointSeq, samplingEpochSeq)
    }
}

private func putOptional(_ value: Any?, key: String, into event: inout [String: Any]) {
    if let value {
        event[key] = value
    }
}

private func milliseconds(_ date: Date) -> Int64 {
    Int64((date.timeIntervalSince1970 * 1000).rounded())
}

private func monotonicNanos() -> Int64 {
    Int64((ProcessInfo.processInfo.systemUptime * 1_000_000_000).rounded())
}

private func secondsBetween(_ startNanos: Int64, _ endNanos: Int64) -> Double {
    Double(endNanos - startNanos) / 1_000_000_000
}

private func average(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    return values.reduce(0, +) / Double(values.count)
}

private func vectorMagnitude(x: Double, y: Double, z: Double) -> Double {
    sqrt(x * x + y * y + z * z)
}

private func rootMeanSquare(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    let squares = values.map { $0 * $0 }
    return sqrt(average(squares))
}

private func int64Value(_ value: Any?) -> Int64? {
    switch value {
    case let value as Int:
        Int64(value)
    case let value as Int64:
        value
    case let value as NSNumber:
        value.int64Value
    default:
        nil
    }
}
