# huawei-phone-sync-demo

目标：验证手机侧通过 Wear Engine 向 WATCH / GT 下发路线并接收 ACK / 状态。

## 目标手机

- 优先：华为手机
- 扩展：非华为 Android
- 观察：iPhone 基础兼容，不作为深度联动主路径

## 技术路径

| 项 | 选择 |
| --- | --- |
| 手机平台 | Android / HarmonyOS 手机 App |
| 通信能力 | Wear Engine |
| 首轮 payload | `../shared/route-payload.sample.json` |
| 首轮返回 | `routeAck`、`watchStatus` |

## 首轮功能

1. 发现已配对的目标手表。
2. 区分 WATCH 数字系列和 GT 系列。
3. 下发路线 JSON 或 GPX 文件。
4. 接收 ACK。
5. 接收电量、佩戴、连接和记录状态。
6. 记录华为手机、非华为 Android、iPhone 的差异。

## 骨架文件

| 文件 | 用途 |
| --- | --- |
| `src/WearEngineClient.kt` | Android / Kotlin 手机侧通信占位 |
| `src/RoutePayload.kt` | 路线 payload 类型草案 |
| `app-build-notes.md` | Gradle / AGC 配置记录 |
| `TODO.md` | 待真实 Android 工程补齐项 |

## 注意

当前目录不是完整 Android / HarmonyOS 手机工程。真实工程创建后，需要接入华为 Maven 仓、AGC 配置文件和 Wear Engine SDK。

