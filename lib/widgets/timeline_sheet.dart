import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/app_settings.dart';
import '../providers/schedule_provider.dart';
import '../services/notification_service.dart';
import '../theme/slot_colors.dart';
import '../utils/task_time.dart';
import 'plan_task_row.dart';

/// 一天的时间线。随时任务在上方，已排期任务按开始时间落在小时格子里，可拖到别的小时或拖回随时。
class TimelineSheet extends StatelessWidget {
  const TimelineSheet({
    super.key,
    required this.day,
    required this.onPlace,
  });

  final DateTime day;
  final Future<void> Function(Task task, DateTime? start, int durationMinutes) onPlace;

  static const _startHour = 0;
  static const _endHour = 24;
  static const _hourHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final provider = context.watch<ScheduleProvider>();
    final seen = <String>{};
    final tasks = <Task>[];
    for (final task in [...provider.inboxTasks, ...provider.completedTasks]) {
      if (!seen.add(task.id) || !sameDay(task.startTime, day)) continue;
      tasks.add(task);
    }
    final anytime = tasks.where(isAnytime).toList();
    final now = DateTime.now();
    final scheduled = tasks.where(isScheduled).toList()
      ..sort((a, b) => a.startTime!.compareTo(b.startTime!));
    final lanes = _lanes(scheduled.where((task) => !_ended(task, now)).toList());

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFFFF4B6A), size: 18),
                const SizedBox(width: 8),
                Text(
                  planHeading(day),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _bucket(
            context,
            label: '随时',
            tasks: anytime,
            onAccept: (task) => onPlace(task, dateOnly(day), 0),
          ),
          _bucket(
            context,
            label: '过期',
            tasks: scheduled.where((task) => _ended(task, DateTime.now())).toList(),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final laneCount = lanes.isEmpty ? 1 : lanes.length;
                final laneWidth = (constraints.maxWidth - 84) / laneCount;
                return _HourScroller(
              day: day,
              child: SizedBox(
                  height: (_endHour - _startHour) * _hourHeight,
                  child: Stack(
                    children: [
                      for (var hour = _startHour; hour < _endHour; hour++)
                        Positioned(
                          top: (hour - _startHour) * _hourHeight,
                          left: 0,
                          right: 0,
                          height: _hourHeight,
                          child: DragTarget<Task>(
                            onAcceptWithDetails: (details) {
                              final task = details.data;
                              final duration = task.durationMinutes == 0 ? 30 : task.durationMinutes;
                              onPlace(
                                task,
                                DateTime(day.year, day.month, day.day, hour),
                                duration,
                              );
                            },
                            builder: (context, candidate, _) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: candidate.isEmpty ? null : const Color(0xFFE8F0FF),
                                  border: const Border(top: BorderSide(color: Color(0xFFE6E8EC))),
                                ),
                                padding: const EdgeInsets.only(left: 12, top: 6),
                                alignment: Alignment.topLeft,
                                child: Text(
                                  formatTimelineHour(hour, use24Hour: settings.use24Hour),
                                  style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                                ),
                              );
                            },
                          ),
                        ),
                      for (var lane = 0; lane < lanes.length; lane++)
                        for (final task in lanes[lane])
                          _block(context, task, lane, laneWidth),
                      Positioned.fill(child: _NowLine(day: day)),
                    ],
                  ),
                ),
              );
              },
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('完成', style: TextStyle(color: SlotColors.today, fontSize: 17)),
          ),
        ],
      ),
    );
  }

  Widget _bucket(
    BuildContext context, {
    required String label,
    required List<Task> tasks,
    Future<void> Function(Task task)? onAccept,
  }) {
    Widget row(Color color) => Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(label, style: const TextStyle(color: Color(0xFF8E8E93))),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final task in tasks) _chip(context, task),
              ],
            ),
          ),
        ],
      ),
    );
    if (onAccept == null) return row(const Color(0xFFF7F8FA));
    return DragTarget<Task>(
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidate, _) {
        return row(candidate.isEmpty ? const Color(0xFFF7F8FA) : const Color(0xFFE8F0FF));
      },
    );
  }

  Widget _chip(BuildContext context, Task task) {
    return LongPressDraggable<Task>(
      data: task,
      feedback: Material(
        borderRadius: BorderRadius.circular(8),
        child: _chipBody(context, task),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _chipBody(context, task)),
      child: _chipBody(context, task),
    );
  }

  Widget _chipBody(BuildContext context, Task task) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: task.isCompleted ? const Color(0xFFF7F8FA) : const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _check(context, task),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => openTaskEditor(context, task),
            child: Text(task.title, style: _titleStyle(task)),
          ),
        ],
      ),
    );
  }

  Widget _check(BuildContext context, Task task) {
    final done = task.isCompleted;
    return GestureDetector(
      onTap: () => _toggle(context, task),
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: done ? const Color(0xFFE6E8EC) : Colors.transparent,
          border: Border.all(color: done ? const Color(0xFFE6E8EC) : const Color(0xFFD0D5DD), width: 1.4),
        ),
      ),
    );
  }

  TextStyle _titleStyle(Task task) {
    final done = task.isCompleted;
    return TextStyle(
      fontSize: 14,
      color: done ? const Color(0xFFC5CAD3) : const Color(0xFF1C1C1E),
      decoration: done ? TextDecoration.lineThrough : null,
      decorationColor: const Color(0xFFC5CAD3),
    );
  }

  bool _ended(Task task, DateTime now) {
    final start = task.startTime;
    if (start == null || isAnytime(task)) return false;
    final end = start.add(Duration(minutes: task.durationMinutes == 0 ? 1 : task.durationMinutes));
    return end.isBefore(now);
  }

  Future<void> _toggle(BuildContext context, Task task) async {
    await context.read<ScheduleProvider>().saveTask(
          task.copyWith(isCompleted: !task.isCompleted, updatedAt: DateTime.now()),
        );
    if (!task.isCompleted) await NotificationService.instance.cancel(task.id);
  }

  Widget _block(BuildContext context, Task task, int lane, double laneWidth) {
    final start = task.startTime!;
    final minutes = (start.hour - _startHour) * 60 + start.minute;
    final top = minutes / 60 * _hourHeight;
    final height = (task.durationMinutes.clamp(20, 240) / 60 * _hourHeight).clamp(28, 220).toDouble();
    return Positioned(
      top: top,
      left: 72 + lane * laneWidth,
      width: laneWidth - 8,
      height: height,
      child: LongPressDraggable<Task>(
        data: task,
        feedback: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: _blockBody(context, task),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: _blockBody(context, task)),
        child: _blockBody(context, task),
      ),
    );
  }

  Widget _blockBody(BuildContext context, Task task) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: task.isCompleted ? const Color(0xFFF7F8FA) : const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _check(context, task),
          const SizedBox(width: 6),
          Flexible(
            child: GestureDetector(
              onTap: () => openTaskEditor(context, task),
              child: Text(task.title, overflow: TextOverflow.ellipsis, style: _titleStyle(task)),
            ),
          ),
        ],
      ),
    );
  }

  List<List<Task>> _lanes(List<Task> scheduled) {
    final lanes = <List<Task>>[];
    for (final task in scheduled) {
      final start = task.startTime!;
      final end = start.add(Duration(minutes: task.durationMinutes == 0 ? 30 : task.durationMinutes));
      var placed = false;
      for (final lane in lanes) {
        final overlaps = lane.any((other) {
          final otherStart = other.startTime!;
          final otherEnd = otherStart.add(
            Duration(minutes: other.durationMinutes == 0 ? 30 : other.durationMinutes),
          );
          return start.isBefore(otherEnd) && end.isAfter(otherStart);
        });
        if (!overlaps) {
          lane.add(task);
          placed = true;
          break;
        }
      }
      if (!placed) lanes.add([task]);
    }
    return lanes;
  }
}

class _HourScroller extends StatefulWidget {
  const _HourScroller({required this.day, required this.child});

  final DateTime day;
  final Widget child;

  @override
  State<_HourScroller> createState() => _HourScrollerState();
}

class _HourScrollerState extends State<_HourScroller> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showNow());
  }

  @override
  void didUpdateWidget(_HourScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!sameDay(oldWidget.day, widget.day)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showNow());
    }
  }

  void _showNow() {
    if (!mounted || !_scroll.hasClients) return;
    final now = DateTime.now();
    if (!sameDay(now, widget.day)) return;
    final max = _scroll.position.maxScrollExtent;
    if (max == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients && _scroll.position.maxScrollExtent > 0) _showNow();
      });
      return;
    }
    final top = (now.hour * 60 + now.minute) / 60 * TimelineSheet._hourHeight;
    final target = top - 80;
    _scroll.jumpTo(target < 0 ? 0 : (target > max ? max : target));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 24),
      children: [widget.child],
    );
  }
}

class _NowLine extends StatefulWidget {
  const _NowLine({required this.day});

  final DateTime day;

  @override
  State<_NowLine> createState() => _NowLineState();
}

class _NowLineState extends State<_NowLine> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (!sameDay(now, widget.day)) return const SizedBox.shrink();
    final minutes = (now.hour - TimelineSheet._startHour) * 60 + now.minute;
    final span = (TimelineSheet._endHour - TimelineSheet._startHour) * 60;
    if (minutes < 0 || minutes > span) return const SizedBox.shrink();
    final top = minutes / 60 * TimelineSheet._hourHeight;
    final settings = context.watch<AppSettings>();
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: top - 8,
            left: 0,
            right: 0,
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    formatClock(now, use24Hour: settings.use24Hour),
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 11),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Color(0xFFFF3B30), shape: BoxShape.circle),
                ),
                const Expanded(child: ColoredBox(color: Color(0xFFFF3B30), child: SizedBox(height: 2))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
