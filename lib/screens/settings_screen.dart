import 'package:flutter/material.dart';

import '../widgets/settings_sheet.dart';

/// 设置页。抽屉里以底部卡片打开，这条路由保留给直接进入的情况。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1B2838),
      body: SafeArea(
        child: SettingsSheet(sheet: false),
      ),
    );
  }
}
