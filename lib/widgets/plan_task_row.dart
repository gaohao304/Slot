import 'package:flutter/material.dart';

import '../models/repeat_rule.dart';
import '../models/task.dart';
import '../providers/app_settings.dart';
import '../theme/slot_colors.dart';
import '../utils/task_time.dart';
import 'quick_add_sheet.dart';

void openTaskEditor(BuildContext context, Task task, {bool isNew = false}) {
  showTaskComposer(
    context,
    task: isNew ? null : task,
    day: task.startTime,
    listName: task.listName,
  );
}

class PlanTaskRow extends StatelessWidget {
  const PlanTaskRow({
    super.key,
    required this.task,
    required this.settings,
    required this.hideDetails,
    required this.onToggle,
    this.onTap,
  });

  final Task task;
  final AppSettings settings;
  final bool hideDetails;
  final VoidCallback onToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheduled = isScheduled(task);
    final overdue = settings.overdueMark == OverdueMark.overdue &&
        isOverdue(task, DateTime.now());
    final start = task.startTime;
    final detail = scheduled && start != null ? scheduleSpan(task, use24Hour: settings.use24Hour) : null;

    return Padding(
      padding: EdgeInsets.only(bottom: settings.rowGap),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 46,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: scheduled && start != null
                      ? ScheduleTimeMark(
                          time: start,
                          use24Hour: settings.use24Hour,
                          color: overdue ? SlotColors.overdue : const Color(0xFF8E8E93),
                        )
                      : const _AnytimeDash(),
                ),
              ),
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1, right: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: task.isCompleted ? SlotColors.today : const Color(0xFFD0D5DD),
                      width: 1.6,
                    ),
                    color: task.isCompleted ? SlotColors.today : Colors.transparent,
                  ),
                  child: task.isCompleted
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title.isEmpty ? '未命名' : task.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: overdue ? SlotColors.overdue : null,
                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (!hideDetails) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          _ListChip(label: listLabelOf(task)),
                          if (detail != null)
                            Text(
                              detail,
                              style: const TextStyle(
                                fontSize: 13,
                                color: SlotColors.chipText,
                              ),
                            ),
                          if (RepeatRule.decode(task.repeat) case final rule?)
                            Text(
                              rule.shortLabel,
                              style: const TextStyle(fontSize: 13, color: SlotColors.chipText),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (task.reminderAt != null)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 2),
                  child: Icon(Icons.notifications_none, size: 18, color: Color(0xFFC8CDD4)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScheduleTimeMark extends StatelessWidget {
  const ScheduleTimeMark({super.key, required this.time, required this.use24Hour, required this.color});

  final DateTime time;
  final bool use24Hour;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 12, height: 1.15, color: color);
    if (use24Hour) {
      return Text(formatClock(time, use24Hour: true), style: style);
    }
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$hour:$minute', style: style),
        Text(time.hour < 12 ? 'am' : 'pm', style: style),
      ],
    );
  }
}

class _AnytimeDash extends StatelessWidget {
  const _AnytimeDash();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 10,
        height: 2,
        margin: const EdgeInsets.only(left: 4),
        color: const Color(0xFFD0D5DD),
      ),
    );
  }
}

class _ListChip extends StatelessWidget {
  const _ListChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A3140)
            : SlotColors.chip,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 13, color: SlotColors.inbox),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: SlotColors.chipText),
          ),
        ],
      ),
    );
  }
}

/// 搜索跳转后，让目标任务行蓝光闪几下。
class TaskFlash extends StatefulWidget {
  const TaskFlash({super.key, required this.active, required this.token, required this.child});

  final bool active;
  final int token;
  final Widget child;

  @override
  State<TaskFlash> createState() => _TaskFlashState();
}

class _TaskFlashState extends State<TaskFlash> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.forward();
  }

  @override
  void didUpdateWidget(TaskFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && widget.token != oldWidget.token) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final step = (_controller.value * 6).floor();
        final on = widget.active && _controller.value < 1 && step.isEven;
        return ColoredBox(
          color: on ? const Color(0xFFD6EBFF) : Colors.transparent,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
