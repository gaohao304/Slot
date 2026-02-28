// =============================================================================
// 日程业务状态 Provider
// =============================================================================
// 职责：封装 ScheduleRepository，维护收件箱/已完成/垃圾箱/按日期任务/按截止日期任务、
//       已知标签与列表名、当前选中日期；提供保存、删除、恢复、移动垃圾箱及标签/列表增删改。
// 供各页面通过 context.read<ScheduleProvider>() / watch 使用。
// =============================================================================

import 'package:flutter/foundation.dart';

import '../models/action.dart';
import '../models/task.dart';
import '../repositories/schedule_repository.dart';

class ScheduleProvider with ChangeNotifier {
  ScheduleProvider({required ScheduleRepository repository})
      : _repository = repository;

  final ScheduleRepository _repository;

  // 缓存列表，避免每次从仓库拉取
  List<Task> _inboxTasks = [];
  List<Task> _completedTasks = [];
  List<Task> _trashTasks = [];
  List<Task> _tasksForDate = [];       // 每日视图中“计划开始”在该日的任务
  List<Task> _tasksByDeadlineDate = []; // 每日视图中“截止今日”的任务
  List<Action> _actionsForDate = [];   // 每日视图中该日的子任务
  List<String> _knownTagNames = [];
  List<String> _knownListNames = [];
  DateTime _selectedDate = DateTime.now();

  List<Task> get inboxTasks => _inboxTasks;
  List<Task> get completedTasks => _completedTasks;
  List<Task> get trashTasks => _trashTasks;
  List<Task> get tasksForDate => _tasksForDate;
  List<Task> get tasksByDeadlineDate => _tasksByDeadlineDate;
  List<Action> get actionsForDate => _actionsForDate;
  List<String> get knownTagNames => _knownTagNames;
  List<String> get knownListNames => _knownListNames;
  DateTime get selectedDate => _selectedDate;

  Future<void> loadInbox() async {
    _inboxTasks = await _repository.getInboxTasks();
    notifyListeners();
  }

  Future<void> loadCompleted() async {
    _completedTasks = await _repository.getCompletedTasks();
    notifyListeners();
  }

  Future<void> loadTrash() async {
    _trashTasks = await _repository.getTrashTasks();
    notifyListeners();
  }

  Future<void> setSelectedDate(DateTime date) async {
    _selectedDate = DateTime(date.year, date.month, date.day);
    await loadTasksAndActionsForDate(_selectedDate);
  }

  Future<void> loadTasksAndActionsForDate(DateTime date) async {
    final tasks = await _repository.getTasksByDate(date);
    final byDeadline = await _repository.getTasksByDeadlineDate(date);
    final actions = await _repository.getActionsByDate(date);
    _tasksForDate = tasks;
    _tasksByDeadlineDate = byDeadline;
    _actionsForDate = actions;
    notifyListeners();
  }

  Future<List<Task>> getTasksByTag(String tag) =>
      _repository.getTasksByTag(tag);

  Future<List<Task>> getTasksByList(String listName) =>
      _repository.getTasksByList(listName);

  Future<List<Task>> getTasksByDeadlineDate(DateTime date) =>
      _repository.getTasksByDeadlineDate(date);

  Future<Task?> getTaskById(String id) => _repository.getTaskById(id);

  Future<List<Action>> getActionsByTaskId(String taskId) =>
      _repository.getActionsByTaskId(taskId);

  Future<Action?> getActionById(String id) => _repository.getActionById(id);

  Future<void> saveTask(Task task) async {
    await _repository.saveTask(task);
    await loadInbox();
    await loadCompleted();
    await loadTrash();
    await loadTasksAndActionsForDate(_selectedDate);
    notifyListeners();
  }

  Future<void> saveAction(Action action) async {
    await _repository.saveAction(action);
    await loadTasksAndActionsForDate(_selectedDate);
    notifyListeners();
  }

  Future<void> moveTaskToTrash(Task task) async {
    await saveTask(task.copyWith(deletedAt: DateTime.now()));
  }

  Future<void> restoreTask(Task task) async {
    await saveTask(task.copyWith(deletedAt: null));
  }

  Future<void> deleteTaskPermanently(String id) async {
    await _repository.deleteTaskPermanently(id);
    await loadTrash();
    notifyListeners();
  }

  Future<void> moveActionToTrash(Action action) async {
    await saveAction(action.copyWith(deletedAt: DateTime.now()));
  }

  Future<void> restoreAction(Action action) async {
    await saveAction(action.copyWith(deletedAt: null));
  }

  Future<void> deleteActionPermanently(String id) async {
    await _repository.deleteActionPermanently(id);
    await loadTasksAndActionsForDate(_selectedDate);
    notifyListeners();
  }

  Future<void> refreshAll() async {
    await loadInbox();
    await loadCompleted();
    await loadTrash();
    await loadKnownTagNames();
    await loadKnownListNames();
    await loadTasksAndActionsForDate(_selectedDate);
    notifyListeners();
  }

  Future<void> loadKnownTagNames() async {
    _knownTagNames = await _repository.getKnownTagNames();
    notifyListeners();
  }

  Future<void> addKnownTagName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_knownTagNames.contains(trimmed)) return;
    _knownTagNames = [..._knownTagNames, trimmed]..sort();
    await _repository.setKnownTagNames(_knownTagNames);
    notifyListeners();
  }

  Future<void> removeKnownTagName(String name) async {
    _knownTagNames = _knownTagNames.where((t) => t != name).toList();
    await _repository.setKnownTagNames(_knownTagNames);
    notifyListeners();
  }

  /// 重命名标签：更新所有带该标签的任务，并更新已知标签列表
  Future<void> renameTag(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == oldName) return;
    final tasks = await _repository.getTasksByTag(oldName);
    for (final task in tasks) {
      final newTags = task.tags.map((t) => t == oldName ? trimmed : t).toList();
      await _repository.saveTask(task.copyWith(tags: newTags));
    }
    if (_knownTagNames.contains(oldName)) {
      _knownTagNames = _knownTagNames.where((t) => t != oldName).toList();
      if (!_knownTagNames.contains(trimmed)) _knownTagNames.add(trimmed);
      _knownTagNames.sort();
      await _repository.setKnownTagNames(_knownTagNames);
    }
    await loadInbox();
    await loadCompleted();
    await loadTrash();
    notifyListeners();
  }

  /// 删除标签：从所有任务中移除该标签，并从已知标签列表移除
  Future<void> deleteTag(String name) async {
    final tasks = await _repository.getTasksByTag(name);
    for (final task in tasks) {
      final newTags = task.tags.where((t) => t != name).toList();
      await _repository.saveTask(task.copyWith(tags: newTags));
    }
    _knownTagNames = _knownTagNames.where((t) => t != name).toList();
    await _repository.setKnownTagNames(_knownTagNames);
    await loadInbox();
    await loadCompleted();
    await loadTrash();
    notifyListeners();
  }

  Future<void> loadKnownListNames() async {
    _knownListNames = await _repository.getKnownListNames();
    notifyListeners();
  }

  Future<void> addKnownListName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_knownListNames.contains(trimmed)) return;
    _knownListNames = [..._knownListNames, trimmed]..sort();
    await _repository.setKnownListNames(_knownListNames);
    notifyListeners();
  }

  Future<void> removeKnownListName(String name) async {
    _knownListNames = _knownListNames.where((t) => t != name).toList();
    await _repository.setKnownListNames(_knownListNames);
    notifyListeners();
  }

  /// 重命名列表：更新所有带该列表名的任务，并更新已知列表名称
  Future<void> renameList(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == oldName) return;
    final allTasks = await _repository.getAllTasks();
    for (final task in allTasks) {
      if (task.listName == oldName) {
        await _repository.saveTask(
          task.copyWith(listName: trimmed, updatedAt: DateTime.now()),
        );
      }
    }
    _knownListNames = _knownListNames.where((t) => t != oldName).toList();
    if (!_knownListNames.contains(trimmed)) {
      _knownListNames.add(trimmed);
      _knownListNames.sort();
    }
    await _repository.setKnownListNames(_knownListNames);
    await refreshAll();
  }

  /// 删除列表：清除所有任务上的该列表名，并从已知列表中移除
  Future<void> deleteList(String name) async {
    final allTasks = await _repository.getAllTasks();
    for (final task in allTasks) {
      if (task.listName == name) {
        await _repository.saveTask(
          task.copyWith(listName: null, updatedAt: DateTime.now()),
        );
      }
    }
    _knownListNames = _knownListNames.where((t) => t != name).toList();
    await _repository.setKnownListNames(_knownListNames);
    await refreshAll();
  }
}
