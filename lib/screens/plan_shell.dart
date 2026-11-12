import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/app_settings.dart';
import '../providers/schedule_provider.dart';
import '../services/notification_service.dart';
import '../theme/slot_colors.dart';
import '../utils/task_time.dart';
import '../widgets/month_calendar.dart';
import '../widgets/plan_task_row.dart';
import '../widgets/quick_add_sheet.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/tags_browser.dart';
import '../widgets/timeline_sheet.dart';
import 'shell_sections.dart';

enum _InboxSort { time, duration }

enum _Section { inbox, plan, lists, tags, history, trash, guide }

/// 计划主界面：左侧抽屉、当天任务、可展开的农历月历、时间线与自动安排。
class PlanShell extends StatefulWidget {
  const PlanShell({super.key});

  @override
  State<PlanShell> createState() => _PlanShellState();
}

class _PlanShellState extends State<PlanShell> with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _quickSearchController = TextEditingController();
  late final AnimationController _calendar;

  _Section _section = _Section.plan;
  bool _hideDetails = false;
  bool _planShowCompleted = false;
  bool _searchRevealMore = false;
  String? _flashTaskId;
  int _flashToken = 0;
  final _flashKey = GlobalKey();
  String? _listFilter;
  String? _tagFilter;
  _InboxSort _inboxSort = _InboxSort.time;
  bool _inboxShowHistory = false;
  bool _inboxHideDetails = false;
  String? _inboxTagFilter;
  bool _quickSearch = false;
  String? _openedList;
  bool _listSortByDuration = false;
  String? _listTagFilter;
  bool _listShowHistory = false;
  bool _listShowDetails = true;
  String? _editListName;
  String? _editFolderId;
  String? _editTagName;
  String? _openedTag;
  bool _tagSortByDuration = false;
  String? _tagListFilter;
  String? _tagExtraFilter;
  bool _tagShowHistory = false;
  bool _tagShowDetails = true;
  bool _listNameEditing = false;
  DateTime _visibleMonth = dateOnly(DateTime.now());
  _PanAxis? _panAxis;
  double _panDx = 0;

  @override
  void initState() {
    super.initState();
    _calendar = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ScheduleProvider>().refreshAll();
    });
  }

  @override
  void dispose() {
    _quickSearchController.dispose();
    _calendar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final provider = context.watch<ScheduleProvider>();
    final day = provider.selectedDate;

    final showQuickSearch = _quickSearch;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: !showQuickSearch && !_listNameEditing,
      drawer: _drawer(provider.inboxTasks.length),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                if (!showQuickSearch)
                  if (_section == _Section.plan)
                    _planHeader(day)
                  else if (_section == _Section.inbox)
                    _inboxHeader()
                  else if (_section == _Section.lists && _openedList != null)
                    _listDetailHeader(_openedList!)
                  else if (_section == _Section.tags && _openedTag != null)
                    _tagDetailHeader(_openedTag!)
                  else
                    _plainHeader(),
                if (_section == _Section.plan && (_listFilter != null || _tagFilter != null) ||
                    _section == _Section.inbox && _inboxTagFilter != null ||
                    _section == _Section.tags && (_tagListFilter != null || _tagExtraFilter != null) ||
                    _section == _Section.lists && _listTagFilter != null)
                  _filterBanner(),
                Expanded(child: _body(provider, settings, day)),
                _bottomSheet(provider, settings, day),
              ],
            ),
            if (showQuickSearch)
              Positioned(
                left: 12,
                right: 12,
                top: 8,
                child: _quickSearchCard(provider, keyboard),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(ScheduleProvider provider, AppSettings settings, DateTime day) {
    switch (_section) {
      case _Section.inbox:
        return InboxPane(
          query: '',
          flashTaskId: _flashTaskId,
          flashToken: _flashToken,
          flashKey: _flashKey,
          sortByDuration: _inboxSort == _InboxSort.duration,
          tagFilter: _inboxTagFilter,
          showHistory: _inboxShowHistory,
          hideDetails: _inboxHideDetails,
          onToggle: _complete,
        );
      case _Section.plan:
        return _planList(provider, settings, day);
      case _Section.lists:
        return ListsPane(
          openedName: _openedList,
          onOpenedName: (name) => setState(() {
            _openedList = name;
            _listTagFilter = null;
          }),
          onAdd: () => _openQuickAdd(day, listName: _openedList),
          onToggle: _complete,
          sortByDuration: _listSortByDuration,
          showHistory: _listShowHistory,
          showDetails: _listShowDetails,
          tagFilter: _listTagFilter,
          editListName: _editListName,
          editFolderId: _editFolderId,
          onEditConsumed: () {
            _editListName = null;
            _editFolderId = null;
          },
          onEditingChanged: (editing) {
            if (_listNameEditing == editing) return;
            setState(() => _listNameEditing = editing);
          },
        );
      case _Section.tags:
        if (_openedTag != null) {
          final tag = _openedTag!;
          return TagDetailPane(
            name: tag,
            sortByDuration: _tagSortByDuration,
            showHistory: _tagShowHistory,
            showDetails: _tagShowDetails,
            listFilter: _tagListFilter,
            tagFilter: _tagExtraFilter,
            onAdd: () => _openQuickAdd(day, tag: tag),
          );
        }
        return TagsPane(
          onOpen: (name) => setState(() {
            _openedTag = name;
            _tagListFilter = null;
            _tagExtraFilter = null;
          }),
          editName: _editTagName,
          onEditConsumed: () => _editTagName = null,
          onEditingChanged: (editing) {
            if (_listNameEditing == editing) return;
            setState(() => _listNameEditing = editing);
          },
        );
      case _Section.history:
        return const HistoryPane();
      case _Section.trash:
        return const TrashPane();
      case _Section.guide:
        return const GuidePane();
    }
  }

  Widget _planList(ScheduleProvider provider, AppSettings settings, DateTime day) {
    final tasks = provider.inboxTasks.where((task) {
      if (!sameDay(task.startTime, day)) return false;
      if (_listFilter != null && listLabelOf(task) != _listFilter) return false;
      if (_tagFilter != null && !task.tags.contains(_tagFilter)) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        if (isAnytime(a) != isAnytime(b)) return isAnytime(a) ? -1 : 1;
        return (a.startTime ?? a.createdAt).compareTo(b.startTime ?? b.createdAt);
      });
    final completed = _planShowCompleted
        ? (provider.completedTasks.where((task) {
            if (!sameDay(task.startTime, day)) return false;
            if (_listFilter != null && listLabelOf(task) != _listFilter) return false;
            if (_tagFilter != null && !task.tags.contains(_tagFilter)) return false;
            return true;
          }).toList()
          ..sort((a, b) => (a.startTime ?? a.createdAt).compareTo(b.startTime ?? b.createdAt)))
        : const <Task>[];

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      children: [
        for (final task in tasks) _planTaskRow(task, settings),
        for (final task in completed) _planTaskRow(task, settings),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _planShowCompleted = !_planShowCompleted),
            child: Text(
              _planShowCompleted ? '隐藏已完成' : '显示已完成',
              style: const TextStyle(color: Color(0xFFC5CAD3), fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () => _openQuickAdd(day),
            icon: const Icon(Icons.add, color: Color(0xFFC5CAD3), size: 28),
          ),
        ),
      ],
    );
  }

  Widget _planTaskRow(Task task, AppSettings settings) {
    final flash = task.id == _flashTaskId;
    return KeyedSubtree(
      key: flash ? _flashKey : ValueKey(task.id),
      child: TaskFlash(
        active: flash,
        token: _flashToken,
        child: PlanTaskRow(
          task: task,
          settings: settings,
          hideDetails: _hideDetails,
          onToggle: () => _complete(task),
          onTap: () => openTaskEditor(context, task),
        ),
      ),
    );
  }

  Future<void> _openSearchTask(Task task) async {
    final dated = task.startTime != null && !isAnytime(task);
    _closeQuickSearch(notify: false);
    if (dated) {
      await context.read<ScheduleProvider>().setSelectedDate(task.startTime!);
    }
    if (!mounted) return;
    setState(() {
      _flashTaskId = task.id;
      _flashToken += 1;
      if (dated) {
        _section = _Section.plan;
        _listFilter = null;
        _tagFilter = null;
        if (task.isCompleted) _planShowCompleted = true;
      } else {
        _section = _Section.inbox;
        _inboxTagFilter = null;
        if (task.isCompleted) _inboxShowHistory = true;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _flashKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target, alignment: 0.3, duration: const Duration(milliseconds: 280));
      }
    });
  }

  Widget _planHeader(DateTime day) {
    final today = dateOnly(DateTime.now());
    final target = dateOnly(day);
    final delta = target.difference(today).inDays;
    final prefix = switch (delta) { 0 => '今天', 1 => '明天', -1 => '昨天', _ => '' };
    const weeks = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final rest = '${weeks[day.weekday - 1]} ${day.month}月${day.day}日';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 2),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _openTimeline,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: SlotColors.accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          if (prefix.isNotEmpty)
                            TextSpan(
                              text: prefix,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                            ),
                          TextSpan(
                            text: prefix.isEmpty ? rest : '  $rest',
                            style: const TextStyle(fontSize: 16, color: SlotColors.inkSecondary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _quickSearch = true),
            icon: const Icon(Icons.search, color: Color(0xFFB0B6C0)),
          ),
          Builder(
            builder: (anchor) => IconButton(
              onPressed: () => _openMore(anchor),
              icon: const Icon(Icons.more_horiz, color: Color(0xFFB0B6C0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inboxHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
      child: Row(
        children: [
          const Icon(Icons.inbox, color: SlotColors.inbox, size: 26),
          const SizedBox(width: 8),
          const Text('收件箱', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(
            onPressed: () => setState(() => _quickSearch = true),
            icon: const Icon(Icons.search, color: Color(0xFFB0B6C0)),
          ),
          Builder(
            builder: (anchor) => IconButton(
              onPressed: () => _openInboxMore(anchor),
              icon: const Icon(Icons.more_horiz, color: Color(0xFFB0B6C0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _plainHeader() {
    final (icon, color, title) = switch (_section) {
      _Section.inbox => (Icons.inbox_outlined, SlotColors.inbox, '收件箱'),
      _Section.lists => (Icons.list_alt, SlotColors.lists, '列表'),
      _Section.tags => (Icons.sell_outlined, SlotColors.tags, '标签'),
      _Section.history => (Icons.check_circle_outline, SlotColors.history, '历史'),
      _Section.trash => (Icons.delete_outline, SlotColors.trash, '回收站'),
      _Section.guide => (Icons.help_outline, SlotColors.guide, '指南'),
      _Section.plan => (Icons.calendar_today, SlotColors.accent, '计划'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const Spacer(),
          if ((_section == _Section.lists && _openedList == null) || (_section == _Section.tags && _openedTag == null))
            IconButton(
              onPressed: () => setState(() => _quickSearch = true),
              icon: const Icon(Icons.search, color: Color(0xFFB0B6C0)),
            ),
        ],
      ),
    );
  }

  Widget _listDetailHeader(String name) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(() {
              _openedList = null;
              _listTagFilter = null;
            }),
            icon: const Icon(Icons.chevron_left, color: Color(0xFF8E8E93)),
          ),
          const Icon(Icons.list_alt, color: SlotColors.lists, size: 22),
          if (_folderOfList(context.read<ScheduleProvider>(), name) != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.folder, color: Color(0xFFF5C518), size: 22),
          ],
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () => _renameOpenedList(name),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _quickSearch = true),
            icon: const Icon(Icons.search, color: Color(0xFFB0B6C0)),
          ),
          Builder(
            builder: (anchor) => IconButton(
              onPressed: () => _openListDetailMore(anchor),
              icon: const Icon(Icons.more_horiz, color: Color(0xFFB0B6C0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagDetailHeader(String name) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(() {
              _openedTag = null;
              _tagListFilter = null;
              _tagExtraFilter = null;
            }),
            icon: const Icon(Icons.chevron_left, color: Color(0xFF8E8E93)),
          ),
          const Icon(Icons.sell_outlined, color: SlotColors.tags, size: 22),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () => _renameTag(name),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _quickSearch = true),
            icon: const Icon(Icons.search, color: Color(0xFFB0B6C0)),
          ),
          Builder(
            builder: (anchor) => IconButton(
              onPressed: () => _openTagMore(anchor),
              icon: const Icon(Icons.more_horiz, color: Color(0xFFB0B6C0)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _renameTag(String name) async {
    final next = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭重命名',
      barrierColor: Colors.black26,
      pageBuilder: (_, _, _) => _RenameTagCard(name: name),
    );
    if (next == null || !mounted) return;
    final trimmed = next.trim();
    if (trimmed.isEmpty || trimmed == name) return;
    await context.read<ScheduleProvider>().renameTag(name, trimmed);
    if (!mounted) return;
    setState(() => _openedTag = trimmed);
  }

  Future<void> _openTagMore(BuildContext anchor) async {
    final overlay = Overlay.of(anchor).context.findRenderObject() as RenderBox;
    final box = anchor.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset(0, box.size.height), ancestor: overlay);
    await showGeneralDialog<void>(
      context: anchor,
      barrierDismissible: true,
      barrierLabel: '关闭菜单',
      barrierColor: Colors.black26,
      pageBuilder: (dialogContext, _, _) {
        return Stack(
          children: [
            Positioned(
              top: origin.dy + 6,
              right: 12,
              width: 236,
              child: Material(
                color: SlotColors.navy,
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _menuRow(
                      dialogContext,
                      Icons.schedule,
                      Colors.white70,
                      '按时间排序',
                      () => setState(() => _tagSortByDuration = false),
                      checked: !_tagSortByDuration,
                    ),
                    _menuRow(
                      dialogContext,
                      Icons.timer_outlined,
                      const Color(0xFFFFCC00),
                      '按时间长度排序',
                      () => setState(() => _tagSortByDuration = true),
                      checked: _tagSortByDuration,
                    ),
                    _menuRow(dialogContext, Icons.list_alt, SlotColors.lists, '按列表筛选', _pickTagList, checked: _tagListFilter != null),
                    _menuRow(dialogContext, Icons.sell, SlotColors.tags, '按标签筛选', _pickTagExtra, checked: _tagExtraFilter != null),
                    _menuRow(
                      dialogContext,
                      Icons.check_box,
                      const Color(0xFFFF6B4A),
                      '显示历史',
                      () => setState(() => _tagShowHistory = !_tagShowHistory),
                      checked: _tagShowHistory,
                    ),
                    _menuRow(
                      dialogContext,
                      Icons.visibility_outlined,
                      const Color(0xFF8E8E93),
                      '显示详情',
                      () => setState(() => _tagShowDetails = !_tagShowDetails),
                      checked: _tagShowDetails,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickTagList() async {
    final provider = context.read<ScheduleProvider>();
    final names = <String>{'收件箱', ...provider.knownListNames};
    for (final task in [...provider.inboxTasks, ...provider.completedTasks]) {
      if (_openedTag != null && task.tags.contains(_openedTag)) names.add(listLabelOf(task));
    }
    final picked = await _pickOne('按列表筛选', ['全部', ...names.toList()..sort()]);
    if (picked == null) return;
    setState(() => _tagListFilter = picked == '全部' ? null : picked);
  }

  Future<void> _pickTagExtra() async {
    final provider = context.read<ScheduleProvider>();
    final names = <String>{...provider.knownTagNames};
    for (final task in [...provider.inboxTasks, ...provider.completedTasks]) {
      names.addAll(task.tags);
    }
    names.remove(_openedTag);
    if (names.isEmpty) {
      _toast('还没有其他标签');
      return;
    }
    final picked = await _pickOne('按标签筛选', ['全部', ...names.toList()..sort()]);
    if (picked == null) return;
    setState(() => _tagExtraFilter = picked == '全部' ? null : picked);
  }

  Widget _filterBanner() {
    final text = [
      if (_section == _Section.plan && _listFilter != null) '列表 $_listFilter',
      if (_section == _Section.plan && _tagFilter != null) '标签 $_tagFilter',
      if (_section == _Section.inbox && _inboxTagFilter != null) '标签 $_inboxTagFilter',
      if (_section == _Section.tags && _tagListFilter != null) '列表 $_tagListFilter',
      if (_section == _Section.tags && _tagExtraFilter != null) '标签 $_tagExtraFilter',
      if (_section == _Section.lists && _listTagFilter != null) '标签 $_listTagFilter',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          GestureDetector(
            onTap: () => setState(() {
              if (_section == _Section.inbox) {
                _inboxTagFilter = null;
              } else if (_section == _Section.tags) {
                _tagListFilter = null;
                _tagExtraFilter = null;
              } else if (_section == _Section.lists) {
                _listTagFilter = null;
              } else {
                _listFilter = null;
                _tagFilter = null;
              }
            }),
            child: const Icon(Icons.close, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _bottomSheet(ScheduleProvider provider, AppSettings settings, DateTime day) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AnimatedBuilder(
      animation: _calendar,
      builder: (context, _) {
        return ColoredBox(
          color: SlotColors.navy,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _controlRow(day),
                if (_section == _Section.plan)
                  ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: _calendar.value,
                      child: MonthCalendar(
                        visibleMonth: _visibleMonth,
                        selected: day,
                        weekStartsOnSunday: settings.weekStartsOnSunday,
                        hasTask: (date) => provider.inboxTasks.any((task) => sameDay(task.startTime, date)),
                        onSelect: (date) {
                          provider.setSelectedDate(date);
                          setState(() => _visibleMonth = DateTime(date.year, date.month));
                        },
                        onMonthChanged: (month) => setState(() => _visibleMonth = month),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _controlRow(DateTime day) {
    return SizedBox(
      height: 62,
      child: Row(
        children: [
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu, color: Colors.white),
          ),
          if (_section == _Section.plan) ...[
            const Spacer(),
            _DayStep(
              icon: Icons.chevron_left,
              onTap: () => _shiftDay(day, -1),
            ),
            GestureDetector(
              onTap: () {
                if (_calendar.value > 0.5) {
                  _calendar.reverse();
                } else {
                  _calendar.forward();
                }
              },
              onPanStart: (_) {
                _panAxis = null;
                _panDx = 0;
              },
              onPanUpdate: (details) {
                final dx = details.delta.dx;
                final dy = details.delta.dy;
                _panAxis ??= dx.abs() > dy.abs() ? _PanAxis.horizontal : _PanAxis.vertical;
                if (_panAxis == _PanAxis.vertical) {
                  _calendar.value = (_calendar.value - dy / 340).clamp(0.0, 1.0);
                  return;
                }
                _panDx += dx;
                final current = context.read<ScheduleProvider>().selectedDate;
                if (_panDx <= -48) {
                  _panDx = 0;
                  _shiftDay(current, 1);
                } else if (_panDx >= 48) {
                  _panDx = 0;
                  _shiftDay(current, -1);
                }
              },
              onPanEnd: (details) {
                if (_panAxis == _PanAxis.vertical) {
                  final velocity = details.velocity.pixelsPerSecond.dy;
                  if (velocity < -400 || (velocity.abs() < 400 && _calendar.value > 0.35)) {
                    _calendar.forward();
                  } else {
                    _calendar.reverse();
                  }
                }
                _panAxis = null;
                _panDx = 0;
              },
              child: const Tooltip(
                message: '月历',
                child: SizedBox(
                  width: 132,
                  height: 44,
                  child: Center(
                    child: SizedBox(
                      width: 46,
                      height: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xD9FFFFFF),
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _DayStep(
              icon: Icons.chevron_right,
              onTap: () => _shiftDay(day, 1),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: GestureDetector(
                onTap: () => _openQuickAdd(day),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: SlotColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 30),
                ),
              ),
            ),
          ],
          if (_section == _Section.inbox || _section == _Section.lists || _section == _Section.tags) ...[
            const Spacer(),
            const SizedBox(
              width: 46,
              height: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xD9FFFFFF),
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: GestureDetector(
                onTap: () {
                  if (_section == _Section.lists && _openedList == null) {
                    _openListCreate(day);
                  } else if (_section == _Section.lists) {
                    _openQuickAdd(day, listName: _openedList);
                  } else if (_section == _Section.tags && _openedTag != null) {
                    _openQuickAdd(day, tag: _openedTag);
                  } else if (_section == _Section.tags) {
                    _openTagCreate(day);
                  } else {
                    _openQuickAdd(day);
                  }
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _section == _Section.tags ? SlotColors.tags : SlotColors.today,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 30),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _drawer(int inboxCount) {
    return Drawer(
      width: 286,
      backgroundColor: SlotColors.navy,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            _drawerItem(_Section.inbox, Icons.inbox_outlined, '收件箱', SlotColors.inbox, badge: inboxCount),
            _drawerItem(_Section.plan, Icons.calendar_month, '计划', SlotColors.plan),
            _drawerItem(_Section.lists, Icons.list_alt, '列表', SlotColors.lists),
            _drawerItem(_Section.tags, Icons.sell, '标签', SlotColors.tags),
            _drawerItem(_Section.history, Icons.check_circle_outline, '历史', SlotColors.history),
            _drawerItem(_Section.trash, Icons.delete_outline, '回收站', SlotColors.trash),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              child: Divider(color: Color(0xFF314158), height: 1),
            ),
            _drawerItem(_Section.guide, Icons.help_outline, '指南', SlotColors.guide),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: ListTile(
                leading: const Icon(Icons.settings, color: Color(0xFF9AA3B2)),
                title: const Text('设置', style: TextStyle(color: Colors.white, fontSize: 17)),
                onTap: () {
                  Navigator.of(context).pop();
                  Future<void>.delayed(const Duration(milliseconds: 180), () {
                    if (mounted) showSlotSettings(context);
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
    _Section section,
    IconData icon,
    String label,
    Color color, {
    int badge = 0,
  }) {
    final selected = _section == section;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected ? SlotColors.navyRaised : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Icon(icon, color: color),
          title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 17)),
          trailing: badge > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                )
              : null,
          onTap: () {
            setState(() {
              _section = section;
              if (section != _Section.lists) {
                _closeQuickSearch(notify: false);
                _openedList = null;
                _listTagFilter = null;
              }
              if (section != _Section.tags) _openedTag = null;
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _shiftDay(DateTime day, int delta) async {
    final next = dateOnly(day).add(Duration(days: delta));
    await context.read<ScheduleProvider>().setSelectedDate(next);
    if (!mounted) return;
    setState(() => _visibleMonth = DateTime(next.year, next.month));
    _tap();
  }

  void _openQuickAdd(DateTime day, {String? listName, String? tag}) {
    showQuickAdd(context, day: day, listName: listName, tag: tag);
    _tap();
  }

  Future<void> _renameOpenedList(String name) async {
    final next = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭重命名',
      barrierColor: Colors.black26,
      pageBuilder: (_, _, _) => _RenameTagCard(name: name),
    );
    if (next == null || !mounted) return;
    final trimmed = next.trim();
    if (trimmed.isEmpty || trimmed == name) return;
    await context.read<ScheduleProvider>().renameList(name, trimmed);
    if (!mounted) return;
    setState(() => _openedList = trimmed);
  }

  Future<void> _openTagCreate(DateTime day) async {
    final choice = await showGeneralDialog<_TagCreate>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭新建',
      barrierColor: const Color(0xCCFFFFFF),
      pageBuilder: (_, _, _) => const _TagCreateSheet(),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _TagCreate.project:
        _openQuickAdd(day);
      case _TagCreate.tag:
        {
          final name = await context.read<ScheduleProvider>().createTag();
          if (!mounted) return;
          setState(() => _editTagName = name);
        }
    }
  }

  Future<void> _openListCreate(DateTime day) async {
    final choice = await showGeneralDialog<_ListCreate>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭新建',
      barrierColor: const Color(0xCCFFFFFF),
      pageBuilder: (_, _, _) => const _ListCreateSheet(),
    );
    if (!mounted || choice == null) return;
    final provider = context.read<ScheduleProvider>();
    switch (choice) {
      case _ListCreate.project:
        _openQuickAdd(day);
      case _ListCreate.list:
        {
          final name = await provider.createList();
          if (!mounted) return;
          setState(() => _editListName = name);
        }
      case _ListCreate.folder:
        {
          final id = await provider.createFolder();
          if (!mounted) return;
          setState(() => _editFolderId = id);
        }
    }
  }

  Future<void> _openListDetailMore(BuildContext anchor) async {
    final overlay = Overlay.of(anchor).context.findRenderObject() as RenderBox;
    final box = anchor.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset(0, box.size.height), ancestor: overlay);
    await showGeneralDialog<void>(
      context: anchor,
      barrierDismissible: true,
      barrierLabel: '关闭菜单',
      barrierColor: Colors.black26,
      pageBuilder: (dialogContext, _, _) {
        return Stack(
          children: [
            Positioned(
              top: origin.dy + 6,
              right: 12,
              width: 236,
              child: Material(
                color: SlotColors.navy,
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _menuRow(
                      dialogContext,
                      Icons.schedule,
                      Colors.white70,
                      '按时间排序',
                      () => setState(() => _listSortByDuration = false),
                      checked: !_listSortByDuration,
                    ),
                    _menuRow(
                      dialogContext,
                      Icons.timer_outlined,
                      const Color(0xFFFFCC00),
                      '按时间长度排序',
                      () => setState(() => _listSortByDuration = true),
                      checked: _listSortByDuration,
                    ),
                    _menuRow(
                      dialogContext,
                      Icons.sell,
                      SlotColors.tags,
                      '按标签筛选',
                      _pickListTag,
                      checked: _listTagFilter != null,
                    ),
                    _menuRow(
                      dialogContext,
                      Icons.check_box,
                      const Color(0xFFFF6B4A),
                      '显示历史',
                      () => setState(() => _listShowHistory = !_listShowHistory),
                      checked: _listShowHistory,
                    ),
                    _menuRow(
                      dialogContext,
                      Icons.visibility_outlined,
                      const Color(0xFF8E8E93),
                      '显示详情',
                      () => setState(() => _listShowDetails = !_listShowDetails),
                      checked: _listShowDetails,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickListTag() async {
    final provider = context.read<ScheduleProvider>();
    final names = <String>{...provider.knownTagNames};
    for (final task in [...provider.inboxTasks, ...provider.completedTasks]) {
      if (_openedList != null && task.listName == _openedList) names.addAll(task.tags);
    }
    if (names.isEmpty) {
      _toast('还没有标签');
      return;
    }
    final picked = await _pickOne('按标签筛选', ['全部', ...names.toList()..sort()]);
    if (picked == null) return;
    setState(() => _listTagFilter = picked == '全部' ? null : picked);
  }

  void _closeQuickSearch({bool notify = true}) {
    _quickSearchController.clear();
    _searchRevealMore = false;
    if (!notify) {
      _quickSearch = false;
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _quickSearch = false);
  }

  String? _folderOfList(ScheduleProvider provider, String name) {
    for (final folder in provider.listCatalog.folders) {
      if (folder.lists.contains(name)) return folder.name;
    }
    return null;
  }

  Widget _quickSearchCard(ScheduleProvider provider, double keyboard) {
    final query = _quickSearchController.text.trim();
    final maxHeight = MediaQuery.sizeOf(context).height - keyboard - 150;
    final hits = _searchHits(provider, query);
    final shown = _searchRevealMore ? hits : hits.take(4).toList();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight < 220 ? 220 : maxHeight),
      child: Material(
        color: Colors.white,
        elevation: 12,
        shadowColor: const Color(0x33000000),
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quickSearchController,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: '快速搜索',
                        hintStyle: const TextStyle(color: Color(0xFFC5CAD3)),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF8E8E93)),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _quickSearchController.clear();
                                  setState(() => _searchRevealMore = false);
                                },
                                icon: const Icon(Icons.close, color: Color(0xFF8E8E93), size: 18),
                              ),
                        filled: true,
                        fillColor: const Color(0xFFF2F3F5),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => setState(() => _searchRevealMore = false),
                    ),
                  ),
                  TextButton(
                    onPressed: _closeQuickSearch,
                    child: const Text('完成', style: TextStyle(color: SlotColors.today, fontSize: 16)),
                  ),
                ],
              ),
            ),
            if (query.isEmpty)
              const SizedBox(
                height: 220,
                child: Center(
                  child: Text(
                    '搜索任务、日程、\n列表及标签。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFC5CAD3), fontSize: 16, height: 1.45),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: (maxHeight - 72).clamp(120, maxHeight)),
                child: _searchResults(provider, shown, hits.length > shown.length),
              ),
          ],
        ),
      ),
    );
  }

  List<_SearchHit> _searchHits(ScheduleProvider provider, String query) {
    if (query.isEmpty) return const [];
    final hits = <_SearchHit>[];
    final seen = <String>{};
    for (final task in [...provider.inboxTasks, ...provider.completedTasks]) {
      if (!seen.add(task.id)) continue;
      final title = task.title.isEmpty ? '未命名' : task.title;
      final titleHit = title.contains(query);
      final extra = (task.listName ?? '').contains(query) ||
          task.tags.any((tag) => tag.contains(query)) ||
          task.notes.contains(query);
      if (titleHit || (_searchRevealMore && extra)) hits.add(_SearchHit.task(task));
    }
    final listNames = <String>{...provider.knownListNames, ...provider.listCatalog.allNames};
    for (final task in [...provider.inboxTasks, ...provider.completedTasks]) {
      final name = task.listName?.trim();
      if (name != null && name.isNotEmpty) listNames.add(name);
    }
    final lists = listNames.where((name) => name.contains(query)).toList()..sort();
    for (final name in lists) {
      hits.add(_SearchHit.list(name));
    }
    final folders = provider.listCatalog.folders.where((folder) => folder.name.contains(query)).toList();
    for (final folder in folders) {
      hits.add(_SearchHit.folder(folder.name));
    }
    final tagNames = <String>{...provider.knownTagNames};
    for (final task in [...provider.inboxTasks, ...provider.completedTasks]) {
      tagNames.addAll(task.tags);
    }
    final tags = tagNames.where((name) => name.contains(query)).toList()..sort();
    for (final name in tags) {
      hits.add(_SearchHit.tag(name));
    }
    return hits;
  }

  Widget _searchResults(ScheduleProvider provider, List<_SearchHit> hits, bool more) {
    if (hits.isEmpty && !more) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 28, 16, 36),
        child: Center(child: Text('没有匹配的内容', style: TextStyle(color: Color(0xFFC5CAD3), fontSize: 16))),
      );
    }
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        for (final hit in hits) _searchHitTile(provider, hit),
        if (more || !_searchRevealMore)
          InkWell(
            onTap: () => setState(() => _searchRevealMore = true),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Row(
                children: [
                  Icon(Icons.search, color: Color(0xFF8E8E93), size: 22),
                  SizedBox(width: 12),
                  Text('... 更多', style: TextStyle(color: Color(0xFF1C1C1E), fontSize: 16)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _searchHitTile(ScheduleProvider provider, _SearchHit hit) {
    final task = hit.task;
    if (task != null) {
      final title = task.title.isEmpty ? '未命名' : task.title;
      return InkWell(
        onTap: () => _openSearchTask(task),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 2, right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFFD0D5DD), width: 1.6),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(_searchWhen(task), style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    final listName = hit.listName;
    if (listName != null) {
      final grouped = _folderOfList(provider, listName) != null;
      return InkWell(
        onTap: () {
          setState(() {
            _section = _Section.lists;
            _openedList = listName;
            _listTagFilter = null;
          });
          _closeQuickSearch();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              const Icon(Icons.list_alt, color: SlotColors.lists, size: 22),
              if (grouped) ...[
                const SizedBox(width: 8),
                const Icon(Icons.folder, color: Color(0xFFF5C518), size: 20),
              ],
              const SizedBox(width: 10),
              Expanded(child: Text(listName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            ],
          ),
        ),
      );
    }
    final folderName = hit.folderName;
    if (folderName != null) {
      return InkWell(
        onTap: () {
          _closeQuickSearch(notify: false);
          setState(() {
            _section = _Section.lists;
            _openedList = null;
          });
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              const Icon(Icons.folder, color: Color(0xFFF5C518), size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(folderName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            ],
          ),
        ),
      );
    }
    final tagName = hit.tagName!;
    return InkWell(
      onTap: () {
        _closeQuickSearch(notify: false);
        setState(() {
          _section = _Section.tags;
          _openedTag = tagName;
          _tagListFilter = null;
          _tagExtraFilter = null;
        });
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            const Icon(Icons.sell, color: SlotColors.tags, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(tagName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }

  String _searchWhen(Task task) {
    final start = task.startTime;
    if (start == null || isAnytime(task)) return '某天';
    final today = dateOnly(DateTime.now());
    final day = dateOnly(start);
    if (day == today) return '今天';
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    if (day == yesterday) return '昨天';
    if (day == tomorrow) return '明天';
    return '${start.month}月${start.day}日';
  }

  Future<void> _complete(Task task) async {
    await context.read<ScheduleProvider>().saveTask(
          task.copyWith(isCompleted: !task.isCompleted, updatedAt: DateTime.now()),
        );
    if (task.isCompleted == false) {
      await NotificationService.instance.cancel(task.id);
    }
    _tap();
  }

  Future<void> _openMore(BuildContext anchor) async {
    final overlay = Overlay.of(anchor).context.findRenderObject() as RenderBox;
    final box = anchor.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset(0, box.size.height), ancestor: overlay);
    await showGeneralDialog<void>(
      context: anchor,
      barrierDismissible: true,
      barrierLabel: '关闭菜单',
      barrierColor: Colors.black26,
      pageBuilder: (dialogContext, _, _) {
        return Stack(
          children: [
            Positioned(
              top: origin.dy + 8,
              right: 16,
              width: 292,
              child: Material(
                color: const Color(0xFF2A3648),
                elevation: 18,
                shadowColor: const Color(0x66000000),
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _planMenuRow(dialogContext, Icons.calendar_month, const Color(0xFFFF4B6A), '时间线', _openTimeline),
                    _planMenuRow(dialogContext, Icons.list_alt, const Color(0xFF3B82F6), '按列表筛选', _pickListFilter),
                    _planMenuRow(dialogContext, Icons.sell, const Color(0xFF34C759), '按标签筛选', _pickTagFilter),
                    _planMenuRow(
                      dialogContext,
                      Icons.edit,
                      const Color(0xFFF5C518),
                      '自动计划',
                      _autoPlan,
                      badge: const _ProMark(),
                    ),
                    _planMenuRow(
                      dialogContext,
                      Icons.visibility_outlined,
                      const Color(0xFF9AA6B4),
                      '显示详情',
                      () => setState(() => _hideDetails = !_hideDetails),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _planMenuRow(
    BuildContext dialogContext,
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap, {
    Widget? badge,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(dialogContext).pop();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 14),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w500)),
            if (badge != null) ...[
              const SizedBox(width: 8),
              badge,
            ],
          ],
        ),
      ),
    );
  }

  Widget _menuRow(
    BuildContext dialogContext,
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap, {
    bool checked = false,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(dialogContext).pop();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16))),
            if (checked) const Icon(Icons.check, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _openInboxMore(BuildContext anchor) async {
    final overlay = Overlay.of(anchor).context.findRenderObject() as RenderBox;
    final box = anchor.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset(0, box.size.height), ancestor: overlay);
    await showGeneralDialog<void>(
      context: anchor,
      barrierDismissible: true,
      barrierLabel: '关闭菜单',
      barrierColor: Colors.black26,
      pageBuilder: (dialogContext, _, _) {
        return Stack(
          children: [
            Positioned(
              top: origin.dy + 6,
              right: 12,
              width: 236,
              child: Material(
                color: SlotColors.navy,
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _menuRow(
                      dialogContext,
                      Icons.schedule,
                      Colors.white70,
                      '按时间排序',
                      () => setState(() => _inboxSort = _InboxSort.time),
                      checked: _inboxSort == _InboxSort.time,
                    ),
                    _menuRow(
                      dialogContext,
                      Icons.timer_outlined,
                      const Color(0xFFFFCC00),
                      '按时间长度排序',
                      () => setState(() => _inboxSort = _InboxSort.duration),
                      checked: _inboxSort == _InboxSort.duration,
                    ),
                    _menuRow(
                      dialogContext,
                      Icons.sell,
                      SlotColors.tags,
                      '按标签筛选',
                      _pickInboxTag,
                      checked: _inboxTagFilter != null,
                    ),
                    _menuRow(
                      dialogContext,
                      Icons.check_box,
                      const Color(0xFFFF6B4A),
                      '显示历史',
                      () => setState(() => _inboxShowHistory = !_inboxShowHistory),
                      checked: _inboxShowHistory,
                    ),
                    _menuRow(
                      dialogContext,
                      Icons.visibility_off_outlined,
                      const Color(0xFF8E8E93),
                      '隐藏详情',
                      () => setState(() => _inboxHideDetails = !_inboxHideDetails),
                      checked: _inboxHideDetails,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickInboxTag() async {
    final provider = context.read<ScheduleProvider>();
    final names = <String>{...provider.knownTagNames};
    for (final task in [...provider.inboxTasks, ...provider.completedTasks]) {
      names.addAll(task.tags);
    }
    if (names.isEmpty) {
      _toast('还没有标签');
      return;
    }
    final picked = await _pickOne('按标签筛选', ['全部', ...names.toList()..sort()]);
    if (picked == null) return;
    setState(() => _inboxTagFilter = picked == '全部' ? null : picked);
  }

  Future<void> _openTimeline() async {
    final provider = context.read<ScheduleProvider>();
    final day = provider.selectedDate;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭时间线',
      barrierColor: Colors.black38,
      pageBuilder: (dialogContext, _, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 72, 16, 28),
          child: TimelineSheet(
            day: day,
            onPlace: (task, start, duration) async {
              await provider.saveTask(
                task.copyWith(
                  startTime: start,
                  durationMinutes: duration,
                  updatedAt: DateTime.now(),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _pickListFilter() async {
    final provider = context.read<ScheduleProvider>();
    final names = <String>{'收件箱', ...provider.knownListNames};
    for (final task in provider.inboxTasks) {
      names.add(listLabelOf(task));
    }
    final picked = await _pickOne('按列表筛选', names.toList()..sort());
    if (picked == null) return;
    setState(() => _listFilter = picked);
  }

  Future<void> _pickTagFilter() async {
    final provider = context.read<ScheduleProvider>();
    final names = <String>{...provider.knownTagNames};
    for (final task in provider.inboxTasks) {
      names.addAll(task.tags);
    }
    if (names.isEmpty) {
      _toast('还没有标签');
      return;
    }
    final picked = await _pickOne('按标签筛选', names.toList()..sort());
    if (picked == null) return;
    setState(() => _tagFilter = picked);
  }

  Future<String?> _pickOne(String title, List<String> options) {
    return showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭',
      barrierColor: Colors.black26,
      pageBuilder: (dialogContext, _, _) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 88, right: 12),
              child: Material(
                color: SlotColors.navy,
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240, maxHeight: 360),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Text(title, style: const TextStyle(color: Colors.white70)),
                      ),
                      for (final option in options)
                        ListTile(
                          title: Text(option, style: const TextStyle(color: Colors.white)),
                          onTap: () => Navigator.pop(dialogContext, option),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _autoPlan() async {
    final provider = context.read<ScheduleProvider>();
    final day = dateOnly(provider.selectedDate);
    final dayTasks = provider.inboxTasks.where((task) => sameDay(task.startTime, day)).toList();
    final anytime = dayTasks.where((task) => isAnytime(task) && !task.pinned).toList();
    if (anytime.isEmpty) {
      _toast('今天没有待安排的任务');
      return;
    }
    final scheduled = dayTasks.where(isScheduled).toList()
      ..sort((a, b) => a.startTime!.compareTo(b.startTime!));
    var cursor = DateTime(day.year, day.month, day.day, 9);
    final now = DateTime.now();
    if (sameDay(now, day) && now.isAfter(cursor)) {
      final rounded = ((now.minute / 15).ceil() * 15);
      final extraHour = rounded >= 60 ? 1 : 0;
      cursor = DateTime(day.year, day.month, day.day, now.hour + extraHour, rounded % 60);
    }
    var placed = 0;
    for (final task in anytime) {
      const duration = 30;
      cursor = _nextFree(cursor, duration, scheduled);
      if (cursor.hour >= 22 && cursor.minute > 0) break;
      if (cursor.day != day.day) break;
      final updated = task.copyWith(
        startTime: cursor,
        durationMinutes: duration,
        updatedAt: DateTime.now(),
      );
      await provider.saveTask(updated);
      scheduled.add(updated);
      cursor = cursor.add(const Duration(minutes: duration));
      placed++;
    }
    _tap();
    _toast(placed == 0 ? '今天已经没有空档' : '已安排 $placed 个任务');
  }

  DateTime _nextFree(DateTime cursor, int duration, List<Task> scheduled) {
    var point = cursor;
    while (true) {
      final end = point.add(Duration(minutes: duration));
      Task? blocker;
      for (final task in scheduled) {
        final start = task.startTime!;
        final taskEnd = start.add(Duration(minutes: task.durationMinutes == 0 ? 30 : task.durationMinutes));
        if (point.isBefore(taskEnd) && end.isAfter(start)) {
          blocker = task;
          break;
        }
      }
      if (blocker == null) return point;
      point = blocker.startTime!.add(
        Duration(minutes: blocker.durationMinutes == 0 ? 30 : blocker.durationMinutes),
      );
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _tap() {
    if (context.read<AppSettings>().sound) {
      HapticFeedback.selectionClick();
    }
  }
}

enum _PanAxis { horizontal, vertical }

class _DayStep extends StatelessWidget {
  const _DayStep({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon == Icons.chevron_right) const _Dots(),
            Icon(icon, color: Colors.white70),
            if (icon == Icons.chevron_left) const _Dots(),
          ],
        ),
      ),
    );
  }
}

class _RenameTagCard extends StatefulWidget {
  const _RenameTagCard({required this.name});

  final String name;

  @override
  State<_RenameTagCard> createState() => _RenameTagCardState();
}

class _RenameTagCardState extends State<_RenameTagCard> {
  late final TextEditingController _controller = TextEditingController(text: widget.name);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottom + 12),
      child: Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.white,
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 16)),
                    ),
                    const Expanded(
                      child: Text('重命名', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8E8E93), fontSize: 16)),
                    ),
                    TextButton(
                      onPressed: _submit,
                      child: const Text('完成', style: TextStyle(color: SlotColors.today, fontSize: 16)),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _TagCreate { project, tag }

class _TagCreateSheet extends StatelessWidget {
  const _TagCreateSheet();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottom + 14),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: const Color(0xFF243447),
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _row(context, Icons.add, Colors.white, '新建项目', '快速添加任务或日程', _TagCreate.project),
              const Divider(height: 1, color: Color(0xFF314158)),
              _row(
                context,
                Icons.sell_outlined,
                SlotColors.tags,
                '新建标签',
                '组织相近任务，对其内容使用标签。',
                _TagCreate.tag,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, Color color, String title, String subtitle, _TagCreate choice) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(choice),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF9AA3B2), fontSize: 13, height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ListCreate { project, list, folder }

class _ListCreateSheet extends StatelessWidget {
  const _ListCreateSheet();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottom + 14),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: const Color(0xFF243447),
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _row(context, Icons.add, Colors.white, '新建项目', '快速添加任务或日程', _ListCreate.project),
              const Divider(height: 1, color: Color(0xFF314158)),
              _row(
                context,
                Icons.list_alt,
                SlotColors.lists,
                '新建列表',
                '在项目中使用列表或用列表整理相似任务。',
                _ListCreate.list,
              ),
              const Divider(height: 1, color: Color(0xFF314158)),
              _row(
                context,
                Icons.folder_outlined,
                const Color(0xFFD0D5DD),
                '新建目录',
                '使用文件夹来为相似列表分组。',
                _ListCreate.folder,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    Color color,
    String title,
    String subtitle,
    _ListCreate choice,
  ) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(choice),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF9AA3B2), fontSize: 13, height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProMark extends StatelessWidget {
  const _ProMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFC5CCD6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(color: Color(0xFF4A5564), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.3),
      ),
    );
  }
}

class _SearchHit {
  const _SearchHit.task(this.task) : listName = null, folderName = null, tagName = null;
  const _SearchHit.list(this.listName) : task = null, folderName = null, tagName = null;
  const _SearchHit.folder(this.folderName) : task = null, listName = null, tagName = null;
  const _SearchHit.tag(this.tagName) : task = null, listName = null, folderName = null;

  final Task? task;
  final String? listName;
  final String? folderName;
  final String? tagName;
}

class _Dots extends StatelessWidget {
  const _Dots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: 3,
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: const BoxDecoration(color: Colors.white38, shape: BoxShape.circle),
          ),
      ],
    );
  }
}
