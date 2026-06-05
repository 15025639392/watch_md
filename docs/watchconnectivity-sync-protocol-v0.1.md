# WatchConnectivity 同步协议 v0.1

更新日期：2026-06-05

## 协议目标

同步协议要保证 iPhone 和 Apple Watch 在弱连接、断连、重复发送和 App 恢复的情况下，仍能完成：

1. iPhone 将计划路线可靠下发到 Watch。
2. Watch 在行进中向 iPhone 同步轻量状态。
3. Watch 结束后将实际轨迹、事件和摘要回传 iPhone。
4. iPhone 和 Watch 都能识别重复消息并去重。
5. 同步失败不能导致路线或轨迹丢失。

## WatchConnectivity 通道选择

| 通道 | 特点 | 本产品用途 |
| --- | --- | --- |
| `sendMessage` / `sendMessageData` | 需要双方可达，适合即时小消息 | 开始同步请求、实时状态、ACK、轻量控制 |
| `updateApplicationContext` | 保存最新状态，后发覆盖前发 | 当前路线同步状态、当前会话概览 |
| `transferUserInfo` | 后台排队可靠传输，适合结构化数据 | 会话摘要、事件 chunk、轨迹小 chunk |
| `transferFile` | 后台排队文件传输，适合大 payload | 路线 payload、大轨迹文件、完整会话归档 |

### 使用原则

1. 路线和轨迹这类不能丢的数据，不依赖 `sendMessage` 单次传输。
2. `sendMessage` 只用于即时状态和唤起对端处理。
3. 大数据优先用 `transferFile`，小型增量可用 `transferUserInfo`。
4. `updateApplicationContext` 只放“最新状态”，不能放必须保留的历史数据。

## 同步对象

| 对象 | 方向 | 通道 | 可靠性要求 |
| --- | --- | --- | --- |
| 路线 manifest | iPhone -> Watch | `sendMessage` + `transferUserInfo` | 高 |
| 路线 payload | iPhone -> Watch | `transferFile` | 高 |
| 路线 ACK | Watch -> iPhone | `sendMessage` + `transferUserInfo` | 高 |
| 会话实时状态 | Watch -> iPhone | `sendMessage` / `updateApplicationContext` | 中 |
| 轨迹 chunk | Watch -> iPhone | `transferUserInfo` / `transferFile` | 高 |
| 事件 chunk | Watch -> iPhone | `transferUserInfo` | 高 |
| 会话摘要 | Watch -> iPhone | `transferUserInfo` | 高 |
| 同步 ACK | 双向 | `sendMessage` + `transferUserInfo` | 高 |

## Envelope 基础结构

所有跨端 payload 都包在 `SyncEnvelope` 中。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `envelopeId` | String | 封包唯一 ID |
| `schemaVersion` | Int | 协议结构版本 |
| `createdAt` | Date/String | 创建时间 |
| `sender` | Enum | `iphone` 或 `watch` |
| `kind` | Enum | 封包类型 |
| `entityId` | String | 关联对象 ID，例如 routeId 或 sessionId |
| `entityVersion` | Int? | 路线版本或会话修订号 |
| `sequence` | Int? | chunk 顺序 |
| `isFinal` | Bool | 是否为最后一个 chunk |
| `payloadChecksum` | String | payload 校验 |
| `payload` | Object | 具体内容 |

### 幂等规则

1. 接收端以 `envelopeId` 去重。
2. 对 chunk 类数据，以 `entityId + kind + sequence` 去重。
3. 对路线，以 `routeId + routeVersion + checksum` 判断是否已安装。
4. 对轨迹点，以 `sessionId + sequence` 去重。
5. 对事件，以 `eventId` 去重。

## 路线下发协议

路线下发分为 manifest 和 payload 两步。

### 1. iPhone 发送 routeManifest

目的：

1. 告诉 Watch 有一条路线准备同步。
2. 让 Watch 判断是否已经有同版本路线。
3. 避免直接覆盖 Watch 上已有可用路线。

内容：

| 字段 | 说明 |
| --- | --- |
| `routeId` | 路线 ID |
| `routeVersion` | 路线版本 |
| `name` | 路线名称 |
| `distanceMeters` | 路线距离 |
| `bounds` | 路线范围 |
| `simplifiedPointCount` | Watch 路线点数 |
| `turnPointCount` | 转向点数量 |
| `waypointCount` | 关键点数量 |
| `payloadChecksum` | 完整路线 payload 校验 |
| `payloadSizeBytes` | payload 大小 |

通道：

1. Watch 可达时，先用 `sendMessage`。
2. 同时或失败后用 `transferUserInfo` 排队。

Watch 收到后：

1. 如果已有同 `routeId + version + checksum`，直接回 `syncAck(status=alreadyReceived, action=routeAlreadyInstalled)`。
2. 如果是新路线，回 `syncAck(status=ok, action=readyForPayload)`。
3. 如果存储空间不足，回 `syncAck(status=rejected, action=routeManifestRejected)` 并带原因。

### 2. iPhone 发送 routePayload

目的：

将 Watch 端必需路线数据下发。

内容：

1. `HikingRoute` 摘要。
2. `simplifiedForWatch` 路线点。
3. `TurnPoint` 列表。
4. `Waypoint` 列表。
5. 默认提醒配置。

通道：

1. 默认 `transferFile`。
2. payload 很小时可用 `transferUserInfo`。

Watch 收到后：

1. 校验 checksum。
2. 写入临时路线文件。
3. 校验成功后原子替换为可用路线。
4. 保留上一次可用路线，直到新路线安装成功。
5. 回 `syncAck`，`status=ok`，`action=routeInstalled`。

### 3. 路线下发状态

| 状态 | iPhone | Watch |
| --- | --- | --- |
| `notSynced` | 显示可同步 | 不显示新路线 |
| `manifestSent` | 等待 Watch 响应 | 检查本地路线 |
| `readyForPayload` | 发送 payload | 显示接收中 |
| `payloadTransferred` | 等待安装 ACK | 校验并安装 |
| `installed` | 显示 Watch 已就绪 | 显示路线卡片，等待用户确认使用 |
| `failed` | 显示重试 | 保留旧路线 |

注意：`routeInstalled` 只表示路线已在 Watch 本地可用，不表示该路线已经绑定当前会话。任何路线进入导航前，都必须由用户在 Watch 上确认。

## 会话状态同步

Watch 开始徒步后，向 iPhone 同步轻量状态。

### sessionStatus 内容

| 字段 | 说明 |
| --- | --- |
| `sessionId` | 会话 ID |
| `routeId` | 路线 ID |
| `routeVersion` | 路线版本 |
| `status` | `active`、`paused`、`finished` |
| `startedAt` | 开始时间 |
| `elapsedSeconds` | 已用时间 |
| `distanceMeters` | 当前实际距离 |
| `routeProgressMeters` | 计划路线进度 |
| `offRouteDistanceMeters` | 当前偏航距离 |
| `lastCoordinate` | 最近位置 |
| `watchBatteryPercent` | Watch 电量 |
| `lastUpdatedAt` | 更新时间 |

通道：

1. iPhone 可达时用 `sendMessage`。
2. 同时用 `updateApplicationContext` 保存最新状态。
3. 不要求每条状态都可靠送达，因为下一条会覆盖上一条。

频率：

1. 正常行进：15-30 秒一次。
2. 状态变化时立即发送，例如暂停、偏航、结束。
3. 低电量时降低频率。

## 轨迹回传协议

轨迹回传必须可靠、可重试、可去重。

### trackChunk

内容：

| 字段 | 说明 |
| --- | --- |
| `sessionId` | 会话 ID |
| `chunkId` | chunk ID |
| `startSequence` | 本 chunk 第一条轨迹点 sequence |
| `endSequence` | 本 chunk 最后一条轨迹点 sequence |
| `isFinal` | 是否最后一包 |
| `points` | TrackPoint 数组 |
| `pointsChecksum` | 点数组校验 |

通道：

1. 小 chunk 用 `transferUserInfo`。
2. 会话结束后的完整轨迹或大 chunk 用 `transferFile`。

发送策略：

1. Watch 本地先保存轨迹点。
2. 行进中可低频发送增量 chunk，但不依赖实时成功。
3. 结束后发送最终完整 chunk 或完整归档文件。
4. 每个 chunk 需要 ACK。
5. 未收到 ACK 的 chunk 保持待发送。

chunk 大小建议：

1. 行进中增量：20-100 个点。
2. 结束后补传：可按 500-1000 个点分块，或压缩成文件。
3. 具体大小后续按 WatchConnectivity 真实表现调参。

### iPhone 接收处理

1. 校验 `sessionId`。
2. 校验 checksum。
3. 以 `sessionId + sequence` 去重写入轨迹点。
4. 更新已收到的 sequence 范围。
5. 回 ACK，包含已接收范围。

### Watch 删除策略

1. 收到 iPhone 完整会话 ACK 前，不删除本地轨迹。
2. 收到完整 ACK 后，可标记为 `synced`。
3. 本地数据至少保留一段时间，避免 iPhone 数据异常后无法恢复。

## 事件回传协议

事件比轨迹点少，但对复盘和问题诊断很重要。

### eventChunk 内容

| 字段 | 说明 |
| --- | --- |
| `sessionId` | 会话 ID |
| `chunkId` | chunk ID |
| `events` | SessionEvent 数组 |
| `isFinal` | 是否最后一包 |

通道：

1. 默认 `transferUserInfo`。
2. 可与轨迹 chunk 分开发送。

接收处理：

1. 以 `eventId` 去重。
2. 按 `timestamp` 排序展示。
3. 回 ACK。

## 会话结束同步

Watch 结束徒步后，必须发送完整结束包。

### 结束同步顺序

```txt
Watch 保存本地完整会话
  -> 发送 sessionSummary
  -> 发送剩余 trackChunk / trackFile
  -> 发送 eventChunk
  -> iPhone 校验完整性
  -> iPhone 回 syncAck(status=ok, action=sessionComplete)
  -> Watch 标记 synced
```

### sessionSummary 内容

1. `SessionSummary`。
2. `trackPointCount`。
3. `eventCount`。
4. `firstTrackSequence`。
5. `lastTrackSequence`。
6. `trackChecksum`。
7. `eventChecksum`。

### iPhone 完整性校验

1. 是否收到 `sessionSummary`。
2. 轨迹点 sequence 是否连续。
3. 轨迹点数量是否匹配。
4. 事件数量是否匹配。
5. checksum 是否匹配。
6. 对应路线版本是否存在。

如果缺数据，iPhone 回 `syncAck(status=missingData, action=missingRangesRequested)`，并在 `missingRanges` 中带缺失 sequence 范围。

## ACK 协议

ACK 也是 `SyncEnvelope`。

### ack payload

| 字段 | 说明 |
| --- | --- |
| `ackId` | ACK ID |
| `ackForEnvelopeId` | 被确认的 envelope |
| `entityId` | routeId 或 sessionId |
| `status` | `ok`、`alreadyReceived`、`rejected`、`checksumFailed`、`missingData` |
| `action` | ACK 对应的动作，完整枚举见下方“MVP 最小协议”和数据模型 |
| `receivedRanges` | 已接收 sequence 范围，可选 |
| `missingRanges` | 缺失 sequence 范围，可选 |
| `reason` | 失败原因，可选 |

### ACK 通道

1. 对端可达时用 `sendMessage`。
2. 同时对关键 ACK 使用 `transferUserInfo` 兜底。

## 断连恢复

### iPhone 断连

Watch 行为：

1. 继续导航和记录。
2. 所有轨迹、事件和摘要写本地。
3. 将待同步 chunk 放入队列。
4. 重新连接后继续补传。

iPhone 行为：

1. 显示最近同步时间。
2. 不把断连等同于会话结束。
3. 重新连接后请求 Watch 当前状态。

### App 重启恢复

两端启动后都执行本地扫描：

1. 查找未 ACK 的 route payload。
2. 查找未完成的 active session。
3. 查找 pending upload 的 session chunk。
4. 查找对端未确认的 ACK。
5. 尝试重新发送或请求缺失范围。

## 去重和冲突

### 路线去重

1. 同 `routeId + version + checksum` 视为同一版本。
2. 同 routeId 但 version 更高，视为更新路线。
3. Watch 正在进行该 routeId 的会话时，不自动替换当前使用中的路线。
4. 新路线可下载但默认标记为“下次使用”。
5. 如果 Watch 正在自由记录且没有绑定计划路线，新下发路线可以进入中途接入判断：先安装路线，再由 Watch 计算当前位置到路线的距离，并通过用户确认决定是否绑定当前会话。
6. 中途接入确认前，不发送表示当前会话已切换路线的 `sessionStatus`。
7. 中途接入确认后，后续 `sessionStatus` 可带新的 `routeId`、`routeVersion`、`routeProgressMeters` 和 `offRouteDistanceMeters`；确认前的历史状态不补发、不改写。
8. iPhone 下发路线、更新路线或重试同步，都不能绕过 Watch 端确认层。

### 轨迹去重

1. 同 `sessionId + sequence` 只写一次。
2. 如果同 sequence 内容不同，保留首次写入并记录冲突事件。
3. session summary 重复到达时更新同步状态，不重复创建历史记录。

### 事件去重

1. 同 `eventId` 只写一次。
2. 相同类型和时间接近的事件不自动合并，避免丢失诊断信息。

## 错误处理

| 错误 | 处理 |
| --- | --- |
| checksum 失败 | 丢弃 payload，回 `syncAck(status=checksumFailed, action=payloadChecksumFailed)` |
| route payload 安装失败 | 保留旧路线，回 `syncAck(status=rejected, action=routePayloadRejected)` |
| Watch 存储不足 | 拒绝新路线，回 `syncAck(status=rejected, action=routeManifestRejected)` 并带原因 |
| iPhone 缺路线版本 | 接收会话，但标记路线缺失，回 `syncAck(status=missingData, action=routeBackfillRequested)` |
| track chunk 缺口 | 回 `syncAck(status=missingData, action=missingRangesRequested)`，在 `missingRanges` 中带缺失 sequence 范围 |
| 重复 chunk | 回 `syncAck(status=alreadyReceived, action=trackChunkReceived)` |
| ACK 丢失 | 发送端重试，接收端幂等处理 |

## 同步状态 UI

### iPhone 路线详情

| 状态 | 文案 |
| --- | --- |
| 未同步 | 同步到 Watch |
| 同步中 | 正在同步 |
| 已就绪 | Watch 已就绪 |
| Watch 不在线 | 等待 Watch 连接 |
| 同步失败 | 同步失败，重试 |

### Watch 路线卡片

| 状态 | 文案 |
| --- | --- |
| 接收中 | 正在接收路线 |
| 已安装 | 使用此路线开始 |
| 安装失败 | 路线不可用 |
| 版本过旧 | 请从 iPhone 重新同步 |

### iPhone 复盘

| 状态 | 文案 |
| --- | --- |
| 同步中 | 正在同步轨迹 |
| 部分同步 | 轨迹同步未完成 |
| 已完成 | 轨迹已保存 |
| 同步失败 | 等待 Watch 重新连接 |

## MVP 最小协议

第一版可以先只实现这些：

1. `routeManifest`
2. `routePayload`
3. `syncAck`
4. `sessionStatus`
5. `trackChunk`
6. `eventChunk`
7. `sessionSummary`

MVP 中 `syncAck` 至少覆盖这些动作：

1. `routeAlreadyInstalled`
2. `readyForPayload`
3. `routeManifestRejected`
4. `routeInstalled`
5. `trackChunkReceived`
6. `eventChunkReceived`
7. `missingRangesRequested`
8. `routeBackfillRequested`
9. `payloadChecksumFailed`
10. `routePayloadRejected`
11. `sessionComplete`

暂缓：

1. 缺口补传的复杂 UI。
2. 多路线并发同步。
3. 多 Watch 设备。
4. 云同步。
5. iPhone 远程控制 Watch 会话。

## 待实测问题

1. WatchConnectivity 在长时间户外弱连接下的 transfer 延迟。
2. `transferFile` 对大轨迹文件的实际可靠性和时延。
3. 行进中频繁 `sendMessage` 对电量的影响。
4. Watch App 在 workout session 下的后台传输行为。
5. 不同 Apple Watch 机型的本地存储和电量压力。
