import 'package:flutter/material.dart';
import '../themes/app_theme.dart';

/// 模式选择页 — 1:1 移植自 ModeActivity.java
class ModePage extends StatelessWidget {
  final String gameType;
  const ModePage({super.key, required this.gameType});

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;

    String title, subtitle;
    switch (gameType) {
      case 'gobang':              title = '五子棋'; subtitle = '15×15 · 五连珠获胜'; break;
      case 'chinese_chess':       title = '中国象棋'; subtitle = '9×10 · 楚河汉界'; break;
      case 'international_chess': title = '国际象棋'; subtitle = '8×8 · 王车易位'; break;
      case 'tictactoe':           title = '井字棋'; subtitle = '3×3 · 三连获胜'; break;
      case 'go':                  title = '围棋'; subtitle = '19×19 · 围地获胜'; break;
      case 'poker':               title = '扑克'; subtitle = '52张标准扑克 · 人机对战'; break;
      case 'uno':                 title = 'UNO'; subtitle = '经典UNO牌 · 自定义牌面 · 人机对战'; break;
      case 'spider':              title = '蜘蛛纸牌'; subtitle = '单人接龙 · 104张牌 · 三种难度'; break;
      default:                    title = '未知'; subtitle = '';
    }

    // 扑克/UNO：显示玩法选择，全部 PvE
    final isSpecial = gameType == 'poker' || gameType == 'uno' || gameType == 'spider';

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                    color: AppThemeColors.primary(night),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(title,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                      color: AppThemeColors.title(night))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(subtitle,
                  style: TextStyle(fontSize: 14,
                      color: AppThemeColors.subtitle(night))),
            ),
            Divider(color: AppThemeColors.divider(night)),
            const SizedBox(height: 16),
            if (isSpecial) ...[
              if (gameType == 'poker') ...[
                _ModeCard(
                  title: '换牌扑克',
                  subtitle: '🃏 5张抽牌 · 选牌换牌 · 比大小',
                  onTap: () => Navigator.pushNamed(context, '/poker',
                      arguments: {'variant': 'draw'}),
                ),
                const SizedBox(height: 12),
                _ModeCard(
                  title: '德州扑克',
                  subtitle: '♠️ 2张底牌 + 5张公共牌 · 7选5比大小',
                  onTap: () => Navigator.pushNamed(context, '/poker',
                      arguments: {'variant': 'holdem'}),
                ),
                const SizedBox(height: 12),
                _ModeCard(
                  title: '斗地主',
                  subtitle: '🃏 三人斗地主 · 叫地主 · 1v2人机对战',
                  onTap: () => Navigator.pushNamed(context, '/doudizhu'),
                ),
              ],
              if (gameType == 'uno') ...[
                for (final entry in [
                  ('双人对战', '👤 vs 🤖 · 1v1 UNO'),
                  ('三人对战', '👤 vs 🤖🤖 · 三人混战'),
                  ('四人对战', '👤 vs 🤖🤖🤖 · 四人混战'),
                ].indexed)
                  Padding(
                    padding: EdgeInsets.only(bottom: entry.$1 < 2 ? 12 : 0),
                    child: _ModeCard(
                      title: entry.$2.$1,
                      subtitle: entry.$2.$2,
                      onTap: () => Navigator.pushNamed(context, '/uno',
                          arguments: {'players': entry.$1 + 2}),
                    ),
                  ),
              ],
              if (gameType == 'spider') ...[
                _ModeCard(
                  title: '♠ 单色（简单）',
                  subtitle: '🕷️ 只有黑桃，适合入门',
                  onTap: () => Navigator.pushNamed(context, '/spider',
                      arguments: {'suits': 1}),
                ),
                const SizedBox(height: 12),
                _ModeCard(
                  title: '♠♥ 双色（中等）',
                  subtitle: '🕷️ 黑桃+红心，略有挑战',
                  onTap: () => Navigator.pushNamed(context, '/spider',
                      arguments: {'suits': 2}),
                ),
                const SizedBox(height: 12),
                _ModeCard(
                  title: '♠♥♦♣ 四色（困难）',
                  subtitle: '🕷️ 全部四种花色，高手向',
                  onTap: () => Navigator.pushNamed(context, '/spider',
                      arguments: {'suits': 4}),
                ),
              ],
            ] else ...[
              _ModeCard(
                title: '双人对弈',
                subtitle: '👥 两位玩家轮流操作',
                onTap: () => Navigator.pushNamed(context, '/game/$gameType',
                    arguments: {'mode': 'pvp'}),
              ),
              const SizedBox(height: 12),
              _ModeCard(
                title: '人机对战',
                subtitle: '🤖 与 AI 对弈',
                onTap: () => Navigator.pushNamed(context, '/game/$gameType',
                    arguments: {'mode': 'pve'}),
              ),
              const SizedBox(height: 12),
              _ModeCard(
                title: '游戏教程',
                subtitle: '📖 学习规则与技巧',
                onTap: () => Navigator.pushNamed(context, '/tutorial',
                    arguments: gameType),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title, subtitle;
  final VoidCallback onTap;
  const _ModeCard({required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppThemeColors.divider(night), width: 1),
        ),
        color: AppThemeColors.highlight(night),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                              color: AppThemeColors.title(night))),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: TextStyle(fontSize: 14,
                              color: AppThemeColors.subtitle(night))),
                    ],
                  ),
                ),
                Text('▸',
                    style: TextStyle(fontSize: 20,
                        color: AppThemeColors.primary(night))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
