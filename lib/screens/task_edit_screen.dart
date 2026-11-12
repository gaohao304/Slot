// =============================================================================
// 任务编辑
// =============================================================================
// 新建/编辑任务：标题、计划开始时间、随时开关、持续时间、截止时间、设置提醒、
// 所属列表、标签、备注；保存时写入 reminderAt 并调度/取消本地通知；删除进垃圾箱。
// 底部可跳转“任务详情/拆分子任务”。依赖 ScheduleProvider、NotificationService。
// =============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/schedule_provider.dart';
import '../services/notification_service.dart';
import 'task_detail_screen.dart';

class TaskEditScreen extends StatefulWidget {
  const TaskEditScreen({
    super.key,
    required this.task,
    required this.isNew,
  });

  final Task task;
  final bool isNew;

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  DateTime? _startTime;
  int _durationMinutes = 30;
  bool _anytime = false;
  DateTime? _deadline;
  DateTime? _reminderAt;
  List<String> _tags = [];
  String? _listName;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _notesController = TextEditingController(text: widget.task.notes);
    final originalStart = widget.task.startTime;
    final originalDuration = widget.task.durationMinutes;
    _anytime = originalDuration == 0;
    _startTime = originalStart;
    _durationMinutes = _anytime ? 30 : originalDuration;
    _deadline = widget.task.deadline;
    _reminderAt = widget.task.reminderAt;
    _tags = List.from(widget.task.tags);
    _listName = widget.task.listName;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ScheduleProvider>();
      provider.loadKnownTagNames();
      provider.loadInbox();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? '新建任务' : '编辑任务'),
        actions: [
          if (!widget.isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除任务',
              onPressed: _deleteTask,
            ),
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('随时'),
              subtitle: const Text('没有固定开始时间，出现在当天列表顶部'),
              trailing: Switch.adaptive(
                value: _anytime,
                onChanged: (value) => setState(() => _anytime = value),
              ),
            ),
            ListTile(
              title: const Text('计划开始时间'),
              subtitle: Text(
                _startTime != null
                    ? DateFormat('yyyy-MM-dd HH:mm').format(_startTime!)
                    : '未设置',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startTime ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null && mounted) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _startTime != null
                        ? TimeOfDay.fromDateTime(_startTime!)
                        : TimeOfDay.now(),
                    builder: (ctx, child) {
                      final media = MediaQuery.of(ctx);
                      return MediaQuery(
                        data: media.copyWith(
                          alwaysUse24HourFormat: true,
                        ),
                        child: child ?? const SizedBox.shrink(),
                      );
                    },
                  );
                  if (time != null && mounted) {
                    setState(() {
                      _startTime = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  }
                }
              },
            ),
            ListTile(
              title: const Text('持续时间（分钟）'),
              subtitle: Text(
                _durationMinutes.toString(),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                      final controller = TextEditingController(
                          text: _durationMinutes.toString());
                      final v = await showDialog<int>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('持续时间'),
                          content: TextField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: '请输入分钟数，例如 25',
                            ),
                            autofocus: true,
                            onSubmitted: (text) {
                              final parsed =
                                  int.tryParse(text.trim());
                              Navigator.pop(dialogContext, parsed);
                            },
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, null),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () {
                                final parsed = int.tryParse(
                                    controller.text.trim());
                                Navigator.pop(dialogContext, parsed);
                              },
                              child: const Text('确定'),
                            ),
                          ],
                        ),
                      );
                      if (v != null && v > 0) {
                        setState(() => _durationMinutes = v);
                      } else if (v != null && v <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('持续时间必须大于 0 分钟')),
                        );
                      }
                    },
            ),
            ListTile(
              title: const Text('截止时间'),
              subtitle: Text(
                _deadline != null
                    ? (_deadline!.hour == 0 && _deadline!.minute == 0
                        ? DateFormat('yyyy-MM-dd').format(_deadline!)
                        : DateFormat('yyyy-MM-dd HH:mm').format(_deadline!))
                    : '未设置',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _deadline ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null && mounted) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _deadline != null
                        ? TimeOfDay.fromDateTime(_deadline!)
                        : TimeOfDay.now(),
                    builder: (ctx, child) {
                      final media = MediaQuery.of(ctx);
                      return MediaQuery(
                        data: media.copyWith(alwaysUse24HourFormat: true),
                        child: child ?? const SizedBox.shrink(),
                      );
                    },
                  );
                  if (time != null && mounted) {
                    setState(() {
                      _deadline = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  }
                }
              },
            ),
            ListTile(
              title: const Text('设置提醒'),
              subtitle: Text(
                _reminderAt != null
                    ? DateFormat('yyyy-MM-dd HH:mm').format(_reminderAt!)
                    : '未设置',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_reminderAt != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: '清除提醒',
                      onPressed: () => setState(() => _reminderAt = null),
                    ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _reminderAt ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                );
                if (date == null || !mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: _reminderAt != null
                      ? TimeOfDay.fromDateTime(_reminderAt!)
                      : TimeOfDay.now(),
                  builder: (ctx, child) {
                    final media = MediaQuery.of(ctx);
                    return MediaQuery(
                      data: media.copyWith(alwaysUse24HourFormat: true),
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
                );
                if (time != null && mounted) {
                  setState(() {
                    _reminderAt = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    );
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('所属列表'),
              subtitle: Text(_listName ?? '未设置'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickListName(context),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('标签', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _showAddTagDialog,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('添加标签'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.asMap().entries.map((entry) {
                final i = entry.key;
                final tag = entry.value;
                return GestureDetector(
                  onLongPress: () => _showEditTagDialog(i),
                  child: Chip(
                    label: Text(tag),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => setState(() => _tags.remove(tag)),
                  ),
                );
              }).toList(),
            ),
            if (_tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '长按标签可编辑，点击 × 可删除',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '暂无标签，点击「添加标签」新增',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text('备选标签', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Consumer<ScheduleProvider>(
              builder: (context, provider, _) {
                final fromTasks = <String>{};
                for (final t in provider.inboxTasks) {
                  fromTasks.addAll(t.tags);
                }
                final suggestedTags = <String>{
                  ...provider.knownTagNames,
                  ...fromTasks,
                }.toList()..sort();
                if (suggestedTags.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '标签页暂无标签，新增的标签会同步到标签页',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggestedTags.map((tag) {
                    final isSelected = _tags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: isSelected,
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _tags.add(tag);
                        } else {
                          _tags.remove(tag);
                        }
                      }),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '备注',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (!widget.isNew)
              OutlinedButton.icon(
                onPressed: () async {
                  final title = _titleController.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请先输入标题')),
                    );
                    return;
                  }
                  final updated = widget.task.copyWith(
                    title: title,
                    startTime: _startTime,
                    durationMinutes: _durationMinutes,
                    deadline: _deadline,
                    notes: _notesController.text,
                    tags: _tags,
                    updatedAt: DateTime.now(),
                  );
                  await context.read<ScheduleProvider>().saveTask(updated);
                  if (mounted) {
                    final t = await context.read<ScheduleProvider>().getTaskById(updated.id);
                    if (t != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TaskDetailScreen(task: t),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.list),
                label: const Text('查看详情 / 拆分子任务'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTask() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: const Text('删除后任务将移动到垃圾箱，确认删除？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await NotificationService.instance.cancel(widget.task.id);
      await context.read<ScheduleProvider>().moveTaskToTrash(widget.task);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _showAddTagDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加标签'),
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
    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        if (!_tags.contains(result)) _tags.add(result);
      });
      // 同步到标签页的已知标签，使新标签在标签视图中显示
      if (mounted) {
        await context.read<ScheduleProvider>().addKnownTagName(result);
      }
    }
  }

  Future<void> _showEditTagDialog(int index) async {
    if (index < 0 || index >= _tags.length) return;
    final controller = TextEditingController(text: _tags[index]);
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
    if (result != null && mounted) {
      setState(() {
        if (result.isEmpty) {
          _tags.removeAt(index);
        } else {
          _tags[index] = result;
          // 去重：同名的只保留当前这一个
          final seen = <String>{};
          _tags.removeWhere((t) {
            if (seen.contains(t)) return true;
            seen.add(t);
            return false;
          });
        }
      });
    }
  }

  /// 校验标题后组装 Task（含 reminderAt/clearReminderAt），保存到仓库并调度/取消本地提醒，然后 pop
  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标题')),
      );
      return;
    }
    final task = widget.task.copyWith(
      title: title,
      startTime: _anytime && _startTime != null
          ? DateTime(_startTime!.year, _startTime!.month, _startTime!.day)
          : _startTime,
      durationMinutes: _anytime ? 0 : _durationMinutes,
      deadline: _deadline,
      reminderAt: _reminderAt,
      clearReminderAt: _reminderAt == null,
      notes: _notesController.text,
      tags: _tags,
      listName: _listName,
      updatedAt: DateTime.now(),
    );
    await context.read<ScheduleProvider>().saveTask(task);
    final svc = NotificationService.instance;
    if (_reminderAt != null && _reminderAt!.isAfter(DateTime.now())) {
      await svc.schedule(
        taskId: task.id,
        title: task.title,
        scheduledAt: _reminderAt!,
      );
    } else {
      await svc.cancel(task.id);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickListName(BuildContext context) async {
    final provider = context.read<ScheduleProvider>();
    final allLists = {
      ...provider.knownListNames,
      ...provider.inboxTasks.map((t) => t.listName).whereType<String>(),
    }.toList()
      ..sort();

    final controller = TextEditingController(text: _listName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('选择或新建列表'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '列表名称',
                  border: OutlineInputBorder(),
                  hintText: '输入或选择列表名称',
                ),
                autofocus: true,
                onSubmitted: (text) =>
                    Navigator.pop(dialogContext, text.trim()),
              ),
              if (allLists.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '已有列表',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 4),
                ...allLists.map(
                  (name) => ListTile(
                    dense: true,
                    title: Text(name),
                    onTap: () => Navigator.pop(dialogContext, name),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: const Text('清除'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (result == null) return;

    if (result.isEmpty) {
      // 清除列表关联
      setState(() => _listName = null);
      return;
    }

    setState(() => _listName = result);
    await provider.addKnownListName(result);
  }
}
