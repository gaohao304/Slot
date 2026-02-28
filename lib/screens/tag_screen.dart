// =============================================================================
// 标签视图
// =============================================================================
// 按标签分组展示任务；可新增/编辑/删除标签（删除会从所有任务移除该标签）；
// 任务编辑页的标签与此处已知标签同步。依赖 ScheduleProvider.knownTagNames、getTasksByTag。
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/schedule_provider.dart';
import 'task_edit_screen.dart';

class TagScreen extends StatefulWidget {
  const TagScreen({super.key});

  @override
  State<TagScreen> createState() => _TagScreenState();
}

class _TagScreenState extends State<TagScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleProvider>().loadKnownTagNames();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('标签视图'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddTagDialog(context),
            tooltip: '新增标签',
          ),
        ],
      ),
      body: Consumer<ScheduleProvider>(
        builder: (context, provider, _) {
          final fromTasks = <String>{};
          for (final t in provider.inboxTasks) {
            fromTasks.addAll(t.tags);
          }
          final allTags = <String>{
            ...provider.knownTagNames,
            ...fromTasks,
          }.toList()..sort();

          if (allTags.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '暂无标签',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _showAddTagDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('新增标签'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: allTags.length,
            itemBuilder: (context, index) {
              final tag = allTags[index];
              return _TagSection(
                key: ValueKey('$tag-${provider.inboxTasks.length}'),
                tag: tag,
                provider: provider,
                onEdit: () => _showEditTagDialog(context, provider, tag),
                onDelete: () => _showDeleteTagDialog(context, provider, tag),
                onTaskTap: (task) => _openTaskEdit(context, task),
              );
            },
          );
        },
      ),
    );
  }

  void _openTaskEdit(BuildContext context, Task task) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskEditScreen(task: task, isNew: false),
      ),
    );
  }

  Future<void> _showAddTagDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增标签'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '标签名称',
            border: OutlineInputBorder(),
            hintText: '输入新标签',
          ),
          autofocus: true,
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && context.mounted) {
      await context.read<ScheduleProvider>().addKnownTagName(result);
    }
  }

  Future<void> _showEditTagDialog(
    BuildContext context,
    ScheduleProvider provider,
    String oldName,
  ) async {
    final controller = TextEditingController(text: oldName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑标签'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '标签名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty && result != oldName && context.mounted) {
      await provider.renameTag(oldName, result.trim());
    }
  }

  Future<void> _showDeleteTagDialog(
    BuildContext context,
    ScheduleProvider provider,
    String tag,
  ) async {
    final tasks = await provider.getTasksByTag(tag);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除标签'),
        content: Text(
          tasks.isEmpty
              ? '确定要删除标签「$tag」吗？'
              : '删除标签「$tag」后，将从 ${tasks.length} 个任务中移除此标签。确定继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await provider.deleteTag(tag);
    }
  }
}

class _TagSection extends StatelessWidget {
  const _TagSection({
    super.key,
    required this.tag,
    required this.provider,
    required this.onEdit,
    required this.onDelete,
    required this.onTaskTap,
  });

  final String tag;
  final ScheduleProvider provider;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(Task task) onTaskTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Task>>(
      future: provider.getTasksByTag(tag),
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Theme.of(context).cardColor,
              child: ListTile(
                leading: const Icon(Icons.label_outline),
                title: Text(
                  tag,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: onEdit,
                      tooltip: '编辑标签',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: onDelete,
                      tooltip: '删除标签',
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: tasks.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '该标签下暂无任务',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tasks.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return ListTile(
                          title: Text(task.title),
                          subtitle: task.startTime != null
                              ? Text(
                                  '开始: ${task.startTime!.toIso8601String().substring(0, 16)}',
                                )
                              : null,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => onTaskTap(task),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
