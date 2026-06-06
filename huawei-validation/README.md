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

1. 先运行本地流程 Demo，确认协议能从手机侧下发到 WATCH / GT 两条线。
2. 用 DevEco Studio 分别创建 `Wearable` 与 `liteWearable` 真实工程。
3. 把本目录中的 README、payload 和 TODO 迁入对应工程。
4. 先用华为手机 + WATCH 5/4、华为手机 + GT 6/5 做 P0 真机验证。
5. 验证通过后再判断是否需要正式 AppGallery Connect 应用、内测和上架材料。

## 本地流程 Demo

不申请 Wear Engine / Health Kit，也不连接真机时，可以先跑本地模拟链路：

```sh
node huawei-validation/scripts/run-local-flow-demo.mjs
```

它会读取 `shared/route-payload.sample.json`，模拟手机侧分别向 `huawei-watch-demo` 和 `huawei-gt-lite-demo` 下发路线，并输出两条线的 ACK 与状态回传。这个脚本用于验证 payload 和流程，不代表真实 Wear Engine 通信已经接通。

手机侧骨架中已经把传输层拆成：

| 文件 | 作用 |
| --- | --- |
| `huawei-phone-sync-demo/harmonyos-phone-sync-demo/src/RouteTransport.ets` | HarmonyOS 手机线统一传输接口 |
| `huawei-phone-sync-demo/android-phone-sync-demo/src/RouteTransport.kt` | Android 手机线统一传输接口 |
| `LocalSimulationTransport` | 两条手机线各自保留本地模拟实现 |
| `WearEngineRouteTransport` | 两条手机线各自保留真实 Wear Engine 接入占位 |
| `RouteFlowRunner` | 下发路线、收 ACK、读状态的流程编排 |

下一步接真机时，优先补齐 `WearEngineRouteTransport`，保持 payload 与 `shared/route-payload.sample.json` 一致。
