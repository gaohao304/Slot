import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/list_catalog.dart';
import '../models/task.dart';
import '../providers/schedule_provider.dart';
import '../theme/slot_colors.dart';
import '../utils/task_time.dart';

Future<void> showMoveListToFolder(BuildContext context, String name) async {
  await _pickFolder(context, name);
}

Future<void> _pickFolder(BuildContext context, String name) async {
  final provider = context.read<ScheduleProvider>();
  final folders = provider.listCatalog.folders;
  final folderId = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('不放入目录'),
              onTap: () => Navigator.pop(sheetContext, ''),
            ),
            for (final folder in folders)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(folder.name),
                onTap: () => Navigator.pop(sheetContext, folder.id),
              ),
          ],
        ),
      );
    },
  );
  if (folderId == null || !context.mounted) return;
  await provider.moveList(name, folderId: folderId.isEmpty ? null : folderId);
}

/// 列表首页：未分组列表、可折叠目录，以及最下方的已存档。
class ListsBrowser extends StatefulWidget {
  const ListsBrowser({
    super.key,
    required this.onOpen,
    this.editListName,
    this.editFolderId,
    this.onEditConsumed,
    this.onEditingChanged,
    this.empty,
  });

  final ValueChanged<String> onOpen;
  final String? editListName;
  final String? editFolderId;
  final VoidCallback? onEditConsumed;
  final ValueChanged<bool>? onEditingChanged;
  final Widget? empty;

  @override
  State<ListsBrowser> createState() => _ListsBrowserState();
}

class _ListsBrowserState extends State<ListsBrowser> {
  final _scroll = ScrollController();
  final Set<String> _expanded = {};
  bool _archiveOpen = false;
  String? _editingList;
  String? _editingFolderId;

  bool get _editing => _editingList != null || _editingFolderId != null;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _followDrag(DragUpdateDetails details) {
    if (!_scroll.hasClients) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final dy = box.globalToLocal(details.globalPosition).dy;
    const edge = 72.0;
    final height = box.size.height;
    var delta = 0.0;
    if (dy < edge) {
      delta = -((edge - dy) / edge) * 16;
    } else if (dy > height - edge) {
      delta = ((dy - (height - edge)) / edge) * 16;
    }
    if (delta == 0) return;
    final position = _scroll.position;
    _scroll.jumpTo((position.pixels + delta).clamp(0, position.maxScrollExtent));
  }

  @override
  void didUpdateWidget(ListsBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    final listName = widget.editListName;
    final folderId = widget.editFolderId;
    if (listName != null && listName != oldWidget.editListName) {
      _editingList = listName;
      _editingFolderId = null;
      _revealList(listName);
      _consumeEdit();
    } else if (folderId != null && folderId != oldWidget.editFolderId) {
      _editingFolderId = folderId;
      _editingList = null;
      _consumeEdit();
    }
  }

  void _consumeEdit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onEditConsumed?.call();
      widget.onEditingChanged?.call(true);
    });
  }

  void _revealList(String name) {
    final catalog = context.read<ScheduleProvider>().listCatalog;
    for (final folder in catalog.folders) {
      if (folder.lists.contains(name)) _expanded.add(folder.id);
    }
    if (catalog.archived.contains(name)) _archiveOpen = true;
  }

  Future<void> _commitList(String original, String raw) async {
    if (_editingList == original) {
      setState(() => _editingList = null);
      if (_editingFolderId == null) widget.onEditingChanged?.call(false);
    }
    final next = raw.trim();
    if (next.isEmpty || next == original || !mounted) return;
    await context.read<ScheduleProvider>().renameList(original, next);
  }

  Future<void> _commitFolder(String id, String raw) async {
    if (_editingFolderId == id) {
      setState(() => _editingFolderId = null);
      if (_editingList == null) widget.onEditingChanged?.call(false);
    }
    final next = raw.trim();
    if (next.isEmpty || !mounted) return;
    await context.read<ScheduleProvider>().renameFolder(id, next);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final catalog = provider.listCatalog;
    final tasks = provider.inboxTasks;
    final showJourney = catalog.loose.isEmpty && catalog.folders.isEmpty && catalog.archived.isEmpty;

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        _dropOnto(
          accepts: (name) => !catalog.loose.contains(name),
          onDrop: (name) => context.read<ScheduleProvider>().moveList(name),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showJourney && widget.empty != null) widget.empty!,
              for (final name in catalog.loose) _listRow(name, tasks, indent: 22),
              if (catalog.loose.isEmpty && !(showJourney && widget.empty != null)) const SizedBox(height: 88),
              if (catalog.loose.isNotEmpty) const _DashedDivider(),
            ],
          ),
        ),
        for (final folder in catalog.folders) ...[
          _dropOnto(
            accepts: (name) => !folder.lists.contains(name),
            onDrop: (name) async {
              await context.read<ScheduleProvider>().moveList(name, folderId: folder.id);
              if (!mounted) return;
              setState(() => _expanded.add(folder.id));
            },
            child: _folderRow(folder),
          ),
          if (_expanded.contains(folder.id))
            for (final name in folder.lists)
              _listRow(name, tasks, indent: 48),
          const _DashedDivider(),
        ],
        if (catalog.folders.isEmpty) const _DashedDivider(),
        _archiveRow(catalog, tasks),
      ],
    );
  }

  Widget _archiveRow(ListCatalog catalog, List<Task> tasks) {
    return Column(
      children: [
        _dropOnto(
          accepts: (name) => !catalog.archived.contains(name),
          onDrop: (name) async {
            await context.read<ScheduleProvider>().moveList(name, archive: true);
            if (!mounted) return;
            setState(() => _archiveOpen = true);
          },
          child: _sectionHeader(
            icon: Icons.folder_outlined,
            title: '已存档',
            expanded: _archiveOpen,
            faded: _editing,
            onToggle: () => setState(() => _archiveOpen = !_archiveOpen),
          ),
        ),
        if (_archiveOpen)
          for (final name in catalog.archived)
            _listRow(name, tasks, indent: 48),
      ],
    );
  }

  Widget _folderRow(ListFolder folder) {
    final editing = _editingFolderId == folder.id;
    return Opacity(
      opacity: _editing && !editing ? 0.35 : 1,
      child: ColoredBox(
        color: editing ? const Color(0xFFD4EBFF) : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 8, 10),
          child: Row(
            children: [
              const Icon(Icons.folder_outlined, color: Color(0xFF8E9AAB), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: editing
                    ? _NameField(
                        initial: folder.name,
                        onDone: (value) => _commitFolder(folder.id, value),
                      )
                    : GestureDetector(
                        onTap: () {
                          setState(() {
                            _editingFolderId = folder.id;
                            _editingList = null;
                          });
                          widget.onEditingChanged?.call(true);
                        },
                        child: Text(
                          folder.name,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                      ),
              ),
              IconButton(
                onPressed: () {
                  if (editing) return;
                  setState(() {
                    if (_expanded.contains(folder.id)) {
                      _expanded.remove(folder.id);
                    } else {
                      _expanded.add(folder.id);
                    }
                  });
                },
                icon: Icon(
                  _expanded.contains(folder.id) ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: const Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required bool expanded,
    required bool faded,
    required VoidCallback onToggle,
  }) {
    return Opacity(
      opacity: faded ? 0.35 : 1,
      child: InkWell(
        onTap: _editing ? null : onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 8, 10),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF8E9AAB), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              Icon(
                expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: const Color(0xFF8E8E93),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropOnto({
    required bool Function(String name) accepts,
    required Future<void> Function(String name) onDrop,
    required Widget child,
  }) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => accepts(details.data),
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidate, _) {
        return ColoredBox(
          color: candidate.isEmpty ? Colors.transparent : const Color(0xFFD4EBFF),
          child: child,
        );
      },
    );
  }

  Widget _listRow(String name, List<Task> tasks, {required double indent}) {
    final inList = tasks.where((task) => task.listName?.trim() == name);
    final total = inList.length;
    final unplanned = inList.where((task) => !isScheduled(task)).length;
    final editing = _editingList == name;
    final row = Opacity(
      opacity: _editing && !editing ? 0.35 : 1,
      child: ColoredBox(
        color: editing ? const Color(0xFFD4EBFF) : Colors.transparent,
        child: InkWell(
          onTap: editing ? null : () => widget.onOpen(name),
          child: Padding(
            padding: EdgeInsets.fromLTRB(indent, 12, 16, 12),
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
                          ? _NameField(
                              initial: name,
                              onDone: (value) => _commitList(name, value),
                            )
                          : GestureDetector(
                              onTap: () {
                                setState(() {
                                  _editingList = name;
                                  _editingFolderId = null;
                                });
                                widget.onEditingChanged?.call(true);
                              },
                              child: Text(
                                name,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                              ),
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
    if (editing) return row;
    final width = MediaQuery.sizeOf(context).width - 24;
    return LongPressDraggable<String>(
      data: name,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragUpdate: _followDrag,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFC5CAD3), width: 1.6),
                  ),
                ),
                Expanded(
                  child: Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: row),
      child: row,
    );
  }
}

class _NameField extends StatefulWidget {
  const _NameField({required this.initial, required this.onDone});

  final String initial;
  final ValueChanged<String> onDone;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
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
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
      ),
      onSubmitted: (_) => _focus.unfocus(),
      onTapOutside: (_) => _focus.unfocus(),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(22, 6, 22, 6),
      child: SizedBox(
        height: 1,
        width: double.infinity,
        child: CustomPaint(painter: _DashPainter()),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD0D5DD)
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      final end = x + dash > size.width ? size.width : x + dash;
      canvas.drawLine(Offset(x, 0), Offset(end, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

