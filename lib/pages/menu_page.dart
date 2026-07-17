import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/theme_provider.dart';
import '../themes/app_theme.dart';
import '../widgets/theme_reveal.dart';
import '../widgets/animations.dart';

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

  static const _cards = [
    ('井字棋', '3×3 · 三连即胜 · 先X后O', '✖', 'tictactoe'),
    ('五子棋', '15×15 · 五连珠获胜 · 人机/双人', '⚫', 'gobang'),
    ('中国象棋', '9×10 · 楚河汉界 · 红先黑后', 'chinese', 'chinese_chess'),
    ('国际象棋', '8×8 · Stockfish 引擎 · 白先黑后', 'rook', 'international_chess'),
    ('围棋', '19×19 · 围地获胜 · 人机/双人', 'go', 'go'),
    ('扑克', '换牌扑克 · 德州扑克 · 斗地主', 'poker', 'poker'),
    ('UNO', '2~4 人对战 · 经典规则 · 人机', 'uno', 'uno'),
    ('蜘蛛纸牌', '单人接龙 · 104张 · 三种难度', 'spider', 'spider'),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    // 每个卡片依次弹出，间隔 120ms
    _cardAnimations = List.generate(_cards.length, (i) {
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
      ThemeRipple.globalKey.currentState?.trigger(center);
    } else {
      final ctx = _themeBtnKey.currentContext;
      if (ctx != null) {
        Provider.of<ThemeProvider>(ctx, listen: false).toggleManual();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BounceIconButton(
                    key: _themeBtnKey,
                    icon: night ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    onPressed: _onThemeToggle,
                    color: AppThemeColors.primary(night),
                  ),
                  const Spacer(),
                  BounceIconButton(
                    icon: Icons.settings_outlined,
                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                    color: AppThemeColors.primary(night),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 标题淡入 + 上滑
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, child) => Opacity(
                  opacity: Curves.easeOut.transform(_ctrl.value),
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - _ctrl.value)),
                    child: child,
                  ),
                ),
                child: Text('弈',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppThemeColors.title(night))),
              ),
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, child) => Opacity(
                  opacity: Curves.easeOut.transform(_ctrl.value),
                  child: child,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text('选择棋类游戏',
                      style: TextStyle(
                          fontSize: 16,
                          color: AppThemeColors.subtitle(night))),
                ),
              ),
              Divider(color: AppThemeColors.divider(night)),
              const SizedBox(height: 16),
              // 卡片依次弹出
              for (int i = 0; i < _cards.length; i++)
                _AnimatedGameCard(
                  animation: _cardAnimations[i],
                  title: _cards[i].$1,
                  subtitle: _cards[i].$2,
                  iconWidget: _buildIconWidget(_cards[i].$3, night),
                  gameType: _cards[i].$4,
                  night: night,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 构建游戏卡片图标
Widget _buildIconWidget(String iconType, bool night) {
  if (iconType == 'chinese') {
    // 中国象棋棋子：红底圆圈 + "象"
    return Container(
      width: 38, height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFCDD2), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(1, 1)),
        ],
      ),
      child: Text('象',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFFFF9C4),
          )),
    );
  }
  if (iconType == 'rook') {
    // 国际象棋车：使用 chessground 的 Merida 棋子贴图
    return SizedBox(
      width: 38, height: 38,
      child: Image(
        image: const AssetImage('assets/piece_sets/merida/bR.png', package: 'chessground'),
        width: 32, height: 32,
      ),
    );
  }
  if (iconType == 'go') {
    // 围棋：黑白各半的圆
    return SizedBox(
      width: 38, height: 38,
      child: Stack(children: [
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.fromBorderSide(BorderSide(color: Color(0xFF1C1B1F), width: 2)),
          ),
        ),
        ClipRect(
          clipper: _HalfClipper(),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1C1B1F),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ]),
    );
  }
  if (iconType == 'poker') {
    return const Text('🃏', style: TextStyle(fontSize: 28));
  }
  if (iconType == 'uno') {
    return SizedBox(
      width: 36, height: 36,
      child: Column(children: [
        Expanded(child: Row(children: [
          Expanded(child: Container(color: const Color(0xFFE53935))),
          Expanded(child: Container(color: const Color(0xFF1E88E5))),
        ])),
        Expanded(child: Row(children: [
          Expanded(child: Container(color: const Color(0xFF43A047))),
          Expanded(child: Container(color: const Color(0xFFFDD835))),
        ])),
      ]),
    );
  }
  if (iconType == 'spider') {
    return const Text('🕷️', style: TextStyle(fontSize: 28));
  }
  // 默认：纯文本图标
  return Text(iconType, style: const TextStyle(fontSize: 28));
}

class _HalfClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width / 2, size.height);
  @override
  bool shouldReclip(covariant CustomClipper<Rect> old) => false;
}

class _AnimatedGameCard extends StatelessWidget {
  final Animation<double> animation;
  final String title, subtitle, gameType;
  final Widget iconWidget;
  final bool night;

  const _AnimatedGameCard({
    required this.animation,
    required this.title,
    required this.subtitle,
    required this.iconWidget,
    required this.gameType,
    required this.night,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(40 * (1 - t), 0),
            child: Transform.scale(
              scale: 0.9 + 0.1 * t,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Pressable(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, '/mode', arguments: gameType);
                  },
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                          color: AppThemeColors.divider(night), width: 1),
                    ),
                    color: AppThemeColors.highlight(night),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          iconWidget,
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: AppThemeColors.title(night))),
                                const SizedBox(height: 4),
                                Text(subtitle,
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: AppThemeColors.subtitle(night))),
                              ],
                            ),
                          ),
                          Text('▸',
                              style: TextStyle(
                                  fontSize: 20,
                                  color: AppThemeColors.primary(night))),
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
