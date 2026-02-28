// =============================================================================
// 设置页
// =============================================================================
// 主题设置：随系统 / 明亮 / 黑暗（RadioListTile，写 ThemeProvider.setMode）；
// 占位项：通知与提醒、同步。
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final mode = themeProvider.mode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置页面'),
      ),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.notifications),
            title: Text('通知与提醒'),
          ),
          const ListTile(
            leading: Icon(Icons.sync),
            title: Text('同步'),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.palette),
            title: Text('主题设置'),
            subtitle: Text('明亮 / 黑暗 / 随系统'),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('随系统主题'),
            value: ThemeMode.system,
            groupValue: mode,
            onChanged: (value) {
              if (value != null) {
                themeProvider.setMode(value);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('明亮主题'),
            value: ThemeMode.light,
            groupValue: mode,
            onChanged: (value) {
              if (value != null) {
                themeProvider.setMode(value);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('黑暗主题'),
            value: ThemeMode.dark,
            groupValue: mode,
            onChanged: (value) {
              if (value != null) {
                themeProvider.setMode(value);
              }
            },
          ),
        ],
      ),
    );
  }
}
