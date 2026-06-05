import Combine
import Foundation
import WatchConnectivity

@MainActor
final class iPhoneSessionSyncService: NSObject, ObservableObject {
    @Published private(set) var receivedSessions: [ReceivedSessionRecord] = []
    @Published private(set) var lastSyncMessage = "等待 Watch 回传"
    @Published private(set) var isWatchConnectivityAvailable = WCSession.isSupported()

    private let receiver = iPhoneSessionSyncReceiver()
    private let store: iPhoneReceivedSessionStore
    private let session: WCSession?

    override init() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ReceivedSessions", isDirectory: true)
        store = try! iPhoneReceivedSessionStore(directoryURL: directory)
        session = WCSession.isSupported() ? .default : nil
        super.init()
        session?.delegate = self
    }

    func start() {
        guard let session else {
            lastSyncMessage = "当前设备不支持 WatchConnectivity"
            return
        }
        session.activate()
        Task {
            await reloadStoredSessions()
        }
    }

    private func reloadStoredSessions() async {
        do {
            receivedSessions = try await store.listRecords()
        } catch {
            lastSyncMessage = "读取历史回传失败：\(error.localizedDescription)"
        }
    }

    private func handleEnvelopeData(_ data: Data) async {
        do {
            let header = try RouteSyncCodec.decoder.decode(SyncEnvelopeHeader.self, from: data)
            let ack: SyncEnvelope<SyncAck>
            let sessionId: String

            switch header.kind {
            case .sessionStatus:
                let envelope = try RouteSyncCodec.decoder.decode(SyncEnvelope<SessionStatusPayload>.self, from: data)
                ack = try await receiver.receiveStatus(envelope)
                sessionId = envelope.payload.sessionId
            case .trackChunk:
                let envelope = try RouteSyncCodec.decoder.decode(SyncEnvelope<TrackChunk>.self, from: data)
                ack = try await receiver.receiveTrackChunk(envelope)
                sessionId = envelope.payload.sessionId
            case .eventChunk:
                let envelope = try RouteSyncCodec.decoder.decode(SyncEnvelope<EventChunk>.self, from: data)
                ack = try await receiver.receiveEventChunk(envelope)
                sessionId = envelope.payload.sessionId
            case .sessionSummary:
                let envelope = try RouteSyncCodec.decoder.decode(SyncEnvelope<SessionSummary>.self, from: data)
                ack = try await receiver.receiveSummary(envelope)
                sessionId = envelope.payload.sessionId
            case .routeManifest, .routePayload, .syncAck:
                lastSyncMessage = "收到非会话回传数据：\(header.kind.rawValue)"
                return
            }

            if let record = await receiver.record(sessionId: sessionId) {
                try await store.save(record)
                await reloadStoredSessions()
            }
            sendAck(ack)
            lastSyncMessage = message(for: ack.payload)
        } catch {
            lastSyncMessage = "处理 Watch 回传失败：\(error.localizedDescription)"
        }
    }

    private func sendAck(_ envelope: SyncEnvelope<SyncAck>) {
        do {
            let data = try RouteSyncCodec.encoder.encode(envelope)
            session?.transferUserInfo([
                WatchSessionSyncTransferKeys.envelopeData: data,
                WatchSessionSyncTransferKeys.kind: envelope.kind.rawValue
            ])
        } catch {
            lastSyncMessage = "ACK 编码失败：\(error.localizedDescription)"
        }
    }

    private func message(for ack: SyncAck) -> String {
        switch (ack.status, ack.action) {
        case (.ok, .sessionComplete):
            return "会话回传完成"
        case (.missingData, .missingRangesRequested):
            return "轨迹缺口等待补传"
        case (.alreadyReceived, _):
            return "重复数据已去重"
        default:
            return "已接收：\(ack.action.rawValue)"
        }
    }
}

extension iPhoneSessionSyncService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error {
                lastSyncMessage = "WatchConnectivity 激活失败：\(error.localizedDescription)"
            } else {
                lastSyncMessage = activationState == .activated ? "等待 Watch 回传" : "WatchConnectivity 未激活"
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[WatchSessionSyncTransferKeys.envelopeData] as? Data else {
            Task { @MainActor in
                lastSyncMessage = "收到 Watch 数据，但缺少 envelope"
            }
            return
        }
        Task { @MainActor in
            await handleEnvelopeData(data)
        }
    }
}

private enum WatchSessionSyncTransferKeys {
    static let envelopeData = "syncEnvelopeData"
    static let kind = "kind"
}

private struct SyncEnvelopeHeader: Decodable {
    var kind: SyncEnvelopeKind
}

private actor iPhoneReceivedSessionStore {
    private let directoryURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directoryURL: URL) throws {
        self.directoryURL = directoryURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func save(_ record: ReceivedSessionRecord) throws {
        let data = try encoder.encode(record)
        let targetURL = directoryURL.appendingPathComponent("\(record.sessionId).json")
        let temporaryURL = directoryURL.appendingPathComponent("\(record.sessionId).tmp")
        try data.write(to: temporaryURL, options: [.atomic])
        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.removeItem(at: targetURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: targetURL)
    }

    func listRecords() throws -> [ReceivedSessionRecord] {
        let urls = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        return try urls.map { try decoder.decode(ReceivedSessionRecord.self, from: Data(contentsOf: $0)) }
            .sorted { ($0.summary?.endedAt ?? .distantPast) > ($1.summary?.endedAt ?? .distantPast) }
    }
}
