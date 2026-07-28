import 'package:flutter/material.dart';

/// 模式选择页 — 使用 M3 ListTile + Card
class ModePage extends StatelessWidget {
  final String gameType;
  const ModePage({super.key, required this.gameType});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String title, subtitle;
    switch (gameType) {
      case 'gobang':              title = '五子棋'; subtitle = '15×15 · 五连珠获胜'; break;
      case 'chinese_chess':       title = '中国象棋'; subtitle = '9×10 · 楚河汉界'; break;
      case 'international_chess': title = '国际象棋'; subtitle = '8×8 · 王车易位'; break;
      case 'tictactoe':           title = '井字棋'; subtitle = '3×3 · 三连获胜'; break;
      case 'go':                  title = '围棋'; subtitle = '19×19 · 围地获胜'; break;
      case 'chinese_checkers':    title = '中国跳棋'; subtitle = '六角星形 · 搭桥跳跃'; break;
      case 'poker':               title = '扑克'; subtitle = '52张标准扑克 · 人机对战'; break;
      case 'uno':                 title = 'UNO'; subtitle = '经典UNO牌 · 人机对战'; break;
      case 'spider':              title = '蜘蛛纸牌'; subtitle = '单人接龙 · 三种难度'; break;
      default:                    title = '未知'; subtitle = '';
    }

    final isSpecial = gameType == 'poker' || gameType == 'uno' || gameType == 'spider' || gameType == 'chinese_checkers';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            )),
            if (subtitle.isNotEmpty)
              Text(subtitle,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ],
        ),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isSpecial) ...[
            if (gameType == 'poker') ...[
              _card(context, '换牌扑克', '🃏 5张抽牌 · 选牌换牌 · 比大小',
                  () => Navigator.pushNamed(context, '/poker', arguments: {'variant': 'draw'})),
              const SizedBox(height: 8),
              _card(context, '德州扑克', '♠️ 2张底牌 + 5张公共牌 · 7选5比大小',
                  () => Navigator.pushNamed(context, '/poker', arguments: {'variant': 'holdem'})),
              const SizedBox(height: 8),
              _card(context, '斗地主', '🃏 三人斗地主 · 叫地主 · 1v2人机',
                  () => Navigator.pushNamed(context, '/doudizhu')),
            ],
            if (gameType == 'uno') ...[
              for (final entry in [
                ('双人对战', '👤 vs 🤖 · 1v1 UNO'),
                ('三人对战', '👤 vs 🤖🤖 · 三人混战'),
                ('四人对战', '👤 vs 🤖🤖🤖 · 四人混战'),
              ].indexed)
                Padding(
                  padding: EdgeInsets.only(bottom: entry.$1 < 2 ? 8 : 0),
                  child: _card(context, entry.$2.$1, entry.$2.$2,
                      () => Navigator.pushNamed(context, '/uno', arguments: {'players': entry.$1 + 2})),
                ),
            ],
            if (gameType == 'spider') ...[
              _card(context, '♠ 单色（简单）', '🕷️ 只有黑桃，适合入门',
                  () => Navigator.pushNamed(context, '/spider', arguments: {'suits': 1})),
              const SizedBox(height: 8),
              _card(context, '♠♥ 双色（中等）', '🕷️ 黑桃+红心，略有挑战',
                  () => Navigator.pushNamed(context, '/spider', arguments: {'suits': 2})),
              const SizedBox(height: 8),
              _card(context, '♠♥♦♣ 四色（困难）', '🕷️ 全部四种花色，高手向',
                  () => Navigator.pushNamed(context, '/spider', arguments: {'suits': 4})),
            ],
            if (gameType == 'chinese_checkers') ...[
              for (final entry in [
                ('双人对战', '👤 vs 🤖 · 1v1 跳棋'),
                ('三人混战', '👤 vs 🤖🤖 · 三方对决'),
                ('四人混战', '👤 vs 🤖🤖🤖 · 四方博弈'),
                ('六人混战', '👤 vs 🤖🤖🤖🤖🤖 · 六方大乱斗'),
              ].indexed)
                Padding(
                  padding: EdgeInsets.only(bottom: entry.$1 < 3 ? 8 : 0),
                  child: _card(
                    context,
                    entry.$2.$1,
                    entry.$2.$2,
                    () => Navigator.pushNamed(context, '/game/chinese_checkers',
                        arguments: {'players': [2, 3, 4, 6][entry.$1]}),
                  ),
                ),
            ],
          ] else ...[
            _card(context, '双人对弈', '👥 两位玩家轮流操作',
                () => Navigator.pushNamed(context, '/game/$gameType', arguments: {'mode': 'pvp'})),
            const SizedBox(height: 8),
            _card(context, '人机对战', '🤖 与 AI 对弈',
                () => Navigator.pushNamed(context, '/game/$gameType', arguments: {'mode': 'pve'})),
            const SizedBox(height: 8),
            _card(context, '游戏教程', '📖 学习规则与技巧',
                () => Navigator.pushNamed(context, '/tutorial', arguments: gameType)),
          ],
        ],
      ),
    );
  }

  Widget _card(BuildContext context, String title, String subtitle, VoidCallback onTap) {
    return Card(
      child: ListTile(
        title: Text(title,
            style: TextStyle(fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}
