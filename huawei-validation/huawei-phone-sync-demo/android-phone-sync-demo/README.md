# android-phone-sync-demo

目标：验证非华为 Android 或通用 Android 手机通过 HMS Core / Wear Engine 与 WATCH / GT 协同。

## 技术路径

| 项 | 选择 |
| --- | --- |
| 手机线 | Android 手机线 |
| 语言 | Kotlin |
| SDK | HMS Core Wear Engine Android SDK |
| 优先级 | P1 |

## 骨架文件

| 文件 | 用途 |
| --- | --- |
| `src/RoutePayload.kt` | 路线 payload、ACK、状态类型草案 |
| `src/RouteTransport.kt` | 手机到手表传输层接口 |
| `src/LocalSimulationTransport.kt` | 本地模拟传输 |
| `src/WearEngineRouteTransport.kt` | 真实 Wear Engine 接入占位 |
| `src/RouteFlowRunner.kt` | 下发路线、收 ACK、读状态流程编排 |

## 下一步

1. 创建真实 Android 工程。
2. 配置华为 Maven 仓和 AGC 应用。
3. 下载 `agconnect-services.json`。
4. 接入 Wear Engine SDK。
5. 补齐 `WearEngineRouteTransport` 中 WATCH 完整路线 payload 和 GT 轻量导航 payload 两条发送路径。
