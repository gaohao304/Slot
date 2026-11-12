import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/app_settings.dart';
import '../providers/schedule_provider.dart';
import '../services/notification_service.dart';
import '../theme/slot_colors.dart';
import '../utils/task_time.dart';
import 'plan_task_row.dart';

/// 标签首页。行样式与列表相同，长按可以拖动排序。
class TagsBrowser extends StatefulWidget {
  const TagsBrowser({
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
  State<TagsBrowser> createState() => _TagsBrowserState();
}

class _TagsBrowserState extends State<TagsBrowser> {
  String? _editing;

  @override
  void didUpdateWidget(TagsBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    final name = widget.editName;
    if (name != null && name != oldWidget.editName) {
      _editing = name;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onEditConsumed?.call();
        widget.onEditingChanged?.call(true);
      });
    }
  }

  Future<void> _commit(String original, String raw) async {
    if (_editing == original) {
      setState(() => _editing = null);
      widget.onEditingChanged?.call(false);
    }
    final next = raw.trim();
    if (next.isEmpty || next == original || !mounted) return;
    await context.read<ScheduleProvider>().renameTag(original, next);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final names = provider.knownTagNames;
    if (names.isEmpty) {
      return const Center(child: Text('还没有标签', style: TextStyle(color: SlotColors.inkSecondary)));
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      buildDefaultDragHandles: false,
      itemCount: names.length,
      onReorder: (oldIndex, newIndex) => context.read<ScheduleProvider>().reorderTags(oldIndex, newIndex),
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 8,
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final name = names[index];
        final editing = _editing == name;
        final row = _tagRow(name, provider.inboxTasks, editing: editing);
        if (editing) return KeyedSubtree(key: ValueKey(name), child: row);
        return ReorderableDelayedDragStartListener(
          key: ValueKey(name),
          index: index,
          child: row,
        );
      },
    );
  }

  Widget _tagRow(String name, List<Task> tasks, {required bool editing}) {
    final inTag = tasks.where((task) => task.tags.contains(name));
    final total = inTag.length;
    final unplanned = inTag.where((task) => !isScheduled(task)).length;
    return Opacity(
      opacity: _editing != null && !editing ? 0.35 : 1,
      child: ColoredBox(
        color: editing ? const Color(0xFFD4EBFF) : Colors.transparent,
        child: InkWell(
          onTap: editing ? null : () => widget.onOpen(name),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(top: 3, right: 14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFC5CAD3), width: 1.6),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      editing
                          ? _TagNameField(initial: name, onDone: (value) => _commit(name, value))
                          : GestureDetector(
                              onTap: () {
                                setState(() => _editing = name);
                                widget.onEditingChanged?.call(true);
                              },
                              child: Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                            ),
                      const SizedBox(height: 3),
                      Text(
                        '$total条任务  $unplanned条未计划',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF9AA3B2)),
                      ),
                    ],
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

/// 点进某个标签后的任务页。
class TagDetailPane extends StatelessWidget {
  const TagDetailPane({
    super.key,
    required this.name,
    required this.onAdd,
    required this.sortByDuration,
    required this.showHistory,
    required this.showDetails,
    this.listFilter,
    this.tagFilter,
  });

  final String name;
  final VoidCallback onAdd;
  final bool sortByDuration;
  final bool showHistory;
  final bool showDetails;
  final String? listFilter;
  final String? tagFilter;

  bool _matches(Task task) {
    if (!task.tags.contains(name)) return false;
    if (listFilter != null && listLabelOf(task) != listFilter) return false;
    if (tagFilter != null && !task.tags.contains(tagFilter)) return false;
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
              ? const _TagEmpty()
              : ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    for (final task in tasks)
                      PlanTaskRow(
                        task: task,
                        settings: settings,
                        hideDetails: !showDetails,
                        onToggle: () => _toggle(context, task),
                        onTap: () => openTaskEditor(context, task),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _toggle(BuildContext context, Task task) async {
    final next = !task.isCompleted;
    await context.read<ScheduleProvider>().saveTask(
          task.copyWith(isCompleted: next, updatedAt: DateTime.now()),
        );
    if (next) await NotificationService.instance.cancel(task.id);
  }
}

class _TagEmpty extends StatelessWidget {
  const _TagEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(size: Size(220, 132), painter: _TagJourneyPainter()),
          SizedBox(height: 28),
          Text('是时候尝试新事物了。', style: TextStyle(color: Color(0xFFC5CAD3), fontSize: 15)),
        ],
      ),
    );
  }
}

class _TagJourneyPainter extends CustomPainter {
  const _TagJourneyPainter();

  static const _ink = Color(0xFF8E9AAB);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(const Offset(28, 28), 16, stroke);
    canvas.drawCircle(const Offset(42, 30), 12, stroke);
    canvas.drawCircle(const Offset(78, 16), 20, stroke);
    canvas.drawCircle(const Offset(96, 18), 15, stroke);
    canvas.drawCircle(const Offset(132, 30), 14, stroke);
    canvas.drawArc(Rect.fromCircle(center: const Offset(108, 42), radius: 11), 0.8, 4.2, false, stroke);
    final hill = Path()
      ..moveTo(0, 92)
      ..quadraticBezierTo(36, 70, 78, 86)
      ..quadraticBezierTo(128, 106, 168, 78)
      ..quadraticBezierTo(198, 62, 220, 74);
    canvas.drawPath(hill, stroke);
    _tree(canvas, stroke, const Offset(46, 78), 16, 22);
    _tree(canvas, stroke, const Offset(150, 70), 15, 20);
    final tip = const Offset(118, 50);
    final pine = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(109, 78)
      ..lineTo(127, 78)
      ..close();
    canvas.drawPath(pine, stroke);
  }

  void _tree(Canvas canvas, Paint paint, Offset ground, double crown, double height) {
    canvas.drawLine(ground, ground + Offset(0, -height * 0.35), paint);
    canvas.drawCircle(ground + Offset(0, -height), crown, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TagNameField extends StatefulWidget {
  const _TagNameField({required this.initial, required this.onDone});

  final String initial;
  final ValueChanged<String> onDone;

  @override
  State<_TagNameField> createState() => _TagNameFieldState();
}

class _TagNameFieldState extends State<_TagNameField> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);
  late final FocusNode _focus = FocusNode();
  var _finished = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _finish();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    });
  }

  @override
  void dispose() {
    _finished = true;
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    final text = _controller.text;
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone(text));
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      autofocus: true,
      textInputAction: TextInputAction.done,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: SlotColors.ink),
      cursorColor: SlotColors.today,
      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none),
      onSubmitted: (_) => _focus.unfocus(),
      onTapOutside: (_) => _focus.unfocus(),
    );
  }
}
