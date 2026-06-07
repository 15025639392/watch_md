# Huawei validation demos

本目录用于沉淀 Apple Watch MVP 之后的华为生态验证工程骨架。当前只是验证工程，不进入首发 MVP。

更新日期：2026-06-06

## 工程拆分

| 工程 | 目标 | 技术路径 | 状态 |
| --- | --- | --- | --- |
| `huawei-watch-demo/` | WATCH 5 / WATCH 4 数字系列手表端 | `Wearable`、ArkTS、ArkUI、`.ets` | 骨架 |
| `huawei-gt-lite-demo/` | WATCH GT 6 / GT 5 手表端 | `liteWearable`、兼容 JS 的类 Web 范式、`.js` / `.html` / `.css` | 骨架 |
| `huawei-phone-sync-demo/harmonyos-phone-sync-demo/` | HarmonyOS / 华为手机侧路线同步 App | DevEco Studio、ArkTS / ArkUI、Wear Engine | 骨架 |
| `huawei-phone-sync-demo/android-phone-sync-demo/` | Android 手机侧路线同步 App | Kotlin、HMS Core Wear Engine Android SDK | 骨架 |
| `shared/` | 三个验证工程共享输入 | 路线 payload、ACK、测试清单、模型草案 | 骨架 |
| `real-project-setup-checklist.md` | 真实 DevEco / Android 工程迁移和 H0-H2 验证 | 环境快照、迁移步骤、阻塞条件 | 清单 |

注意：`.kt` 文件只属于 `android-phone-sync-demo`。它不是 WATCH 或 GT 手表端代码，也不代表 HarmonyOS 手机侧最终实现。WATCH 数字系列手表端使用 ArkTS / ArkUI；GT 系列手表端优先按 `liteWearable` 的类 Web / JS 范式验证；HarmonyOS / 华为手机侧使用独立 ArkTS 骨架。

## 手机侧也要分线

| 手机线 | 目标 | 工程策略 |
| --- | --- | --- |
| HarmonyOS / 华为手机线 | 验证华为生态内最完整链路，包含 Huawei Health、HMS Core、AppGallery、Wear Engine | `huawei-phone-sync-demo/harmonyos-phone-sync-demo/` |
| Android 手机线 | 验证非华为 Android 或通用 Android 手机能否通过 HMS Core / Wear Engine 稳定协同 | `huawei-phone-sync-demo/android-phone-sync-demo/` |
| iPhone 线 | 只做基础兼容观察 | 不作为深度华为手表联动主路径 |

共享内容应放在 `shared/`：路线 payload、ACK、状态模型、偏航规则和测试 checklist。手机端实现按系统分线，手表端实现按 WATCH / GT 分线。

## 当前边界

1. 不把 WATCH 和 GT 当成同一个手表端应用。
2. WATCH 数字系列优先验证完整手表 App。
3. GT 系列优先验证轻量手表 App 或手机协同链路。
4. 手机侧 Wear Engine Demo 负责路线下发、ACK 和状态同步。
5. 路线模型、GPX 解析、偏航规则和通信 payload 可以共享；手表端工程不要默认共享。

对应产品规格：

1. `../docs/huawei-watch-series-mvp-spec-v0.1.md`
2. `../docs/huawei-gt-series-mvp-spec-v0.1.md`

## 下一步

1. 按 `real-project-setup-checklist.md` 用 DevEco Studio 分别创建 `Wearable` 与 `liteWearable` 真实工程。
2. 把本目录中的 README、payload 和 TODO 迁入对应工程。
3. 在真实工程中接入 `LocalSimulationTransport`，保持本地协议回归入口。
4. 优先补齐 HarmonyOS / 华为手机线的 `WearEngineRouteTransport`。
5. 先用华为手机 + WATCH 5/4、华为手机 + GT 6/5 做 P0 真机验证。
6. 验证通过后再判断是否需要正式 AppGallery Connect 应用、内测和上架材料。

## 本地流程 Demo

不申请 Wear Engine / Health Kit，也不连接真机时，可以先跑本地模拟链路：

```sh
node huawei-validation/scripts/run-local-flow-demo.mjs
```

它会读取 `shared/route-payload.sample.json` 作为 WATCH 数字系列完整路线 payload，读取 `shared/gt-navigation-payload.sample.json` 作为 GT 系列轻量导航 payload，并输出两条线的 ACK 与状态回传。这个脚本用于验证 payload 和流程，不代表真实 Wear Engine 通信已经接通。

## 本地场景 Demo

无公司账号、无真机、无 Wear Engine 接入时，还可以先跑可重复的场景模拟：

```sh
node huawei-validation/scripts/run-local-scenario-demo.mjs
```

当前场景覆盖：

| 场景 | 用途 |
| --- | --- |
| `happy-path` | WATCH 完整路线与 GT 轻量导航均下发成功 |
| `watch-disconnected-retry` | WATCH 首次断连、重连后重试成功 |
| `gt-low-battery` | GT 可接收导航，但状态回传低电量警告 |
| `invalid-watch-payload` | WATCH payload 不合法时在传输前拒绝 |

脚本会输出：

| 文件 | 用途 |
| --- | --- |
| `generated/local-simulation/summary.json` | 场景数量、事件数量、warning / retry / rejected 摘要 |
| `generated/local-simulation/events.jsonl` | 每一步事件日志，后续真机 Wear Engine 验证可沿用同类记录格式 |
| `generated/local-simulation/report.md` | 可读验证报告，便于归档和与真机结果对照 |

这些文件证明的是本地协议和流程，不代表真实 Wear Engine 已经可用。

## 真实工程导入包

创建 DevEco Studio / Android Studio 真实工程前，可以先生成导入包：

```sh
node huawei-validation/scripts/prepare-real-project-import.mjs
```

脚本会输出 `huawei-validation/generated/real-project-import/`，按 WATCH、GT、HarmonyOS 手机、Android 手机和共享协议样本拆好目录，并生成 `MANIFEST.md`。这个目录是迁移辅助产物，真实工程仍应由 DevEco Studio / Android Studio 创建。

## 模拟器状态

本机已检测到 DevEco 的 `Huawei_Wearable` API 20-24 模板，但尚未下载 wearable/watch system image。无真机时，需要先在 DevEco Device Manager 创建 `Huawei_Wearable` API 24、466x466 模拟器并下载镜像。

检查命令：

```sh
bash scripts/check-huawei-watch-emulator.sh
```

## H0 Readiness

创建真实工程或下载手表镜像后，运行：

```sh
bash huawei-validation/scripts/check-h0-readiness.sh
```

它会检查 DevEco / Emulator、wearable system image、`hdc list targets`、真实工程导入包和本地 payload 流程。若仍提示 wearable system image 缺失，说明还不能用本机手表模拟器完成 H0。

手机侧骨架中已经把传输层拆成：

| 文件 | 作用 |
| --- | --- |
| `huawei-phone-sync-demo/harmonyos-phone-sync-demo/src/RouteTransport.ets` | HarmonyOS 手机线统一传输接口 |
| `huawei-phone-sync-demo/android-phone-sync-demo/src/RouteTransport.kt` | Android 手机线统一传输接口 |
| `LocalSimulationTransport` | 两条手机线各自保留本地模拟实现 |
| `WearEngineRouteTransport` | 两条手机线各自保留真实 Wear Engine 接入占位 |
| `RouteFlowRunner` | 下发路线、收 ACK、读状态的流程编排 |

下一步接真机时，优先补齐 `WearEngineRouteTransport`，保持 WATCH payload 与 `shared/route-payload.sample.json` 一致，GT payload 与 `shared/gt-navigation-payload.sample.json` 一致。
