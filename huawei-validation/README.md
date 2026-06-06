# Huawei validation demos

本目录用于沉淀 Apple Watch MVP 之后的华为生态验证工程骨架。当前只是验证工程，不进入首发 MVP。

更新日期：2026-06-06

## 工程拆分

| 工程 | 目标 | 技术路径 | 状态 |
| --- | --- | --- | --- |
| `huawei-watch-demo/` | WATCH 5 / WATCH 4 数字系列 | `Wearable`、ArkTS、ArkUI | 骨架 |
| `huawei-gt-lite-demo/` | WATCH GT 6 / GT 5 | `liteWearable`、兼容 JS 的类 Web 范式；必要时退回手机协同 | 骨架 |
| `huawei-phone-sync-demo/` | 华为手机 / 非华为 Android 手机侧 | Android / HarmonyOS 手机 App + Wear Engine | 骨架 |
| `shared/` | 三个验证工程共享输入 | 路线 payload、ACK、测试清单、模型草案 | 骨架 |

## 当前边界

1. 不把 WATCH 和 GT 当成同一个手表端应用。
2. WATCH 数字系列优先验证完整手表 App。
3. GT 系列优先验证轻量手表 App 或手机协同链路。
4. 手机侧 Wear Engine Demo 负责路线下发、ACK 和状态同步。
5. 路线模型、GPX 解析、偏航规则和通信 payload 可以共享；手表端工程不要默认共享。

## 下一步

1. 用 DevEco Studio 分别创建 `Wearable` 与 `liteWearable` 真实工程。
2. 把本目录中的 README、payload 和 TODO 迁入对应工程。
3. 先用华为手机 + WATCH 5/4、华为手机 + GT 6/5 做 P0 真机验证。
4. 验证通过后再判断是否需要正式 AppGallery Connect 应用、内测和上架材料。

