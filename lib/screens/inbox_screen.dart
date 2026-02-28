// =============================================================================
// 收件箱
// =============================================================================
// 展示未完成且未删除的任务列表；FAB 新建任务写入收件箱；每项可勾选完成、点击进编辑；
// 进入编辑可删除（进垃圾箱）。依赖 ScheduleProvider.inboxTasks。
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/task.dart';
import '../providers/schedule_provider.dart';
import 'task_edit_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleProvider>().loadInbox();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('收件箱'),
      ),
      body: Consumer<ScheduleProvider>(
        builder: (context, provider, _) {
          final tasks = provider.inboxTasks;
          if (tasks.isEmpty) {
            return const Center(
              child: Text('暂无任务，点击右下角添加'),
            );
          }
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return ListTile(
                leading: Checkbox(
                  value: task.isCompleted,
                  onChanged: (value) =>
                      _toggleComplete(context, task, value ?? true),
                ),
                title: Text(task.title),
                subtitle: task.startTime != null
                    ? Text(
                        '开始: ${task.startTime!.toIso8601String().substring(0, 16)}')
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _openEdit(context, task),
                ),
                onTap: () => _openEdit(context, task),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTask(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _toggleComplete(
    BuildContext context,
    Task task,
    bool isCompleted,
  ) async {
    final updated = task.copyWith(
      isCompleted: isCompleted,
      updatedAt: DateTime.now(),
    );
    await context.read<ScheduleProvider>().saveTask(updated);
  }

  void _addTask(BuildContext context) {
    final task = Task(
      id: const Uuid().v4(),
      title: '',
      createdAt: DateTime.now(),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskEditScreen(task: task, isNew: true),
      ),
    );
  }

  void _openEdit(BuildContext context, Task task) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskEditScreen(task: task, isNew: false),
      ),
    );
  }
}
