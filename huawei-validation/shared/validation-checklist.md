# Huawei validation checklist

更新日期：2026-06-06

## 必填设备信息

| 项 | 记录 |
| --- | --- |
| 手表型号 |  |
| 手表系统版本 |  |
| 手机型号 |  |
| 手机系统版本 |  |
| Huawei Health 版本 |  |
| HMS Core 版本 |  |
| AppGallery / AGC 地区 |  |
| 华为账号地区 |  |

## P0 验证

| 项 | WATCH 数字系列 | GT 系列 |
| --- | --- | --- |
| DevEco 可创建目标工程 |  |  |
| 可调试安装 Demo |  |  |
| 可打开 Demo 首页 |  |  |
| 手机可发现目标手表 |  |  |
| 手机可下发 WATCH 路线 JSON |  | 不适用 |
| 手机可下发 GT 轻量导航 JSON | 不适用 |  |
| 手表可回 ACK |  |  |
| 手表可回传电量 / 佩戴 / 连接状态 |  |  |
| GT 可展示路线状态 / 下一个关键点 | 不适用 |  |
| WATCH 可绘制简化路线或自绘兜底 |  | 不适用 |
| 偏航提醒可触发震动或通知 |  |  |
| 息屏后 30 分钟记录表现 |  |  |

## H0-H2 本地验证

| 项 | 预期 |
| --- | --- |
| 本地脚本可读取 WATCH payload | `node huawei-validation/scripts/run-local-flow-demo.mjs` 成功 |
| 本地脚本可读取 GT payload | `node huawei-validation/scripts/run-local-flow-demo.mjs` 成功 |
| WATCH ACK 包含 `storedPointCount` | 大于等于 2 |
| GT ACK 包含 `storedWaypointCount` | 大于等于 2 |
| WATCH / GT 状态区分 `deviceLine` | 分别为 `WATCH` 和 `GT` |

## 结论

| 项 | 结论 |
| --- | --- |
| 是否支持自研手表 App |  |
| 是否必须走手机协同 |  |
| 是否具备进入下一轮开发价值 |  |
| 阻塞项 |  |
