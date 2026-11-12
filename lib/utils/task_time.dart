import '../models/task.dart';

bool sameDay(DateTime? a, DateTime b) {
  if (a == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 当天 0 点且没有时长，视为「随时」。
bool isAnytime(Task task) {
  if (task.anytime) return true;
  final start = task.startTime;
  if (start == null) return false;
  return task.durationMinutes == 0 && start.hour == 0 && start.minute == 0;
}

bool isScheduled(Task task) => task.startTime != null && !isAnytime(task);

String listLabelOf(Task task) {
  final name = task.listName?.trim();
  if (name == null || name.isEmpty) return '收件箱';
  return name;
}

String formatClock(DateTime time, {required bool use24Hour}) {
  if (use24Hour) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  final period = time.hour < 12 ? '上午' : '下午';
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$period$hour:$minute';
}

String durationPhrase(int minutes) {
  if (minutes <= 0) return '0分钟';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours > 0 && rest == 0) return '$hours小时';
  if (hours > 0) return '$hours小时$rest分钟';
  return '$rest分钟';
}

/// 已排期任务的说明：时长指向结束时间，例如「4小时 → 上午7:30」。
String scheduleSpan(Task task, {required bool use24Hour}) {
  final start = task.startTime;
  if (start == null) return '';
  if (task.durationMinutes <= 0) return formatClock(start, use24Hour: use24Hour);
  final end = start.add(Duration(minutes: task.durationMinutes));
  return '${durationPhrase(task.durationMinutes)} → ${formatClock(end, use24Hour: use24Hour)}';
}

String formatTimelineHour(int hour, {required bool use24Hour}) {
  if (use24Hour) return '${hour.toString().padLeft(2, '0')}:00';
  if (hour == 0) return '12 AM';
  if (hour < 12) return '$hour AM';
  if (hour == 12) return '12 PM';
  return '${hour - 12} PM';
}

/// 已排期且结束时间早于现在。
bool isOverdue(Task task, DateTime now) {
  final start = task.startTime;
  if (start == null || isAnytime(task) || task.isCompleted) return false;
  final end = start.add(Duration(minutes: task.durationMinutes == 0 ? 1 : task.durationMinutes));
  return end.isBefore(now);
}

const chineseMonths = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二'];

String chineseMonthTitle(DateTime month) =>
    '${month.year}年${chineseMonths[month.month - 1]}月';

String planHeading(DateTime day) {
  final today = dateOnly(DateTime.now());
  final target = dateOnly(day);
  const weeks = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  final week = weeks[day.weekday - 1];
  final md = '${day.month}月${day.day}日';
  final prefix = switch (target.difference(today).inDays) {
    0 => '今天',
    1 => '明天',
    -1 => '昨天',
    _ => '',
  };
  if (prefix.isEmpty) return '$week $md';
  return '$prefix  $week $md';
}
