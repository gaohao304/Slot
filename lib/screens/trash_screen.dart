// =============================================================================
// 垃圾箱
// =============================================================================
// 展示已软删除的任务（ScheduleProvider.trashTasks）；支持恢复、永久删除。
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/schedule_provider.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleProvider>().loadTrash();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('垃圾箱'),
      ),
      body: Consumer<ScheduleProvider>(
        builder: (context, provider, _) {
          final tasks = provider.trashTasks;
          if (tasks.isEmpty) {
            return const Center(child: Text('垃圾箱为空'));
          }
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return ListTile(
                title: Text(task.title),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () =>
                          provider.restoreTask(task),
                      child: const Text('恢复'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('彻底删除'),
                            content: const Text('确定要彻底删除该任务吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('删除'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          provider.deleteTaskPermanently(task.id);
                        }
                      },
                      child: const Text('彻底删除'),
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
}
