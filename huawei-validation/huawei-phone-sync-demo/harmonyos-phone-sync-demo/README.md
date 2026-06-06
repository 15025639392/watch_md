# harmonyos-phone-sync-demo

目标：验证 HarmonyOS / 华为手机通过 Wear Engine 与 WATCH / GT 的最完整华为生态协同链路。

## 技术路径

| 项 | 选择 |
| --- | --- |
| 手机线 | HarmonyOS / 华为手机线 |
| 工具 | DevEco Studio |
| 语言 / UI | ArkTS / ArkUI，具体以目标 HarmonyOS 手机应用模板为准 |
| SDK | HarmonyOS / HMS SDK，Wear Engine |
| 优先级 | P0 |

## 首轮功能

1. 发现已配对 WATCH / GT。
2. 向 WATCH 下发 `shared/route-payload.sample.json` 对应的完整路线 payload。
3. 向 GT 下发 `shared/gt-navigation-payload.sample.json` 对应的轻量导航 payload。
4. 接收 WATCH / GT ACK。
5. 读取或接收手表状态。
6. 记录 Huawei Health、HMS Core、AppGallery、账号地区和设备系统版本。

## 骨架文件

| 文件 | 用途 |
| --- | --- |
| `src/RoutePayload.ets` | 路线 payload、ACK、状态类型草案 |
| `src/RouteTransport.ets` | 手机到手表传输层接口 |
| `src/LocalSimulationTransport.ets` | 本地模拟传输 |
| `src/WearEngineRouteTransport.ets` | 真实 Wear Engine 接入占位 |
| `src/RouteFlowRunner.ets` | 下发路线、收 ACK、读状态流程编排 |
| `app-manifest-notes.md` | DevEco / AGC 配置记录 |
| `TODO.md` | 待真实 HarmonyOS 手机工程补齐项 |

## 注意

当前目录不是完整 DevEco 工程。真实开发时，用 DevEco Studio 创建 HarmonyOS 手机应用工程，再迁入这些骨架文件。
