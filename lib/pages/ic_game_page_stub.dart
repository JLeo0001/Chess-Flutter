import 'package:flutter/material.dart';

/// Web 占位页 — 国际象棋依赖 dartchess/chessground（64-bit 位运算），
/// 无法编译到 JavaScript，Web 上显示不可用提示。
class InternationalChessGamePage extends StatelessWidget {
  final bool isPvE;
  const InternationalChessGamePage({super.key, this.isPvE = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('国际象棋')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.desktop_windows_rounded,
                  size: 64,
                  color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'Web 版暂不支持国际象棋',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '国际象棋引擎依赖 dartchess 的 64-bit 位棋盘运算，\n当前 Web 引擎 (JavaScript) 无法支持。\n\n请使用 Android / iOS / 桌面版体验。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
