// =============================================================================
// 列表视图
// =============================================================================
// 按“所属列表”分组展示任务；可新增/重命名/删除列表；进入某列表后展示该 listName 任务，
// FAB 可在该列表下新建任务；任务编辑页可选择或新建所属列表。
// 依赖 ScheduleProvider.knownListNames、getTasksByList。
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/task.dart';
import '../providers/schedule_provider.dart';
import 'task_edit_screen.dart';

class ListScreen extends StatefulWidget {
  const ListScreen({super.key});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
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
        title: const Text('列表视图'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新增列表',
            onPressed: () => _addList(context),
          ),
        ],
      ),
      body: Consumer<ScheduleProvider>(
        builder: (context, provider, _) {
          final fromTasks = <String>{};
          for (final t in provider.inboxTasks) {
            if (t.listName != null && t.listName!.isNotEmpty) {
              fromTasks.add(t.listName!);
            }
          }
          final allLists = <String>{
            ...provider.knownListNames,
            ...fromTasks,
          }.toList()
            ..sort();

          if (allLists.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '暂无列表',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _addList(context),
                    icon: const Icon(Icons.add),
                    label: const Text('新增列表'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: allLists.length,
            itemBuilder: (context, index) {
              final listName = allLists[index];
              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(listName),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: '重命名列表',
                      onPressed: () => _editList(context, listName),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      tooltip: '删除列表',
                      onPressed: () => _deleteList(context, listName),
                    ),
                  ],
                ),
                onTap: () async {
                  final tasks = await provider.getTasksByList(listName);
                  if (!context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _ListTasksScreen(
                        listName: listName,
                        tasks: tasks,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addList(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新增列表'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '列表名称',
            border: OutlineInputBorder(),
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
    if (result != null &&
        result.trim().isNotEmpty &&
        context.mounted) {
      await context.read<ScheduleProvider>().addKnownListName(result.trim());
    }
  }
}

  Future<void> _editList(BuildContext context, String oldName) async {
    final controller = TextEditingController(text: oldName);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重命名列表'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '列表名称',
            border: OutlineInputBorder(),
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
    if (result != null &&
        result.trim().isNotEmpty &&
        result.trim() != oldName &&
        context.mounted) {
      await context
          .read<ScheduleProvider>()
          .renameList(oldName, result.trim());
    }
  }

  Future<void> _deleteList(BuildContext context, String name) async {
    final provider = context.read<ScheduleProvider>();
    final tasks = await provider.getTasksByList(name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除列表'),
        content: Text(
          tasks.isEmpty
              ? '确定要删除列表「$name」吗？'
              : '删除列表「$name」后，将从 ${tasks.length} 个任务中清除此列表归属，任务本身不会被删除。确定继续？',
        ),
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
      await provider.deleteList(name);
    }
}

class _ListTasksScreen extends StatefulWidget {
  const _ListTasksScreen({
    required this.listName,
    required this.tasks,
  });

  final String listName;
  final List<Task> tasks;

  @override
  State<_ListTasksScreen> createState() => _ListTasksScreenState();
}

class _ListTasksScreenState extends State<_ListTasksScreen> {
  late List<Task> _tasks;

  @override
  void initState() {
    super.initState();
    _tasks = List.from(widget.tasks);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listName),
      ),
      body: _tasks.isEmpty
          ? const Center(child: Text('该列表下暂无任务'))
          : ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return ListTile(
                  title: Text(task.title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TaskEditScreen(
                          task: task,
                          isNew: false,
                        ),
                      ),
                    );
                    await _reload();
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _reload() async {
    final provider = context.read<ScheduleProvider>();
    final tasks = await provider.getTasksByList(widget.listName);
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
    });
  }

  Future<void> _addTask() async {
    final task = Task(
      id: const Uuid().v4(),
      title: '',
      listName: widget.listName,
      createdAt: DateTime.now(),
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskEditScreen(task: task, isNew: true),
      ),
    );
    await _reload();
  }
}
