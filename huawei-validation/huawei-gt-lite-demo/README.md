# huawei-gt-lite-demo

目标：验证 HUAWEI WATCH GT 系列的轻量手表应用或手机协同路径。

## 目标设备

- 优先：HUAWEI WATCH GT 6
- 备选：HUAWEI WATCH GT 5

## 技术路径

| 项 | 选择 |
| --- | --- |
| 设备类型 | 轻量级智能可穿戴设备 |
| DevEco 模板 | `liteWearable`，以目标机型支持为准 |
| 主要语言 | 兼容 JS 的类 Web 范式 |
| 工程目标 | 轻量路线提醒 / 偏航提醒 Demo |

## 首轮功能

1. 显示路线名称、下一关键点和偏航状态。
2. 接收手机侧下发的路线摘要或关键点列表。
3. 回传 ACK 和轻量状态。
4. 验证震动 / 通知 / 息屏 / 长续航表现。
5. 如果目标 GT 机型不能安装自研 App，则退回手机侧 Wear Engine 协同验证。

## 骨架文件

| 文件 | 用途 |
| --- | --- |
| `src/index.js` | 轻量页面逻辑占位 |
| `src/index.css` | 轻量页面样式占位 |
| `src/index.html` | 类 Web UI 占位 |
| `app-manifest-notes.md` | DevEco / AGC 配置记录 |
| `TODO.md` | 待 DevEco 真实工程补齐项 |

## 注意

当前目录不是完整 DevEco 工程。GT 系列是否支持目标自研 App、是否需要从华为运动健康 App 侧安装、是否只能做手机协同，都必须以真机和 AGC 后台验证为准。

