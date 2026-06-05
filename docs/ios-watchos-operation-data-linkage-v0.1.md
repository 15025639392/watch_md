# iOS / watchOS 操作与数据联动规格 v0.1

更新日期：2026-06-06

## 文档目标

本文补充 iPhone 与 Apple Watch 在 MVP 中的操作分工、页面动作、数据归属和同步触发关系。它不替代数据模型、同步协议或会话流程，而是作为开发和验收时的联动查表。

核心原则：

1. iPhone 负责路线准备、路线下发、同步状态解释和结束后复盘。
2. Apple Watch 负责开始、暂停、继续、结束、行进导航、轨迹采集和本地兜底保存。
3. iPhone 不远程开始或远程结束 Watch 徒步，避免把手机做成行进主控。
4. Watch 与 iPhone 断连时，Watch 仍能独立完成会话并在重连后补传。
5. 所有跨端数据以 `SyncEnvelope` 包装，接收端按幂等规则去重。

## 端上职责矩阵

| 功能 | iPhone | Apple Watch | 数据主写入端 |
| --- | --- | --- | --- |
| 远端路线列表 | 拉取摘要、搜索、展示 | 不做列表发现 | iPhone |
| GPX 导入 | 文件导入、分享入口、解析校验 | 不导入 GPX | iPhone |
| 路线详情 | 完整地图预览、统计、关键点 | 路线卡片、起点方向、就绪状态 | iPhone |
| 路线同步 | 发送 manifest / payload、展示进度 | 接收、校验、原子安装 | iPhone 生成，Watch 安装 |
| 开始徒步 | 只提示去 Watch 开始 | 主入口，创建会话 | Watch |
| 行进导航 | 显示低频辅助状态 | 地图、路线跟随、偏航提醒 | Watch |
| 暂停/继续 | 只展示状态 | 主操作入口 | Watch |
| 结束徒步 | 不远程结束 | 二次确认结束 | Watch |
| 轨迹回传 | 接收、去重、完整性校验、ACK | 分块上传、等待 ACK、保留本地 | Watch 生成，iPhone 汇总 |
| 复盘 | 地图叠加、摘要、事件、导出 | 显示结束摘要和同步状态 | iPhone |

## 操作链路总览

```txt
iPhone 路线列表 / GPX 导入
  -> iPhone 路线详情
  -> 用户点击同步到 Watch
  -> routeManifest / routePayload
  -> Watch 安装路线
  -> Watch 路线卡片显示已就绪
  -> 用户在 Watch 点击开始
  -> Watch 创建 HikingSession
  -> Watch 采集 TrackPoint / SessionEvent
  -> sessionStatus 低频同步到 iPhone
  -> 用户在 Watch 暂停 / 继续 / 结束
  -> trackChunk / eventChunk / sessionSummary 回传
  -> iPhone 校验完整性并回 syncAck
  -> iPhone 复盘页展示完整或部分同步结果
```

自由记录兜底：

```txt
Watch 无可用计划路线
  -> 用户在 Watch 点击自由记录开始
  -> Watch 创建无计划路线会话
  -> Watch 只采集实际轨迹和运动数据
  -> 不生成路线进度、偏航事件和转向提醒
  -> 结束后按普通 session 回传
  -> iPhone 按自由记录复盘
```

## iPhone 操作规格

### 1. 路线列表

用户操作：

1. 打开 App 进入路线列表。
2. 刷新远端路线摘要。
3. 搜索已知路线名称、编号、短码或区域。
4. 从文件选择器或系统分享导入 GPX。
5. 点击路线进入详情。

系统动作：

| 操作 | 读取数据 | 写入数据 | 同步触发 |
| --- | --- | --- | --- |
| 打开列表 | `RemoteRouteSummary`、本地 `HikingRoute` | 本地列表缓存 | 无 |
| 刷新远端摘要 | 服务端路线摘要 | `RemoteRouteSummary.localStatus` | 无 |
| 导入 GPX | GPX 文件 | `HikingRoute`、`RouteVariant(original)`、`RouteVariant(simplifiedForWatch)`、`Waypoint`、`TurnPoint` | 无 |
| 点击详情 | 本地路线与变体 | 最近访问状态 | 无 |

UI 状态：

| 状态 | 表现 | 用户可做 |
| --- | --- | --- |
| 未下载 | 显示路线摘要和下载入口 | 下载详情 |
| 已下载 | 显示可查看详情 | 进入详情 |
| 有更新 | 显示远端版本更新 | 用户确认后更新 |
| 已同步 | 显示 Watch 已就绪 | 查看详情或重新同步 |
| 导入失败 | 显示失败原因 | 重新选择文件 |

### 2. 路线详情

用户操作：

1. 查看完整路线地图、距离、爬升、起终点和关键点。
2. 查看 Watch 连接、电量、同步状态和权限提示。
3. 点击“同步到 Watch”或“重试同步”。

系统动作：

| 操作 | 读取数据 | 写入数据 | 同步触发 |
| --- | --- | --- | --- |
| 进入详情 | `HikingRoute`、`RouteVariant`、`Waypoint`、`TurnPoint` | 无 | 无 |
| 点击同步 | 路线、简化路线、提醒配置 | `RouteSyncState` | `routeManifest` |
| Watch ready | manifest ACK | `RouteSyncState=readyForPayload` | `routePayload` |
| Watch installed | payload ACK | `RouteSyncState=installed`、路线本地状态 | 无 |
| 同步失败 | ACK 或传输错误 | `RouteSyncState=failed`、失败原因 | 可重试 |

限制：

1. iPhone 路线详情不提供“开始徒步”。
2. Watch 不在线时允许排队同步，但不能显示“Watch 已就绪”。
3. 新路线安装成功前，Watch 必须保留上一条可用路线。

### 3. 行进中状态页

用户操作：

1. 查看 Watch 是否仍在记录。
2. 查看最近同步时间、Watch 电量、距离、偏航状态。
3. 在必要时查看操作提示。

系统动作：

| 数据来源 | iPhone 展示 | 写入规则 |
| --- | --- | --- |
| `sessionStatus` | active / paused / finished、距离、轨迹点数、事件数、同步状态 | 后发覆盖前发 |
| `updateApplicationContext` | 最新会话概览 | 只保存最新，不作为历史事实 |
| `trackChunk` / `eventChunk` | 可选显示已接收进度 | 幂等追加 |

限制：

1. 行进中 iPhone 不作为主导航地图。
2. iPhone 不提供远程暂停、继续或结束。
3. 低频状态丢失不影响会话完整性，后续状态会覆盖。

### 4. 复盘页

用户操作：

1. 查看计划路线与实际轨迹叠加。
2. 查看距离、时长、爬升、速度、心率、能量和偏航事件。
3. 查看同步是否完整。
4. 导出 GPX。

系统动作：

| 接收对象 | iPhone 写入 | 完整性规则 |
| --- | --- | --- |
| `sessionStatus` | 会话概览 | 可缺，不阻断复盘 |
| `trackChunk` | `TrackPoint` | 按 `sessionId + sequence` 去重，检查连续性 |
| `eventChunk` | `SessionEvent` | 按 `eventId` 去重 |
| `sessionSummary` | `SessionSummary` | 与轨迹和事件共同判断完整 |
| `syncAck` | 返回给 Watch | 完整时回 `sessionComplete`，缺失时回 `missingRangesRequested` |

复盘状态：

| 状态 | 条件 | 页面表现 |
| --- | --- | --- |
| 同步中 | 已收到部分数据但未完整 | 显示已收到轨迹，提示等待 Watch |
| 部分同步 | 缺 track 或 event 范围 | 标记数据不完整 |
| 完整同步 | 摘要、最终轨迹和最终事件都已收齐 | 正常复盘 |
| 自由记录 | 会话无真实计划路线 | 只显示实际轨迹，不显示偏航和路线进度 |
| 健康数据缺失 | 无 HealthKit 运动引用或指标为空 | 地图和轨迹仍可用 |

## Watch 操作规格

### 1. 路线就绪页

用户操作：

1. 查看最近安装路线。
2. 确认路线名称、距离、同步时间、电量和定位状态。
3. 点击“开始徒步”。
4. 没有路线时点击“自由记录”。

系统动作：

| 操作 | 读取数据 | 写入数据 | 同步触发 |
| --- | --- | --- | --- |
| 打开 Watch App | 已安装 `RoutePayload` | 最近可用路线状态 | 无 |
| 收到 manifest | `routeManifest` | 待接收路线状态 | `syncAck(readyForPayload/alreadyReceived/rejected)` |
| 收到 payload | `routePayload` | 原子安装路线、更新同步时间 | `syncAck(routeInstalled/routePayloadRejected)` |
| 点击开始 | 已安装路线、权限、电量 | `HikingSession(status=active)` | `sessionStatus` |

### 2. 地图页

用户操作：

1. 抬腕查看当前位置、方向、计划路线和已走轨迹。
2. 横滑或点击进入数据页、控制页。
3. 偏航时按提示回到路线。

系统动作：

| 输入 | 处理 | 输出 |
| --- | --- | --- |
| Core Location 点 | 生成 `TrackPoint`，追加本地会话 | 地图当前位置、已走轨迹 |
| 已安装路线 | 线段投影、路线进度计算 | 剩余距离、最近路线距离 |
| 定位精度 | 判断可信度 | `locationAccuracyPoor` / `locationRecovered` |
| 偏航状态机 | 连续可信点确认 | `offRouteStarted` / `offRouteUpdated` / `offRouteEnded` |
| HKWorkout 数据 | 心率、能量、运动距离 | 数据页和摘要可用指标 |

保存原则：

1. 每个正式定位点先写入 Watch 本地，再考虑同步。
2. 暂停期间不写正式轨迹点。
3. 自由记录模式不计算路线进度和偏航。
4. 会话进行中可以低频发送 `sessionStatus`，但不能依赖实时成功。

### 3. 控制页

用户操作：

1. 暂停。
2. 继续。
3. 标记点。
4. 结束。

MVP 操作规则：

| 操作 | 状态前置 | Watch 写入 | iPhone 联动 |
| --- | --- | --- | --- |
| 暂停 | `active` | `HikingSession.status=paused`、`SessionEvent(pause)` | 立即发送 `sessionStatus` |
| 继续 | `paused` | `HikingSession.status=active`、`SessionEvent(resume)` | 立即发送 `sessionStatus` |
| 标记点 | `active` 或 `paused` | `SessionEvent(manualMarker)` | 随 event chunk 回传 |
| 结束 | `active` 或 `paused`，二次确认 | `HikingSession.status=finished`、`SessionSummary` | 生成上传计划 |

说明：

1. 当前 MVP 可以先保留标记点事件，不做完整编辑和冲突解决。
2. 结束必须二次确认，避免误触导致会话中断。
3. 结束后 Watch 先显示本地摘要，再进入同步状态。

### 4. 结束同步页

用户操作：

1. 查看距离、用时、轨迹点数和同步状态。
2. iPhone 不在线时离开页面也不丢数据。
3. 需要时手动重试同步。

系统动作：

| 步骤 | Watch 行为 | iPhone 行为 |
| --- | --- | --- |
| 生成上传计划 | 创建 `sessionStatus`、`trackChunk`、`eventChunk`、`sessionSummary` | 无 |
| 发送 chunk | 通过可靠队列排队 | 接收、校验、去重 |
| 收到 ACK | 清理对应 pending envelope | 记录接收状态 |
| 收到缺失请求 | 保留并重发缺失范围 | 回 `missingRangesRequested` |
| 收到完整 ACK | 标记会话已同步 | 回 `sessionComplete` |

本地保留：

1. 收到完整 ACK 前，Watch 不删除会话、轨迹、事件或摘要。
2. 收到完整 ACK 后，只标记为已同步，不立即物理删除。
3. App 重启后必须能恢复未上传会话队列。

## 数据归属与写入边界

| 数据对象 | 创建端 | 可修改端 | 同步方向 | 说明 |
| --- | --- | --- | --- | --- |
| `RemoteRouteSummary` | 服务端 / iPhone 缓存 | iPhone | 不下发 Watch | 只用于列表和下载状态 |
| `HikingRoute` | iPhone | iPhone | iPhone -> Watch | Watch 只安装和读取 |
| `RouteVariant(original)` | iPhone | iPhone | 默认不同步 | iPhone 复盘和导出用 |
| `RouteVariant(simplifiedForWatch)` | iPhone | iPhone | iPhone -> Watch | Watch 地图和偏航用 |
| `Waypoint` | iPhone | iPhone，Watch 标记点另记事件 | iPhone -> Watch | Watch 不在 MVP 中编辑路线 waypoint |
| `TurnPoint` | iPhone | iPhone | iPhone -> Watch | Watch 只读并提醒 |
| `AlertConfiguration` | iPhone 默认配置 | iPhone | iPhone -> Watch | Watch 运行时读取 |
| `HikingSession` | Watch | Watch | Watch -> iPhone | iPhone 不直接改状态 |
| `TrackPoint` | Watch | Watch | Watch -> iPhone | iPhone 去重追加，不改点序 |
| `SessionEvent` | Watch | Watch | Watch -> iPhone | iPhone 用于复盘 |
| `SessionSummary` | Watch | Watch | Watch -> iPhone | iPhone 用于复盘摘要 |
| `SyncEnvelope` | 双端 | 不修改 payload | 双向 | 只追加和 ACK |

## 跨端状态对照

### 路线同步状态

| 状态 | iPhone 触发 | Watch 触发 | 用户可见文案 |
| --- | --- | --- | --- |
| `notSynced` | 路线未下发 | 未安装路线 | 未同步 |
| `manifestSent` | 点击同步后发送 manifest | 收到同步请求 | 正在准备 |
| `readyForPayload` | 收到 Watch ACK | manifest 校验通过 | 正在传输 |
| `payloadTransferred` | payload 已发出 | 正在校验安装 | 正在安装 |
| `installed` | 收到 `routeInstalled` | 原子安装成功 | Watch 已就绪 |
| `failed` | 传输失败或 ACK 失败 | 校验失败或空间不足 | 同步失败，可重试 |

### 会话状态

| Watch 会话状态 | Watch 操作 | iPhone 展示 | 允许的数据写入 |
| --- | --- | --- | --- |
| `idle` | 等待开始 | 无进行中会话 | 无 |
| `active` | 正在徒步 | Apple Watch 正在记录 | `TrackPoint`、`SessionEvent`、`sessionStatus` |
| `paused` | 暂停 | Apple Watch 已暂停 | 暂停事件、状态；不写正式轨迹点 |
| `finished` | 已结束 | 等待同步 / 已同步 | 补传 chunk、摘要、ACK |

### 同步完整性

| iPhone 接收情况 | iPhone ACK | Watch 行为 |
| --- | --- | --- |
| 重复 envelope | `alreadyReceived` | 清理或跳过重复 pending |
| 轨迹连续且最终 chunk 已到 | `trackChunkReceived` 或等待摘要 | 继续发送其他对象 |
| 缺失轨迹 sequence | `missingData + missingRangesRequested` | 保留并补发缺失范围 |
| 摘要、最终轨迹和最终事件都完整 | `ok + sessionComplete` | 标记会话已同步 |
| checksum 失败 | `failed` 或 `rejected` | 保留本地并重试 |

## 当前工程实现对照

当前 `watch-hiking-app/` 已具备以下联动基础：

| 范围 | 当前状态 | 仍需验证或补齐 |
| --- | --- | --- |
| 路线模型 | `HikingRoute`、`RouteVariant`、`Waypoint`、`TurnPoint` 已在 `HikingCore` 实现 | 与真实服务端路线详情字段对齐 |
| GPX 导入 | iPhone 文件选择器、分享入口和本地路线库已接入 | 大 GPX 性能和 iCloud 文件真机验证 |
| 路线同步模型 | `routeManifest`、`routePayload`、`syncAck`、`RouteSyncState` 已实现 | 真实 WatchConnectivity 路线发送端和文件传输 |
| Watch 会话 | 开始、暂停、继续、结束、自由记录已接入 | 长时间后台定位和 workout 生命周期真机验证 |
| Watch 地图 | 计划路线、已走轨迹、偏航状态和触觉提醒已接入 | 真机地图性能、底图可读性和电量影响 |
| 会话回传 | session/status/chunk/summary 模型、iPhone 接收和 ACK 已接入 | Watch 真实发送队列和断连重试真机验证 |
| iPhone 复盘 | 当前已有接收计数和状态入口 | 完整复盘页面、GPX 导出和健康数据关联 |

## 验收清单

1. iPhone 能从远端摘要或 GPX 导入创建本地路线。
2. iPhone 路线详情能显示 Watch 同步状态，并且不提供开始徒步。
3. 点击同步后，Watch 能收到、校验并安装路线；失败时保留旧路线。
4. Watch 无路线时能进入自由记录，不触发偏航和转向提醒。
5. Watch 能独立开始、暂停、继续和结束会话。
6. Watch 行进中能本地保存轨迹点和事件，iPhone 断连不丢数据。
7. iPhone 能接收低频 `sessionStatus` 并显示最近状态。
8. 结束后 Watch 能分块回传轨迹、事件和摘要。
9. iPhone 能对重复、乱序和缺失 chunk 做幂等处理和缺失请求。
10. iPhone 收齐完整会话后回 `sessionComplete`，Watch 标记已同步。
11. iPhone 复盘页能区分完整同步、部分同步、自由记录和健康数据缺失。

## 不在 MVP 范围

1. iPhone 远程开始、暂停、继续或结束 Watch 徒步。
2. iPhone 行进中主导航。
3. 多 Watch 或多 iPhone 并发同步冲突处理。
4. Watch 上完整路线编辑、GPX 导入或路线社区。
5. 云端多设备历史同步。
6. 复杂 waypoint 编辑冲突解决。

## 关联文档

1. [徒步路线与会话数据模型 v0.1](./hiking-data-model-v0.1.md)
2. [WatchConnectivity 同步协议 v0.1](./watchconnectivity-sync-protocol-v0.1.md)
3. [徒步会话完整流程 v0.1](./hiking-session-flow-v0.1.md)
4. [WatchOS 徒步地图页规格 v0.1](./watchos-map-page-spec-v0.1.md)
5. [iPhone 路线详情与复盘页面规格 v0.1](./iphone-route-review-spec-v0.1.md)
