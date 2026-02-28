// =============================================================================
// 日程数据仓库
// =============================================================================
// ScheduleRepository：抽象接口，便于日后接入云端同步。
// LocalScheduleRepository：基于 Hive 的本地实现，Task/Action 存为 JSON 字符串，
// 已知标签名、列表名单独 Box 存储。
// =============================================================================

import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/action.dart';
import '../models/task.dart';

/// 日程数据仓库接口（便于后续接入云端同步）
abstract class ScheduleRepository {
  Future<List<Task>> getAllTasks();
  Future<List<Task>> getInboxTasks();
  Future<List<Task>> getCompletedTasks();
  Future<List<Task>> getTrashTasks();
  Future<List<Task>> getTasksByTag(String tag);
  Future<List<Task>> getTasksByList(String listName);
  Future<List<Task>> getTasksByDate(DateTime date);
  Future<List<Task>> getTasksByDeadlineDate(DateTime date);
  Future<Task?> getTaskById(String id);
  Future<void> saveTask(Task task);
  Future<void> deleteTaskPermanently(String id);

  Future<List<Action>> getActionsByTaskId(String taskId);
  Future<List<Action>> getActionsByDate(DateTime date);
  Future<Action?> getActionById(String id);
  Future<void> saveAction(Action action);
  Future<void> deleteActionPermanently(String id);

  Future<List<String>> getKnownTagNames();
  Future<void> setKnownTagNames(List<String> names);

  Future<List<String>> getKnownListNames();
  Future<void> setKnownListNames(List<String> names);
}

/// 本地 Hive 实现：Task/Action 各一 Box，key 为 id，value 为 JSON 字符串
class LocalScheduleRepository implements ScheduleRepository {
  static const _tasksBoxName = 'tasks';
  static const _actionsBoxName = 'actions';
  static const _knownTagsBoxName = 'known_tags';
  static const _knownTagsKey = 'list';
  static const _knownListsBoxName = 'known_lists';
  static const _knownListsKey = 'list';

  Box<String>? _tasksBox;
  Box<String>? _actionsBox;
  Box<String>? _knownTagsBox;
  Box<String>? _knownListsBox;

  Future<Box<String>> get _tasks async =>
      _tasksBox ??= await Hive.openBox<String>(_tasksBoxName);
  Future<Box<String>> get _actions async =>
      _actionsBox ??= await Hive.openBox<String>(_actionsBoxName);
  Future<Box<String>> get _knownTags async =>
      _knownTagsBox ??= await Hive.openBox<String>(_knownTagsBoxName);
  Future<Box<String>> get _knownLists async =>
      _knownListsBox ??= await Hive.openBox<String>(_knownListsBoxName);

  /// 所有未软删除的任务，按创建时间倒序
  @override
  Future<List<Task>> getAllTasks() async {
    final box = await _tasks;
    return box.values
        .map((s) => Task.fromMap(Map<String, dynamic>.from(jsonDecode(s))))
        .where((t) => t.deletedAt == null)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 收件箱：未完成且未删除
  @override
  Future<List<Task>> getInboxTasks() async {
    final all = await getAllTasks();
    return all.where((t) => !t.isCompleted).toList();
  }

  @override
  Future<List<Task>> getCompletedTasks() async {
    final box = await _tasks;
    return box.values
        .map((s) => Task.fromMap(Map<String, dynamic>.from(jsonDecode(s))))
        .where((t) => t.deletedAt == null && t.isCompleted)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<Task>> getTrashTasks() async {
    final box = await _tasks;
    return box.values
        .map((s) => Task.fromMap(Map<String, dynamic>.from(jsonDecode(s))))
        .where((t) => t.deletedAt != null)
        .toList()
      ..sort((a, b) => (b.deletedAt ?? b.createdAt).compareTo(a.deletedAt ?? a.createdAt));
  }

  @override
  Future<List<Task>> getTasksByTag(String tag) async {
    final all = await getAllTasks();
    return all.where((t) => t.tags.contains(tag)).toList();
  }

  @override
  Future<List<Task>> getTasksByList(String listName) async {
    final all = await getAllTasks();
    return all.where((t) => t.listName == listName).toList();
  }

  /// 计划开始时间落在指定日期当天的任务（用于每日视图时间轴）
  @override
  Future<List<Task>> getTasksByDate(DateTime date) async {
    final all = await getAllTasks();
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return all.where((t) {
      final s = t.startTime;
      return s != null && !s.isBefore(start) && s.isBefore(end);
    }).toList()
      ..sort((a, b) => (a.startTime ?? a.createdAt).compareTo(b.startTime ?? b.createdAt));
  }

  /// 截止日期为指定日期的任务（用于每日视图“截止今日”）
  @override
  Future<List<Task>> getTasksByDeadlineDate(DateTime date) async {
    final all = await getAllTasks();
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return all.where((t) {
      final d = t.deadline;
      return d != null && !d.isBefore(start) && d.isBefore(end);
    }).toList()
      ..sort((a, b) => (a.deadline ?? a.createdAt).compareTo(b.deadline ?? b.createdAt));
  }

  @override
  Future<Task?> getTaskById(String id) async {
    final box = await _tasks;
    final s = box.get(id);
    if (s == null) return null;
    return Task.fromMap(Map<String, dynamic>.from(jsonDecode(s)));
  }

  @override
  Future<void> saveTask(Task task) async {
    final box = await _tasks;
    await box.put(task.id, jsonEncode(task.toMap()));
  }

  @override
  Future<void> deleteTaskPermanently(String id) async {
    final box = await _tasks;
    await box.delete(id);
  }

  @override
  Future<List<Action>> getActionsByTaskId(String taskId) async {
    final box = await _actions;
    return box.values
        .map((s) => Action.fromMap(Map<String, dynamic>.from(jsonDecode(s))))
        .where((a) => a.deletedAt == null && a.parentTaskId == taskId)
        .toList()
      ..sort((a, b) => (a.startTime ?? a.createdAt).compareTo(b.startTime ?? b.createdAt));
  }

  @override
  Future<List<Action>> getActionsByDate(DateTime date) async {
    final box = await _actions;
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return box.values
        .map((s) => Action.fromMap(Map<String, dynamic>.from(jsonDecode(s))))
        .where((a) {
          if (a.deletedAt != null) return false;
          final s = a.startTime;
          return s != null && !s.isBefore(start) && s.isBefore(end);
        })
        .toList()
      ..sort((a, b) => (a.startTime ?? a.createdAt).compareTo(b.startTime ?? b.createdAt));
  }

  @override
  Future<Action?> getActionById(String id) async {
    final box = await _actions;
    final s = box.get(id);
    if (s == null) return null;
    return Action.fromMap(Map<String, dynamic>.from(jsonDecode(s)));
  }

  @override
  Future<void> saveAction(Action action) async {
    final box = await _actions;
    await box.put(action.id, jsonEncode(action.toMap()));
  }

  @override
  Future<void> deleteActionPermanently(String id) async {
    final box = await _actions;
    await box.delete(id);
  }

  @override
  Future<List<String>> getKnownTagNames() async {
    final box = await _knownTags;
    final raw = box.get(_knownTagsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>?;
    return list?.map((e) => e as String).toList() ?? [];
  }

  @override
  Future<void> setKnownTagNames(List<String> names) async {
    final box = await _knownTags;
    await box.put(_knownTagsKey, jsonEncode(names));
  }

  @override
  Future<List<String>> getKnownListNames() async {
    final box = await _knownLists;
    final raw = box.get(_knownListsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>?;
    return list?.map((e) => e as String).toList() ?? [];
  }

  @override
  Future<void> setKnownListNames(List<String> names) async {
    final box = await _knownLists;
    await box.put(_knownListsKey, jsonEncode(names));
  }
}
