import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 同心圆展开日夜切换动画
///
/// 工作原理：
/// 1. 点击按钮时记录按钮位置和当前主题背景色
/// 2. 立即切换主题（下层重建）
/// 3. 用旧背景色覆盖全屏，圆形孔洞从按钮位置向外扩张
/// 4. 孔洞中露出下层的新主题
class ThemeReveal extends StatefulWidget {
  final Widget child;
  final VoidCallback onToggleTheme;

  static final GlobalKey<ThemeRevealState> globalKey = GlobalKey();

  const ThemeReveal({
    super.key,
    required this.child,
    required this.onToggleTheme,
  });

  @override
  State<ThemeReveal> createState() => ThemeRevealState();
}

class ThemeRevealState extends State<ThemeReveal>
    with SingleTickerProviderStateMixin {
  Offset? _center;
  AnimationController? _ctrl;
  Animation<double>? _anim;
  Color _oldBg = Colors.transparent;
  double _maxRadius = 0;

  void trigger(Offset center) {
    if (!mounted) return;

    // 释放上一个动画控制器，防止多 controller 并发导致 setState 风暴
    _ctrl?.dispose();
    _ctrl = null;
    _anim = null;

    // 记录按钮位置和切换前的背景色
    _oldBg = Theme.of(context).colorScheme.surface;
    _center = center;

    final size = MediaQuery.of(context).size;
    final dx = math.max(center.dx, size.width - center.dx);
    final dy = math.max(center.dy, size.height - center.dy);
    _maxRadius = math.sqrt(dx * dx + dy * dy) + 20; // 稍微多出一点防白边

    // 先切主题（会触发同步重建），再播动画
    widget.onToggleTheme();

    if (!mounted) return;

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = CurvedAnimation(parent: _ctrl!, curve: Curves.fastOutSlowIn);
    _ctrl!.addListener(() {
      if (mounted) setState(() {});
    });
    _ctrl!.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _center = null);
        _ctrl?.dispose();
        _ctrl = null;
        _anim = null;
      }
    });
    _ctrl!.forward();
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    _ctrl = null;
    _anim = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_center != null && _anim != null && _anim!.value < 1.0)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CircleRevealPainter(
                  center: _center!,
                  radius: _maxRadius * _anim!.value,
                  color: _oldBg,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CircleRevealPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final Color color;

  _CircleRevealPainter({
    required this.center,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 全屏矩形 - 圆形孔洞 = 露出新主题
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CircleRevealPainter old) =>
      old.radius != radius || old.center != center || old.color != color;
}
