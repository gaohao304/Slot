// =============================================================================
// 每日视图
// =============================================================================
// 顶部日期切换；“截止今日”区块（当日截止且未完成的任务）；“当天未排入时间轴的任务”；
// 下方 DailyTimeline 24 小时时间轴（任务/子任务直角块、当日当前时刻红线）。
// 依赖 ScheduleProvider.tasksForDate / tasksByDeadlineDate / actionsForDate。
// =============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/action.dart' as slot_models;
import '../models/task.dart';
import '../providers/schedule_provider.dart';
import '../widgets/daily_timeline.dart';
import 'task_edit_screen.dart';

class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleProvider>().loadTasksAndActionsForDate(
            context.read<ScheduleProvider>().selectedDate,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('每日视图'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeDate(context, -1),
          ),
          TextButton(
            onPressed: () => _pickDate(context),
            child: Consumer<ScheduleProvider>(
              builder: (context, provider, _) =>
                  Text(DateFormat('yyyy-MM-dd').format(provider.selectedDate)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeDate(context, 1),
          ),
        ],
      ),
      body: Consumer<ScheduleProvider>(
        builder: (context, provider, _) {
          final selectedDate = provider.selectedDate;
          final tasks = provider.tasksForDate;
          final actions = provider.actionsForDate;

          // 有明确开始时间和持续时间的任务，用于时间轴展示
          final timelineTasks = tasks
              .where((t) => t.startTime != null && t.durationMinutes > 0)
              .toList();

          // 当天但未明确时间段的任务：按开始时间或截止时间的日期匹配
          final unscheduledTasks = provider.inboxTasks.where((t) {
            final dateCandidate = t.startTime ?? t.deadline;
            if (dateCandidate == null) return false;
            final sameDay =
                DateTime(dateCandidate.year, dateCandidate.month, dateCandidate.day) ==
                    DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
            final hasTimeRange =
                t.startTime != null && t.durationMinutes > 0;
            return sameDay && !hasTimeRange;
          }).toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

          // 截止今日：截止日期为当日且未完成的任务，排除已在「未排入时间轴」中展示的
          final unscheduledIds = unscheduledTasks.map((t) => t.id).toSet();
          final dueTodayTasks = provider.tasksByDeadlineDate
              .where((t) =>
                  !t.isCompleted && !unscheduledIds.contains(t.id))
              .toList();

          return Column(
            children: [
              if (dueTodayTasks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '截止今日',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
              if (dueTodayTasks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: dueTodayTasks.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final task = dueTodayTasks[index];
                        return ListTile(
                          dense: true,
                          leading: Checkbox(
                            value: task.isCompleted,
                            onChanged: (_) =>
                                _toggleCompleteTask(context, task),
                          ),
                          title: Text(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: task.isCompleted
                                ? const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : null,
                          ),
                          subtitle: task.deadline != null
                              ? Text(
                                  '截止: ${DateFormat('yyyy-MM-dd HH:mm').format(task.deadline!)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall,
                                )
                              : null,
                          onTap: () => _openTaskEdit(context, task),
                        );
                      },
                    ),
                  ),
                ),
              if (unscheduledTasks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '当天未排入时间轴的任务',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
              if (unscheduledTasks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: unscheduledTasks.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final task = unscheduledTasks[index];
                        return ListTile(
                          dense: true,
                          leading: Checkbox(
                            value: task.isCompleted,
                            onChanged: (_) =>
                                _toggleCompleteTask(context, task),
                          ),
                          title: Text(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: task.isCompleted
                                ? const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : null,
                          ),
                          subtitle: task.deadline != null
                              ? Text(
                                  '截止: ${DateFormat('yyyy-MM-dd HH:mm').format(task.deadline!)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall,
                                )
                              : null,
                          onTap: () => _openTaskEdit(context, task),
                        );
                      },
                    ),
                  ),
                ),
              Expanded(
                child: DailyTimeline(
                  date: selectedDate,
                  tasks: timelineTasks,
                  actions: actions,
                  onTaskTap: (t) => _openTaskEdit(context, t),
                  onTaskToggleComplete: (t) => _toggleCompleteTask(context, t),
                  onActionTap: (a) => _toggleCompleteAction(context, a),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _changeDate(BuildContext context, int delta) {
    final provider = context.read<ScheduleProvider>();
    final next = provider.selectedDate.add(Duration(days: delta));
    provider.setSelectedDate(next);
  }

  Future<void> _pickDate(BuildContext context) async {
    final provider = context.read<ScheduleProvider>();
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) provider.setSelectedDate(picked);
  }

  void _toggleCompleteTask(BuildContext context, Task task) {
    context.read<ScheduleProvider>().saveTask(
          task.copyWith(isCompleted: !task.isCompleted),
        );
  }

  void _openTaskEdit(BuildContext context, Task task) async {
    final provider = context.read<ScheduleProvider>();
    final latest = await provider.getTaskById(task.id) ?? task;
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskEditScreen(task: latest, isNew: false),
      ),
    );
    if (!context.mounted) return;
    await context
        .read<ScheduleProvider>()
        .loadTasksAndActionsForDate(context.read<ScheduleProvider>().selectedDate);
  }

  void _toggleCompleteAction(BuildContext context, slot_models.Action action) {
    context.read<ScheduleProvider>().saveAction(
          action.copyWith(isCompleted: !action.isCompleted),
        );
  }
}
