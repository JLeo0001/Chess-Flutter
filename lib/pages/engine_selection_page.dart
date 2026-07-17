import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chess_engine_provider.dart';
import '../models/log_provider.dart';

/// 引擎选择页面 — 使用 M3 ListTile + Radio
class EngineSelectionPage extends StatelessWidget {
  const EngineSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final engineProv = context.watch<ChessEngineProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择国际象棋引擎'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('当前引擎',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.primary)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Text(engineProv.isBuiltin ? '⚙️' : '☁️',
                    style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(engineProv.displayName,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface)),
                      Text(
                          engineProv.isBuiltin
                              ? '纯 Dart 实现，离线可用，深度 4'
                              : '调 LiChess Cloud Eval API，断网回退内置 AI',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          Text('选择引擎',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.primary)),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              RadioListTile<int>(
                title: const Text('内置 AI（离线）'),
                subtitle: const Text(
                    '纯 Dart 实现，无需网络 · 深度 4 + Alpha-Beta 剪枝'),
                value: 0,
                groupValue: engineProv.isBuiltin ? 0 : 1,
                onChanged: (_) async {
                  await context.read<ChessEngineProvider>().setBuiltin();
                  log('ENGINE', '切换为内置 AI 引擎');
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              const Divider(height: 1, indent: 16),
              RadioListTile<int>(
                title: const Text('LiChess 云端（在线）'),
                subtitle: const Text(
                    '调用 LiChess API 获取 StockFish 分析 · 断网时自动回退内置 AI'),
                value: 1,
                groupValue: engineProv.isBuiltin ? 0 : 1,
                onChanged: (_) async {
                  await context.read<ChessEngineProvider>().setLichess();
                  log('ENGINE', '切换为 LiChess 云端引擎');
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('说明',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: cs.onSurface)),
                  const SizedBox(height: 8),
                  Text(
                    '• 内置 AI：纯 Dart 实现，深度 4 Alpha-Beta 搜索，离线可用\n'
                    '• LiChess 云端：免费调 LiChess API，StockFish 级别棋力\n'
                    '• 云端模式无网络或 API 无缓存数据时，自动回退到内置 AI\n'
                    '• 无需下载任何额外文件，APK 体积最小化',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
