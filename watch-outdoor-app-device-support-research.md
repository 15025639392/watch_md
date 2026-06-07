# 手表设备支持情况与户外 App 开发调研

调研日期：2026-06-05；Garmin/Suunto/COROS 复查：2026-06-08；小米/OPPO/vivo 复查：2026-06-08  
重点平台：Apple Watch、华为手表、Wear OS、Garmin、Suunto、COROS、小米、OPPO、vivo  
调研目标：面向徒步人群，梳理主流智能手表对户外 App 的支持能力、手表端可开发功能、手机 App 与手表 App 的联动方式，以及产品落地建议。

## 结论摘要

如果目标是开发严肃户外 App，Apple Watch 是当前第三方开发最成熟、能力最确定的平台，适合优先做 MVP 和核心体验验证。华为手表适合在 HarmonyOS 生态内做轻量户外能力、健康数据联动和手机-手表协同，但不同机型、系统版本、地区和手机生态差异更大，需要按目标型号验证。

如果目标人群明确是徒步用户，平台判断要从“能不能开发完整 App”扩展为“能不能稳定完成长时间路线导航、偏航提醒、爬升统计、返航和离线使用”。因此 Apple Watch 仍适合首发验证产品体验，但 Garmin/佳明的重要性会上升，尤其适合专业徒步、长线徒步和重度户外用户。

Wear OS 应作为 Android 用户侧的备选平台纳入路线图。它具备 Health Services、Data Layer 和 Maps SDK on Wear OS 等开发路径，适合做 Android 手机 + Wear OS 手表的双端产品，但机型、厂商系统层和电量表现需要实机验证。

专业户外品牌如 Garmin、Suunto、COROS 在硬件续航、运动算法和专业户外体验上更强，但开放方式不同：Garmin 具备 Connect IQ 手表应用生态和 Garmin Connect 云端 API，最值得优先评估；Suunto 可通过 Partner Program、Cloud API 和 SuuntoPlus Sports Apps 接入；COROS 当前更适合做数据同步和路线同步合作，不应假设可以开发完整自有手表 App。

中国 Android 手机厂商生态需要分区域和系统判断。小米和 OPPO 是不同厂商，各自都有需要单独确认的手表型号、地区版本和健康 App 生态；如果具体机型运行 Wear OS，可以按通用 Wear OS 路线验证。中国区或非 Wear OS 机型通常依赖厂商自有系统、健康 App 和有限应用生态，不应默认可安装标准 Wear OS App。vivo 当前重点是 BlueOS/蓝河操作系统，需要验证 SDK、手表应用发布、健康数据和户外传感器权限。

## 户外 App 需要的核心手表能力

| 能力 | 价值 | 典型功能 |
| --- | --- | --- |
| 定位/GPS | 户外轨迹和导航基础 | 轨迹记录、路线导航、偏航提醒、返航 |
| 海拔/气压/方向 | 山地、徒步、越野核心指标 | 累计爬升、坡度、海拔曲线、方向指引 |
| 心率/运动数据 | 运动强度和健康安全 | 心率区间、配速、距离、卡路里、训练负荷 |
| 后台运行 | 放下手腕仍持续记录 | 长时间徒步、跑步、骑行记录 |
| 离线能力 | 无网络或无手机时可用 | 离线地图、离线路线、POI 缓存 |
| 震动/声音提醒 | 户外低打扰提示 | 偏航、补给、天气、心率过高 |
| 手机联动 | 大屏规划、小屏执行 | 手机规划路线，手表导航和采集 |
| 数据同步 | 运动后分析和分享 | 轨迹、心率、海拔、分段、导出 GPX/FIT |

## 手机系统与手表组合判断

手表平台不能只按手表品牌判断，还必须看用户手机系统。徒步 App 需要手机规划路线、手表执行导航、运动后同步数据；如果手机和手表生态不匹配，路线下发、权限授权、应用安装和数据回传都会受影响。

| 手机 + 手表组合 | 可行性 | 对徒步 App 的影响 | 产品建议 |
| --- | --- | --- | --- |
| iPhone + Apple Watch/watchOS | 强可行 | 最完整的手机-手表联动，适合首发 MVP | 首发主路径 |
| Android 手机 + Apple Watch/watchOS | 不建议 | Android 不能作为 Apple Watch 的官方配对、设置、App 安装和 HealthKit 数据管理端 | 不纳入支持范围 |
| Android 手机 + Wear OS | 强可行 | Android 手机可通过 Data Layer 与 Wear OS 手表同步路线、资源和状态 | Android 通用智能表主路径 |
| Android 手机 + 华为手表 | 可行，但要分机型和生态 | 可通过 Huawei Health 配对；开发侧可通过 Wear Engine、Health Kit 等能力做协同，但非华为 Android、地区、AppGallery/HMS Core、机型能力会影响体验 | 中国/华为生态重点验证 |
| 华为手机 + 华为手表 | 最强华为路径 | 系统、HMS、AppGallery、Wear Engine 和健康生态更完整 | 华为平台优先验证组合 |
| Xiaomi 手机 + Xiaomi Wear OS 手表 | 可行，但看 GMS/地区 | 若手表为 Wear OS 且能使用 Google Play，可按 Wear OS App 开发；中国 ROM、GMS、Mi Fitness / 小米运动健康和配对路径可能影响体验 | 按 Wear OS 路线验证，不按所有小米手表承诺 |
| OPPO 手机 + OPPO / OnePlus Wear OS 手表 | 可行，但看 GMS/地区 | 若手表为 Wear OS 且能使用 Google Play，可按 Wear OS App 开发；中国 ROM、GMS、OPPO 健康和配对路径可能影响体验 | 按 Wear OS 路线验证，不按所有 OPPO 手表承诺 |
| vivo 手机 + vivo 自家手表 | 不确定 | 通常依赖 vivo 健康、BlueOS / 自家系统和厂商应用生态，第三方户外 App、路线下发和健康数据权限需单独验证 | 暂不纳入首发，按 SDK、合作或实机验证处理 |
| Xiaomi 手机 + Xiaomi 非 Wear OS 手表 | 不确定 | 通常依赖 Mi Fitness / 小米运动健康和小米自有系统生态，第三方户外 App、路线下发和健康数据权限需单独验证 | 暂不纳入首发，按合作或实机验证处理 |
| OPPO 手机 + OPPO 非 Wear OS 手表 | 不确定 | 通常依赖 OPPO 健康和 OPPO 自有系统生态，第三方户外 App、路线下发和健康数据权限需单独验证 | 暂不纳入首发，按合作或实机验证处理 |
| iPhone + 华为手表 | 基础可用，深度联动弱 | 可用于部分健康/通知能力，但第三方深度联动通常弱于 Android/Huawei 生态 | 不作为核心研发路径 |

### Android 手机 + Apple Watch/watchOS

Apple Watch 的官方设置、配对、应用管理和健康数据能力依赖 iPhone 与 Apple Watch app。Android 手机没有官方 Apple Watch 配对应用，也无法作为 watchOS App 分发、HealthKit 授权、WatchConnectivity 同步的宿主。

因此，即使用户个人通过非官方方式或蜂窝网络让 Apple Watch 做部分独立使用，也不适合作为产品支持路径。对徒步 App 来说，这个组合无法稳定完成：

1. Android 手机向 Apple Watch 下发 GPX 路线。
2. Android 手机安装或管理 watchOS 端 App。
3. Android 手机读取 Apple Watch 写入的 HealthKit 运动数据。
4. Android 手机与 Apple Watch 做 WatchConnectivity 实时同步。

产品结论：Android 用户如果要使用手表端徒步能力，应引导到 Wear OS、华为、佳明、高驰或颂拓等生态，而不是 Apple Watch。

### Android 手机 + 华为手表

华为手表可以与 Android 手机配对，官方支持通过 Huawei Health 完成设备连接和管理。对徒步产品来说，这个组合有实际价值，尤其适合中国市场、华为手表存量用户，以及偏长续航的 Watch GT 系列用户。

但需要把 Android 手机再拆成两类：

| 组合 | 体验判断 | 需要验证 |
| --- | --- | --- |
| 华为手机 + 华为手表 | 最完整 | HarmonyOS/EMUI 版本、Wear Engine、Health Kit、AppGallery 上架、手表端安装 |
| 非华为 Android + 华为手表 | 可用但不确定性更高 | Huawei Health 安装路径、HMS Core、通知权限、后台保活、Wear Engine 可用性、地区限制 |

对徒步 App 的可做能力：

1. 手机端导入 GPX、标注 POI 和风险点。
2. 手机通过 Wear Engine 或文件/消息能力向手表下发路线、图片或轻量地图资源。
3. 手表端显示路线、当前位置、偏航提示和基础运动数据。
4. 运动后通过 Health Kit 或 App 自有同步链路回传记录。

主要风险：

1. Huawei Health 在部分 Android 手机上不一定来自 Google Play，需要通过 AppGallery 或华为官方路径安装。
2. 非华为 Android 的后台权限、通知权限、HMS Core 状态可能影响连接稳定性。
3. 具体手表是否能安装第三方手表 App、是否支持目标 Wear Engine 能力，必须按机型验证。
4. iOS + 华为手表可以做基础使用，但不应作为深度徒步联动的主路径。

产品结论：Android 手机 + 华为手表可以纳入第二阶段验证，但不要泛称“支持华为手表”。应先确定目标手机类型、目标手表型号、系统版本、地区和上架路径。

### 小米 / OPPO / vivo 补充判断

2026-06-08 复查：这几类平台不能只按手机品牌归类，必须先确认手表操作系统、地区版本、配对 App 和应用分发渠道。

| 平台 | 当前可查开放路径 | 对徒步 App 的意义 | 风险与限制 | 建议 |
| --- | --- | --- | --- | --- |
| 小米 | 部分新款手表在海外或特定型号使用 Wear OS；中国区多依赖 Xiaomi HyperOS / Mi Fitness / 小米运动健康生态 | Wear OS 机型可按通用 Wear OS 验证；非 Wear OS 机型更偏原生运动、健康同步和有限应用生态 | 不应默认所有 Xiaomi Watch 都能安装标准 Wear OS App；小米健康数据和手表应用开发开放范围需逐型号确认 | 只把 Wear OS Xiaomi Watch 纳入 Android 通用路径；中国区机型先做资料和实机验证 |
| OPPO | OPPO Watch X / OnePlus Watch 2 等存在 Wear OS 路线；中国区 OPPO Watch 系列和健康生态需按型号确认 | Wear OS 机型可用 Health Services、Data Layer、Maps SDK；品牌健康生态可作为后续合作或数据同步方向 | 国内外型号系统可能不同；OPPO 健康数据 API、手表应用发布和后台能力没有统一公开结论 | Wear OS 机型按 Wear OS 验证；非 Wear OS 机型暂不进入研发排期 |
| vivo | vivo BlueOS / 蓝河操作系统已有开发者生态入口和 SDK 方向，vivo WATCH 系列也有自家健康 App 生态 | 有潜力做中国区手机-手表协同验证，尤其是 vivo 手机用户 | 需要确认 BlueOS SDK 是否面向手表第三方 App、是否能访问定位/健康/运动、是否有应用发布路径和目标机型支持 | P2/P3 资料验证，暂不作为 Apple Watch MVP 后的第一平台 |

对本项目而言，这三类平台的共同处理原则：

1. 如果目标手表是 Wear OS，优先归入 Wear OS 路线，而不是按小米或 OPPO 品牌单独设计。
2. 如果目标手表是厂商自研系统，先验证是否存在公开 SDK、手表应用商店、健康数据 API、定位/传感器权限和路线/文件下发能力。
3. 不把小米、OPPO、vivo 纳入 Apple Watch MVP；它们属于 Android/中国区扩展平台调研。

## 徒步人群产品侧重点

徒步用户和跑步、骑行用户不完全一样。徒步场景通常速度更慢、持续时间更长、路径不确定性更高，对“路线安全”和“低电量可靠性”的要求高于实时配速表现。

| 需求 | 徒步用户价值 | 产品功能 |
| --- | --- | --- |
| 路线导入与导航 | 先规划路线，到现场按路线走 | GPX 导入、路线预览、手表端路线线框 |
| 偏航提醒 | 山路岔口、林道、无明显路标时降低迷路风险 | 偏离路线震动、偏航距离、回到路线方向 |
| 返航/回到起点 | 迷路、天气变化、体力不足时快速撤退 | 原路返回、直线回起点、最近轨迹点回撤 |
| 爬升与海拔 | 判断强度、剩余难度和风险 | 当前海拔、累计爬升、剩余爬升、海拔曲线 |
| 补给/风险点 | 徒步强依赖水源、营地、岔路、危险点 | POI、补给点提醒、风险点提醒 |
| 离线可用 | 山区弱网或无网是常态 | 离线路线、关键 POI、轻量底图缓存 |
| 长续航 | 徒步常见 4-10 小时，长线可能多日 | 低频采样、地图轻量化、电量策略 |
| 运动后复盘 | 记录路线、分享轨迹、沉淀路线库 | GPX/FIT/TCX 导出、轨迹回放、海拔/心率分析 |

徒步 MVP 应优先保证“路线不丢、位置不断、偏航能提醒、结束能同步”。地图视觉可以后置，先做路线线框和关键点，比一开始追求完整离线地图更稳。

## Apple Watch 支持情况

Apple Watch 适合做完整的户外运动手表 App。它在定位、健康数据、后台运动、手机联动、表盘组件和离线缓存方面都有明确的开发者能力。

### 手表端可支持功能

| 功能 | 支持情况 | 户外 App 场景 |
| --- | --- | --- |
| GPS/定位 | 支持 Core Location | 轨迹记录、路线导航、当前位置、偏航检测 |
| 海拔/航向 | 支持定位与设备传感器相关能力 | 爬升统计、方向指引、返航 |
| 健康/运动数据 | 支持 HealthKit、HKWorkoutSession | 实时心率、运动距离、配速、能量消耗 |
| 后台运动记录 | 支持 workout-processing 后台模式 | 长时间徒步、跑步、骑行记录 |
| 触觉/声音提醒 | 运动场景中可用 | 偏航提醒、补给提醒、心率提醒 |
| 地图与路线 | 可用 MapKit 或自研地图渲染 | 路线展示、离线瓦片、POI |
| 离线缓存 | App 可缓存路线、地图和状态 | 无网络/无手机继续导航 |
| 蜂窝网络 | Cellular 机型可独立联网 | 实时同步、远程状态、应急消息 |
| 表盘组件 | WidgetKit/Complications | 快速查看路线进度、运动状态 |
| 手机联动 | WatchConnectivity、HealthKit、WorkoutKit | 手机规划，手表执行，运动后同步 |

### Apple Watch 能做的户外产品形态

1. 手表独立运动记录：跑步、徒步、骑行、滑雪、越野等。
2. 手表地图导航：GPX 导入、轨迹线、当前位置、偏航提醒。
3. 手机路线规划 + 手表导航：手机大屏编辑路线，手表抬腕执行。
4. 实时运动仪表盘：心率、配速、坡度、累计爬升、剩余距离。
5. 离线户外：缓存地图、路线和 POI，无手机也能使用。
6. 运动后分析：轨迹、心率曲线、海拔曲线、分段、导出 GPX/FIT/TCX。
7. 表盘轻交互：显示运动状态、路线进度、快捷开始。

### 手机 App 与 Apple Watch 联动方式

| 联动方式 | 适合场景 |
| --- | --- |
| WatchConnectivity `sendMessage` / `sendMessageData` | 手机和手表都在线时实时传命令，例如开始导航、暂停运动、切换路线 |
| WatchConnectivity `updateApplicationContext` | 同步最新状态，例如当前路线、当前用户设置 |
| WatchConnectivity `transferUserInfo` | 后台排队同步运动摘要、轨迹点、设置变更 |
| WatchConnectivity `transferFile` | 同步 GPX、FIT、地图包、路线文件 |
| HealthKit | 手表写入运动，手机读取并做分析 |
| WorkoutKit | 手机创建训练计划，同步到 Apple Watch |
| mirrored workout session | 手表主运动，手机作为实时展示或控制端 |

### Apple Watch 开发注意事项

1. Apple Watch 同一时间只能运行一个 workout session。
2. 需要用户授权 HealthKit、定位和通知等权限。
3. 长时间 GPS、地图渲染和频繁同步会显著影响电量。
4. 地图能力建议拆分为轻量路线图、离线瓦片缓存和关键 POI，避免手表端承担过重渲染。
5. 应优先保证运动记录可靠，再扩展地图视觉体验。

### Apple 参考资料

- Apple Set up Apple Watch: https://support.apple.com/en-us/104980
- Apple HealthKit: https://developer.apple.com/documentation/healthkit
- Apple HKWorkoutSession: https://developer.apple.com/documentation/healthkit/hkworkoutsession
- Apple Running workout sessions: https://developer.apple.com/documentation/healthkit/workouts_and_activity_rings/running_workout_sessions
- Apple WatchConnectivity WCSession: https://developer.apple.com/documentation/watchconnectivity/wcsession
- Apple WorkoutKit: https://developer.apple.com/documentation/workoutkit
- Apple Offline Maps on iPhone/Apple Watch: https://support.apple.com/guide/iphone/download-offline-maps-iphcfb5f5bc6/ios
- Apple Maps HIG: https://developer.apple.com/design/human-interface-guidelines/maps

## 华为手表支持情况

华为侧主要分为两类能力：直接为 HarmonyOS 手表开发应用，以及通过 Wear Engine、Health Kit、Location Kit 等能力让手机 App 与华为穿戴设备协同。

### 手表端可支持功能

| 功能 | 支持情况 | 户外 App 场景 |
| --- | --- | --- |
| 手表应用 | HarmonyOS wearable/lite wearable 开发 | 手表端运动页、导航页、快捷操作 |
| 定位 | Location Kit 支持 HarmonyOS 生态 | 位置获取、轨迹记录、导航 |
| 健康数据 | Health Kit 支持用户授权后的健康数据访问 | 心率、运动记录、健康分析 |
| 手机-手表通信 | Wear Engine | 手机发送路线/消息，手表回传状态 |
| 设备状态 | Wear Engine | 连接、佩戴、充电、电量监测 |
| 运动健康状态 | Wear Engine | 活动、心率、异常通知等场景 |
| 传感器管理 | Wear Engine 相关能力 | 加速度计、PPG/ECG 等设备数据，取决于机型和权限 |
| 通知提醒 | HarmonyOS 通知能力/Wear Engine | 偏航、补给、风险提醒 |
| 表冠/手势 | HarmonyOS wearable 交互 | 缩放地图、滚动数据页、切换数据屏 |

### 华为手机与手表联动方式

| 联动方式 | 户外 App 场景 |
| --- | --- |
| 手机发送消息到手表 | 发送路线、导航指令、天气预警 |
| 手机发送文件/媒体 | 下发路线图、图片、简化地图资源 |
| 手表回传数据 | 回传心率、活动状态、传感器数据 |
| 手机推送通知到手表 | 偏航、补给点、风险提醒 |
| 设备状态监控 | 电量低、未佩戴、断连提醒 |
| Health Kit 数据同步 | 手机端做运动分析和健康报告 |

### 华为手表开发注意事项

1. 华为手表机型差异较大，需要先确定目标设备清单。
2. Watch GT、Watch Fit、Watch Ultimate、Watch D 等系列虽然都属于华为穿戴设备，但开放 API、系统版本、是否支持调试安装和上架路径可能不同。
3. 需要确认目标设备是否支持 HarmonyOS 5 或对应 wearable/lite wearable 开发。
4. 需要确认 AppGallery 是否支持目标手表应用上架。
5. 需要确认 Wear Engine、Health Kit、Location Kit 在目标地区、目标手机系统和目标手表型号上的可用性。
6. iOS 用户使用华为手表时，第三方联动能力通常弱于华为手机或 Android 生态。

2026-06-06 追加调研结论：华为平台应按“智能可穿戴、轻量级智能可穿戴、手环、儿童/特殊形态设备”拆开判断。当前优先验证 `WATCH` 数字系列和 `WATCH GT` 系列：前者用于验证完整智能表 App、后台定位和安装/上架路径，后者用于验证长续航户外用户、轻量导航和手机协同稳定性。华为消费者支持页也能证明 WATCH、GT、FIT、Ultimate、D/D2 等多个系列存在手表应用市场、地图或导航同步场景，但首批资源不分散到 FIT、Ultimate、D/D2。详细矩阵见 [华为各类型手表支持情况调研 v0.1](./docs/huawei-watch-support-research-v0.1.md)。

### 华为参考资料

- Huawei Pairing watch/band with Android phone: https://consumer.huawei.com/en/support/content/en-us16008856/
- Huawei HarmonyOS Wearable App Development: https://developer.huawei.com/consumer/en/multidevice/wearables/get-started/
- Huawei HarmonyOS 穿戴应用开发入门: https://developer.huawei.com/consumer/cn/multidevice/wearables/get-started/
- Huawei Wear Engine: https://developer.huawei.com/consumer/en/hms/huawei-wearengine/
- Huawei Wear Engine 中文页: https://developer.huawei.com/consumer/cn/hms/huawei-wearengine/
- Huawei Health Kit: https://developer.huawei.com/consumer/en/hms/huaweihealth/
- Huawei Location Kit Codelab: https://developer.huawei.com/consumer/en/codelab/HMS-LocationKit/

## Wear OS 支持情况

Wear OS 是 Android 生态内最接近 Apple Watch 的通用第三方手表 App 平台。对户外 App 来说，它的价值在于可以直接开发手表端应用，并与 Android 手机 App 通过 Data Layer 同步路线、设置、图片或轻量地图资源。

### 手表端可支持功能

| 功能 | 支持情况 | 户外 App 场景 |
| --- | --- | --- |
| 运动/健康数据 | Health Services on Wear OS 3+ | 运动记录、心率、距离、速度、配速、海拔等指标 |
| 主动运动会话 | ExerciseClient | 跑步、徒步、骑行等运动的实时采集和展示 |
| 被动健康监听 | PassiveMonitoringClient | 低频健康状态、目标事件、活动提醒 |
| 地图 | Maps SDK for Android on Wear OS | 手表端位置展示、路线查看、标记点 |
| 手机-手表通信 | Wear OS Data Layer API | 同步路线、配置、图片、离线资源和命令 |
| 资源下发 | DataItem、Asset、Message、Channel | 下发 GPX、路线摘要、压缩地图图片或小型资源包 |
| Android 生态分发 | Google Play | Android 用户侧独立分发手表 App |

### Wear OS 开发注意事项

1. Health Services 从 Wear OS 3 开始提供较统一的健康与运动数据入口，适合作为 Android 侧运动记录核心。
2. Data Layer 只适用于 Android 手机与 Wear OS 手表之间的数据同步；如果 Wear OS 设备与 iOS 配对，则该通信路径不可用。
3. Maps SDK 可在 Wear OS 手表端运行，但地图交互、UI 控件和资源消耗都需要按小屏和电量重新设计。
4. Wear OS 机型差异明显，尤其是 Pixel Watch、Samsung Galaxy Watch 和其他厂商设备在系统版本、传感器、续航和厂商服务上可能不同。
5. 如果产品已有 Android 用户基础，Wear OS 可以排在华为之前做验证；如果目标用户主要在中国大陆，还需要结合华为、荣耀、小米等生态重新排序。

### Wear OS 参考资料

- Wear OS Health Services: https://developer.android.com/health-and-fitness/guides/health-services
- Wear OS Data Layer: https://developer.android.com/training/wearables/data/sync
- Wear OS Maps SDK: https://developers.google.com/maps/documentation/android-sdk/wear

### 中国 Android 厂商生态参考资料

- Google Wear OS developer docs: https://developer.android.com/training/wearables
- Xiaomi Watch 2 Pro product page: https://www.mi.com/global/product/xiaomi-watch-2-pro/
- Xiaomi Watch S4 product page: https://www.mi.com/global/product/xiaomi-watch-s4/
- OPPO Watch X product page: https://www.oppo.com/en/accessories/watch-x/
- OnePlus Watch 2 product page: https://www.oneplus.com/us/oneplus-watch-2
- vivo BlueOS developer: https://developer.vivo.com/product/blueos
- vivo WATCH product page: https://www.vivo.com.cn/vivo/watch

## 专业户外表生态补充调研

专业户外表不应按“能否做完整第三方手表 App”单一维度判断。更实际的评估方式是区分三件事：是否能开发手表端功能、是否能把路线/训练计划推到设备、是否能读取运动后的活动数据。

| 平台 | 开放能力 | 适合做什么 | 不适合先假设什么 | 当前建议 |
| --- | --- | --- | --- | --- |
| Garmin | Connect IQ SDK、Connect IQ Store、Garmin Connect Developer Program、Courses/Training/Activity API | 手表 Device App / Data Field、FIT 扩展记录、GPS/传感器读取、路线或训练计划推送、活动文件读取 | 不应假设所有设备都支持同等 API、地图 UI、存储、后台和原生导航集成能力 | P1+ 重点验证，专业户外用户第二增长平台 |
| Suunto | Suunto Partner Program、Cloud API、SuuntoPlus Sports Apps / Guides、第三方路线同步 | 读取活动/FIT 数据、同步路线或训练指导、开发轻量腕上运动增强功能 | 不应假设有 Apple Watch 式完整自由 App 平台或可替换原生运动页 | P2 评估，适合做伙伴生态和 SuuntoPlus 小应用验证 |
| COROS | Partner/API application、第三方数据同步、路线同步伙伴、原生路线导航 | 运动数据同步、路线同步、训练平台集成、借助 COROS 原生导航执行路线 | 不应假设有公开手表 App SDK 或可替换原生运动页 | P2/P3，先验证合作权限和路线同步范围 |

### Garmin 细化判断

2026-06-08 复查：Garmin 是专业户外表里最值得优先验证的平台。Connect IQ SDK 最新官方页面显示当前版本为 9.1.0，支持 Data Fields、Device Apps、Widgets、Watch Faces、Audio Content Provider 等形态；Device Apps 可使用 GPS/传感器数据、ANT+/BLE、与手机或互联网通信，并记录 FIT；Data Fields 可叠加到设备已有运动页面，并通过 FitContributor 把自定义字段写入活动 FIT 文件。Connect IQ API 文档还包含 ActivityRecording、Activity、Position、Communications、Sensor、WatchUi、PersistedLocations 等模块，说明 Garmin 具备比 Suunto/COROS 更完整的腕上第三方开发路径。

Garmin Connect Developer Program 是另一条云端接入路径。官方说明该项目包含 Health API、Activity API、Training API、Courses API、Women’s Health API。其中 Activity API 可在用户授权并同步设备后读取完整活动数据，并提供 FIT、GPX、TCX 文件；Training API 可发布结构化 workouts 和 training plans 到 Garmin Connect 日历，再同步到兼容设备；Courses API 可发布 courses 和 course points 到 Garmin Connect，用户可在兼容手表或骑行码表的标准 Courses 菜单中跟随路线。官方同时说明这些 Garmin Connect APIs 是 cloud-to-cloud 集成；如果需要移动 App 与 Garmin wearables 的实时直连，需要另看 Garmin Health SDKs，不应把云端 API 误解成实时手表控制通道。

对本项目而言，Garmin 的现实产品形态可能不是“复制 Apple Watch App”，而是：

1. 在手机/云端生成徒步 course、course points、训练计划或补给/风险点指导，借 Garmin Courses/Training API 推送到 Garmin Connect，再由用户同步到兼容设备。
2. 通过 Activity API 获取用户授权后的活动详情和 FIT/GPX/TCX 文件，用于运动后复盘、路线沉淀和数据分析。
3. 用 Connect IQ Data Field 做叠加在原生 Hiking/Walking/Trail Run 等运动模式上的轻量实时能力，例如偏航距离、补给倒计时、检查点 ETA、风险点提醒、自定义 FIT 字段记录。
4. 用 Connect IQ Device App 验证更完整的腕上路线辅助或会话记录，但必须先确认目标设备 API Level、内存、地图/图形能力、定位权限、ActivityRecording 行为和 Connect IQ Store 上架要求。
5. 把 Garmin 作为专业户外用户的第二增长平台，并优先验证 “Courses API + Activity API + 轻量 Data Field” 组合，而不是一开始做完整自研 Garmin 地图 App。

Garmin 的关键限制也要写清楚：

1. 设备差异大。Fenix/Epix/Enduro/Forerunner/Instinct/Edge 等产品的屏幕、地图、存储、API Level、运动模式和 Connect IQ 限制不同，不能用单一 Garmin 结论覆盖所有型号。
2. Courses/Training API 依赖用户授权、Garmin Connect 和设备同步链路，不等于手机即时向手表推送任意资源。
3. Connect IQ 可开发腕上功能，但未必能接管 Garmin 原生地图、原生导航和所有系统运动算法；应优先和原生运动/路线生态组合。
4. Connect IQ Data Field 更适合叠加信息和记录自定义字段；Device App 更自由但上架、体验一致性、电量和长时间稳定性风险更高。
5. Activity API 是运动后数据路径，数据可用性取决于用户同步设备到 Garmin Connect。

建议下一轮 Garmin 验证拆成两个并行小实验：

1. 云端 API 实验：申请 Garmin Connect Developer Program，验证 Courses API 是否能写入徒步 course/course points，Activity API 是否能读取活动文件，Training API 是否适合补给/风险点或结构化训练。
2. Connect IQ 实验：选 1-2 个目标设备系列，做一个 Data Field 原型，读取当前活动、定位、海拔/心率等数据，显示路线相关提示，并通过 FitContributor 写入自定义 FIT 字段。

### Suunto 细化判断

2026-06-08 复查：Suunto 的接入路径偏伙伴生态，但比纯数据 API 更进一步。API Zone 说明需要加入 Suunto Partner Program 才能获得 API 访问；API 面向通过 Suunto App 连接消费者，重点是读取用户授权后的 workout/FIT 活动数据。SuuntoPlus 页面和 API Zone 说明，SuuntoPlus Sports Apps 是运行在 Suunto 手表运动中的轻量、可定制功能，可用于传感器驱动的数据叠加、计算、计时器或实时指导；开发者可安装 SuuntoPlus Editor，在本地用自己的手表和电脑开发测试，发布则需要通过 ApiZone 提交并由 Suunto 审核。SuuntoPlus Guides 则更适合训练计划、比赛补给、爬升段落或路线相关实时指导内容。

路线能力上，Suunto App 支持规划路线、管理路线库，并与 Strava、Komoot 等伙伴服务同步路线；Komoot 路线可带转向提示同步到手表，Strava 路线也可进入 Suunto App 路线库后选择同步到手表。官方材料还显示 Suunto App 连接 200+ 伙伴服务，但具体 API 权限、路线写入、Guide 下发、发布范围和中国区可用性需要逐项申请和实机验证。

对本项目而言，Suunto 更适合做：

1. 路线、训练计划或 SuuntoPlus Guide 下发。
2. 运动后数据读取和分析。
3. 用 SuuntoPlus Sports App 做轻量腕上实时功能，例如补给提醒、坡度/爬升段提示、检查点倒计时或安全信息页。
4. 借助 Suunto 原生运动、导航和路线库执行徒步，而不是复制完整自有地图和会话系统。

不建议在没有伙伴权限和实机验证前，把 Suunto 规划为完整自有手表 App 平台。下一步验证重点是：是否能获得 Partner/API 权限；是否能写入路线、Guide 或训练计划；SuuntoPlus Sports App 可访问哪些实时数据字段；目标机型是否支持 SuuntoPlus；审核发布周期和区域可用性是否满足产品节奏。

### COROS 细化判断

2026-06-08 复查：COROS 官方列出了第三方 App 数据同步和 Partner with COROS 路径，也明确开发者可提交 API Application。COROS Partner 页面和帮助中心显示，COROS 已支持 Strava、Komoot、Ride with GPS、Wikiloc 等路线或活动同步伙伴；路线可以从第三方、GPX 文件或 COROS App 导入后同步到设备，部分设备还支持运动进行中从手机同步路线到手表。COROS 自身设备具备丰富的户外运动能力，例如路线导航、偏航提醒、转向提示、海拔信息和运动中开启/结束导航等，但当前仍未找到公开、完整的手表端第三方 App SDK。

对本项目而言，COROS 应按“合作/API 数据接入”处理：

1. 优先确认是否能拿到 API 权限。
2. 验证是否能读取活动、同步路线、同步训练计划，以及路线同步是否可覆盖徒步场景。
3. 如果可合作，产品形态优先是“手机/云端生成或管理路线，推送到 COROS 原生路线库，运动后读取活动数据”，而不是开发自有 COROS 手表 App。
4. 暂不把 COROS 纳入自研手表端 MVP。

### 专业户外表参考资料

- Garmin Connect IQ SDK: https://developer.garmin.com/connect-iq/overview/
- Garmin Connect IQ Getting Started: https://developer.garmin.com/connect-iq/connect-iq-basics/getting-started/
- Garmin Connect IQ App Types: https://developer.garmin.com/connect-iq/connect-iq-basics/app-types/
- Garmin Connect IQ API Docs: https://developer.garmin.com/connect-iq/api-docs/
- Garmin Connect Developer Program: https://developer.garmin.com/gc-developer-program/overview/
- Garmin Activity API: https://developer.garmin.com/gc-developer-program/activity-api/
- Garmin Courses API: https://developer.garmin.com/gc-developer-program/courses-api/
- Garmin Training API: https://developer.garmin.com/gc-developer-program/training-api/
- Garmin Health SDKs: https://developer.garmin.com/health-sdk/overview/
- Suunto API Zone: https://apizone.suunto.com/
- Suunto API list: https://apizone.suunto.com/apis
- SuuntoPlus Sports Apps: https://apizone.suunto.com/suuntoplus
- SuuntoPlus product page: https://www.suunto.com/suuntoplus/
- Suunto App: https://www.suunto.com/en-us/suunto-app/suunto-app-2022/
- Suunto Strava routes: https://www.suunto.com/en-ca/Support/faq-articles/strava/strava-routes/
- Suunto Komoot partner: https://www.suunto.com/partners/komoot/
- COROS Partners: https://coros.com/partners
- COROS Supported 3rd Party Apps: https://support.coros.com/hc/en-us/articles/360040256531-Supported-3rd-Party-Apps
- COROS Downloading and Using Routes: https://support.coros.com/hc/en-us/articles/24181489692436-Downloading-and-Using-Routes
- COROS Using Navigation Features: https://support.coros.com/hc/en-us/articles/360039841072-Using-Navigation-Features
- COROS Route Syncing to Watch During Activity: https://support.coros.com/hc/en-us/articles/6504037499284-Route-Syncing-to-Watch-During-Activity

## 离线地图方案补充评估

离线地图是手表户外 App 的高风险模块，不建议在 MVP 阶段直接做“完整地图”。更稳妥的分层方式如下：

| 层级 | 手表端能力 | 手机端能力 | 适用阶段 |
| --- | --- | --- | --- |
| L0 路线线框 | 显示路线 polyline、当前位置、方向、偏航距离 | 导入 GPX、简化路线、下发路线点 | MVP 必做 |
| L1 关键点导航 | 显示 POI、补给点、风险点、距离和提醒 | POI 编辑、风险点标注、下发提醒策略 | MVP/P1 |
| L2 轻量底图 | 显示路线走廊范围内的简化瓦片或栅格图 | 下载、裁剪、压缩、缓存和下发地图资源 | P1 实机验证 |
| L3 完整离线地图 | 多缩放级别、地形、道路、POI、交互缩放 | 地图包管理、增量更新、授权和成本控制 | P2 以后 |

平台侧判断：

1. Apple Watch：Apple 官方 Maps App 支持把 iPhone 离线地图或徒步路线同步到 Apple Watch，但这应视为系统地图能力，不应直接假设第三方 App 可复用这份离线地图缓存。手表端 MVP 应优先自绘路线、当前位置、方向和偏航提示。
2. Wear OS：Maps SDK 可在 Wear OS 上展示地图；Data Layer 可以从 Android 手机向手表同步图片或资源。适合验证“手机下载地图，手表显示路线走廊轻量底图”的方案。
3. Garmin：优先利用 Garmin 原生 Course/Route/Workout 生态；如果做 Connect IQ，应先评估目标设备是否支持所需的地图 UI、路线对象和存储能力。
4. Suunto/COROS：优先走官方路线同步和指南/训练计划能力，不应在早期尝试替代设备原生地图。

离线地图第一轮实机验证指标：

1. 路线点数量：500、2,000、10,000 点的解析、简化和渲染表现。
2. 资源体积：500 KB、2 MB、10 MB 资源下发耗时和失败率。
3. 电量：仅路线、路线 + POI、路线 + 轻量底图三种模式的 1 小时耗电。
4. 断连：手表离开手机后能否继续导航、偏航提醒和保存运动。
5. 恢复：运动中断、App 重启、手表锁屏后是否能恢复路线和记录状态。

## 实机验证计划

| 平台 | 必测项目 | 通过标准 |
| --- | --- | --- |
| Apple Watch | HKWorkoutSession 后台记录、Core Location、心率、路线下发、偏航提醒、结束后同步 | 1 小时连续记录无丢失；断开手机后仍能继续；运动结束可回传完整轨迹 |
| Wear OS | Health Services ExerciseClient、GPS/心率/海拔、Data Layer 资源下发、地图显示 | Android 手机下发路线稳定；手表端能独立完成一次户外记录 |
| 华为 | Wear Engine 消息/文件、Health Kit 权限、WATCH / GT 目标机型安装和上架路径 | 至少 `WATCH 5/4` 与 `WATCH GT 5/6` 两条主线验证通过，明确地区、系统和手机生态限制 |
| 小米 | Xiaomi Wear OS 目标机型、非 Wear OS 国内机型、小米运动健康 / Mi Fitness 数据和应用分发路径 | Wear OS 机型能跑通通用 Android + Wear OS Demo；非 Wear OS 机型明确是否存在公开 SDK 和发布路径 |
| OPPO | OPPO / OnePlus Wear OS 目标机型、非 Wear OS 国内机型、OPPO 健康数据和应用分发路径 | Wear OS 机型能跑通通用 Android + Wear OS Demo；非 Wear OS 机型明确是否存在公开 SDK 和发布路径 |
| vivo | BlueOS SDK、vivo WATCH 目标机型、定位/健康/运动权限、应用分发 | 明确 BlueOS 是否支持手表第三方户外 App；能否访问徒步所需实时数据 |
| Garmin | Courses/Training/Activity API、Connect IQ Data Field 示例、目标设备 API Level 和 Connect IQ Store 流程 | 能推送 course/course points 或训练；能获取活动 FIT/GPX/TCX；能在目标设备上稳定运行轻量 Data Field |
| Suunto | Partner/API 申请、Route/Guide/Workout API、SuuntoPlus Editor | 明确审批路径；能本地测试 SuuntoPlus Sports App 或 API demo |
| COROS | API Application、路线/活动同步、合作要求 | 明确是否可获得权限；不可获得前不进入研发排期 |

## 平台优先级更新

| 优先级 | 平台 | 原因 |
| --- | --- | --- |
| 1 | Apple Watch | 能力完整、开发文档成熟，适合快速验证徒步路线导航、偏航提醒和运动记录体验 |
| 2 | Garmin/佳明 | 徒步和专业户外用户价值高，续航、GPS、路线和户外能力强，Connect IQ 和云端 API 都值得评估 |
| 3 | Wear OS | Android 用户侧关键平台，具备健康、通信、地图能力，但需机型和续航验证 |
| 4 | 华为 | 中国及 HarmonyOS 生态重要，但机型、地区、上架和权限差异需要先收敛 |
| 5 | 小米自研系统手表 | 中国 Android 手机生态价值高，但需先确认 SDK、应用分发、健康数据和手表端权限 |
| 6 | OPPO 自研系统手表 | 中国 Android 手机生态价值高，但需先确认 SDK、应用分发、健康数据和手表端权限 |
| 7 | vivo / BlueOS 手表 | 中国 Android 手机生态价值高，但需先确认 BlueOS SDK、应用分发、健康数据和手表端权限 |
| 8 | Suunto | 适合伙伴生态、路线/指南/活动数据接入，不适合首发完整 App |
| 9 | COROS | 设备户外能力强，但第三方开放路径更偏 API/合作，研发不确定性高 |

## 建议的产品架构

建议采用手机 App 与手表 App 双端分工：手机负责复杂任务，手表负责户外现场高频任务。

| 模块 | 手机 App | 手表 App |
| --- | --- | --- |
| 路线规划 | 主力，大屏编辑 GPX/路线/POI | 选择路线、开始导航 |
| 地图资源 | 下载、压缩、缓存、下发 | 显示轻量地图/轨迹 |
| 运动记录 | 分析、历史、导出 | 实时采集、后台记录 |
| 实时导航 | 辅助大屏查看 | 主界面，抬腕即看 |
| 健康数据 | 运动后分析 | 心率、配速、距离、提醒 |
| 通知提醒 | 策略计算、远程信息 | 震动、声音、屏幕提醒 |
| 云同步 | 登录、备份、分享 | 尽量少依赖网络 |

## MVP 功能建议

第一阶段建议优先做 Apple Watch，因为能力完整、开发路径清晰、验证效率高。如果目标用户更偏重度徒步或长线户外，应同步启动 Garmin/佳明接入验证，确认路线、活动数据和轻量手表功能是否能覆盖核心场景。

### 手表端 MVP

1. 开始/暂停/结束运动。
2. 实时数据显示：时间、距离、当前海拔、累计爬升、心率、电量。
3. 路线导航：显示轨迹线、当前位置、前进方向、剩余距离。
4. 偏航提醒：震动 + 屏幕提示 + 回到路线方向。
5. 补给点/风险点提醒：水源、营地、岔路、危险路段。
6. 回到起点或返航提示：原路返回、直线回起点、最近轨迹点回撤。
7. 低电量模式：降低采样频率、关闭重地图、保留路线和偏航提醒。
8. 运动结束后同步手机。

### 手机端 MVP

1. GPX 路线导入。
2. 路线预览与编辑。
3. 路线风险点和补给点标注。
4. 离线地图下载。
5. 将路线、POI 和必要地图资源下发到手表。
6. 运动后轨迹、心率、海拔、爬升、分段分析。
7. GPX/FIT/TCX 导出。

## 后续调研清单

| 优先级 | 项目 | 目的 |
| --- | --- | --- |
| P0 | Apple Watch 实机验证 | 验证后台运动、定位、心率、路线同步和电量表现 |
| P0 | 华为 WATCH / GT 目标机型清单 | 明确优先验证 WATCH 数字系列和 WATCH GT 系列，而不是泛称支持华为 |
| P0 | 手机-手表组合矩阵 | 明确 iPhone/Android/华为手机与 Apple Watch/Wear OS/华为手表的支持边界 |
| P1 | Wear OS 实机验证 | 验证 Health Services、Data Layer、地图和电量表现 |
| P1 | Garmin Connect IQ/API 验证 | 验证 Courses API 路线/点位下发、Activity API 活动文件读取、Connect IQ Data Field 轻量导航/提醒能力 |
| P1 | 华为 Wear Engine Demo 验证 | 验证手机下发路线、手表回传状态 |
| P1 | 华为 Health Kit 数据权限验证 | 确认运动数据读取、写入和授权流程 |
| P1 | 离线地图方案评估 | 确认手表端瓦片大小、缓存策略和渲染性能 |
| P2 | Xiaomi Wear OS 机型验证 | 确认 Xiaomi Wear OS 手表是否可复用 Android 通用实现 |
| P2 | OPPO / OnePlus Wear OS 机型验证 | 确认 OPPO / OnePlus Wear OS 手表是否可复用 Android 通用实现 |
| P2 | vivo BlueOS 资料与 SDK 验证 | 确认是否能开发手表端第三方户外功能 |
| P3 | 小米非 Wear OS 机型合作验证 | 确认是否存在公开 SDK、应用商店和健康数据 API |
| P3 | OPPO 非 Wear OS 机型合作验证 | 确认是否存在公开 SDK、应用商店和健康数据 API |
| P3 | vivo 非 BlueOS 或非公开 SDK 机型合作验证 | 确认是否存在公开 SDK、应用商店和健康数据 API |
| P2 | Suunto Partner/SuuntoPlus 验证 | 评估路线、指南、活动数据和运动小应用接入 |
| P2 | COROS API 合作验证 | 确认是否可获得 API 权限及路线/活动同步范围 |

## 当前判断

如果目标用户是徒步人群，Apple Watch 仍然最适合作为首发 MVP 平台，用来验证完整自有手表 App 体验；Garmin/佳明应提升为第二优先级，因为它覆盖更专业的徒步和长线户外用户。Wear OS 适合覆盖 Android 通用智能手表用户，但要重点验证续航和地图能力。华为适合作为重点区域/生态平台推进，但必须先建立机型兼容矩阵，并通过实机验证确认可开发能力、权限、上架路径和手机联动效果。Suunto 和 COROS 暂按伙伴/API 接入处理，不进入首发自研手表 App 范围。
