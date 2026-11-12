import 'package:flutter/material.dart';

import '../models/repeat_rule.dart';
import '../theme/slot_colors.dart';
import '../utils/task_time.dart';

enum SetupPage { time, date, reminder, repeat }

class ScheduleDraft {
  ScheduleDraft({
    required this.day,
    this.anytime = true,
    this.time = const TimeOfDay(hour: 0, minute: 0),
    this.reminderOn = false,
    this.reminderMinutes = 0,
    this.repeat,
  });

  DateTime day;
  bool anytime;
  TimeOfDay time;
  bool reminderOn;
  int reminderMinutes;
  RepeatRule? repeat;

  DateTime get start {
    if (anytime) return dateOnly(day);
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  DateTime get reminderAt => start.subtract(Duration(minutes: reminderMinutes));
}

Future<ScheduleDraft?> showScheduleSetup(
  BuildContext context, {
  required ScheduleDraft draft,
  SetupPage initial = SetupPage.time,
}) {
  return showGeneralDialog<ScheduleDraft>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭设置',
    barrierColor: Colors.black38,
    pageBuilder: (_, _, _) => _SetupSheet(initial: draft, page: initial),
  );
}

class _SetupSheet extends StatefulWidget {
  const _SetupSheet({required this.initial, required this.page});

  final ScheduleDraft initial;
  final SetupPage page;

  @override
  State<_SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends State<_SetupSheet> {
  late ScheduleDraft _draft;
  late SetupPage _page;
  bool _editingRepeat = false;

  @override
  void initState() {
    super.initState();
    final source = widget.initial;
    _draft = ScheduleDraft(
      day: source.day,
      anytime: source.anytime,
      time: source.time,
      reminderOn: source.reminderOn,
      reminderMinutes: source.reminderMinutes,
      repeat: source.repeat == null
          ? null
          : RepeatRule(
              afterComplete: source.repeat!.afterComplete,
              every: source.repeat!.every,
              unit: source.repeat!.unit,
              end: source.repeat!.end,
              endDate: source.repeat!.endDate,
              endCount: source.repeat!.endCount,
            ),
    );
    _page = widget.page;
    _editingRepeat = _draft.repeat != null && _page == SetupPage.repeat;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.62;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: Material(
            color: const Color(0xFF1B2838),
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: height,
              child: Column(
                children: [
                  _header(),
                  const Divider(height: 1, color: Color(0xFF314158)),
                  Expanded(child: _body()),
                  _tabBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final editing = _page == SetupPage.repeat && _editingRepeat;
    final title = switch (_page) {
      SetupPage.time => '时间',
      SetupPage.date => '日期',
      SetupPage.reminder => '提前提醒',
      SetupPage.repeat => '重复',
    };
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          TextButton(
            onPressed: () {
              if (editing) {
                setState(() {
                  _editingRepeat = false;
                  _draft.repeat = null;
                });
                return;
              }
              _clearPage();
            },
            child: Text(
              editing ? '取消' : '清除',
              style: TextStyle(color: editing ? Colors.white70 : const Color(0xFFFF5A5A)),
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_draft),
            child: const Text('完成', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _clearPage() {
    setState(() {
      switch (_page) {
        case SetupPage.time:
          _draft.anytime = true;
          _draft.time = const TimeOfDay(hour: 0, minute: 0);
        case SetupPage.date:
          _draft.day = dateOnly(DateTime.now());
        case SetupPage.reminder:
          _draft.reminderOn = false;
          _draft.reminderMinutes = 0;
        case SetupPage.repeat:
          _draft.repeat = null;
          _editingRepeat = false;
      }
    });
  }

  Widget _body() {
    return switch (_page) {
      SetupPage.time => _timePage(),
      SetupPage.date => _datePage(),
      SetupPage.reminder => _reminderPage(),
      SetupPage.repeat => _editingRepeat ? _repeatEditor() : _repeatEmpty(),
    };
  }

  Widget _timePage() {
    return Column(
      children: [
        const SizedBox(height: 14),
        Text(_weekdayDate(_draft.day), style: const TextStyle(color: Colors.white70, fontSize: 16)),
        if (!_draft.anytime)
          Text(_clock(_draft.time), style: const TextStyle(color: Colors.white, fontSize: 16)),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: const Text('随时', style: TextStyle(color: Colors.white)),
          value: _draft.anytime,
          activeTrackColor: SlotColors.today,
          onChanged: (value) => setState(() => _draft.anytime = value),
        ),
        SizedBox(height: 88, child: _dayStrip()),
        SizedBox(
          height: 120,
          child: Stack(
            children: [
              Opacity(
                opacity: _draft.anytime ? 0.35 : 1,
                child: IgnorePointer(
                  ignoring: _draft.anytime,
                  child: _TimeWheels(
                    time: _draft.time,
                    onChanged: (time) => setState(() => _draft.time = time),
                  ),
                ),
              ),
              if (_draft.anytime)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _draft.anytime = false),
                  ),
                ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _preset('早晨', '上午9:00', const TimeOfDay(hour: 9, minute: 0)),
              _preset('下午', '下午1:00', const TimeOfDay(hour: 13, minute: 0)),
              _preset('傍晚', '下午7:00', const TimeOfDay(hour: 19, minute: 0)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _preset(String title, String subtitle, TimeOfDay time) {
    return TextButton(
      onPressed: () => setState(() {
        _draft.anytime = false;
        _draft.time = time;
      }),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: SlotColors.today, fontSize: 16)),
          Text(subtitle, style: const TextStyle(color: SlotColors.today, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _dayStrip() {
    final start = _draft.day.subtract(const Duration(days: 3));
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: 14,
      itemBuilder: (context, index) {
        final day = start.add(Duration(days: index));
        final selected = sameDay(day, _draft.day);
        final today = sameDay(day, DateTime.now());
        final tomorrow = sameDay(day, DateTime.now().add(const Duration(days: 1)));
        final top = today ? '★' : (tomorrow ? '明天' : _week(day));
        return GestureDetector(
          onTap: () => setState(() => _draft.day = dateOnly(day)),
          child: Container(
            width: 58,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? SlotColors.today : Colors.transparent, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  top,
                  style: TextStyle(
                    color: today ? const Color(0xFFFFD60A) : Colors.white70,
                    fontSize: 11,
                    height: 1.05,
                  ),
                ),
                Text(
                  '${day.day}',
                  style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.1, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${day.month}月',
                  style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.05),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _datePage() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Text(_weekdayDate(_draft.day), style: const TextStyle(color: Colors.white70)),
        if (!_draft.anytime) Text(_clock(_draft.time), style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        const Divider(height: 1, color: Color(0xFF314158)),
        Expanded(
          child: _MiniMonth(
            day: _draft.day,
            onSelect: (day) => setState(() => _draft.day = day),
          ),
        ),
      ],
    );
  }

  Widget _reminderPage() {
    final event = DateTime(
      _draft.day.year,
      _draft.day.month,
      _draft.day.day,
      _draft.time.hour,
      _draft.time.minute,
    );
    final remind = event.subtract(Duration(minutes: _draft.reminderMinutes));
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _timeBlock(remind, Colors.white),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Icon(Icons.arrow_back, color: Colors.white38, size: 18),
            ),
            _timeBlock(event, Colors.white54),
          ],
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: const Text('提醒', style: TextStyle(color: Colors.white)),
          value: _draft.reminderOn,
          activeTrackColor: SlotColors.today,
          onChanged: (value) => setState(() => _draft.reminderOn = value),
        ),
        IgnorePointer(
          ignoring: !_draft.reminderOn,
          child: Opacity(
            opacity: _draft.reminderOn ? 1 : 0.35,
            child: _HourMinuteWheels(
              minutes: _draft.reminderMinutes,
              onChanged: (minutes) => setState(() => _draft.reminderMinutes = minutes),
            ),
          ),
        ),
        const Spacer(),
        _quickMinutes(
          onPick: (minutes) => setState(() {
            _draft.reminderOn = minutes > 0;
            _draft.reminderMinutes = minutes;
          }),
        ),
      ],
    );
  }

  Widget _timeBlock(DateTime value, Color color) {
    return Column(
      children: [
        Text(_weekdayDate(value), style: TextStyle(color: color)),
        Text(_clock(TimeOfDay.fromDateTime(value)), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _repeatEmpty() {
    return Column(
      children: [
        const SizedBox(height: 28),
        const Text('没有重复', style: TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: SlotColors.today,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => setState(() {
                _draft.repeat = RepeatRule();
                _editingRepeat = true;
              }),
              child: const Text('添加'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _repeatEditor() {
    final rule = _draft.repeat!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF243244),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              _seg('完成后', rule.afterComplete, () => setState(() => rule.afterComplete = true)),
              _seg('定期', !rule.afterComplete, () => setState(() => rule.afterComplete = false)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF121A24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text.rich(
            TextSpan(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              children: [
                TextSpan(text: rule.summary(_draft.day).split('每').first),
                TextSpan(text: '每${rule.every}${rule.unitLabel}', style: const TextStyle(color: SlotColors.today)),
                TextSpan(text: rule.afterComplete ? '再次安排' : '重复'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        _RepeatWheels(
          every: rule.every,
          unit: rule.unit,
          onChanged: (every, unit) => setState(() {
            rule.every = every;
            rule.unit = unit;
          }),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('时间', style: TextStyle(color: Colors.white)),
          trailing: Text(
            _draft.anytime ? '随时' : _clock(_draft.time),
            style: const TextStyle(color: SlotColors.today),
          ),
          onTap: () => setState(() => _page = SetupPage.time),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('结束', style: TextStyle(color: Colors.white)),
          trailing: Text(_endLabel(rule), style: const TextStyle(color: SlotColors.today)),
          onTap: _pickEnd,
        ),
      ],
    );
  }

  String _endLabel(RepeatRule rule) {
    return switch (rule.end) {
      RepeatEnd.never => '从不',
      RepeatEnd.onDate => rule.endDate == null
          ? '于日期'
          : '${rule.endDate!.year}年${rule.endDate!.month}月${rule.endDate!.day}日',
      RepeatEnd.count => '${rule.endCount}次',
    };
  }

  Future<void> _pickEnd() async {
    final rule = _draft.repeat!;
    final choice = await showModalBottomSheet<RepeatEnd>(
      context: context,
      backgroundColor: const Color(0xFF1B2838),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('从不', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, RepeatEnd.never),
            ),
            ListTile(
              title: const Text('于日期', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, RepeatEnd.onDate),
            ),
            ListTile(
              title: const Text('重复次数', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, RepeatEnd.count),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == RepeatEnd.onDate) {
      final picked = await showDatePicker(
        context: context,
        initialDate: rule.endDate ?? _draft.day,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
      );
      if (picked == null || !mounted) return;
      setState(() {
        rule.end = RepeatEnd.onDate;
        rule.endDate = picked;
      });
      return;
    }
    if (choice == RepeatEnd.count) {
      final count = await _pickCount(rule.endCount);
      if (count == null || !mounted) return;
      setState(() {
        rule.end = RepeatEnd.count;
        rule.endCount = count;
      });
      return;
    }
    setState(() => rule.end = RepeatEnd.never);
  }

  Future<int?> _pickCount(int current) {
    var value = current;
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2838),
        title: const Text('重复次数', style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (context, setLocal) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => setLocal(() => value = value > 1 ? value - 1 : 1),
                icon: const Icon(Icons.remove, color: Colors.white),
              ),
              Text('$value', style: const TextStyle(color: Colors.white, fontSize: 24)),
              IconButton(
                onPressed: () => setLocal(() => value += 1),
                icon: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, value), child: const Text('完成')),
        ],
      ),
    );
  }

  Widget _seg(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? SlotColors.today : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70)),
        ),
      ),
    );
  }

  Widget _tabBar() {
    return SizedBox(
      height: 52,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _tab(Icons.schedule, SetupPage.time),
          _tab(Icons.calendar_month, SetupPage.date),
          _tab(Icons.notifications_none, SetupPage.reminder),
          _tab(Icons.repeat, SetupPage.repeat),
        ],
      ),
    );
  }

  Widget _tab(IconData icon, SetupPage page) {
    final selected = _page == page;
    return IconButton(
      onPressed: () => setState(() => _page = page),
      icon: Icon(icon, color: selected ? SlotColors.today : const Color(0xFF8E8E93)),
    );
  }

  Widget _quickMinutes({required ValueChanged<int> onPick}) {
    const options = [(0, '无'), (60, '1h'), (90, '1h 30m'), (120, '2h'), (240, '4h')];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final option in options)
            TextButton(
              onPressed: () => onPick(option.$1),
              child: Text(option.$2, style: const TextStyle(color: SlotColors.today)),
            ),
        ],
      ),
    );
  }
}

class _MiniMonth extends StatefulWidget {
  const _MiniMonth({required this.day, required this.onSelect});

  final DateTime day;
  final ValueChanged<DateTime> onSelect;

  @override
  State<_MiniMonth> createState() => _MiniMonthState();
}

class _MiniMonthState extends State<_MiniMonth> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.day.year, widget.day.month);
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(_month.year, _month.month, 1);
    final leading = first.weekday % 7;
    final start = first.subtract(Duration(days: leading));
    const labels = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        setState(() {
          _month = DateTime(_month.year, _month.month + (velocity < 0 ? 1 : -1));
        });
      },
      child: Column(
        children: [
          Text(
            chineseMonthTitle(_month),
            style: const TextStyle(color: SlotColors.today, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final label in labels)
                Expanded(
                  child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ),
            ],
          ),
          for (var week = 0; week < 6; week++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(child: _cell(start.add(Duration(days: week * 7 + col)))),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(DateTime day) {
    final inMonth = day.month == _month.month;
    final selected = sameDay(day, widget.day);
    return GestureDetector(
      onTap: () => widget.onSelect(dateOnly(day)),
      child: Container(
        height: 36,
        alignment: Alignment.center,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? SlotColors.today : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${day.day}',
            style: TextStyle(color: inMonth ? Colors.white : Colors.white30, fontWeight: selected ? FontWeight.w700 : FontWeight.w400),
          ),
        ),
      ),
    );
  }
}

class _TimeWheels extends StatelessWidget {
  const _TimeWheels({required this.time, required this.onChanged});

  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    final am = time.hour < 12;
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = (time.minute / 5).round().clamp(0, 11);
    return SizedBox(
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 36),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SlotColors.today, width: 2),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Wheel(
                width: 72,
                index: am ? 0 : 1,
                itemCount: 2,
                label: (index) => index == 0 ? '上午' : '下午',
                onChanged: (index) => onChanged(_compose(index == 0, hour12, minute * 5)),
              ),
              _Wheel(
                width: 56,
                index: hour12 == 12 ? 0 : hour12,
                itemCount: 12,
                label: (index) => index == 0 ? '12' : '$index',
                onChanged: (index) {
                  final hour = index == 0 ? 12 : index;
                  onChanged(_compose(am, hour, minute * 5));
                },
              ),
              _Wheel(
                width: 56,
                index: minute,
                itemCount: 12,
                label: (index) => (index * 5).toString().padLeft(2, '0'),
                onChanged: (index) => onChanged(_compose(am, hour12, index * 5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  TimeOfDay _compose(bool am, int hour12, int minute) {
    final hour = am ? (hour12 == 12 ? 0 : hour12) : (hour12 == 12 ? 12 : hour12 + 12);
    return TimeOfDay(hour: hour, minute: minute);
  }
}

class _HourMinuteWheels extends StatelessWidget {
  const _HourMinuteWheels({required this.minutes, required this.onChanged});

  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final hours = minutes ~/ 60;
    final mins = ((minutes % 60) / 5).round().clamp(0, 11);
    return SizedBox(
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 48),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SlotColors.today, width: 2),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Wheel(
                width: 48,
                index: hours.clamp(0, 23),
                itemCount: 24,
                label: (index) => '$index',
                onChanged: (index) => onChanged(index * 60 + mins * 5),
              ),
              const Text('小时', style: TextStyle(color: Colors.white, fontSize: 16)),
              _Wheel(
                width: 48,
                index: mins,
                itemCount: 12,
                label: (index) => (index * 5).toString().padLeft(2, '0'),
                onChanged: (index) => onChanged(hours * 60 + index * 5),
              ),
              const Text('分钟', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RepeatWheels extends StatelessWidget {
  const _RepeatWheels({required this.every, required this.unit, required this.onChanged});

  final int every;
  final RepeatUnit unit;
  final void Function(int every, RepeatUnit unit) onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 72),
            decoration: BoxDecoration(
              color: SlotColors.today,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Wheel(
                width: 48,
                index: (every - 1).clamp(0, 29),
                itemCount: 30,
                label: (index) => '${index + 1}',
                onChanged: (index) => onChanged(index + 1, unit),
                selectedColor: Colors.white,
              ),
              _Wheel(
                width: 48,
                index: unit.index,
                itemCount: RepeatUnit.values.length,
                label: (index) => RepeatUnit.values[index] == RepeatUnit.day
                    ? '天'
                    : RepeatUnit.values[index] == RepeatUnit.week
                        ? '周'
                        : '月',
                onChanged: (index) => onChanged(every, RepeatUnit.values[index]),
                selectedColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Wheel extends StatefulWidget {
  const _Wheel({
    required this.width,
    required this.index,
    required this.itemCount,
    required this.label,
    required this.onChanged,
    this.selectedColor = Colors.white,
  });

  final double width;
  final int index;
  final int itemCount;
  final String Function(int index) label;
  final ValueChanged<int> onChanged;
  final Color selectedColor;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late FixedExtentScrollController _controller;
  bool _jumping = false;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: widget.index);
  }

  @override
  void didUpdateWidget(covariant _Wheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && _controller.hasClients && _controller.selectedItem != widget.index) {
      _jumping = true;
      _controller.jumpToItem(widget.index);
      _jumping = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: ListWheelScrollView.useDelegate(
        controller: _controller,
        itemExtent: 36,
        diameterRatio: 1.4,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) {
          if (_jumping) return;
          widget.onChanged(index);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: widget.itemCount,
          builder: (context, index) {
            final selected = index == widget.index;
            return Center(
              child: Text(
                widget.label(index),
                style: TextStyle(
                  color: selected ? widget.selectedColor : Colors.white38,
                  fontSize: selected ? 18 : 16,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

String _week(DateTime day) {
  const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return names[day.weekday - 1];
}

String _weekdayDate(DateTime day) => '${_week(day)} ${day.month}月${day.day}日';

String _clock(TimeOfDay time) {
  final period = time.hour < 12 ? '上午' : '下午';
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$period$hour:$minute';
}

Future<int?> showDurationPicker(BuildContext context, {required int? minutes}) {
  return showGeneralDialog<int>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭持续时间',
    barrierColor: Colors.black38,
    pageBuilder: (_, _, _) => _DurationSheet(minutes: minutes ?? 0),
  );
}

class _DurationSheet extends StatefulWidget {
  const _DurationSheet({required this.minutes});

  final int minutes;

  @override
  State<_DurationSheet> createState() => _DurationSheetState();
}

class _DurationSheetState extends State<_DurationSheet> {
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _minutes = widget.minutes;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Material(
            color: const Color(0xFF1B2838),
            borderRadius: BorderRadius.circular(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消', style: TextStyle(color: Colors.white70)),
                      ),
                      const Expanded(
                        child: Text('持续时间', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 17)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, _minutes),
                        child: const Text('完成', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF314158)),
                _HourMinuteWheels(
                  minutes: _minutes,
                  onChanged: (value) => setState(() => _minutes = value),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final option in const [(0, '无'), (60, '1h'), (90, '1h 30m'), (120, '2h'), (240, '4h')])
                        TextButton(
                          onPressed: () => setState(() => _minutes = option.$1),
                          child: Text(option.$2, style: const TextStyle(color: SlotColors.today)),
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
