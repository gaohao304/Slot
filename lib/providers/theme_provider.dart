// =============================================================================
// 主题 Provider
// =============================================================================
// 职责：维护全局 ThemeMode（system / light / dark），供 MaterialApp themeMode 使用；
//       设置页通过 setMode 切换，App 用 Consumer<ThemeProvider> 重建。
// =============================================================================

import 'package:flutter/material.dart';

/// 全局主题设置：明亮 / 深色 / 跟随系统。
class ThemeProvider with ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }
}

