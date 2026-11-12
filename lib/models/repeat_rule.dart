/// 新建任务里的重复规则。编码成一段短字符串存进 Task.repeat。
class RepeatRule {
  RepeatRule({
    this.afterComplete = false,
    this.every = 1,
    this.unit = RepeatUnit.day,
    this.end = RepeatEnd.never,
    this.endDate,
    this.endCount = 10,
  });

  bool afterComplete;
  int every;
  RepeatUnit unit;
  RepeatEnd end;
  DateTime? endDate;
  int endCount;

  String get unitLabel => switch (unit) {
        RepeatUnit.day => '天',
        RepeatUnit.week => '周',
        RepeatUnit.month => '月',
      };

  String summary(DateTime start) {
    final interval = '每$every$unitLabel';
    if (afterComplete) return '完成后$interval再次安排';
    final date = '${start.year}年${start.month}月${start.day}日';
    return '由$date开始，$interval重复';
  }

  String get shortLabel {
    final interval = '每$every$unitLabel';
    return afterComplete ? '完成后$interval' : interval;
  }

  String encode() {
    final endDateText = endDate?.toIso8601String() ?? '';
    return '${afterComplete ? 1 : 0}|$every|${unit.name}|${end.name}|$endDateText|$endCount';
  }

  static RepeatRule? decode(String raw) {
    if (raw.isEmpty) return null;
    final parts = raw.split('|');
    if (parts.length < 6) return null;
    return RepeatRule(
      afterComplete: parts[0] == '1',
      every: int.tryParse(parts[1]) ?? 1,
      unit: RepeatUnit.values.firstWhere(
        (item) => item.name == parts[2],
        orElse: () => RepeatUnit.day,
      ),
      end: RepeatEnd.values.firstWhere(
        (item) => item.name == parts[3],
        orElse: () => RepeatEnd.never,
      ),
      endDate: parts[4].isEmpty ? null : DateTime.tryParse(parts[4]),
      endCount: int.tryParse(parts[5]) ?? 10,
    );
  }
}

enum RepeatUnit { day, week, month }

enum RepeatEnd { never, onDate, count }
