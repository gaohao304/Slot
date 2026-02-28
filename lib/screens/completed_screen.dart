// =============================================================================
// 已完成
// =============================================================================
// 展示已勾选完成的任务列表（ScheduleProvider.completedTasks）；每项可点击进编辑、
// 取消完成或删除；返回后刷新列表。
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/schedule_provider.dart';
import 'task_edit_screen.dart';

class CompletedScreen extends StatefulWidget {
  const CompletedScreen({super.key});

  @override
  State<CompletedScreen> createState() => _CompletedScreenState();
}

class _CompletedScreenState extends State<CompletedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleProvider>().loadCompleted();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('已完成'),
      ),
      body: Consumer<ScheduleProvider>(
        builder: (context, provider, _) {
          final tasks = provider.completedTasks;
          if (tasks.isEmpty) {
            return const Center(child: Text('暂无已完成任务'));
          }
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(task.title),
                onTap: () async {
                  final t = await provider.getTaskById(task.id);
                  if (t != null && context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TaskEditScreen(task: t, isNew: false),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
