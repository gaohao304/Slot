// =============================================================================
// 任务详情 / 拆分子任务
// =============================================================================
// 展示任务标题、备注；子任务列表（可勾选完成、编辑标题、删除）；可添加子任务；
// 从任务编辑页“查看详情”进入。子任务为 Action 模型，parentTaskId 指向当前 Task。
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/action.dart' as slot_models;
import '../models/task.dart';
import '../providers/schedule_provider.dart';

class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务详情'),
      ),
      body: Consumer<ScheduleProvider>(
        builder: (context, provider, _) {
          return FutureBuilder<List<slot_models.Action>>(
            future: provider.getActionsByTaskId(task.id),
            builder: (context, snapshot) {
              final actions = snapshot.data ?? [];
              return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (task.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('备注', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(task.notes),
                ],
                const SizedBox(height: 16),
                const Text('子任务', style: TextStyle(fontWeight: FontWeight.bold)),
                ...actions.map(
                  (a) => ListTile(
                    leading: Checkbox(
                      value: a.isCompleted,
                      onChanged: (_) => _toggleSubTaskComplete(context, a),
                    ),
                    title: GestureDetector(
                      onTap: () => _editSubTaskTitle(context, a),
                      child: Text(
                        a.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: a.isCompleted
                            ? const TextStyle(
                                decoration: TextDecoration.lineThrough,
                              )
                            : null,
                      ),
                    ),
                    subtitle: a.startTime != null
                        ? Text(
                            '${a.startTime!.toIso8601String().substring(0, 16)} · ${a.durationMinutes} 分钟',
                          )
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: '删除子任务',
                      onPressed: () => _deleteSubTask(context, a),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _addSubTask(context),
                  icon: const Icon(Icons.add),
                  label: const Text('添加子任务'),
                ),
              ],
            ),
          );
            },
          );
        },
      ),
    );
  }

  void _addSubTask(BuildContext context) async {
    final action = slot_models.Action(
      id: const Uuid().v4(),
      parentTaskId: task.id,
      title: '新子任务',
      createdAt: DateTime.now(),
    );
    await context.read<ScheduleProvider>().saveAction(action);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已添加子任务，可在编辑中设置时间')),
      );
    }
  }

  void _toggleSubTaskComplete(BuildContext context, slot_models.Action action) {
    context.read<ScheduleProvider>().saveAction(
          action.copyWith(
            isCompleted: !action.isCompleted,
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<void> _editSubTaskTitle(
    BuildContext context,
    slot_models.Action action,
  ) async {
    final controller = TextEditingController(text: action.title);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑子任务名称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '请输入子任务名称',
          ),
          autofocus: true,
          onSubmitted: (text) =>
              Navigator.pop(dialogContext, text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && context.mounted) {
      await context.read<ScheduleProvider>().saveAction(
            action.copyWith(
              title: result,
              updatedAt: DateTime.now(),
            ),
          );
    }
  }

  Future<void> _deleteSubTask(
    BuildContext context,
    slot_models.Action action,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除子任务'),
        content: const Text('确认删除该子任务吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<ScheduleProvider>().moveActionToTrash(action);
    }
  }
}
