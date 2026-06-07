# watchOS 低功耗证据采集设计 v0.1

更新日期：2026-06-07

## 目标

本文设计 Apple Watch 徒步 MVP 的低功耗证据采集层，用于后续轨迹清洗、累计爬升复盘和跨平台算法对齐。

现有工程已经能把 `CLLocation` 写成 `TrackPoint`，用于 Watch 地图、会话回传和 iPhone 复盘。下一步不应把更多传感器字段直接塞进 `TrackPoint`，而应新增一条独立证据线：

```txt
Core Location / Core Motion / CMAltimeter / 采样状态
  -> watch_evidence.jsonl
  -> 离线清洗 / acceptance-web 对齐 / replay fixture
```

保留现有产品链路：

```txt
CLLocation -> TrackPoint -> 地图显示 / 会话回传 / iPhone 复盘
```

## 非目标

1. 不在 Watch 首版实时运行复杂清洗算法。
2. 不采集 `gnss_snapshot`、卫星数量、C/N0、星座或 used-in-fix。
3. 不记录高频原始 IMU 或压力样本流。
4. 不用气压计修正经纬度。
5. 不用 motion 补轨迹点。
6. 不因为证据采集破坏长时间徒步续航。

## 设计原则

1. `TrackPoint` 是产品输出点，`watch_evidence.jsonl` 是可重放原始证据。
2. 位置、采样、motion、barometer 使用独立时间线，后续算法负责对齐。
3. 传感器证据以窗口摘要落盘，不写每个原始 sample。
4. 省电模式必须写入 `sampling_policy`，让后续清洗知道采样变稀是主动策略，而不是定位异常。
5. Watch 端优先保证定位、偏航提醒、本地保存和结束同步。
6. 证据日志允许比产品轨迹更详细，但必须低频、分段、可恢复。

## 数据线总览

| 数据线 | 事件 | 当前优先级 | 功耗策略 | 用途 |
| --- | --- | --- | --- | --- |
| Session context | `session_metadata` | P0 | 会话开始写一次，结束补状态 | 设备、版本、会话分组。 |
| Sampling | `sampling_policy` | P0 | 只在 start / pause / resume / power mode change 写 | 解释采样请求、暂停、恢复和省电降频。 |
| Location | `raw_location` | P0 | 按 Core Location 自然回调写，不额外强拉高频 | 水平轨迹、GAP、速度、GNSS 海拔线。 |
| Session event | `session_event` | P0 | 状态变化和关键事件即时写 | 暂停、继续、结束、偏航、低电量。 |
| Barometer | `barometer_window` | P1 | 内存中按样本累计，5-30 秒窗口落盘 | 气压累计爬升和累计下降。 |
| Motion | `device_motion_window` | P1 | 5-30 秒窗口摘要，低电量可关闭或降频 | 静止、低速、休息、恢复解释。 |
| Upload manifest | `evidence_manifest` | P1 | 会话结束写 | iPhone 接收和校验 evidence 文件。 |

## 时间字段

watchOS 没有 Android `Location.getElapsedRealtimeNanos()`。为了和 motion / barometer 对齐，需要保存两类时间：

| 字段 | 来源 | 用途 |
| --- | --- | --- |
| `eventWallTimeMillis` | `Date()` | 给人看、排序展示。 |
| `timeMillis` | `CLLocation.timestamp` | Location fix 的墙钟时间。 |
| `receivedElapsedRealtimeNanos` | 收到回调时 `ProcessInfo.processInfo.systemUptime` | App 收到回调的单调时间。 |
| `estimatedFixElapsedRealtimeNanos` | 由 `CLLocation.timestamp` 和会话开始映射 | 估算 fix 的单调时间，用于离线对齐。 |
| `eventElapsedRealtimeNanos` | 写事件时的单调时间 | JSONL 事件顺序和传感器窗口对齐。 |

推荐会话开始时记录：

```txt
sessionWallStart = Date()
sessionUptimeStartSeconds = ProcessInfo.processInfo.systemUptime
```

估算 Location fix 单调时间：

```txt
estimatedFixElapsedRealtimeNanos =
  (sessionUptimeStartSeconds + location.timestamp.timeIntervalSince(sessionWallStart))
  * 1_000_000_000
```

后续清洗默认使用 `estimatedFixElapsedRealtimeNanos` 作为 Location 连续性时间；如果发现映射异常，可退回 `timeMillis` 做人工复盘。

## `session_metadata`

会话开始时写一次，结束时可补 `completionState` 或通过单独事件记录结束。

```json
{
  "event": "session_metadata",
  "sessionId": "session-uuid",
  "eventSeq": 1,
  "eventWallTimeMillis": 1760000000000,
  "eventElapsedRealtimeNanos": 123000000000,
  "createdWallTimeMillis": 1760000000000,
  "createdElapsedRealtimeNanos": 123000000000,
  "strategyVersion": "watchos-evidence-v0.1",
  "appVersion": "0.1",
  "platform": "watchOS",
  "deviceModel": "Apple Watch",
  "routeId": "route-uuid",
  "routeVersion": 1,
  "sessionMode": "plannedRoute"
}
```

隐私边界：

1. 不写硬件序列号、Apple ID、广告 ID、手机号或可唯一识别用户的系统标识。
2. `watchDeviceId` 如果需要用于多设备验收，应使用 App 内生成的匿名 ID，并允许重置。

## `sampling_policy`

`sampling_policy` 是请求侧证据。它不是从定位点推出来的，而是在 App 开始、暂停、继续、结束、低电量模式切换或重新配置定位采样时写入。

```json
{
  "event": "sampling_policy",
  "sessionId": "session-uuid",
  "eventSeq": 2,
  "eventWallTimeMillis": 1760000000000,
  "eventElapsedRealtimeNanos": 123000000000,
  "samplingEpochId": 1,
  "state": "MOVING_STANDARD",
  "locationProvider": "core_location",
  "desiredAccuracy": "best",
  "distanceFilterMeters": 5,
  "allowsBackgroundLocationUpdates": true,
  "barometerWindowSeconds": 10,
  "motionWindowSeconds": 10,
  "powerMode": "standard"
}
```

建议状态：

| 状态 | 含义 |
| --- | --- |
| `MOVING_STANDARD` | 标准记录。 |
| `MOVING_POWER_SAVE` | 用户主动省电或电量进入节能模式。 |
| `MOVING_LOW_POWER` | 低电量模式。 |
| `MOVING_CRITICAL_POWER` | 极低电量模式。 |
| `PAUSED` | 用户暂停，定位可停止或极低频 keepalive。 |
| `RECOVERY` | App 恢复、定位重启或会话恢复后的短暂恢复期。 |
| `FINISHED` | 会话结束，不再追加正常定位证据。 |

## `raw_location`

每个有效 `CLLocation` 回调写一条 `raw_location`。现有 `TrackPoint` 仍照常生成，但 raw evidence 要保留更接近系统回调的字段。

```json
{
  "event": "raw_location",
  "sessionId": "session-uuid",
  "eventSeq": 12,
  "eventWallTimeMillis": 1760000005000,
  "eventElapsedRealtimeNanos": 128000000000,
  "rawPointId": 7,
  "provider": "core_location",
  "lat": 29.123456,
  "lng": 106.123456,
  "accuracy": 8.5,
  "altitude": 520.3,
  "verticalAccuracy": 12.0,
  "speed": 1.2,
  "bearing": 35.0,
  "timeMillis": 1760000004980,
  "estimatedFixElapsedRealtimeNanos": 127980000000,
  "receivedElapsedRealtimeNanos": 128000000000,
  "callbackDelayNanos": 20000000,
  "samplingEpochId": 1,
  "samplingState": "MOVING_STANDARD",
  "desiredAccuracy": "best",
  "distanceFilterMeters": 5,
  "isPaused": false
}
```

字段说明：

| 字段 | 说明 |
| --- | --- |
| `accuracy` | `CLLocation.horizontalAccuracy`，负数视为无效位置，不写入或标记 invalid。 |
| `altitude` | `CLLocation.altitude`，属于 GNSS altitude line。 |
| `verticalAccuracy` | `CLLocation.verticalAccuracy`，用于判断 GNSS 海拔是否可用。 |
| `speed` | `CLLocation.speed`，负数写 null。 |
| `bearing` | `CLLocation.course`，负数写 null。 |
| `samplingEpochId` | 当前采样 epoch，来自请求侧状态。 |
| `callbackDelayNanos` | `receivedElapsedRealtimeNanos - estimatedFixElapsedRealtimeNanos`，只作诊断。 |

## `device_motion_window`

`device_motion_window` 是活动门控证据，用于后续判断静止漂移、低速真实移动、休息小移动和 GAP 恢复。它不生成经纬度。

不要写高频原始 motion sample；只写窗口摘要。

```json
{
  "event": "device_motion_window",
  "sessionId": "session-uuid",
  "eventSeq": 30,
  "eventWallTimeMillis": 1760000010000,
  "eventElapsedRealtimeNanos": 133000000000,
  "deviceMotionWindowId": 3,
  "startElapsedRealtimeNanos": 128000000000,
  "endElapsedRealtimeNanos": 133000000000,
  "accelerometerDynamicRmsMps2": 0.18,
  "accelerometerDynamicMaxMps2": 0.72,
  "gyroscopeRmsRadps": 0.04,
  "gyroscopeMaxRadps": 0.21,
  "stepCounterDelta": 7,
  "sampleCount": 120,
  "powerMode": "standard"
}
```

采样建议：

| 模式 | 窗口 | 备注 |
| --- | --- | --- |
| 标准 | 5-10 秒 | 支撑清洗，避免高频落盘。 |
| 节能 | 10-15 秒 | 保留活动趋势。 |
| 低电量 | 15-30 秒或关闭 | 优先定位和本地保存。 |
| 极低电量 | 关闭 | 不影响核心轨迹记录。 |
| 暂停 | 关闭或 30 秒 | 若需要识别暂停漂移，可低频保留。 |

实现上可用 `CMMotionManager` 或可用性更高的低频 motion/step 证据。具体传感器可用性需要真机验证。

## `barometer_window`

`barometer_window` 用于气压累计爬升和累计下降。它不修正经纬度，也不替代 `Location.altitude`。

关键设计点：

1. 5-10 秒是落盘窗口，不是计算粒度。
2. `CMAltimeter` 的相对高度回调到达时，应先在内存中按样本累计窗口内上升和下降。
3. 每个窗口落盘时写入 `windowAscentMeters` 和 `windowDescentMeters`。
4. 会话总累计爬升等于所有有效窗口 `windowAscentMeters` 之和；会话总累计下降等于所有有效窗口 `windowDescentMeters` 之和。
5. 不能只用窗口首尾差计算累计爬升 / 下降，否则窗口内先升后降会被抵消。

```json
{
  "event": "barometer_window",
  "sessionId": "session-uuid",
  "eventSeq": 31,
  "eventWallTimeMillis": 1760000010000,
  "eventElapsedRealtimeNanos": 133000000000,
  "barometerWindowId": 3,
  "startElapsedRealtimeNanos": 128000000000,
  "endElapsedRealtimeNanos": 133000000000,
  "sampleCount": 5,
  "startRelativeAltitudeMeters": 0.2,
  "endRelativeAltitudeMeters": 1.6,
  "minRelativeAltitudeMeters": 0.2,
  "maxRelativeAltitudeMeters": 1.6,
  "avgRelativeAltitudeMeters": 0.9,
  "deltaRelativeAltitudeMeters": 1.4,
  "windowAscentMeters": 1.4,
  "windowDescentMeters": 0.0,
  "sessionBarometerAscentMeters": 18.6,
  "sessionBarometerDescentMeters": 7.4,
  "startPressureKpa": 95.44,
  "endPressureKpa": 95.42,
  "minPressureKpa": 95.42,
  "maxPressureKpa": 95.44,
  "avgPressureKpa": 95.43,
  "powerMode": "standard"
}
```

注意：

1. `CMAltimeter` 提供相对高度和压力，字段名应保留 `relativeAltitude` 语义。
2. 与 Android `barometer_window` 的 `rawAltitudeMeters` 不完全同源，后续转换到 acceptance-web 时需要单独适配。
3. 绝对高度展示可用 GNSS 做校准，但校准不能重写历史累计爬升。
4. `windowAscentMeters` / `windowDescentMeters` 是窗口内按有效相邻样本累计的结果，不等同于 `endRelativeAltitudeMeters - startRelativeAltitudeMeters`。
5. `sessionBarometerAscentMeters` / `sessionBarometerDescentMeters` 是写该窗口时的会话累计值，方便崩溃恢复和人工复盘；最终结果仍可由窗口求和复算。

### 窗口内累计规则

只从真实垂直变化捕捉角度看，窗口化落盘可以省电省存储，但累计爬升 / 下降应按窗口内样本计算。

推荐内存状态：

```txt
previousAcceptedRelativeAltitudeMeters
currentWindowAscentMeters
currentWindowDescentMeters
sessionBarometerAscentMeters
sessionBarometerDescentMeters
```

每个 `CMAltimeter` 样本到达时：

```txt
delta = sample.relativeAltitudeMeters - previousAcceptedRelativeAltitudeMeters

if delta >= minAltitudeStepMeters:
  currentWindowAscentMeters += delta
  sessionBarometerAscentMeters += delta
  previousAcceptedRelativeAltitudeMeters = sample.relativeAltitudeMeters

else if delta <= -minAltitudeStepMeters:
  currentWindowDescentMeters += abs(delta)
  sessionBarometerDescentMeters += abs(delta)
  previousAcceptedRelativeAltitudeMeters = sample.relativeAltitudeMeters

else:
  保留样本用于 avg/min/max，不累计 ascent/descent
```

默认建议：

| 参数 | 建议值 | 说明 |
| --- | --- | --- |
| `minAltitudeStepMeters` | 0.5-1.0m | 过滤气压计微小抖动，真实阈值需真机样本校准。 |
| `maxBarometerSampleGapSeconds` | 30s | 超过后不跨 gap 累计，重置 previous accepted altitude。 |
| `maxVerticalSpeedMetersPerSecond` | 2m/s | 过滤不合理尖刺；该阈值只表示垂直变化物理异常，不判断运动方式。 |

示例：

```txt
窗口内相对高度:
0s: 100m
3s: 105m
6s: 100m

只看窗口首尾:
delta = 0m

按样本累计:
windowAscentMeters = 5m
windowDescentMeters = 5m
```

因此 `barometer_window` 必须保存窗口内累计值，而不是只保存 `deltaRelativeAltitudeMeters`。

### 窗口字段要求

为了支撑准确累计爬升 / 下降，每个窗口至少保留：

| 字段 | 是否必需 | 用途 |
| --- | --- | --- |
| `startRelativeAltitudeMeters` | 是 | 复盘窗口起点。 |
| `endRelativeAltitudeMeters` | 是 | 复盘窗口终点和跨窗口连续性。 |
| `minRelativeAltitudeMeters` | 是 | 检查窗口内低点和异常波动。 |
| `maxRelativeAltitudeMeters` | 是 | 检查窗口内高点和异常波动。 |
| `avgRelativeAltitudeMeters` | 建议 | 平滑趋势展示。 |
| `deltaRelativeAltitudeMeters` | 建议 | 快速查看窗口首尾变化。 |
| `windowAscentMeters` | 是 | 窗口内累计上升。 |
| `windowDescentMeters` | 是 | 窗口内累计下降。 |
| `sampleCount` | 是 | 判断窗口可信度。 |
| `startPressureKpa` / `endPressureKpa` | 建议 | 复盘压力变化方向。 |
| `minPressureKpa` / `maxPressureKpa` / `avgPressureKpa` | 建议 | 诊断压力异常。 |

采样建议：

| 模式 | 窗口 |
| --- | --- |
| 标准 | 5-10 秒 |
| 节能 | 10-15 秒 |
| 低电量 | 15-30 秒 |
| 极低电量 | 30-60 秒或关闭 |
| 暂停 | 关闭或低频保留 |

## 功耗模式与采样配置

证据采集应跟随 `低电量与长时间徒步策略 v0.1` 的运行模式。

| 模式 | Location | Barometer | Motion | Live snapshot | 地图刷新 |
| --- | --- | --- | --- | --- | --- |
| 标准 | `distanceFilter=5m` | 5-10s | 5-10s | 5s 或 5 点 | 正常 |
| 节能 | `distanceFilter=10m` | 10-15s | 10-15s | 15-30s | 降频 |
| 低电量 | `distanceFilter=20m`，偏航时临时提高 | 15-30s | 15-30s 或关闭 | 状态变化 | 抬腕 / 状态变化 |
| 极低电量 | `distanceFilter=50m` 或系统可接受最低频 | 30-60s 或关闭 | 关闭 | 停止实时 | 线框优先 |
| 暂停 | 停止或 60-120s keepalive | 关闭 | 关闭或 30s | 状态变化 | 暂停态 |

MVP 可以先实现标准和暂停两类，后续再接入电量阈值自动切换。

## 文件与同步

Watch 本地目录建议：

```txt
WatchSessions/
  session-id.json
  session-id.evidence.jsonl
```

会话结束后上传：

1. 现有 `sessionStatus`、`trackChunk`、`eventChunk`、`sessionSummary` 保持不变。
2. 新增 `evidenceManifest`，描述 evidence 文件大小、checksum、事件数和版本。
3. 新增 evidence 文件传输或 evidence chunk 传输。
4. iPhone 收到后保存到 `ReceivedSessions/session-id.evidence.jsonl`。
5. 如果 evidence 上传失败，不阻断现有 session 完成态，但复盘页标记“缺少清洗证据”。

## 与现有模型关系

| 现有模型 | 是否保留 | 调整 |
| --- | --- | --- |
| `TrackPoint` | 保留 | 继续服务 UI、回传和复盘，不塞入 motion/barometer 窗口。 |
| `SessionEvent` | 保留 | 同步写入 `session_event` evidence，便于离线对齐。 |
| `SessionSummary` | 保留 | 仍是 Watch 端即时摘要；后续可追加 Web/离线清洗摘要。 |
| `LiveTrackSnapshot` | 保留 | 仍是实时预览，不替代完整 evidence。 |

## 实施切片

### Slice A：Location evidence 最小闭环

1. 新增 `EvidenceLogger` actor，支持 JSONL 追加写、事件序号、flush 和关闭。
2. 会话开始写 `session_metadata`。
3. `WatchLocationSampler.start()` 写 `sampling_policy`。
4. 每个 `CLLocation` 写 `raw_location`。
5. pause / resume / finish 写 `session_event` 和新的 `sampling_policy`。
6. evidence 文件随会话保存在 Watch 本地。

验收：

1. Watch 模拟器或真机运行一次自由记录。
2. 本地会话目录出现 `.evidence.jsonl`。
3. 每个 `TrackPoint.sequence` 附近能找到对应 `raw_location.rawPointId`。

### Slice B：气压计窗口

1. 接入 `CMAltimeter.isRelativeAltitudeAvailable()` 可用性判断。
2. 会话 active 时启动相对高度更新。
3. 按功耗模式聚合 `barometer_window`。
4. 暂停、结束、极低电量时降频或停止。

验收：

1. 有气压计设备上生成 `barometer_window`。
2. 无气压计或模拟器不可用时写诊断事件，不影响轨迹记录。

### Slice C：Motion 窗口

1. 接入低频 `device_motion_window` 摘要。
2. 只记录 RMS / max / step delta 等统计，不落原始高频流。
3. 按功耗模式降频。

验收：

1. 静止、步行、暂停三类片段的窗口统计能被人工区分。
2. 长时间运行无明显写盘膨胀。

### Slice D：iPhone 回传和转换

当前已完成：

1. 上传 `evidenceManifest` 和 `evidenceChunk` envelope。
2. Watch 上传计划会读取本地 `session-id.evidence.jsonl` 并随会话回传。
3. iPhone 收齐 evidence chunk 后保存到 `ReceivedSessions/session-id.evidence.jsonl`。
4. evidence 上传失败不阻断现有 session 完成态。
5. 提供 `watch-hiking-app/Tools/watch-evidence-to-acceptance.mjs`，把 watch evidence 字段归一化为 `acceptance-web` 可读取的 JSONL alias。

后续待做：

1. iPhone 复盘详情展示 evidence 完整性以外的导出入口。
2. 用真实 Apple Watch evidence 回归 `acceptance-web` 六层清洗结果。

验收：

1. iPhone `ReceivedSessions` 同时包含 session JSON 和 evidence JSONL。
2. 转换后的 JSONL 可被 `acceptance-web` 离线工具读取。

## 真机验证清单

| 项目 | 状态 |
| --- | --- |
| Core Location 后台长时间稳定性 | 需要 Apple Watch 真机验证 |
| HKWorkoutSession 与 evidence 写盘并行稳定性 | 需要 Apple Watch 真机验证 |
| CMAltimeter 相对高度窗口可用性 | 需要 Apple Watch 真机验证 |
| Core Motion 窗口功耗 | 需要 Apple Watch 真机验证 |
| 低电量模式自动切换 | 后续实现后验证 |
| evidence 文件传输断连 / 重连表现 | 需要 iPhone + Apple Watch 真机验证 |
