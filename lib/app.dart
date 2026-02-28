// =============================================================================
// Slot 应用根组件
// =============================================================================
// 职责：注册全局 Provider（数据仓库、日程状态、主题），配置 MaterialApp 的
//       明亮/深色主题与路由表，根据 ThemeProvider 切换 themeMode。
// 路由：/ 首页，/inbox 收件箱，/list 列表，/tag 标签，/daily 每日视图，
//       /completed 已完成，/trash 垃圾箱，/settings 设置，/account 账户。
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/schedule_provider.dart';
import 'providers/theme_provider.dart';
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

class SlotApp extends StatelessWidget {
  const SlotApp({super.key});

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
        // 主题模式：明亮 / 深色 / 随系统
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Slot',
            themeMode: themeProvider.mode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
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
}
