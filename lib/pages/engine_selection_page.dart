import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chess_engine_provider.dart';
import '../models/log_provider.dart';
import '../themes/app_theme.dart';

/// 引擎选择页面 — 选择国际象棋引擎
class EngineSelectionPage extends StatelessWidget {
  const EngineSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final engineProv = context.watch<ChessEngineProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                  color: AppThemeColors.primary(night),
                ),
                const SizedBox(width: 8),
                Text('选择国际象棋引擎',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                        color: AppThemeColors.title(night))),
              ]),
            ),
            Divider(color: AppThemeColors.divider(night)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('当前引擎',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppThemeColors.primary(night))),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppThemeColors.divider(night), width: 1),
                ),
                color: AppThemeColors.highlight(night),
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
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                                  color: AppThemeColors.title(night))),
                          Text(engineProv.isBuiltin
                                  ? '纯 Dart 实现，离线可用，深度 4'
                                  : '调 LiChess Cloud Eval API，断网回退内置 AI',
                              style: TextStyle(fontSize: 12,
                                  color: AppThemeColors.subtitle(night))),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('选择引擎',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppThemeColors.primary(night))),
            ),
            const SizedBox(height: 8),
            _EngineOptionCard(
              icon: '⚙️',
              title: '内置 AI（离线）',
              subtitle: '纯 Dart 实现，无需网络，即开即用 · 深度 4 + Alpha-Beta 剪枝',
              selected: engineProv.isBuiltin,
              onTap: () async {
                await context.read<ChessEngineProvider>().setBuiltin();
                log('ENGINE', '切换为内置 AI 引擎');
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            _EngineOptionCard(
              icon: '☁️',
              title: 'LiChess 云端（在线）',
              subtitle: '调用 LiChess Cloud Eval API 获取 StockFish 分析 · 断网时自动回退内置 AI',
              selected: engineProv.isLichess,
              onTap: () async {
                await context.read<ChessEngineProvider>().setLichess();
                log('ENGINE', '切换为 LiChess 云端引擎');
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: AppThemeColors.highlight(night),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppThemeColors.divider(night)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('说明',
                          style: TextStyle(fontWeight: FontWeight.w600,
                              color: AppThemeColors.title(night))),
                      const SizedBox(height: 4),
                      Text(
                        '• 内置 AI：纯 Dart 实现，深度 4 Alpha-Beta 搜索，离线可用\n'
                        '• LiChess 云端：免费调 LiChess API，StockFish 级别棋力\n'
                        '• 云端模式无网络或 API 无缓存数据时，自动回退到内置 AI\n'
                        '• 无需下载任何额外文件，APK 体积最小化',
                        style: TextStyle(fontSize: 13,
                            color: AppThemeColors.subtitle(night)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EngineOptionCard extends StatelessWidget {
  final String icon, title, subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _EngineOptionCard({
    required this.icon, required this.title, required this.subtitle,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? AppThemeColors.primary(night) : AppThemeColors.divider(night),
            width: selected ? 2 : 1,
          ),
        ),
        color: AppThemeColors.highlight(night),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                            color: AppThemeColors.title(night))),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(fontSize: 13,
                            color: AppThemeColors.subtitle(night))),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: AppThemeColors.primary(night), size: 22)
              else
                Text('▸', style: TextStyle(fontSize: 20, color: AppThemeColors.primary(night))),
            ]),
          ),
        ),
      ),
    );
  }
}
