# Slot 工程说明

本文档描述项目结构与各模块职责，详细注释已写入对应源码文件头部或关键方法处。

## 工程结构概览

```
lib/
├── main.dart                 # 入口：Hive、时区、通知初始化后 runApp(SlotApp)
├── app.dart                  # 根组件：MultiProvider + MaterialApp 路由与主题
├── models/
│   ├── task.dart             # 任务模型（含 reminderAt、listName、tags 等）
│   └── action.dart           # 子任务模型（parentTaskId 关联 Task）
├── repositories/
│   └── schedule_repository.dart  # 日程数据抽象 + Hive 本地实现
├── providers/
│   ├── schedule_provider.dart    # 收件箱/已完成/垃圾箱/按日期/标签/列表状态
│   └── theme_provider.dart       # 主题模式（明亮/黑暗/随系统）
├── services/
│   └── notification_service.dart # 本地提醒调度与取消
├── widgets/
│   ├── daily_timeline.dart   # 每日时间轴（24 小时、任务块、当前时刻红线）
│   ├── item_tile.dart        # 通用任务/子任务列表项
│   └── reminder_ui.dart      # 提醒/延迟入口占位 UI
└── screens/
    ├── home_screen.dart      # 首页入口列表
    ├── inbox_screen.dart     # 收件箱
    ├── list_screen.dart      # 列表视图（按 listName 分组）
    ├── tag_screen.dart       # 标签视图（按 tag 分组）
    ├── daily_screen.dart     # 每日视图（截止今日 + 未排入 + 时间轴）
    ├── completed_screen.dart # 已完成
    ├── trash_screen.dart     # 垃圾箱
    ├── settings_screen.dart  # 设置（主题等）
    ├── account_screen.dart   # 账号占位
    ├── task_edit_screen.dart # 任务编辑（含设置提醒、所属列表、标签）
    └── task_detail_screen.dart # 任务详情 / 拆分子任务
```

## 数据流

- **数据持久化**：`ScheduleRepository`（当前为 `LocalScheduleRepository`）负责 Task/Action 的 CRUD 与已知标签/列表名；Hive Box 存 JSON 字符串。
- **业务状态**：`ScheduleProvider` 持有收件箱、已完成、垃圾箱、按日任务、按截止日任务等列表，以及选中日期、已知标签/列表名；各页通过 `context.read/watch<ScheduleProvider>()` 使用。
- **主题**：`ThemeProvider` 持有 `ThemeMode`，设置页修改后 `MaterialApp.themeMode` 随之更新。
- **提醒**：任务编辑页保存时若 `reminderAt` 在未来则调用 `NotificationService.schedule`，清除或删除时调用 `NotificationService.cancel`。

## 路由

| 路径       | 页面       |
|------------|------------|
| `/`        | 首页       |
| `/inbox`   | 收件箱     |
| `/list`    | 列表视图   |
| `/tag`     | 标签视图   |
| `/daily`   | 每日视图   |
| `/completed` | 已完成   |
| `/trash`   | 垃圾箱     |
| `/settings` | 设置     |
| `/account` | 账号       |

新建/编辑任务、任务详情、子任务编辑均通过 `Navigator.push` 打开，未写入命名路由。

## 源码注释说明

- 每个 Dart 文件顶部已增加 **文件级注释**（`// ======...` 块），说明该文件职责、依赖与使用场景。
- 模型、仓库、Provider、服务、部分 Screen 的关键方法或字段配有 **行内/块注释**（如 `/// 收件箱：未完成且未删除`）。
- 阅读时可优先查看文件头注释，再按需查看具体方法旁的备注。
