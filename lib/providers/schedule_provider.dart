// =============================================================================
// 日程业务状态 Provider
// =============================================================================
// 职责：封装 ScheduleRepository，维护收件箱/已完成/垃圾箱/按日期任务/按截止日期任务、
//       已知标签与列表名、当前选中日期；提供保存、删除、恢复、移动垃圾箱及标签/列表增删改。
// 供各页面通过 context.read<ScheduleProvider>() / watch 使用。
// =============================================================================

import 'package:flutter/foundation.dart';

import '../models/action.dart';
import '../models/list_catalog.dart';
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
  ListCatalog _catalog = const ListCatalog();
  bool _catalogReady = false;
  DateTime _selectedDate = DateTime.now();

  List<Task> get inboxTasks => _inboxTasks;
  List<Task> get completedTasks => _completedTasks;
  List<Task> get trashTasks => _trashTasks;
  List<Task> get tasksForDate => _tasksForDate;
  List<Task> get tasksByDeadlineDate => _tasksByDeadlineDate;
  List<Action> get actionsForDate => _actionsForDate;
  List<String> get knownTagNames => _knownTagNames;
  List<String> get knownListNames => _knownListNames;
  ListCatalog get listCatalog => _catalog;
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
    await saveTask(task.copyWith(clearDeletedAt: true));
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
    final stored = await _repository.getKnownTagNames();
    final extras = <String>[];
    for (final task in [..._inboxTasks, ..._completedTasks]) {
      for (final tag in task.tags) {
        final name = tag.trim();
        if (name.isEmpty || stored.contains(name) || extras.contains(name)) continue;
        extras.add(name);
      }
    }
    _knownTagNames = [...stored, ...extras];
    if (extras.isNotEmpty) await _repository.setKnownTagNames(_knownTagNames);
    notifyListeners();
  }

  Future<void> addKnownTagName(String name, {bool atTop = false}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_knownTagNames.contains(trimmed)) return;
    _knownTagNames = atTop ? [trimmed, ..._knownTagNames] : [..._knownTagNames, trimmed];
    await _repository.setKnownTagNames(_knownTagNames);
    notifyListeners();
  }

  /// 在最上方新建一个标签，名称默认为「新建标签」。
  Future<String> createTag() async {
    var name = '新建标签';
    var index = 2;
    while (_knownTagNames.contains(name)) {
      name = '新建标签 $index';
      index++;
    }
    await addKnownTagName(name, atTop: true);
    return name;
  }

  Future<void> reorderTags(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _knownTagNames.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0) newIndex = 0;
    if (newIndex > _knownTagNames.length - 1) newIndex = _knownTagNames.length - 1;
    final next = List<String>.of(_knownTagNames);
    final name = next.removeAt(oldIndex);
    next.insert(newIndex, name);
    _knownTagNames = next;
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
      final next = List<String>.of(_knownTagNames);
      final index = next.indexOf(oldName);
      if (next.contains(trimmed)) {
        next.removeAt(index);
      } else {
        next[index] = trimmed;
      }
      _knownTagNames = next;
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
    var catalog = await _repository.getListCatalog();
    final extras = <String>[];
    for (final task in [..._inboxTasks, ..._completedTasks]) {
      final name = task.listName?.trim();
      if (name == null || name.isEmpty || catalog.contains(name) || extras.contains(name)) continue;
      extras.add(name);
    }
    if (extras.isNotEmpty) {
      catalog = catalog.copyWith(loose: [...catalog.loose, ...extras]);
      await _repository.setListCatalog(catalog);
    }
    _catalog = catalog;
    _knownListNames = catalog.allNames;
    _catalogReady = true;
    notifyListeners();
  }

  Future<void> _ensureCatalog() async {
    if (_catalogReady) return;
    await loadKnownListNames();
  }

  Future<void> addKnownListName(String name, {bool atTop = false}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _ensureCatalog();
    if (_catalog.contains(trimmed)) return;
    final loose = List<String>.of(_catalog.loose);
    if (atTop) {
      loose.insert(0, trimmed);
    } else {
      loose.add(trimmed);
    }
    _catalog = _catalog.copyWith(loose: loose);
    await _repository.setListCatalog(_catalog);
    _knownListNames = _catalog.allNames;
    notifyListeners();
  }

  /// 在列表最上方新建一个列表，名称默认为「新建列表」。
  Future<String> createList() async {
    await _ensureCatalog();
    final name = _uniqueName('新建列表', _catalog.contains);
    await addKnownListName(name, atTop: true);
    return name;
  }

  /// 在已存档上方新建一个空目录，名称默认为「新建目录」。
  Future<String> createFolder() async {
    await _ensureCatalog();
    final name = _uniqueName('新建目录', (candidate) => _catalog.folders.any((folder) => folder.name == candidate));
    final folder = ListFolder(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
    );
    _catalog = _catalog.copyWith(folders: [folder, ..._catalog.folders]);
    await _repository.setListCatalog(_catalog);
    notifyListeners();
    return folder.id;
  }

  String _uniqueName(String base, bool Function(String name) taken) {
    if (!taken(base)) return base;
    var index = 2;
    while (taken('$base $index')) {
      index++;
    }
    return '$base $index';
  }

  Future<void> removeKnownListName(String name) async {
    await _ensureCatalog();
    _catalog = _catalog.without(name);
    await _repository.setListCatalog(_catalog);
    _knownListNames = _catalog.allNames;
    notifyListeners();
  }

  /// 重命名列表：更新所有带该列表名的任务，并保持它原来的位置。
  Future<void> renameList(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == oldName) return;
    await _ensureCatalog();
    final allTasks = await _repository.getAllTasks();
    for (final task in allTasks) {
      if (task.listName == oldName) {
        await _repository.saveTask(
          task.copyWith(listName: trimmed, updatedAt: DateTime.now()),
        );
      }
    }
    _catalog = _catalog.renameList(oldName, trimmed);
    await _repository.setListCatalog(_catalog);
    await refreshAll();
  }

  Future<void> renameFolder(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _ensureCatalog();
    _catalog = _catalog.copyWith(
      folders: [
        for (final folder in _catalog.folders)
          if (folder.id == id) folder.copyWith(name: trimmed) else folder,
      ],
    );
    await _repository.setListCatalog(_catalog);
    notifyListeners();
  }

  /// 移动列表。folderId 为空且不归档时，放回未分组列表的最上方。
  Future<void> moveList(String name, {String? folderId, bool archive = false}) async {
    await _ensureCatalog();
    if (!_catalog.contains(name)) return;
    _catalog = _catalog.place(name, folderId: folderId, archive: archive);
    await _repository.setListCatalog(_catalog);
    _knownListNames = _catalog.allNames;
    notifyListeners();
  }

  /// 删除列表：清除所有任务上的该列表名，并从已知列表中移除
  Future<void> deleteList(String name) async {
    await _ensureCatalog();
    final allTasks = await _repository.getAllTasks();
    for (final task in allTasks) {
      if (task.listName == name) {
        await _repository.saveTask(
          task.copyWith(listName: null, updatedAt: DateTime.now()),
        );
      }
    }
    _catalog = _catalog.without(name);
    await _repository.setListCatalog(_catalog);
    await refreshAll();
  }
}
