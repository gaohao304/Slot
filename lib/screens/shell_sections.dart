import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/app_settings.dart';
import '../providers/schedule_provider.dart';
import '../theme/slot_colors.dart';
import '../utils/task_time.dart';
import '../widgets/lists_browser.dart';
import '../widgets/tags_browser.dart';
import '../widgets/plan_task_row.dart';
import '../widgets/quick_add_sheet.dart';

class InboxPane extends StatefulWidget {
  const InboxPane({
    super.key,
    required this.query,
    required this.onToggle,
    required this.sortByDuration,
    required this.showHistory,
    required this.hideDetails,
    this.tagFilter,
    this.flashTaskId,
    this.flashToken = 0,
    this.flashKey,
  });

  final String query;
  final Future<void> Function(Task task) onToggle;
  final bool sortByDuration;
  final bool showHistory;
  final bool hideDetails;
  final String? tagFilter;
  final String? flashTaskId;
  final int flashToken;
  final Key? flashKey;

  @override
  State<InboxPane> createState() => _InboxPaneState();
}

class _InboxPaneState extends State<InboxPane> {
  final Map<String, DateTime> _finishingAt = {};
  final Map<String, Timer> _timers = {};

  @override
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final provider = context.watch<ScheduleProvider>();
    bool matches(Task task) {
      if (widget.tagFilter != null && !task.tags.contains(widget.tagFilter)) return false;
      if (widget.query.isEmpty) return true;
      return task.title.contains(widget.query);
    }

    final active = provider.inboxTasks.where(matches).toList()..sort(_compareActive);
    final history = widget.showHistory
        ? (provider.completedTasks.where(matches).toList()
          ..sort((a, b) => (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt)))
        : <Task>[];
    final tasks = [...active, ...history];

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        if (tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 72),
            child: _Empty(text: '不时也要休息一下。'),
          ),
        for (final task in tasks)
          KeyedSubtree(
            key: task.id == widget.flashTaskId ? widget.flashKey : ValueKey(task.id),
            child: TaskFlash(
              active: task.id == widget.flashTaskId,
              token: widget.flashToken,
              child: _InboxRow(
                task: task,
                use24Hour: settings.use24Hour,
                hideDetails: widget.hideDetails,
                finishedAt: task.isCompleted ? (task.updatedAt ?? task.createdAt) : _finishingAt[task.id],
                onToggle: () => _toggle(task),
                onTap: () => openTaskEditor(context, task),
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () => showQuickAdd(context, day: DateTime.now()),
            icon: const Icon(Icons.add, color: Color(0xFFC5CAD3), size: 28),
          ),
        ),
      ],
    );
  }

  void _toggle(Task task) {
    if (task.isCompleted) {
      widget.onToggle(task);
      return;
    }
    final pending = _timers.remove(task.id);
    if (pending != null) {
      pending.cancel();
      setState(() => _finishingAt.remove(task.id));
      return;
    }
    setState(() => _finishingAt[task.id] = DateTime.now());
    _timers[task.id] = Timer(const Duration(seconds: 1), () async {
      _timers.remove(task.id);
      _finishingAt.remove(task.id);
      await widget.onToggle(task);
      if (mounted) setState(() {});
    });
  }

  int _compareActive(Task a, Task b) {
    if (widget.sortByDuration) {
      final byDuration = b.durationMinutes.compareTo(a.durationMinutes);
      if (byDuration != 0) return byDuration;
    }
    final aTime = isScheduled(a) ? a.startTime : null;
    final bTime = isScheduled(b) ? b.startTime : null;
    if (aTime == null && bTime == null) return a.createdAt.compareTo(b.createdAt);
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return aTime.compareTo(bTime);
  }
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({
    required this.task,
    required this.use24Hour,
    required this.hideDetails,
    required this.onToggle,
    this.finishedAt,
    this.onTap,
  });

  final Task task;
  final bool use24Hour;
  final bool hideDetails;
  final DateTime? finishedAt;
  final VoidCallback onToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final done = finishedAt != null;
    final muted = const Color(0xFFB0B6C0);
    final start = task.startTime;
    final scheduled = isScheduled(task) && !done;
    final detail = !scheduled || start == null ? null : scheduleSpan(task, use24Hour: use24Hour);
    final doneLabel = finishedAt == null
        ? null
        : '${finishedAt!.month}月${finishedAt!.day}日 ${formatClock(finishedAt!, use24Hour: use24Hour)}';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 74,
              child: done || !scheduled
                  ? const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text('—', style: TextStyle(color: Color(0xFFC5CAD3), fontSize: 18)),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${start!.month}月${start.day}日', style: const TextStyle(fontSize: 12, height: 1.15, color: Color(0xFF8E8E93))),
                        const SizedBox(height: 2),
                        ScheduleTimeMark(time: start, use24Hour: use24Hour, color: const Color(0xFF8E8E93)),
                      ],
                    ),
            ),
            GestureDetector(
              onTap: onToggle,
              child: Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 1, right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: done ? SlotColors.today : const Color(0xFFD0D5DD), width: 1.6),
                  color: done ? SlotColors.today : Colors.transparent,
                ),
                child: done ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title.isEmpty ? '未命名' : task.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: done ? muted : const Color(0xFF1C1C1E),
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (!hideDetails)
                    Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      _InboxChip(label: listLabelOf(task), muted: done),
                      if (!done && detail != null)
                        Text(detail, style: const TextStyle(fontSize: 13, color: SlotColors.chipText)),
                      if (done && doneLabel != null)
                        Text(doneLabel, style: const TextStyle(fontSize: 13, color: Color(0xFFB0B6C0))),
                    ],
                  ),
                ],
              ),
            ),
            if (!done && task.reminderAt != null)
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 2),
                child: Icon(Icons.notifications_none, size: 18, color: Color(0xFFC8CDD4)),
              ),
          ],
        ),
      ),
    );
  }
}

class _InboxChip extends StatelessWidget {
  const _InboxChip({required this.label, required this.muted});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: muted ? const Color(0xFFF7F7F8) : SlotColors.chip,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 13, color: muted ? const Color(0xFFC5CAD3) : SlotColors.inbox),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: muted ? const Color(0xFFC5CAD3) : SlotColors.chipText)),
        ],
      ),
    );
  }
}

class ListsPane extends StatelessWidget {
  const ListsPane({
    super.key,
    required this.openedName,
    required this.onOpenedName,
    required this.onAdd,
    required this.onToggle,
    this.sortByDuration = false,
    this.showHistory = false,
    this.showDetails = true,
    this.tagFilter,
    this.editListName,
    this.editFolderId,
    this.onEditConsumed,
    this.onEditingChanged,
  });

  final String? openedName;
  final ValueChanged<String?> onOpenedName;
  final VoidCallback onAdd;
  final Future<void> Function(Task task) onToggle;
  final bool sortByDuration;
  final bool showHistory;
  final bool showDetails;
  final String? tagFilter;
  final String? editListName;
  final String? editFolderId;
  final VoidCallback? onEditConsumed;
  final ValueChanged<bool>? onEditingChanged;

  @override
  Widget build(BuildContext context) {
    final opened = openedName;
    if (opened == null) {
      return ListsBrowser(
        onOpen: (name) => onOpenedName(name),
        editListName: editListName,
        editFolderId: editFolderId,
        onEditConsumed: onEditConsumed,
        onEditingChanged: onEditingChanged,
        empty: const SizedBox(height: 320, child: _ListsEmpty()),
      );
    }
    return _ListDetail(
      name: opened,
      onAdd: onAdd,
      onToggle: onToggle,
      sortByDuration: sortByDuration,
      showHistory: showHistory,
      showDetails: showDetails,
      tagFilter: tagFilter,
    );
  }
}

class _ListDetail extends StatelessWidget {
  const _ListDetail({
    required this.name,
    required this.onAdd,
    required this.onToggle,
    required this.sortByDuration,
    required this.showHistory,
    required this.showDetails,
    this.tagFilter,
  });

  final String name;
  final VoidCallback onAdd;
  final Future<void> Function(Task task) onToggle;
  final bool sortByDuration;
  final bool showHistory;
  final bool showDetails;
  final String? tagFilter;

  bool _matches(Task task) {
    if (task.listName != name) return false;
    if (tagFilter != null && !task.tags.contains(tagFilter!)) return false;
    return true;
  }

  int _compare(Task a, Task b) {
    if (sortByDuration) {
      final aEmpty = a.durationMinutes <= 0;
      final bEmpty = b.durationMinutes <= 0;
      if (aEmpty != bEmpty) return aEmpty ? 1 : -1;
      final byDuration = b.durationMinutes.compareTo(a.durationMinutes);
      if (byDuration != 0) return byDuration;
    }
    final aTime = isScheduled(a) ? a.startTime : null;
    final bTime = isScheduled(b) ? b.startTime : null;
    if (aTime == null && bTime == null) return a.createdAt.compareTo(b.createdAt);
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return aTime.compareTo(bTime);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final settings = context.watch<AppSettings>();
    final active = provider.inboxTasks.where(_matches).toList()..sort(_compare);
    final history = showHistory ? (provider.completedTasks.where(_matches).toList()..sort(_compare)) : const <Task>[];
    final tasks = [...active, ...history];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add, color: Color(0xFFC5CAD3), size: 28),
          ),
        ),
        Expanded(
          child: tasks.isEmpty
              ? const _ListDetailEmpty()
              : ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    for (final task in tasks)
                      PlanTaskRow(
                        task: task,
                        settings: settings,
                        hideDetails: !showDetails,
                        onToggle: () => onToggle(task),
                        onTap: () => openTaskEditor(context, task),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ListDetailEmpty extends StatelessWidget {
  const _ListDetailEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(size: Size(220, 132), painter: _JourneyPainter()),
            SizedBox(height: 28),
            Text(
              '如果您等一个完美的时刻等了太久，这完美的时刻可能就会离您而去。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFC5CAD3), fontSize: 15, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class TagsPane extends StatelessWidget {
  const TagsPane({
    super.key,
    required this.onOpen,
    this.editName,
    this.onEditConsumed,
    this.onEditingChanged,
  });

  final ValueChanged<String> onOpen;
  final String? editName;
  final VoidCallback? onEditConsumed;
  final ValueChanged<bool>? onEditingChanged;

  @override
  Widget build(BuildContext context) {
    return TagsBrowser(
      onOpen: onOpen,
      editName: editName,
      onEditConsumed: onEditConsumed,
      onEditingChanged: onEditingChanged,
    );
  }
}

class HistoryPane extends StatelessWidget {
  const HistoryPane({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final tasks = context.watch<ScheduleProvider>().completedTasks;
    if (tasks.isEmpty) return const _Empty(text: '还没有完成的任务');
    return ListView(
      padding: const EdgeInsets.only(top: 8),
      children: [
        for (final task in tasks)
          PlanTaskRow(
            task: task,
            settings: settings,
            hideDetails: false,
            onToggle: () async {
              await context.read<ScheduleProvider>().saveTask(
                    task.copyWith(isCompleted: false, updatedAt: DateTime.now()),
                  );
            },
            onTap: () => openTaskEditor(context, task),
          ),
      ],
    );
  }
}

class TrashPane extends StatelessWidget {
  const TrashPane({super.key});

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<ScheduleProvider>().trashTasks;
    if (tasks.isEmpty) return const _Empty(text: '回收站是空的');
    return ListView(
      children: [
        for (final task in tasks)
          ListTile(
            title: Text(task.title.isEmpty ? '未命名' : task.title),
            subtitle: const Text('已删除'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '恢复',
                  onPressed: () => context.read<ScheduleProvider>().restoreTask(task),
                  icon: const Icon(Icons.restore, color: SlotColors.today),
                ),
                IconButton(
                  tooltip: '彻底删除',
                  onPressed: () => context.read<ScheduleProvider>().deleteTaskPermanently(task.id),
                  icon: const Icon(Icons.delete_forever, color: SlotColors.overdue),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class GuidePane extends StatelessWidget {
  const GuidePane({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: const [
        _GuideBlock(title: '计划', body: '底部左右箭头切换日期。点中间的横条展开月历，绿点表示那天有任务，格子下方是当天的农历。'),
        _GuideBlock(title: '添加', body: '点右下角加号，或列表里的加号，把任务放到当前这一天。没有具体时间的任务显示为随时。'),
        _GuideBlock(title: '时间线', body: '从右上角菜单打开时间线。长按任务拖到某一小时即可排期，拖回「随时」则取消时间。重叠的任务会并排显示。'),
        _GuideBlock(title: '自动计划', body: '把当天的随时任务按 30 分钟一段，从上午 9 点起填进空档。已经排好的时间会被跳过。'),
        _GuideBlock(title: '筛选和详情', body: '可以按列表或标签筛选。隐藏详情后只保留标题。过期任务会标红，可在设置里关闭。'),
      ],
    );
  }
}

class _GuideBlock extends StatelessWidget {
  const _GuideBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 15, height: 1.4, color: SlotColors.inkSecondary)),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: const TextStyle(color: SlotColors.inkSecondary)),
    );
  }
}

class _ListsEmpty extends StatelessWidget {
  const _ListsEmpty();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment(0, -0.35),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: Size(220, 132),
            painter: _JourneyPainter(),
          ),
          SizedBox(height: 28),
          Text(
            '千里之行始于足下。',
            style: TextStyle(color: Color(0xFFC5CAD3), fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _JourneyPainter extends CustomPainter {
  const _JourneyPainter();

  static const _ink = Color(0xFF8E9AAB);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _cloud(canvas, stroke, const Offset(28, 28), 16);
    _cloud(canvas, stroke, const Offset(78, 16), 20);
    _cloud(canvas, stroke, const Offset(132, 30), 14);
    _moon(canvas, stroke, const Offset(108, 42), 11);

    final hill = Path()
      ..moveTo(0, 92)
      ..quadraticBezierTo(36, 70, 78, 86)
      ..quadraticBezierTo(128, 106, 168, 78)
      ..quadraticBezierTo(198, 62, 220, 74);
    canvas.drawPath(hill, stroke);

    _roundTree(canvas, stroke, const Offset(46, 78), 16, 22);
    _roundTree(canvas, stroke, const Offset(78, 86), 13, 16);
    _pine(canvas, stroke, const Offset(118, 78), 18, 28);
    _roundTree(canvas, stroke, const Offset(150, 70), 15, 20);
    _pine(canvas, stroke, const Offset(178, 74), 14, 22);
  }

  void _cloud(Canvas canvas, Paint paint, Offset center, double radius) {
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center + Offset(radius * 0.9, 2), radius * 0.75, paint);
    canvas.drawCircle(center + Offset(-radius * 0.85, 3), radius * 0.65, paint);
  }

  void _moon(Canvas canvas, Paint paint, Offset center, double radius) {
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0.8,
      4.2,
      false,
      paint,
    );
  }

  void _roundTree(Canvas canvas, Paint paint, Offset ground, double crown, double height) {
    canvas.drawLine(ground, ground + Offset(0, -height * 0.35), paint);
    canvas.drawCircle(ground + Offset(0, -height), crown, paint);
  }

  void _pine(Canvas canvas, Paint paint, Offset ground, double width, double height) {
    final tip = ground + Offset(0, -height);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(ground.dx - width / 2, ground.dy)
      ..lineTo(ground.dx + width / 2, ground.dy)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawLine(ground, ground + const Offset(0, 8), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
