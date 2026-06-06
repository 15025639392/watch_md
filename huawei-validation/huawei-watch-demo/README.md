# huawei-watch-demo

目标：验证 HUAWEI WATCH 数字系列的完整手表 App 路径。

## 目标设备

- 优先：HUAWEI WATCH 5
- 备选：HUAWEI WATCH 4

## 技术路径

| 项 | 选择 |
| --- | --- |
| 设备类型 | 智能可穿戴设备 |
| DevEco 模板 | `Wearable` |
| 主要语言 | ArkTS |
| UI | ArkUI |
| 工程目标 | 完整手表 App Demo |

## 首轮功能

1. Demo 首页显示路线名称、路线距离和同步状态。
2. 接收手机侧 Wear Engine 下发的路线 JSON。
3. 手表侧落本地后回 ACK。
4. 显示路线线框、当前位置占位和偏航状态占位。
5. 验证震动、通知、定位、息屏和后台表现。

## 骨架文件

| 文件 | 用途 |
| --- | --- |
| `src/MainPage.ets` | ArkTS / ArkUI 首页占位 |
| `src/RouteModels.ets` | 路线 payload 类型草案 |
| `src/WearEngineBridge.ets` | Wear Engine 通信桥接占位 |
| `app-manifest-notes.md` | DevEco / AGC 配置记录 |
| `TODO.md` | 待 DevEco 真实工程补齐项 |

## 注意

当前目录不是完整 DevEco 工程。用 DevEco Studio 创建真实 `Wearable` 工程后，把本目录中的源文件和说明迁入工程对应目录。

