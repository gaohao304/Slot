// =============================================================================
// 提醒/延迟入口 UI
// =============================================================================
// 占位卡片：展示“到时间提醒（延迟 N 分钟）”及延迟按钮，后续可接入本地通知与延迟逻辑。
// =============================================================================

import 'package:flutter/material.dart';

/// 提醒、延迟入口（后续接入本地通知与延迟 N 分钟）
class ReminderUi extends StatelessWidget {
  const ReminderUi({
    super.key,
    this.onDelay,
    this.delayMinutes = 5,
  });

  final VoidCallback? onDelay;
  final int delayMinutes;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.notifications),
            const SizedBox(width: 12),
            Expanded(
              child: Text('到时间提醒（延迟 $delayMinutes 分钟）'),
            ),
            if (onDelay != null)
              TextButton(
                onPressed: onDelay,
                child: const Text('延迟'),
              ),
          ],
        ),
      ),
    );
  }
}
