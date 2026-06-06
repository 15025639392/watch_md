import Combine
import Foundation
import WatchConnectivity

@MainActor
final class iPhoneSessionSyncService: NSObject, ObservableObject {
    @Published private(set) var receivedSessions: [ReceivedSessionRecord] = []
    @Published private(set) var lastSyncMessage = "等待 Watch 回传"
    @Published private(set) var isWatchConnectivityAvailable = WCSession.isSupported()
    @Published private(set) var isWatchConnected = false
    @Published private(set) var watchConnectionTitle = "检查 Watch"
    @Published private(set) var watchConnectionDetail = "正在读取 Apple Watch 状态"

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
            isWatchConnected = false
            watchConnectionTitle = "当前设备不支持"
            watchConnectionDetail = "这台设备不能与 Apple Watch 通信"
            return
        }
        updateWatchConnectionState(session)
        session.activate()
        Task {
            await reloadStoredSessions()
        }
    }

    private func updateCurrentWatchConnectionState() {
        guard let session else {
            isWatchConnected = false
            watchConnectionTitle = "当前设备不支持"
            watchConnectionDetail = "这台设备不能与 Apple Watch 通信"
            return
        }
        updateWatchConnectionState(session)
    }

    private func updateWatchConnectionState(_ session: WCSession) {
        isWatchConnectivityAvailable = WCSession.isSupported()

        guard isWatchConnectivityAvailable else {
            isWatchConnected = false
            watchConnectionTitle = "当前设备不支持"
            watchConnectionDetail = "这台设备不能与 Apple Watch 通信"
            return
        }

        guard session.activationState == .activated else {
            isWatchConnected = false
            watchConnectionTitle = "正在连接 Watch"
            watchConnectionDetail = "WatchConnectivity 正在激活"
            return
        }

        guard session.isPaired else {
            isWatchConnected = false
            watchConnectionTitle = "未配对 Watch"
            watchConnectionDetail = "请先在 iPhone 上配对 Apple Watch"
            return
        }

        guard session.isWatchAppInstalled else {
            isWatchConnected = false
            watchConnectionTitle = "Watch App 未安装"
            watchConnectionDetail = "请先把 Watch App 安装到 Apple Watch"
            return
        }

        if session.isReachable {
            isWatchConnected = true
            watchConnectionTitle = "Watch 已连接"
            watchConnectionDetail = "可以实时通信；结束后也会继续支持可靠回传"
        } else {
            isWatchConnected = false
            watchConnectionTitle = "Watch 未实时连接"
            watchConnectionDetail = "可靠回传会排队，Watch 靠近并打开后继续同步"
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
            updateCurrentWatchConnectionState()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            updateCurrentWatchConnectionState()
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            updateCurrentWatchConnectionState()
        }
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
