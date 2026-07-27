import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/theme_provider.dart';
import '../widgets/theme_reveal.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage>
    with SingleTickerProviderStateMixin {
  static final _themeBtnKey = GlobalKey();
  late final AnimationController _ctrl;
  late final List<Animation<double>> _cardAnimations;

  static const _games = [
    ('井字棋', '3×3 · 三连即胜 · 先X后O', Icons.grid_on, 'tictactoe'),
    ('五子棋', '15×15 · 五连珠获胜 · 人机/双人', Icons.circle_outlined, 'gobang'),
    ('中国象棋', '9×10 · 楚河汉界 · 红先黑后', Icons.shield_outlined, 'chinese_chess'),
    ('国际象棋', '8×8 · 多引擎 · 白先黑后', Icons.workspace_premium, 'international_chess'),
    ('围棋', '19×19 · 围地获胜 · 人机/双人', Icons.change_circle_outlined, 'go'),
    ('扑克', '换牌扑克 · 德州扑克 · 斗地主', Icons.style, 'poker'),
    ('UNO', '2~4 人对战 · 经典规则 · 人机', Icons.palette_outlined, 'uno'),
    ('蜘蛛纸牌', '单人接龙 · 104张 · 三种难度', Icons.ac_unit, 'spider'),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _cardAnimations = List.generate(_games.length, (i) {
      final start = i * 0.15;
      final end = (start + 0.35).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start, end, curve: Curves.easeOutBack),
      );
    });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onThemeToggle() {
    final renderBox =
        _themeBtnKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final localPos = renderBox.localToGlobal(Offset.zero);
      final center = Offset(
        localPos.dx + renderBox.size.width / 2,
        localPos.dy + renderBox.size.height / 2,
      );
      ThemeReveal.globalKey.currentState?.trigger(center);
    } else {
      context.read<ThemeProvider>().toggleManual();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final night = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶栏按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    key: _themeBtnKey,
                    icon: Icon(
                      night ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      color: cs.primary,
                    ),
                    onPressed: _onThemeToggle,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.settings_outlined, color: cs.primary),
                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 标题
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _ctrl,
                  curve: const Interval(0, 0.5, curve: Curves.easeOut),
                ),
                child: Text('弈',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface)),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text('选择棋类游戏',
                    style: TextStyle(
                        fontSize: 16, color: cs.onSurfaceVariant)),
              ),
              const Divider(),
              const SizedBox(height: 16),
              // 游戏卡片
              for (int i = 0; i < _games.length; i++)
                _AnimatedGameCard(
                  animation: _cardAnimations[i],
                  title: _games[i].$1,
                  subtitle: _games[i].$2,
                  icon: _games[i].$3,
                  gameType: _games[i].$4,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedGameCard extends StatelessWidget {
  final Animation<double> animation;
  final String title, subtitle, gameType;
  final IconData icon;

  const _AnimatedGameCard({
    required this.animation,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gameType,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        final t = animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(40 * (1 - t), 0),
            child: Transform.scale(
              scale: 0.9 + 0.1 * t,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pushNamed(context, '/mode',
                          arguments: gameType);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(icon, size: 28, color: cs.primary),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurface)),
                                const SizedBox(height: 4),
                                Text(subtitle,
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
