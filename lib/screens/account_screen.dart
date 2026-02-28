// =============================================================================
// 账号信息
// =============================================================================
// 占位页：展示“账号信息页（登录状态、账号信息、退出等）”，后续可接入登录/账号 API。
// =============================================================================

import 'package:flutter/material.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账号信息'),
      ),
      body: const Center(
        child: Text('账号信息页（登录状态、账号信息、退出等）'),
      ),
    );
  }
}
