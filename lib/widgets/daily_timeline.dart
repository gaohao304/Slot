// =============================================================================
// 每日时间轴组件
// =============================================================================
// 职责：24 小时行，左侧时间标签，右侧 Stack 内绘制：当日当前时刻红线（仅今天）、
//       任务直角矩形块（宽度=时间轴宽/同起任务数，高度=该小时持续占比，50% 透明色）、
//       跨小时任务横向位置按“同起任务”固定以形成整体矩形；以及 Action 块。
// 同起任务：按 task.startTime 分组，allWithSameStart 固定列序与宽度，空缺用占位。
// =============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/action.dart' as slot_models;
import '../models/task.dart';

/// 每日时间轴：左侧时间标签，右侧任务/子任务条块
class DailyTimeline extends StatelessWidget {
  const DailyTimeline({
    super.key,
    required this.date,
    required this.tasks,
    required this.actions,
    this.onTaskTap,
    this.onTaskToggleComplete,
    this.onActionTap,
  });

  final DateTime date;
  final List<Task> tasks;
  final List<slot_models.Action> actions;
  final void Function(Task)? onTaskTap;
  final void Function(Task)? onTaskToggleComplete;
  final void Function(slot_models.Action)? onActionTap;

  static const double hourHeight = 60;
  /// 任务方块颜色（使用时统一加 50% 透明度）
  static final List<Color> _taskColors = [
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.teal,
  ];

  @override
  Widget build(BuildContext context) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final slots = List.generate(24, (i) => dayStart.add(Duration(hours: i)));
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    return ListView.builder(
      itemCount: 24,
      itemBuilder: (context, hourIndex) {
        final slotTime = slots[hourIndex];
        final timeLabel = DateFormat('HH:mm').format(slotTime);
        final taskBlocks = _blocksForHour(context, slotTime, hourIndex,
            isToday: isToday, now: now);
        return SizedBox(
          height: hourHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 48,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    timeLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    if (hourIndex < 23)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Divider(
                          height: 1,
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ...taskBlocks.map((b) => b),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _blocksForHour(
    BuildContext context,
    DateTime slotTime,
    int hourIndex, {
    required bool isToday,
    required DateTime now,
  }) {
    final slotStart = slotTime.millisecondsSinceEpoch;
    final slotEnd = slotTime.add(const Duration(hours: 1)).millisecondsSinceEpoch;
    final list = <Widget>[];

    // 当日当前时刻红线：仅当为今天且当前小时行内绘制，用固定高度 Stack 避免 overflow
    if (isToday && hourIndex == now.hour) {
      final minuteFrac =
          (now.minute + now.second / 60.0 + now.millisecond / 60000.0) / 60.0;
      final lineTop = minuteFrac * hourHeight;
      final timeStr = DateFormat('HH:mm').format(now);
      const indicatorHeight = 14.0; // 固定总高度，避免 Column 撑高导致 overflow
      final top = (lineTop - indicatorHeight).clamp(0.0, hourHeight - indicatorHeight);
      list.add(
        Positioned(
          left: 0,
          right: 0,
          top: top,
          height: indicatorHeight,
          child: ClipRect(
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 2,
                  child: Container(color: Colors.red.shade700),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                      height: 1.0,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 找出本小时内需要展示的任务
    final hourTasks = <Task>[];
    for (final task in tasks) {
      final s = task.startTime;
      if (s == null) continue;
      final startMs = s.millisecondsSinceEpoch;
      final endMs = startMs + task.durationMinutes * 60 * 1000;
      if (endMs <= slotStart || startMs >= slotEnd) continue;
      hourTasks.add(task);
    }

    // 按开始时间分组；同一开始时间的多个任务用 Row 均分宽度
    final Map<int, List<Task>> groupsByStart = {};
    for (final task in hourTasks) {
      final key = task.startTime!.millisecondsSinceEpoch;
      groupsByStart.putIfAbsent(key, () => []).add(task);
    }

    for (final group in groupsByStart.values) {
      final groupStartMs = group.first.startTime!.millisecondsSinceEpoch;
      // 该开始时刻下全局同起任务（用于固定 N 与颜色顺序，跨小时一致）
      final allWithSameStart = tasks
          .where((t) =>
              t.startTime != null &&
              t.startTime!.millisecondsSinceEpoch == groupStartMs)
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));

      final groupTop = (groupStartMs < slotStart ? slotStart : groupStartMs) -
          slotStart;
      final groupTopPx =
          (groupTop / (60 * 60 * 1000)) * hourHeight;

      double maxHeightPx = 0;
      final blockData = <_BlockData>[];
      for (final task in group) {
        final startMs = task.startTime!.millisecondsSinceEpoch;
        final endMs = startMs + task.durationMinutes * 60 * 1000;
        final overlapStart = startMs < slotStart ? slotStart : startMs;
        final overlapEnd = endMs > slotEnd ? slotEnd : endMs;
        // 方块高度 = 该小时内持续时间占时间轴的比例
        final heightPx =
            (overlapEnd - overlapStart) / (60 * 60 * 1000) * hourHeight;
        if (heightPx > maxHeightPx) maxHeightPx = heightPx;
        final colorIndex =
            allWithSameStart.indexOf(task).clamp(0, _taskColors.length - 1);
        blockData.add(_BlockData(
          task: task,
          heightPx: heightPx,
          colorIndex: colorIndex,
        ));
      }
      maxHeightPx = maxHeightPx.clamp(4, double.infinity);
      final dataById = {
        for (final b in blockData) b.task.id: b,
      };

      list.add(
        Positioned(
          left: 4,
          right: 4,
          top: groupTopPx,
          height: maxHeightPx,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 宽度 = 时间轴宽度 / N（N 为同起任务数，跨小时保持一致）
              final n = allWithSameStart.isNotEmpty ? allWithSameStart.length : 1;
              final w = constraints.maxWidth / n;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  for (final t in allWithSameStart)
                    SizedBox(
                      width: w,
                      height: (dataById[t.id]?.heightPx ?? 0)
                          .clamp(0, double.infinity),
                      child: dataById[t.id] != null
                          ? _TaskBlock(
                              task: dataById[t.id]!.task,
                              color: _taskColors[dataById[t.id]!.colorIndex],
                              isStartHour:
                                  dataById[t.id]!.task.startTime!.hour ==
                                      slotTime.hour,
                              onTaskTap: onTaskTap,
                              onTaskToggleComplete: onTaskToggleComplete,
                            )
                          : const SizedBox.shrink(),
                    ),
                ],
              );
            },
          ),
        ),
      );
    }

    for (final action in actions) {
      final s = action.startTime;
      if (s == null) continue;
      final startMs = s.millisecondsSinceEpoch;
      final endMs = startMs + action.durationMinutes * 60 * 1000;
      if (endMs <= slotStart || startMs >= slotEnd) continue;
      final overlapStart = startMs < slotStart ? slotStart : startMs;
      final overlapEnd = endMs > slotEnd ? slotEnd : endMs;
      final height = (overlapEnd - overlapStart) / (60 * 60 * 1000) * hourHeight;
      final top = (overlapStart - slotStart) / (60 * 60 * 1000) * hourHeight;

      list.add(
        Positioned(
          left: 24,
          right: 4,
          top: top,
          height: height.clamp(4, double.infinity),
          child: Material(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              onTap: onActionTap != null ? () => onActionTap!(action) : null,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  action.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return list;
  }
}

class _BlockData {
  _BlockData({
    required this.task,
    required this.heightPx,
    required this.colorIndex,
  });
  final Task task;
  final double heightPx;
  final int colorIndex;
}

class _TaskBlock extends StatelessWidget {
  const _TaskBlock({
    required this.task,
    required this.color,
    required this.isStartHour,
    this.onTaskTap,
    this.onTaskToggleComplete,
  });

  final Task task;
  final Color color;
  final bool isStartHour;
  final void Function(Task)? onTaskTap;
  final void Function(Task)? onTaskToggleComplete;

  @override
  Widget build(BuildContext context) {
    // 方块颜色统一 50% 透明度；已完成稍淡
    final blockColor = task.isCompleted
        ? color.withValues(alpha: 0.35)
        : color.withValues(alpha: 0.5);
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: blockColor,
      child: isStartHour
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: task.isCompleted,
                    onChanged: onTaskToggleComplete != null
                        ? (_) => onTaskToggleComplete!(task)
                        : null,
                    visualDensity:
                        const VisualDensity(horizontal: -4, vertical: -4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: GestureDetector(
                      onTap: onTaskTap != null ? () => onTaskTap!(task) : null,
                      child: Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isCompleted
                              ? Colors.grey.shade700
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
