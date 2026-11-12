// =============================================================================
// Slot - 日程管理应用 入口
// =============================================================================
// 职责：初始化 Flutter 绑定、Hive 本地存储、时区、本地通知，并启动应用。
// 依赖：hive_flutter（本地持久化）、timezone/flutter_timezone（提醒调度）、
//       flutter_local_notifications（系统通知）。
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Hive 本地数据库（任务、子任务等持久化）
  await Hive.initFlutter();

  // 初始化时区数据，供定时提醒使用
  tz_data.initializeTimeZones();
  try {
    final name = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(name));
  } catch (_) {
    tz.setLocalLocation(tz.UTC);
  }

  // 初始化本地通知插件并请求通知权限（Android 13+ 需 POST_NOTIFICATIONS）
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermission();

  final settingsBox = await Hive.openBox<String>('settings');

  runApp(SlotApp(settingsBox: settingsBox));
}
