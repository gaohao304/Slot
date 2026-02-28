// =============================================================================
// 通用列表项（任务/子任务）
// =============================================================================
// 用于列表视图、标签视图等：展示 title、subtitle（开始时间或标签等）、可选 trailing。
// =============================================================================

import 'package:flutter/material.dart';

import '../models/action.dart' as slot_models;
import '../models/task.dart';

/// 列表/标签用条目展示（Task 或 Action 二选一）
class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    this.task,
    this.action,
    this.onTap,
    this.trailing,
  }) : assert(task != null || action != null);

  final Task? task;
  final slot_models.Action? action;
  final VoidCallback? onTap;
  final Widget? trailing;

  String get _title => task?.title ?? action!.title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(_title),
      subtitle: _buildSubtitle(),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget? _buildSubtitle() {
    if (task != null) {
      final t = task!;
      if (t.startTime != null) {
        return Text('开始: ${t.startTime!.toIso8601String().substring(0, 16)}');
      }
      if (t.tags.isNotEmpty) return Text('标签: ${t.tags.join(", ")}');
    }
    if (action != null) {
      final a = action!;
      if (a.startTime != null) {
        return Text('${a.startTime!.toIso8601String().substring(0, 16)} · ${a.durationMinutes} 分钟');
      }
    }
    return null;
  }
}
