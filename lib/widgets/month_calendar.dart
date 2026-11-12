import 'package:flutter/material.dart';

import '../theme/slot_colors.dart';
import '../utils/lunar_calendar.dart';
import '../utils/task_time.dart';

class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.visibleMonth,
    required this.selected,
    required this.weekStartsOnSunday,
    required this.hasTask,
    required this.onSelect,
    required this.onMonthChanged,
  });

  final DateTime visibleMonth;
  final DateTime selected;
  final bool weekStartsOnSunday;
  final bool Function(DateTime day) hasTask;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final labels = weekStartsOnSunday
        ? const ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
        : const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final first = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final leading = weekStartsOnSunday ? first.weekday % 7 : first.weekday - 1;
    final gridStart = first.subtract(Duration(days: leading));
    final today = dateOnly(DateTime.now());

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -200) {
          onMonthChanged(DateTime(visibleMonth.year, visibleMonth.month + 1));
        } else if (velocity > 200) {
          onMonthChanged(DateTime(visibleMonth.year, visibleMonth.month - 1));
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          children: [
            Text(
              chineseMonthTitle(visibleMonth),
              style: const TextStyle(
                color: SlotColors.monthTitle,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final label in labels)
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF9AA3B2), fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (var week = 0; week < 6; week++)
              Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child: _DayCell(
                        day: gridStart.add(Duration(days: week * 7 + col)),
                        visibleMonth: visibleMonth,
                        selected: selected,
                        today: today,
                        hasTask: hasTask,
                        onSelect: onSelect,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.visibleMonth,
    required this.selected,
    required this.today,
    required this.hasTask,
    required this.onSelect,
  });

  final DateTime day;
  final DateTime visibleMonth;
  final DateTime selected;
  final DateTime today;
  final bool Function(DateTime day) hasTask;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final inMonth = day.month == visibleMonth.month;
    final isSelected = sameDay(day, selected);
    final lunar = solarToLunar(day).cellLabel;
    final color = !inMonth
        ? const Color(0xFF5C6778)
        : isSelected
            ? Colors.white
            : Colors.white;
    return GestureDetector(
      onTap: () => onSelect(dateOnly(day)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          children: [
            Container(
              width: isSelected ? 42 : 36,
              height: isSelected ? 42 : 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? SlotColors.today : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      color: color,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 16,
                      height: 1,
                    ),
                  ),
                  if (isSelected)
                    Text(
                      lunar,
                      style: const TextStyle(fontSize: 8, height: 1.1, color: Color(0xFFD6E4FF)),
                    ),
                ],
              ),
            ),
            if (!isSelected)
              Text(
                lunar,
                style: const TextStyle(fontSize: 9, color: Color(0xFF9AA3B2)),
              ),
            const SizedBox(height: 2),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: hasTask(day) ? SlotColors.eventDot : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
