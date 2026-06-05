# 徒步路线与会话数据模型 v0.1

更新日期：2026-06-05

## 设计目标

数据模型要支撑 iPhone 准备路线、Watch 独立导航记录、结束后回传复盘。

核心原则：

1. 路线、轨迹、关键点和事件都使用 App 自有模型。
2. MapKit 只负责展示，不作为核心数据结构。
3. HealthKit 只负责运动数据关联，不保存路线语义。
4. Watch 端必须能在 iPhone 断连时独立读写会话数据。
5. 所有可同步对象都需要稳定 ID、版本和时间戳。

## 模型总览

| 模型 | 含义 | 主要创建端 | 主要使用端 |
| --- | --- | --- | --- |
| `HikingRoute` | 一条计划路线 | iPhone | iPhone / Watch |
| `RoutePoint` | 计划路线上的点 | iPhone | iPhone / Watch |
| `RouteVariant` | 原始路线或简化路线 | iPhone | iPhone / Watch |
| `Waypoint` | 用户或 GPX 提供的关键点 | iPhone | iPhone / Watch |
| `TurnPoint` | 从路线几何中生成的转向点 | iPhone | Watch |
| `HikingSession` | 一次实际徒步会话 | Watch | Watch / iPhone |
| `TrackPoint` | 实际轨迹点 | Watch | Watch / iPhone |
| `SessionEvent` | 偏航、提醒、暂停等事件 | Watch | Watch / iPhone |
| `SessionSummary` | 会话摘要 | Watch | iPhone / Watch |
| `SyncEnvelope` | 同步封包 | iPhone / Watch | iPhone / Watch |

## HikingRoute

表示一条计划路线。它可以来自 GPX 导入，也可以来自未来的路线创建器。

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `routeId` | UUID/String | 是 | 路线稳定 ID |
| `version` | Int | 是 | 路线版本，每次路线内容变化递增 |
| `name` | String | 是 | 路线名称 |
| `source` | Enum | 是 | `gpxImport`、`manual`、`shared`、`watchRemoteFetch` 等 |
| `createdAt` | Date | 是 | 创建时间 |
| `updatedAt` | Date | 是 | 更新时间 |
| `distanceMeters` | Double | 是 | 计划路线距离 |
| `ascentMeters` | Double? | 否 | 累计爬升，缺海拔时为空 |
| `descentMeters` | Double? | 否 | 累计下降 |
| `estimatedDurationSeconds` | Int? | 否 | 预计耗时 |
| `bounds` | GeoBounds | 是 | 路线包围盒 |
| `startPoint` | GeoCoordinate | 是 | 起点 |
| `endPoint` | GeoCoordinate | 是 | 终点 |
| `originalPointCount` | Int | 是 | 原始点数 |
| `simplifiedPointCount` | Int | 是 | Watch 简化路线点数 |
| `hasElevation` | Bool | 是 | 是否有海拔数据 |
| `checksum` | String | 是 | 路线内容校验 |

### 说明

1. `HikingRoute` 保存摘要和元数据，不直接塞入大量点。
2. 大量点放在 `RouteVariant` 中，方便按需同步。
3. `routeId + version` 用于判断 Watch 上路线是否过期。
4. `watchRemoteFetch` 仅表示 Watch 按用户已知路线编号、短码或精确名称远程获取指定路线，不表示路线推荐、附近路线发现或路线社区。

## RouteVariant

表示同一条路线的不同点序列。

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `variantId` | UUID/String | 是 | 变体 ID |
| `routeId` | UUID/String | 是 | 所属路线 |
| `routeVersion` | Int | 是 | 对应路线版本 |
| `kind` | Enum | 是 | `original`、`simplifiedForWatch`、`preview` |
| `points` | [RoutePoint] | 是 | 路线点序列 |
| `pointCount` | Int | 是 | 点数量 |
| `distanceMeters` | Double | 是 | 该变体计算出的距离 |
| `simplificationToleranceMeters` | Double? | 否 | 简化容差 |
| `checksum` | String | 是 | 点序列校验 |

### 变体策略

| 变体 | 用途 | 同步到 Watch |
| --- | --- | --- |
| `original` | iPhone 复盘、导出、精确统计 | 默认不同步 |
| `simplifiedForWatch` | Watch 地图绘制、偏航检测、转向判断 | 必须同步 |
| `preview` | 列表缩略图或小地图 | 可选 |

## RoutePoint

表示计划路线上的一个点。

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `index` | Int | 是 | 点在序列中的顺序 |
| `latitude` | Double | 是 | 纬度 |
| `longitude` | Double | 是 | 经度 |
| `elevationMeters` | Double? | 否 | 海拔 |
| `distanceFromStartMeters` | Double | 是 | 沿路线累计距离 |
| `timestamp` | Date? | 否 | GPX 原始时间，可为空 |

### 说明

1. Watch 偏航和剩余距离计算主要依赖 `distanceFromStartMeters`。
2. `index` 必须稳定，不能在同一变体内重复。

## Waypoint

表示路线上的关键点。它可能来自 GPX，也可能由用户手动标记。

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `waypointId` | UUID/String | 是 | 关键点 ID |
| `routeId` | UUID/String | 是 | 所属路线 |
| `name` | String | 是 | 名称 |
| `kind` | Enum | 是 | `start`、`end`、`water`、`camp`、`risk`、`viewpoint`、`custom` |
| `coordinate` | GeoCoordinate | 是 | 坐标 |
| `distanceFromStartMeters` | Double? | 否 | 投影到路线后的累计距离 |
| `note` | String? | 否 | 备注 |
| `alertEnabled` | Bool | 是 | 是否提醒 |
| `alertDistanceMeters` | Double? | 否 | 提醒距离 |

### MVP 范围

首版必须支持起点、终点。其他类型可以先在模型里保留，不一定做完整 UI。

## TurnPoint

表示从路线几何中识别出的转向点。首版它不是地图路网岔路，而是计划路线上明显方向变化的位置。

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `turnPointId` | UUID/String | 是 | 转向点 ID |
| `routeId` | UUID/String | 是 | 所属路线 |
| `routeVersion` | Int | 是 | 对应路线版本 |
| `routePointIndex` | Int | 是 | 对应简化路线点 index |
| `coordinate` | GeoCoordinate | 是 | 坐标 |
| `distanceFromStartMeters` | Double | 是 | 沿路线累计距离 |
| `turnAngleDegrees` | Double | 是 | 前后路段夹角 |
| `direction` | Enum | 是 | `left`、`right`、`sharpLeft`、`sharpRight`、`uTurn` |
| `alertDistanceMeters` | Double | 是 | 提醒距离 |

### 生成规则

1. 从路线点序列计算连续路段方向角。
2. 前后方向变化超过阈值时生成候选转向点。
3. 距离过近的候选点合并。
4. 过小的抖动和 GPS 噪声不生成提醒。

## HikingSession

表示一次实际徒步记录。MVP 中由 Watch 创建。

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `sessionId` | UUID/String | 是 | 会话 ID |
| `routeId` | UUID/String | 是 | 对应计划路线 |
| `routeVersion` | Int | 是 | 开始时使用的路线版本 |
| `watchDeviceId` | String? | 否 | Watch 设备标识或匿名设备 ID |
| `status` | Enum | 是 | `planned`、`active`、`paused`、`finished`、`abandoned` |
| `startedAt` | Date? | 否 | 开始时间 |
| `endedAt` | Date? | 否 | 结束时间 |
| `lastUpdatedAt` | Date | 是 | 最近更新时间 |
| `healthKitWorkoutId` | String? | 否 | HealthKit 运动记录引用 |
| `syncStatus` | Enum | 是 | `localOnly`、`pendingUpload`、`syncing`、`synced`、`failed` |

### 状态转换

```txt
planned -> active -> paused -> active -> finished
planned -> active -> abandoned
active -> finished
paused -> finished
```

### 原则

1. `finished` 后不再追加轨迹点，只能补同步。
2. `abandoned` 用于用户明确丢弃记录。
3. App 崩溃或 Watch 重启后，通过 `active` 或 `paused` 状态恢复。

## TrackPoint

表示实际行走轨迹点。

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `trackPointId` | UUID/String | 是 | 点 ID，也可由 sessionId + sequence 生成 |
| `sessionId` | UUID/String | 是 | 所属会话 |
| `sequence` | Int | 是 | 会话内递增序号 |
| `timestamp` | Date | 是 | 采样时间 |
| `latitude` | Double | 是 | 纬度 |
| `longitude` | Double | 是 | 经度 |
| `elevationMeters` | Double? | 否 | 海拔 |
| `horizontalAccuracyMeters` | Double? | 否 | 水平精度 |
| `verticalAccuracyMeters` | Double? | 否 | 垂直精度 |
| `speedMetersPerSecond` | Double? | 否 | 速度 |
| `courseDegrees` | Double? | 否 | 行进方向 |
| `heartRateBpm` | Double? | 否 | 可选心率快照 |
| `isPaused` | Bool | 是 | 是否暂停期间采集 |
| `nearestRouteDistanceMeters` | Double? | 否 | 到计划路线最近距离 |
| `routeProgressMeters` | Double? | 否 | 投影到计划路线后的累计进度 |

### 采样原则

1. 正常记录默认 3-5 秒采样一次。
2. 低电量时可以降低采样频率。
3. 暂停期间默认不写正式轨迹点，可保留低频定位点作为非正式点。
4. 定位精度太差的点可以标记或丢弃，不能直接触发偏航。

## SessionEvent

表示会话中发生的产品事件，用于 Watch 状态、同步和 iPhone 复盘。

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `eventId` | UUID/String | 是 | 事件 ID |
| `sessionId` | UUID/String | 是 | 所属会话 |
| `type` | Enum | 是 | 事件类型 |
| `timestamp` | Date | 是 | 发生时间 |
| `coordinate` | GeoCoordinate? | 否 | 发生位置 |
| `routeProgressMeters` | Double? | 否 | 发生时路线进度 |
| `severity` | Enum | 是 | `info`、`warning`、`critical` |
| `payload` | Dictionary | 否 | 扩展字段 |

### 事件类型

| 类型 | 说明 |
| --- | --- |
| `sessionStarted` | 会话开始 |
| `sessionPaused` | 暂停 |
| `sessionResumed` | 继续 |
| `sessionFinished` | 结束 |
| `offRouteStarted` | 进入偏航 |
| `offRouteUpdated` | 偏航距离变化 |
| `offRouteEnded` | 回到路线 |
| `turnAlertTriggered` | 转向提醒触发 |
| `waypointAlertTriggered` | 关键点提醒触发 |
| `locationAccuracyPoor` | 定位不稳 |
| `locationRecovered` | 定位恢复 |
| `lowBattery` | 低电量 |
| `appRecovered` | App 恢复会话 |
| `syncFailed` | 同步失败 |

### payload 示例

偏航事件：

```json
{
  "distanceFromRouteMeters": 38.4,
  "nearestRoutePointIndex": 124,
  "bearingToRouteDegrees": 232
}
```

转向提醒事件：

```json
{
  "turnPointId": "turn-123",
  "distanceToTurnMeters": 46.2,
  "direction": "left",
  "turnAngleDegrees": 58
}
```

## SessionSummary

表示会话结束后的摘要，用于列表和复盘入口。

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `sessionId` | UUID/String | 是 | 会话 ID |
| `routeId` | UUID/String | 是 | 对应路线 |
| `routeName` | String | 是 | 路线名称快照 |
| `startedAt` | Date | 是 | 开始时间 |
| `endedAt` | Date | 是 | 结束时间 |
| `durationSeconds` | Int | 是 | 总时长 |
| `movingDurationSeconds` | Int? | 否 | 移动时间 |
| `distanceMeters` | Double | 是 | 实际距离 |
| `ascentMeters` | Double? | 否 | 实际累计爬升 |
| `averageSpeedMetersPerSecond` | Double? | 否 | 平均速度 |
| `maxElevationMeters` | Double? | 否 | 最高海拔 |
| `minElevationMeters` | Double? | 否 | 最低海拔 |
| `averageHeartRateBpm` | Double? | 否 | 平均心率 |
| `offRouteEventCount` | Int | 是 | 偏航次数 |
| `trackPointCount` | Int | 是 | 轨迹点数 |
| `syncStatus` | Enum | 是 | 同步状态 |

## SyncEnvelope

表示 iPhone 和 Watch 之间传输的数据封包。

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `envelopeId` | UUID/String | 是 | 封包 ID |
| `schemaVersion` | Int | 是 | 数据结构版本 |
| `createdAt` | Date | 是 | 创建时间 |
| `sender` | Enum | 是 | `iphone` 或 `watch` |
| `kind` | Enum | 是 | 封包类型 |
| `payloadChecksum` | String | 是 | payload 校验 |
| `payload` | Object | 是 | 具体数据 |

### 封包类型

| 类型 | 方向 | 内容 |
| --- | --- | --- |
| `routeManifest` | iPhone -> Watch | 路线摘要、版本、校验 |
| `routePayload` | iPhone -> Watch | 简化路线、转向点、关键点 |
| `sessionStatus` | Watch -> iPhone | 进行中状态 |
| `trackChunk` | Watch -> iPhone | 增量轨迹点 |
| `eventChunk` | Watch -> iPhone | 增量事件 |
| `sessionSummary` | Watch -> iPhone | 会话摘要 |
| `syncAck` | 双向 | 同步确认 |

## 地理基础类型

### GeoCoordinate

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `latitude` | Double | 是 |
| `longitude` | Double | 是 |
| `elevationMeters` | Double? | 否 |

### GeoBounds

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `minLatitude` | Double | 是 |
| `minLongitude` | Double | 是 |
| `maxLatitude` | Double | 是 |
| `maxLongitude` | Double | 是 |

## MVP 最小必需字段

为了第一版快速落地，最低需要这些模型字段。

### 路线同步到 Watch

1. `routeId`
2. `routeVersion`
3. `name`
4. `distanceMeters`
5. `bounds`
6. `startPoint`
7. `endPoint`
8. `simplifiedForWatch.points`
9. `turnPoints`
10. `waypoints`
11. `checksum`

### Watch 记录会话

1. `sessionId`
2. `routeId`
3. `routeVersion`
4. `status`
5. `startedAt`
6. `endedAt`
7. `trackPoints`
8. `events`
9. `summary`

### iPhone 复盘

1. 计划路线点。
2. 实际轨迹点。
3. 偏航事件。
4. 暂停/继续事件。
5. 会话摘要。

## 后续待定

1. 路线简化算法和容差。
2. 轨迹点压缩策略。
3. 离线地图包索引模型。
4. 多日徒步和多段路线模型。
5. 用户手动标记点的编辑与同步冲突规则。
6. GPX/FIT/TCX 导出字段映射。
7. Watch 远程获取指定路线的来源元数据，例如 `sourceProvider`、`remoteRouteId`、`queryText`、`fetchedAt`、`remoteChecksum`。
8. Watch 远程获取指定路线时，服务端返回原始 GPX 还是已简化的 Watch route payload。
