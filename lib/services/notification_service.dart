// =============================================================================
// 本地通知服务
// =============================================================================
// 职责：按任务 id 调度/取消系统提醒；需在 main 中先 init 并完成 timezone 的 setLocalLocation。
// 使用：任务编辑页保存时若 reminderAt 在未来则 schedule，清除或删除任务时 cancel。
// =============================================================================

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// 本地提醒服务：按任务 id 调度/取消系统通知。
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// 用任务 id 生成稳定且合法的 Android 通知 id（正整数）。
  static int notificationIdFromTaskId(String taskId) {
    return taskId.hashCode.abs() % 0x7FFFFFFF;
  }

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Android 13+ 需在调用 schedule 前请求通知权限。
  Future<bool> requestPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true;
    final granted = await androidPlugin.requestNotificationsPermission();
    return granted ?? false;
  }

  /// 在 [scheduledAt] 触发一条通知，标题为 [title]，
  /// 使用 [taskId] 派生通知 id，便于后续取消。
  Future<void> schedule({
    required String taskId,
    required String title,
    required DateTime scheduledAt,
  }) async {
    if (scheduledAt.isBefore(DateTime.now())) return;
    final id = notificationIdFromTaskId(taskId);
    final androidDetails = AndroidNotificationDetails(
      'slot_reminders',
      '任务提醒',
      channelDescription: '任务设置提醒时触发的系统通知',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    final tzDate = tz.TZDateTime.from(scheduledAt, tz.local);
    await _plugin.zonedSchedule(
      id,
      '提醒',
      title,
      tzDate,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// 取消该任务对应的提醒。
  Future<void> cancel(String taskId) async {
    final id = notificationIdFromTaskId(taskId);
    await _plugin.cancel(id);
  }
}
