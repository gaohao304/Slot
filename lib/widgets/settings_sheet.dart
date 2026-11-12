import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings.dart';
import '../theme/slot_colors.dart';

Future<void> showSlotSettings(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1B2838),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => const SettingsSheet(),
  );
}

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key, this.sheet = true});

  /// 从底部弹出时限制高度；作为整页时铺满。
  final bool sheet;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final content = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                const SizedBox(width: 8),
                const Icon(Icons.settings, color: Colors.white70),
                const SizedBox(width: 8),
                const Text('设置', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('完成', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const Text('Slot', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('状态： 标准', style: TextStyle(color: Color(0xFF9AA3B2))),
                const SizedBox(height: 22),
                const _SectionLabel('通用'),
                _tile(
                  context,
                  color: const Color(0xFF5AC8FA),
                  icon: Icons.palette_outlined,
                  title: '主题',
                  value: settings.themeLabel,
                  onTap: () => _pickTheme(context, settings),
                ),
                _tile(
                  context,
                  color: const Color(0xFFFF4B6A),
                  icon: Icons.crop_square,
                  title: '图标',
                  value: '',
                  showChevron: true,
                  onTap: () => _info(context, '桌面图标跟随系统，应用内图标保持当前样式。'),
                ),
                _tile(
                  context,
                  color: const Color(0xFF34C759),
                  icon: Icons.notifications_none,
                  title: '通知',
                  value: settings.notifyLabel,
                  onTap: () => _pickNotify(context, settings),
                ),
                _tile(
                  context,
                  color: const Color(0xFFBF5AF2),
                  icon: Icons.music_note,
                  title: '通知声音',
                  value: settings.notifySound,
                  onTap: () => _pickSound(context, settings),
                ),
                _tile(
                  context,
                  color: SlotColors.accent,
                  icon: Icons.flag_outlined,
                  title: '标记',
                  value: settings.markLabel,
                  onTap: () => _pickMark(context, settings),
                ),
                _switchTile(
                  context,
                  color: const Color(0xFFFFCC00),
                  icon: Icons.volume_up_outlined,
                  title: '声效',
                  value: settings.sound,
                  onChanged: (v) {
                    if (v) HapticFeedback.lightImpact();
                    settings.setSound(v);
                  },
                ),
                _tile(
                  context,
                  color: const Color(0xFF8E8E93),
                  icon: Icons.text_fields,
                  title: '字号',
                  value: settings.fontLabel,
                  onTap: () => _pickFont(context, settings),
                ),
                _tile(
                  context,
                  color: const Color(0xFF5AC8FA),
                  icon: Icons.format_line_spacing,
                  title: '项目距离',
                  value: settings.spacingLabel,
                  onTap: () => _pickSpacing(context, settings),
                ),
                const SizedBox(height: 18),
                const _SectionLabel('日期和时间'),
                _tile(
                  context,
                  color: const Color(0xFF8E8E93),
                  icon: Icons.star_outline,
                  title: '每周起始日',
                  value: settings.weekLabel,
                  onTap: () => _pickWeek(context, settings),
                ),
                _switchTile(
                  context,
                  color: SlotColors.today,
                  icon: Icons.schedule,
                  title: '24时制',
                  value: settings.use24Hour,
                  onChanged: settings.setUse24Hour,
                ),
              ],
            ),
          ),
        ],
      );
    if (!sheet) return content;
    return SizedBox(height: MediaQuery.sizeOf(context).height * 0.86, child: content);
  }

  Widget _tile(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
    bool showChevron = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _icon(color, icon),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.isNotEmpty)
            Text(value, style: const TextStyle(color: Color(0xFF9AA3B2), fontSize: 15)),
          if (showChevron) const Icon(Icons.chevron_right, color: Color(0xFF9AA3B2)),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _switchTile(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _icon(color, icon),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      trailing: Switch.adaptive(
        value: value,
        activeTrackColor: SlotColors.today,
        onChanged: onChanged,
      ),
      onTap: () => onChanged(!value),
    );
  }

  Widget _icon(Color color, IconData icon) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(text, style: const TextStyle(color: Color(0xFF9AA3B2), fontSize: 13)),
    );
  }
}

Future<void> _info(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('好'))],
    ),
  );
}

Future<void> _pickTheme(BuildContext context, AppSettings settings) {
  return _pick<ThemeMode>(
    context,
    title: '主题',
    current: settings.themeMode,
    options: const [
      (ThemeMode.system, '系统'),
      (ThemeMode.light, '浅色'),
      (ThemeMode.dark, '深色'),
    ],
    onSelected: settings.setThemeMode,
  );
}

Future<void> _pickNotify(BuildContext context, AppSettings settings) {
  return _pick<NotifyScope>(
    context,
    title: '通知',
    current: settings.notifyScope,
    options: const [
      (NotifyScope.off, '关闭'),
      (NotifyScope.tasks, '任务'),
      (NotifyScope.tasksAndSchedule, '任务及日程'),
    ],
    onSelected: settings.setNotifyScope,
  );
}

Future<void> _pickSound(BuildContext context, AppSettings settings) {
  return _pick<String>(
    context,
    title: '通知声音',
    current: settings.notifySound,
    options: const [('Again', 'Again'), ('Chord', 'Chord'), ('Bell', 'Bell')],
    onSelected: settings.setNotifySound,
  );
}

Future<void> _pickMark(BuildContext context, AppSettings settings) {
  return _pick<OverdueMark>(
    context,
    title: '标记',
    current: settings.overdueMark,
    options: const [
      (OverdueMark.overdue, '过期'),
      (OverdueMark.off, '关闭'),
    ],
    onSelected: settings.setOverdueMark,
  );
}

Future<void> _pickFont(BuildContext context, AppSettings settings) {
  return _pick<int>(
    context,
    title: '字号',
    current: settings.fontScaleIndex,
    options: const [(0, '小'), (1, '正常'), (2, '大'), (3, '超大')],
    onSelected: settings.setFontScaleIndex,
  );
}

Future<void> _pickSpacing(BuildContext context, AppSettings settings) {
  return _pick<ItemSpacing>(
    context,
    title: '项目距离',
    current: settings.spacing,
    options: const [
      (ItemSpacing.tight, '紧'),
      (ItemSpacing.medium, '中'),
      (ItemSpacing.loose, '松'),
    ],
    onSelected: settings.setSpacing,
  );
}

Future<void> _pickWeek(BuildContext context, AppSettings settings) {
  return _pick<bool>(
    context,
    title: '每周起始日',
    current: settings.weekStartsOnSunday,
    options: const [(true, '星期日'), (false, '星期一')],
    onSelected: settings.setWeekStartsOnSunday,
  );
}

Future<void> _pick<T>(
  BuildContext context, {
  required String title,
  required T current,
  required List<(T, String)> options,
  required Future<void> Function(T) onSelected,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(title),
      children: [
        for (final option in options)
          SimpleDialogOption(
            onPressed: () async {
              await onSelected(option.$1);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Row(
              children: [
                Expanded(child: Text(option.$2)),
                if (option.$1 == current) const Icon(Icons.check, color: SlotColors.today, size: 18),
              ],
            ),
          ),
      ],
    ),
  );
}
