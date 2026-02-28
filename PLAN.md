# Slot 开发计划

## 1. 项目概述

- **项目名**：Slot（日程管理应用）
- **技术栈**：Flutter、Provider、Hive、intl、uuid

## 2. 工程文件架构说明

| 目录/文件 | 职责 |
|-----------|------|
| `lib/models/` | Task、Action 数据模型 |
| `lib/repositories/` | ScheduleRepository 抽象与 LocalScheduleRepository（Hive）实现 |
| `lib/providers/` | ScheduleProvider（状态与业务入口） |
| `lib/screens/` | 各页面：Home、Inbox、List、Tag、Daily、Completed、Trash、Account、Settings、TaskDetail、TaskEdit |
| `lib/widgets/` | daily_timeline、item_tile、reminder_ui 等可复用组件 |
| `lib/app.dart` | 路由与 MultiProvider 注入 |

## 3. 数据流与职责

- **数据流**：UI → Provider → Repository → Hive
- **Repository 抽象**：便于后续接入云端同步（可新增 ScheduleRepository 的远程实现）

## 4. 可选后续规划

- **测试**：扩充 `test/widget_test.dart`，覆盖核心组件与业务逻辑
- **云端同步**：实现 ScheduleRepository 的远程实现，与本地 Hive 协同
- **国际化 / 无障碍**：按需引入 intl 文案与语义化标签
