import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

enum ItemSpacing { tight, medium, loose }

enum NotifyScope { off, tasks, tasksAndSchedule }

enum OverdueMark { off, overdue }

/// 设置里能改、并且会作用到界面上的偏好。存在 Hive `settings` box。
class AppSettings extends ChangeNotifier {
  AppSettings(this._box) {
    themeMode = ThemeMode.values[_readInt('theme', ThemeMode.system.index)];
    final font = _readInt('font', 1);
    fontScaleIndex = font < 0 ? 0 : (font > 3 ? 3 : font);
    spacing = ItemSpacing.values[_readInt('spacing', ItemSpacing.medium.index)];
    weekStartsOnSunday = _readBool('weekSunday', true);
    use24Hour = _readBool('h24', false);
    sound = _readBool('sound', true);
    notifyScope = NotifyScope.values[_readInt('notify', NotifyScope.tasksAndSchedule.index)];
    notifySound = _box.get('notifySound') ?? 'Again';
    overdueMark = OverdueMark.values[_readInt('mark', OverdueMark.overdue.index)];
  }

  final Box<String> _box;

  late ThemeMode themeMode;
  late int fontScaleIndex;
  late ItemSpacing spacing;
  late bool weekStartsOnSunday;
  late bool use24Hour;
  late bool sound;
  late NotifyScope notifyScope;
  late String notifySound;
  late OverdueMark overdueMark;

  static const fontLabels = ['小', '正常', '大', '超大'];
  static const fontScales = [0.9, 1.0, 1.12, 1.28];

  double get fontScale => fontScales[fontScaleIndex];
  String get fontLabel => fontLabels[fontScaleIndex];

  String get spacingLabel => switch (spacing) {
        ItemSpacing.tight => '紧',
        ItemSpacing.medium => '中',
        ItemSpacing.loose => '松',
      };

  double get rowGap => switch (spacing) {
        ItemSpacing.tight => 2,
        ItemSpacing.medium => 8,
        ItemSpacing.loose => 16,
      };

  String get themeLabel => switch (themeMode) {
        ThemeMode.system => '系统',
        ThemeMode.light => '浅色',
        ThemeMode.dark => '深色',
      };

  String get notifyLabel => switch (notifyScope) {
        NotifyScope.off => '关闭',
        NotifyScope.tasks => '任务',
        NotifyScope.tasksAndSchedule => '任务及日程',
      };

  String get markLabel => overdueMark == OverdueMark.overdue ? '过期' : '关闭';

  String get weekLabel => weekStartsOnSunday ? '星期日' : '星期一';

  int _readInt(String key, int fallback) => int.tryParse(_box.get(key) ?? '') ?? fallback;

  bool _readBool(String key, bool fallback) {
    final raw = _box.get(key);
    if (raw == null) return fallback;
    return raw == '1';
  }

  Future<void> _put(String key, String value) async {
    await _box.put(key, value);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await _put('theme', '${mode.index}');
  }

  Future<void> setFontScaleIndex(int index) async {
    fontScaleIndex = index < 0 ? 0 : (index > 3 ? 3 : index);
    await _put('font', '$fontScaleIndex');
  }

  Future<void> setSpacing(ItemSpacing value) async {
    spacing = value;
    await _put('spacing', '${value.index}');
  }

  Future<void> setWeekStartsOnSunday(bool value) async {
    weekStartsOnSunday = value;
    await _put('weekSunday', value ? '1' : '0');
  }

  Future<void> setUse24Hour(bool value) async {
    use24Hour = value;
    await _put('h24', value ? '1' : '0');
  }

  Future<void> setSound(bool value) async {
    sound = value;
    await _put('sound', value ? '1' : '0');
  }

  Future<void> setNotifyScope(NotifyScope value) async {
    notifyScope = value;
    await _put('notify', '${value.index}');
  }

  Future<void> setNotifySound(String value) async {
    notifySound = value;
    await _put('notifySound', value);
  }

  Future<void> setOverdueMark(OverdueMark value) async {
    overdueMark = value;
    await _put('mark', '${value.index}');
  }
}
