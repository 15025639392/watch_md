# 偏航检测规则 v0.1

更新日期：2026-06-05

## 目标

偏航检测用于判断用户是否明显离开计划路线，并在 Watch 上触发地图状态、触觉提醒和复盘事件。

它要解决两个问题：

1. 用户真的走错时，要及时提醒。
2. GPS 漂移、定位弱、路线点稀疏时，不要频繁误报。

## 产品定义

偏航不是“当前位置不在路线线上”，而是：

> 在定位可信的前提下，用户连续一段时间距离计划路线超过阈值，并且没有正在被系统识别为正常路线误差。

MVP 中，偏航检测只基于计划路线几何和实时定位，不依赖 Apple Maps 路网。

## 输入数据

| 输入 | 来源 | 用途 |
| --- | --- | --- |
| `simplifiedForWatch.points` | iPhone 下发 | Watch 端地图绘制和偏航检测 |
| 当前定位点 | Core Location | 计算当前位置 |
| 水平精度 | Core Location | 判断定位是否可信 |
| 速度和方向 | Core Location | 辅助判断误报 |
| `routeProgressMeters` | 本地计算 | 判断用户沿路线进度 |
| 暂停状态 | Watch 会话 | 暂停时降低偏航提醒 |

## 核心输出

每次定位更新后，偏航模块输出 `RouteMatchResult`。

| 字段 | 说明 |
| --- | --- |
| `status` | `onRoute`、`suspectedOffRoute`、`offRoute`、`locationUnreliable`、`paused` |
| `distanceFromRouteMeters` | 当前点到计划路线的最近距离 |
| `projectedCoordinate` | 当前点投影到计划路线后的最近位置 |
| `nearestSegmentStartIndex` | 最近路段起点 index |
| `routeProgressMeters` | 投影点沿路线的累计距离 |
| `bearingToRouteDegrees` | 从当前位置回到路线的方向 |
| `confidence` | 判断可信度 |

## 几何判断

### 最近路线位置

不要只找最近路线点，要找最近路线段上的投影点。

流程：

1. 将路线点序列看作多个连续线段。
2. 对当前定位点计算到每个候选线段的最近投影点。
3. 找到距离最短的投影点。
4. 计算当前位置到投影点的距离。
5. 计算投影点在路线上的累计距离。

### 性能优化

Watch 不应每次定位更新都扫描全路线。

MVP 可以使用：

1. 先从上一次匹配的路线段附近窗口查找。
2. 窗口内找不到合理结果时，再扩大范围。
3. 用户偏航严重或刚开始时，允许全路线扫描。

建议窗口：

1. 正常行进：当前进度前后 200-500m。
2. 偏航中：当前进度前后 500-1000m。
3. 路线交叉或回头路：扩大窗口，并结合最近历史进度判断。

## 状态机

偏航状态不要由单个定位点直接触发。

```txt
onRoute
  -> suspectedOffRoute
  -> offRoute
  -> onRoute

any
  -> locationUnreliable
  -> previous reliable state

any
  -> paused
  -> previous active state
```

### onRoute

含义：

用户被认为仍在计划路线附近。

进入条件：

1. `distanceFromRouteMeters <= returnThresholdMeters`。
2. 或用户刚开始会话且距离起点在允许范围内。

Watch 表现：

1. 顶部显示“路线上”。
2. 不显示偏航连接线。

### suspectedOffRoute

含义：

用户可能偏离路线，但还没有确认。

进入条件：

1. `distanceFromRouteMeters > offRouteThresholdMeters`。
2. 定位精度可信。
3. 连续点数不足以确认偏航。

Watch 表现：

1. MVP 可以不显示，或只弱提示。
2. 不震动。
3. 继续收集后续定位点。

### offRoute

含义：

用户被确认偏航。

进入条件：

1. 连续 N 个可信定位点超过偏航阈值。
2. 或持续超过偏航阈值达到最短时间。
3. 当前未暂停。

Watch 表现：

1. 顶部显示“偏离 Xm”。
2. 显示当前位置到投影点的警示色连接线。
3. 底部显示“向某方向回到路线”。
4. 首次进入时触觉提醒。

### locationUnreliable

含义：

定位精度不足，不能可靠判断是否偏航。

进入条件：

1. 水平精度大于定位弱阈值。
2. 或定位更新时间过久。
3. 或定位点突然大幅跳跃且与速度不匹配。

Watch 表现：

1. 顶部显示“定位不稳”。
2. 显示定位精度圈。
3. 暂停新的偏航提醒。

### paused

含义：

用户主动暂停记录。

行为：

1. 不触发新的偏航提醒。
2. 可以继续计算当前位置与路线关系。
3. 不把暂停期间的位置变化写入正式偏航事件。

## 默认阈值

这些值用于 MVP，必须通过实地测试调参。

| 阈值 | 默认值 | 说明 |
| --- | --- | --- |
| `offRouteThresholdMeters` | 30m | 超过后进入疑似偏航 |
| `returnThresholdMeters` | 20m | 回到路线阈值，避免状态抖动 |
| `locationWeakAccuracyMeters` | 50m | 大于此值时定位不可信 |
| `confirmPointCount` | 3 | 连续 3 个可信点才确认偏航 |
| `confirmDurationSeconds` | 10-15s | 或持续超过阈值一定时间 |
| `repeatAlertIntervalSeconds` | 120s | 持续偏航的重复提醒间隔 |
| `repeatAlertDistanceDeltaMeters` | 50m | 偏航距离继续扩大多少才再次提醒 |
| `startToleranceMeters` | 80m | 起点附近允许误差 |
| `finishToleranceMeters` | 80m | 终点附近允许误差 |

## 定位可信度

偏航判断要先判断定位点是否可信。

### 不可信定位

以下情况不直接触发偏航：

1. 水平精度大于 `locationWeakAccuracyMeters`。
2. 定位时间戳太旧。
3. 相邻点距离变化和速度明显不匹配。
4. 点位突然跳出很远，但下一点又回到路线附近。

### 可信度分级

| 级别 | 条件 | 偏航处理 |
| --- | --- | --- |
| 高 | 精度小于 20m，速度/方向连续 | 可正常判断 |
| 中 | 精度 20-50m，点位基本连续 | 可进入疑似，确认后偏航 |
| 低 | 精度大于 50m 或点位跳跃 | 不触发偏航，只提示定位不稳 |

## 误报控制

### 连续确认

单个点超过阈值不报警，必须连续确认。

规则：

1. 连续 3 个可信定位点超过 30m。
2. 或超过阈值持续 10-15 秒。
3. 两者满足其一即可进入 `offRoute`。

### 滞回阈值

进入和退出偏航使用不同阈值：

1. 超过 30m 才可能进入偏航。
2. 回到 20m 内才退出偏航。

这样可以避免用户在边界附近来回跳。

### 提醒限频

偏航后不要一直震。

规则：

1. 首次进入 `offRoute` 立即提醒。
2. 仍在偏航时，至少间隔 120 秒才允许重复提醒。
3. 如果偏航距离比上次提醒时增加超过 50m，可提前提醒。
4. 回到路线后轻震一次。

### 起点和终点宽容

起点和终点附近不应过早报偏航。

规则：

1. 会话刚开始且路线进度小于 100m 时，使用 `startToleranceMeters`。
2. 接近终点时，使用 `finishToleranceMeters`。
3. 到达终点后不自动结束，也不强制偏航提醒。

## 路线特殊情况

### 回头路和路线交叉

问题：

同一位置附近可能对应路线上的多个进度点。

处理：

1. 优先选择接近上一次 `routeProgressMeters` 的投影点。
2. 如果用户明显反向行走，允许进度倒退。
3. 在路线交叉附近扩大候选窗口。
4. 不要只按空间距离选择投影点。

### 路线点太稀疏

问题：

GPX 点太少时，直线段可能穿过实际弯路，造成误判。

处理：

1. 导入时检测点间距。
2. 点间距过大时提示路线精度较低。
3. Watch 端可以提高偏航阈值。
4. 复盘时标记路线质量问题。

### 山谷和林区漂移

问题：

GPS 在山谷、林区、峡谷中容易跳点。

处理：

1. 依赖定位可信度分级。
2. 使用连续确认。
3. 定位不稳时优先提示“不稳”，不提示“走错”。

## 事件记录

偏航检测会生成 `SessionEvent`。

### offRouteStarted

触发：

首次进入 `offRoute`。

payload：

```json
{
  "distanceFromRouteMeters": 38.4,
  "nearestSegmentStartIndex": 124,
  "routeProgressMeters": 1820.5,
  "bearingToRouteDegrees": 232,
  "horizontalAccuracyMeters": 12.0
}
```

### offRouteUpdated

触发：

持续偏航且距离显著变化，或重复提醒发生。

payload：

```json
{
  "distanceFromRouteMeters": 91.2,
  "deltaSinceLastAlertMeters": 52.8,
  "routeProgressMeters": 1845.7
}
```

### offRouteEnded

触发：

用户回到路线阈值内。

payload：

```json
{
  "durationSeconds": 186,
  "maxDistanceFromRouteMeters": 102.4,
  "returnRouteProgressMeters": 1902.3
}
```

### locationAccuracyPoor

触发：

定位进入不可信状态。

payload：

```json
{
  "horizontalAccuracyMeters": 76.0,
  "lastReliableRouteProgressMeters": 1740.2
}
```

## Watch UI 映射

| 偏航状态 | 顶部状态 | 底部提示 | 地图元素 | 触觉 |
| --- | --- | --- | --- | --- |
| `onRoute` | 路线上 | 剩余距离/下一关键点 | 正常路线 | 无 |
| `suspectedOffRoute` | 路线上或弱提示 | 保持路线 | 可不显示 | 无 |
| `offRoute` | 偏离 Xm | 向某方向回到路线 | 偏航连接线 + 最近路线点 | 首次明显震动 |
| `locationUnreliable` | 定位不稳 | 等待定位恢复 | 精度圈 | 可无 |
| `paused` | 已暂停 | 记录暂停中 | 地图仍可看 | 无 |

## 复盘映射

iPhone 复盘页使用偏航事件展示：

1. 偏航发生点。
2. 偏航持续时间。
3. 最大偏航距离。
4. 偏航段实际轨迹。
5. 回到路线的位置。

MVP 复盘不需要复杂评分，只需要让用户看清哪里走偏了。

## MVP 验收标准

1. 单个 GPS 漂移点不会触发偏航。
2. 连续偏离路线超过阈值后会进入偏航状态。
3. 回到路线后会退出偏航状态。
4. 定位精度差时不会频繁误报偏航。
5. 偏航状态能在 Watch 地图上显示距离和回到路线方向。
6. 偏航事件能被保存并同步到 iPhone。
7. 路线交叉或回头路附近不会明显跳错路线进度。
8. 暂停期间不会生成正式偏航事件。

## 待实测问题

1. 30m 偏航阈值在不同山地环境是否过敏或过钝。
2. 3 个定位点确认是否会造成提醒太慢。
3. 简化路线是否会影响偏航距离计算。
4. Apple Watch 不同机型 GPS 精度差异。
5. 地图底图道路与 GPX 路线不一致时用户如何理解偏航提醒。
