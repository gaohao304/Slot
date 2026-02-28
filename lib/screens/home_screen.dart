// =============================================================================
// 首页
// =============================================================================
// 以列表展示 8 个入口：账号、收件箱、列表视图、标签视图、每日视图、已完成、
// 垃圾箱、设置；点击跳转对应路由；FAB 可在此扩展（当前在收件箱等子页）。
// =============================================================================

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/task.dart';
import 'task_edit_screen.dart';

/// 首页：以列表形式展示 8 个入口，点击切换到对应页面
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _entries = [
    _Entry('账号信息', Icons.person, '/account'),
    _Entry('收件箱', Icons.inbox, '/inbox'),
    _Entry('列表视图', Icons.list, '/list'),
    _Entry('标签视图', Icons.label, '/tag'),
    _Entry('每日视图', Icons.calendar_today, '/daily'),
    _Entry('已完成', Icons.check_circle, '/completed'),
    _Entry('垃圾箱', Icons.delete_outline, '/trash'),
    _Entry('设置页面', Icons.settings, '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Slot'),
      ),
      body: ListView.builder(
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final e = _entries[index];
          return ListTile(
            leading: Icon(e.icon),
            title: Text(e.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(e.route),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTask(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _addTask(BuildContext context) {
    final task = Task(
      id: const Uuid().v4(),
      title: '',
      createdAt: DateTime.now(),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskEditScreen(task: task, isNew: true),
      ),
    );
  }
}

class _Entry {
  const _Entry(this.title, this.icon, this.route);
  final String title;
  final IconData icon;
  final String route;
}
