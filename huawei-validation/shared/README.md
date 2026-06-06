# Shared validation assets

本目录放 WATCH、GT 和手机侧验证工程共享的协议草案、测试 payload 和检查清单。

## 文件

| 文件 | 用途 |
| --- | --- |
| `route-payload.sample.json` | 手机下发给 WATCH 数字系列的完整路线验证 JSON |
| `gt-navigation-payload.sample.json` | 手机下发给 GT 系列的轻量导航协同 JSON |
| `route-ack.sample.json` | 手表收到路线后的 ACK 示例，WATCH / GT 可按字段裁剪 |
| `watch-status.sample.json` | 手表回传状态示例 |
| `validation-checklist.md` | WATCH / GT / 手机侧共同测试清单 |

## 协议边界

1. WATCH 数字系列优先接收可绘制、可偏航匹配的简化路线点。
2. GT 系列优先接收路线摘要、关键点、转向提示和偏航阈值；简化几何只是可选验证字段。
3. ACK、状态和控制事件保持同一套命名，便于手机侧复用流程编排。
4. 本目录中的 JSON 只证明本地协议结构，不代表 Wear Engine 真机链路已经接通。
