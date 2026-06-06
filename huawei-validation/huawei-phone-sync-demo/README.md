# huawei-phone-sync-demo

目标：验证手机侧通过 Wear Engine 向 WATCH / GT 下发路线并接收 ACK / 状态。

本工程是手机侧总入口，下面分为 HarmonyOS / 华为手机线和 Android 手机线。`.kt` 文件只在 Android 子工程里；HarmonyOS 手机侧使用独立 ArkTS 骨架。

它不是 WATCH 或 GT 手表端工程：

| 目录 | 端 | 语言 / 文件 |
| --- | --- | --- |
| `../huawei-watch-demo/` | WATCH 数字系列手表端 | ArkTS / ArkUI，`.ets` |
| `../huawei-gt-lite-demo/` | GT 系列手表端 | `liteWearable` 类 Web / JS，`.js` / `.html` / `.css` |
| `./harmonyos-phone-sync-demo/` | HarmonyOS / 华为手机侧同步端 | ArkTS / ArkUI，`.ets` |
| `./android-phone-sync-demo/` | Android 手机侧同步端 | Kotlin，`.kt` |

## 手机侧分线

| 手机线 | 验证重点 | 当前状态 |
| --- | --- | --- |
| HarmonyOS / 华为手机 | 华为生态内 Wear Engine、Huawei Health、HMS Core、AppGallery 的完整链路 | `harmonyos-phone-sync-demo/` 骨架 |
| Android 手机 | 非华为 Android 或通用 Android + HMS Core / Wear Engine 可用性 | `android-phone-sync-demo/` 骨架 |
| iPhone | 基础配对、通知、健康兼容观察 | 暂不作为深度联动主路径 |

## 目标手机

- 优先：华为手机
- 扩展：非华为 Android
- 观察：iPhone 基础兼容，不作为深度联动主路径

## 技术路径

| 项 | 选择 |
| --- | --- |
| 手机平台 | HarmonyOS / 华为手机 App、Android 手机 App |
| 通信能力 | Wear Engine |
| WATCH 首轮 payload | `../shared/route-payload.sample.json` |
| GT 首轮 payload | `../shared/gt-navigation-payload.sample.json` |
| 首轮返回 | `routeAck`、`watchStatus` |

## 首轮功能

1. 发现已配对的目标手表。
2. 区分 WATCH 数字系列和 GT 系列。
3. 向 WATCH 下发完整路线 JSON。
4. 向 GT 下发轻量导航 JSON。
5. 接收 ACK。
6. 接收电量、佩戴、连接和记录状态。
7. 记录华为手机、非华为 Android、iPhone 的差异。

## 本地流程模拟

真实 Wear Engine 接入前，先在仓库根目录运行：

```sh
node huawei-validation/scripts/run-local-flow-demo.mjs
```

该脚本模拟手机侧分别读取 WATCH 路线 payload 和 GT 轻量导航 payload，并向 WATCH Demo 和 GT Lite Demo 下发，生成 ACK 和状态回传。

## 骨架文件

| 文件 / 目录 | 用途 |
| --- | --- |
| `harmonyos-phone-sync-demo/` | HarmonyOS / 华为手机侧 ArkTS 骨架 |
| `android-phone-sync-demo/` | Android 手机侧 Kotlin 骨架 |
| `app-build-notes.md` | Gradle / AGC 配置记录 |
| `TODO.md` | 待真实 Android 工程补齐项 |

## 注意

当前目录不是完整 Android / HarmonyOS 手机工程。真实工程创建后，需要分别接入 DevEco / Android 工程、AGC 配置文件和 Wear Engine SDK。

本地模拟和真实 Wear Engine 接入应共享 `RouteTransport` 接口。两条手机线都保留 `LocalSimulationTransport` 做协议回归；接入真机时只替换为各自的 `WearEngineRouteTransport`。
