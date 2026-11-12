import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/action.dart' as slot_models;
import '../models/list_catalog.dart';
import '../models/repeat_rule.dart';
import '../models/task.dart';
import '../providers/schedule_provider.dart';
import '../services/notification_service.dart';
import '../theme/slot_colors.dart';
import '../utils/task_time.dart';
import 'task_setup_sheet.dart';

/// 点加号，或点开已有任务。两者都是同一张任务卡片。
Future<void> showQuickAdd(BuildContext context, {required DateTime day, String? listName, String? tag}) {
  return showTaskComposer(
    context,
    day: day,
    listName: listName,
    tags: tag == null ? null : [tag],
  );
}

Future<void> showTaskComposer(
  BuildContext context, {
  Task? task,
  DateTime? day,
  String? listName,
  List<String>? tags,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, _, _) => TaskComposer(task: task, day: day, listName: listName, tags: tags),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
    ),
  );
}

class TaskComposer extends StatefulWidget {
  const TaskComposer({super.key, this.task, this.day, this.listName, this.tags});

  final Task? task;
  final DateTime? day;
  final String? listName;
  final List<String>? tags;

  @override
  State<TaskComposer> createState() => _TaskComposerState();
}

class _DraftAction {
  _DraftAction(this.action) : title = TextEditingController(text: action.title), existed = true;

  _DraftAction.create(String parentId)
      : action = slot_models.Action(
          id: const Uuid().v4(),
          parentTaskId: parentId,
          title: '',
          createdAt: DateTime.now(),
        ),
        title = TextEditingController(),
        existed = false;

  slot_models.Action action;
  final TextEditingController title;
  final bool existed;

  void dispose() => title.dispose();
}

class _TaskComposerState extends State<TaskComposer> {
  final _title = TextEditingController();
  final _focus = FocusNode();
  late final String _taskId;
  late ScheduleDraft _draft;
  late String? _listName;
  late List<String> _tags;
  late String _notes;
  late bool _pinned;
  late bool _completed;
  late DateTime _createdAt;
  int? _duration;
  final List<_DraftAction> _subtasks = [];
  bool _showCompleted = false;
  bool _canPop = false;
  bool _leaving = false;
  bool _asEvent = false;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    final start = task?.startTime ?? widget.day ?? DateTime.now();
    _taskId = task?.id ?? const Uuid().v4();
    _title.text = task?.title ?? '';
    _listName = task?.listName ?? widget.listName;
    _tags = List<String>.from(task?.tags ?? widget.tags ?? const []);
    _notes = task?.notes ?? '';
    _pinned = task?.pinned ?? false;
    _completed = task?.isCompleted ?? false;
    _createdAt = task?.createdAt ?? DateTime.now();
    _duration = task == null || task.durationMinutes <= 0 ? null : task.durationMinutes;
    final rawMinutes = task?.reminderAt == null ? 0 : start.difference(task!.reminderAt!).inMinutes;
    final reminderMinutes = rawMinutes < 0 ? 0 : (rawMinutes > 24 * 60 ? 24 * 60 : rawMinutes);
    _draft = ScheduleDraft(
      day: dateOnly(start),
      anytime: task == null ? true : (task.anytime || isAnytime(task)),
      time: TimeOfDay(hour: start.hour, minute: start.minute),
      reminderOn: task?.reminderAt != null,
      reminderMinutes: reminderMinutes,
      repeat: RepeatRule.decode(task?.repeat ?? ''),
    );
    _asEvent = !_draft.anytime;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _focus.requestFocus();
      if (task == null) return;
      final actions = await context.read<ScheduleProvider>().getActionsByTaskId(task.id);
      if (!mounted) return;
      setState(() => _subtasks.addAll(actions.map(_DraftAction.new)));
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _focus.dispose();
    for (final item in _subtasks) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _subtasks.where((item) => _showCompleted || !item.action.isCompleted);
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _leaving) return;
        _leave(save: true);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _leave(save: true),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: Column(
                        children: [
                          _header(),
                          const SizedBox(height: 8),
                          _card(),
                          for (final item in visible) _subtaskRow(item),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              onPressed: _addSubtask,
                              icon: const Icon(Icons.add, color: Color(0xFFC5CAD3), size: 28),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => setState(() => _showCompleted = !_showCompleted),
                              child: Text(
                                '显示已完成',
                                style: TextStyle(
                                  color: _showCompleted ? SlotColors.today : const Color(0xFFB0B6C0),
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: constraints.maxHeight),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        IconButton(
          onPressed: () => _leave(save: true),
          icon: const Icon(Icons.close, color: Color(0xFF8E8E93)),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _modeChip('新建任务', selected: !_asEvent, onTap: () => _setEvent(false)),
              const SizedBox(width: 8),
              _modeChip('新建日程', selected: _asEvent, onTap: () => _setEvent(true)),
            ],
          ),
        ),
        if (widget.task != null)
          IconButton(
            onPressed: () => _leave(save: false, trash: true),
            icon: const Icon(Icons.delete_outline, color: Color(0xFFFF8A9B)),
          )
        else
          const SizedBox(width: 48),
      ],
    );
  }

  Widget _card() {
    final listLabel = (_listName == null || _listName!.trim().isEmpty) ? '收件箱' : _listName!.trim();
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: const Color(0x1A000000),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _completed = !_completed),
                  child: Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(left: 8, right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _completed ? SlotColors.today : const Color(0xFFD0D5DD), width: 1.6),
                      color: _completed ? SlotColors.today : Colors.transparent,
                    ),
                    child: _completed ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _title,
                    focusNode: _focus,
                    decoration: const InputDecoration(
                      hintText: '新建任务',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    GestureDetector(
                      onTap: _pickList,
                      child: _chip(
                        icon: _listName == null ? Icons.inbox_outlined : Icons.list_alt,
                        label: listLabel,
                        color: _listName == null ? SlotColors.inbox : SlotColors.lists,
                      ),
                    ),
                    for (final tag in _tags)
                      GestureDetector(
                        onTap: _pickTags,
                        child: _chip(icon: Icons.sell_outlined, label: tag, color: SlotColors.tags),
                      ),
                    GestureDetector(
                      onTap: _pickTags,
                      child: _chip(icon: Icons.add, label: '标签', color: const Color(0xFF8E8E93)),
                    ),
                  ],
                ),
              ),
            ),
            _line(icon: Icons.schedule, label: _dateLine(), onTap: () => _openSetup(SetupPage.time)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: _inline(Icons.notifications_none, _reminderLabel(), () => _openSetup(SetupPage.reminder)),
                  ),
                  Expanded(
                    child: _inline(Icons.repeat, _repeatLabel(), () => _openSetup(SetupPage.repeat)),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _line(
                    icon: Icons.timelapse,
                    label: _duration == null || _duration == 0 ? '持续时间' : _durationLabel(_duration!),
                    onTap: _pickDuration,
                  ),
                ),
                IconButton(
                  tooltip: '锁定',
                  onPressed: () => setState(() => _pinned = !_pinned),
                  icon: Icon(
                    _pinned ? Icons.lock : Icons.lock_outline,
                    color: _pinned ? SlotColors.today : const Color(0xFFC5CAD3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _subtaskRow(_DraftAction item) {
    final done = item.action.isCompleted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() {
              item.action = item.action.copyWith(isCompleted: !done, updatedAt: DateTime.now());
            }),
            child: Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: done ? SlotColors.today : const Color(0xFFD0D5DD), width: 1.6),
                color: done ? SlotColors.today : Colors.transparent,
              ),
              child: done ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
          ),
          Expanded(
            child: TextField(
              controller: item.title,
              decoration: const InputDecoration(
                hintText: '子任务',
                border: InputBorder.none,
                isDense: true,
              ),
              style: TextStyle(
                fontSize: 16,
                color: done ? const Color(0xFFB0B6C0) : const Color(0xFF1C1C1E),
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  Widget _line({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF8E8E93)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 15))),
          ],
        ),
      ),
    );
  }

  Widget _inline(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF8E8E93)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  void _setEvent(bool event) {
    setState(() {
      _asEvent = event;
      _draft.anytime = !event;
      if (event && _draft.time.hour == 0 && _draft.time.minute == 0) {
        _draft.time = const TimeOfDay(hour: 9, minute: 0);
      }
    });
  }

  Widget _modeChip(String label, {required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? SlotColors.today : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF8E8E93),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _dateLine() {
    final day = '${_draft.day.month}月${_draft.day.day}日';
    if (_draft.anytime) return day;
    return '$day ${_clock(_draft.time)}';
  }

  String _reminderLabel() {
    if (!_draft.reminderOn) return '无提醒';
    return '提前${_durationLabel(_draft.reminderMinutes)}';
  }

  String _repeatLabel() => _draft.repeat == null ? '没有重复' : _draft.repeat!.shortLabel;

  String _durationLabel(int minutes) {
    if (minutes <= 0) return '无';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '$mins分钟';
    if (mins == 0) return '$hours小时';
    return '$hours小时$mins分钟';
  }

  Future<void> _openSetup(SetupPage page) async {
    _focus.unfocus();
    final result = await showScheduleSetup(context, draft: _draft, initial: page);
    if (result == null || !mounted) return;
    setState(() => _draft = result);
  }

  Future<void> _pickDuration() async {
    _focus.unfocus();
    final result = await showDurationPicker(context, minutes: _duration);
    if (result == null || !mounted) return;
    setState(() => _duration = result == 0 ? null : result);
  }

  Future<void> _pickList() async {
    _focus.unfocus();
    final provider = context.read<ScheduleProvider>();
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ListChoices(
        catalog: provider.listCatalog,
        initial: _listName == null || _listName!.trim().isEmpty ? '收件箱' : _listName!.trim(),
      ),
    );
    if (picked == null || !mounted) return;
    if (picked != '收件箱' && !provider.listCatalog.contains(picked)) {
      await provider.addKnownListName(picked);
    }
    if (!mounted) return;
    setState(() => _listName = picked == '收件箱' ? null : picked);
  }

  Future<void> _pickTags() async {
    _focus.unfocus();
    final provider = context.read<ScheduleProvider>();
    final names = <String>[...provider.knownTagNames];
    for (final tag in _tags) {
      if (!names.contains(tag)) names.add(tag);
    }
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _TagChoices(names: names, initial: {..._tags}),
    );
    if (picked == null || !mounted) return;
    for (final tag in picked) {
      if (!provider.knownTagNames.contains(tag)) await provider.addKnownTagName(tag);
    }
    if (!mounted) return;
    setState(() => _tags = picked);
  }

  void _addSubtask() {
    setState(() => _subtasks.add(_DraftAction.create(_taskId)));
  }

  Future<void> _leave({required bool save, bool trash = false}) async {
    if (_leaving) return;
    _leaving = true;
    final provider = context.read<ScheduleProvider>();
    if (trash && widget.task != null) {
      await provider.moveTaskToTrash(widget.task!);
      await NotificationService.instance.cancel(widget.task!.id);
    } else if (save) {
      await _persist(provider);
    }
    if (!mounted) return;
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _persist(ScheduleProvider provider) async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final scheduled = !_draft.anytime;
    final start = _draft.start;
    final duration = _duration ?? (scheduled ? 30 : 0);
    DateTime? reminder;
    if (scheduled && _draft.reminderOn && _draft.reminderMinutes >= 0) {
      reminder = start.subtract(Duration(minutes: _draft.reminderMinutes));
    }
    final task = Task(
      id: _taskId,
      title: title,
      startTime: start,
      durationMinutes: duration,
      reminderAt: reminder,
      tags: List<String>.from(_tags),
      listName: _listName,
      createdAt: _createdAt,
      isCompleted: _completed,
      notes: _notes,
      deadline: widget.task?.deadline,
      userId: widget.task?.userId,
      pinned: _pinned,
      repeat: _draft.repeat?.encode() ?? '',
      anytime: _draft.anytime,
      updatedAt: DateTime.now(),
    );
    await provider.saveTask(task);
    await provider.setSelectedDate(_draft.day);
    if (reminder != null && reminder.isAfter(DateTime.now()) && !_completed) {
      await NotificationService.instance.schedule(
        taskId: task.id,
        title: task.title,
        scheduledAt: reminder,
      );
    } else {
      await NotificationService.instance.cancel(task.id);
    }
    for (final item in _subtasks) {
      final subTitle = item.title.text.trim();
      if (subTitle.isEmpty) {
        if (item.existed) await provider.moveActionToTrash(item.action);
        continue;
      }
      await provider.saveAction(
        item.action.copyWith(title: subTitle, parentTaskId: _taskId, updatedAt: DateTime.now()),
      );
    }
  }
}

class _PickerFrame extends StatelessWidget {
  const _PickerFrame({
    required this.title,
    required this.search,
    required this.onClear,
    required this.onDone,
    required this.onQuery,
    required this.rows,
  });

  final String title;
  final TextEditingController search;
  final VoidCallback onClear;
  final VoidCallback onDone;
  final VoidCallback onQuery;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height - inset - 120;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Material(
        color: const Color(0xFF243447),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: height < 280 ? 280 : height,
          child: Column(
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed: onClear,
                    child: const Text('清除', style: TextStyle(color: Color(0xFFFF5A78), fontSize: 16)),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: onDone,
                    child: const Text('完成', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: search,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: '搜索或创建',
                    hintStyle: const TextStyle(color: Color(0xFF9AA3B2)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF9AA3B2)),
                    filled: true,
                    fillColor: const Color(0xFF1B2838),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (_) => onQuery(),
                ),
              ),
              Expanded(child: ListView(children: rows)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListChoices extends StatefulWidget {
  const _ListChoices({required this.catalog, required this.initial});

  final ListCatalog catalog;
  final String initial;

  @override
  State<_ListChoices> createState() => _ListChoicesState();
}

class _ListChoicesState extends State<_ListChoices> {
  late String _selected = widget.initial;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(String name) {
    final query = _search.text.trim();
    return query.isEmpty || name.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = widget.catalog;
    final query = _search.text.trim();
    final rows = <Widget>[];
    if (_matches('收件箱')) rows.add(_row('收件箱', icon: Icons.inbox_outlined, color: SlotColors.inbox));
    for (final name in catalog.loose) {
      if (_matches(name)) rows.add(_row(name));
    }
    for (final folder in catalog.folders) {
      final children = folder.lists.where(_matches).toList();
      final showFolder = _matches(folder.name) || children.isNotEmpty;
      if (!showFolder) continue;
      rows.add(_folder(folder.name));
      rows.add(const Divider(height: 1, color: Color(0xFF314158)));
      final shown = _matches(folder.name) && query.isNotEmpty ? folder.lists : children;
      for (final name in shown) {
        rows.add(_row(name, indent: 28));
      }
    }
    final known = query == '收件箱' || catalog.contains(query);
    if (query.isNotEmpty && !known) rows.add(_row(query));
    return _PickerFrame(
      title: '列表',
      search: _search,
      onQuery: () => setState(() {}),
      onClear: () => setState(() => _selected = '收件箱'),
      onDone: () => Navigator.pop(context, _selected),
      rows: rows,
    );
  }

  Widget _folder(String name) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Row(
        children: [
          const Icon(Icons.folder_outlined, color: Color(0xFFD0D5DD), size: 22),
          const SizedBox(width: 10),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 17)),
        ],
      ),
    );
  }

  Widget _row(String name, {IconData? icon, Color? color, double indent = 18}) {
    final selected = _selected == name;
    return InkWell(
      onTap: () => setState(() => _selected = name),
      child: Padding(
        padding: EdgeInsets.fromLTRB(indent, 12, 18, 12),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: color ?? Colors.white, size: 22),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 17))),
            if (selected) const Icon(Icons.check, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

class _TagChoices extends StatefulWidget {
  const _TagChoices({required this.names, required this.initial});

  final List<String> names;
  final Set<String> initial;

  @override
  State<_TagChoices> createState() => _TagChoicesState();
}

class _TagChoicesState extends State<_TagChoices> {
  late final Set<String> _selected = {...widget.initial};
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();
    final names = widget.names.where((name) => query.isEmpty || name.contains(query)).toList();
    final rows = <Widget>[
      for (final name in names) _row(name),
      if (query.isNotEmpty && !widget.names.contains(query)) _row(query),
    ];
    return _PickerFrame(
      title: '标签',
      search: _search,
      onQuery: () => setState(() {}),
      onClear: () => setState(_selected.clear),
      onDone: () => Navigator.pop(context, _selected.toList()),
      rows: rows,
    );
  }

  Widget _row(String name) {
    final checked = _selected.contains(name);
    return InkWell(
      onTap: () => setState(() {
        if (checked) {
          _selected.remove(name);
        } else {
          _selected.add(name);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: checked ? SlotColors.today : const Color(0xFF9AA3B2), width: 1.6),
                color: checked ? SlotColors.today : Colors.transparent,
              ),
              child: checked ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 17))),
          ],
        ),
      ),
    );
  }
}


String _clock(TimeOfDay time) {
  final period = time.hour < 12 ? '上午' : '下午';
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$period$hour:$minute';
}
