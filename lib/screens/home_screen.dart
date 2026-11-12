import 'package:flutter/material.dart';

import 'plan_shell.dart';

/// 首页即计划壳：抽屉、当天列表、月历和时间线都在这里。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const PlanShell();
}
