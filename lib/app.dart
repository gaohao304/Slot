// =============================================================================
// Slot 应用根组件
// =============================================================================
// 职责：注册全局 Provider（数据仓库、日程状态、主题），配置 MaterialApp 的
//       明亮/深色主题与路由表，根据 ThemeProvider 切换 themeMode。
// 路由：/ 首页，/inbox 收件箱，/list 列表，/tag 标签，/daily 每日视图，
//       /completed 已完成，/trash 垃圾箱，/settings 设置，/account 账户。
// =============================================================================

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'providers/app_settings.dart';
import 'providers/schedule_provider.dart';
import 'repositories/schedule_repository.dart';
import 'screens/account_screen.dart';
import 'screens/completed_screen.dart';
import 'screens/daily_screen.dart';
import 'screens/home_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/list_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tag_screen.dart';
import 'screens/trash_screen.dart';
import 'theme/slot_colors.dart';
import 'widgets/iphone_frame.dart';

class SlotApp extends StatelessWidget {
  const SlotApp({super.key, required this.settingsBox});

  final Box<String> settingsBox;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 日程数据仓库（Hive 持久化）
        Provider<ScheduleRepository>(
          create: (_) => LocalScheduleRepository(),
        ),
        // 日程业务状态：收件箱、已完成、按日期/标签/列表查询等
        ChangeNotifierProvider<ScheduleProvider>(
          create: (context) => ScheduleProvider(
            repository: context.read<ScheduleRepository>(),
          ),
        ),
        ChangeNotifierProvider<AppSettings>(
          create: (_) => AppSettings(settingsBox),
        ),
      ],
      child: Consumer<AppSettings>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Slot',
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: _theme(Brightness.light),
            darkTheme: _theme(Brightness.dark),
            builder: (context, child) {
              return IphoneFrame(
                child: Builder(
                  builder: (context) {
                    final scale = context.watch<AppSettings>().fontScale;
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(scale),
                      ),
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
                ),
              );
            },
            initialRoute: '/',
            routes: {
              '/': (context) => const HomeScreen(),
              '/account': (context) => const AccountScreen(),
              '/inbox': (context) => const InboxScreen(),
              '/list': (context) => const ListScreen(),
              '/tag': (context) => const TagScreen(),
              '/daily': (context) => const DailyScreen(),
              '/completed': (context) => const CompletedScreen(),
              '/trash': (context) => const TrashScreen(),
              '/settings': (context) => const SettingsScreen(),
            },
          );
        },
      ),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: dark ? const Color(0xFF10141C) : Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: SlotColors.today,
        brightness: brightness,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF10141C) : Colors.white,
        foregroundColor: dark ? Colors.white : SlotColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    );
  }
}
