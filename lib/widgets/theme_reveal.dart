import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 日夜切换波纹动画 — 不使用截图，使用装饰性波纹扩散效果
/// 点击按钮后主题立即切换，同时从按钮位置播放波纹动画
class ThemeRipple extends StatefulWidget {
  final Widget child;
  final VoidCallback onToggleTheme;

  /// 全局访问入口
  static final GlobalKey<ThemeRippleState> globalKey =
      GlobalKey<ThemeRippleState>();

  const ThemeRipple({
    super.key,
    required this.child,
    required this.onToggleTheme,
  });

  @override
  State<ThemeRipple> createState() => ThemeRippleState();
}

class ThemeRippleState extends State<ThemeRipple>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Offset _center = Offset.zero;
  bool _showRipple = false;

  /// 触发主题切换 + 波纹动画
  void trigger(Offset centerPosition) {
    if (_showRipple) return;

    _center = centerPosition;

    // 立即切换主题
    widget.onToggleTheme();

    // 启动波纹动画
    _controller?.dispose();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _controller!.addListener(() => setState(() {}));
    _controller!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showRipple = false);
      }
    });

    setState(() {
      _showRipple = true;
      _controller!.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    // 波纹颜色：使用相反主题的高亮色 + 逐渐透明
    final rippleColor = night
        ? const Color(0xFFE8DEF8) // 日间高亮色
        : const Color(0xFF4F378B); // 夜间高亮色

    return Stack(
      children: [
        widget.child,
        if (_showRipple && _controller != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RipplePainter(
                  center: _center,
                  progress: _controller!.value,
                  color: rippleColor,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RipplePainter extends CustomPainter {
  final Offset center;
  final double progress; // 0..1
  final Color color;

  _RipplePainter({
    required this.center,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 计算所需最大半径（从中心到最远角落）
    final maxRadius = math.sqrt(
      math.max(
        center.dx * center.dx + center.dy * center.dy,
        math.max(
          (size.width - center.dx) * (size.width - center.dx) +
              (size.height - center.dy) * (size.height - center.dy),
          math.max(
            center.dx * center.dx +
                (size.height - center.dy) * (size.height - center.dy),
            (size.width - center.dx) * (size.width - center.dx) +
                center.dy * center.dy,
          ),
        ),
      ),
    );

    // 动画：半径从小到大，透明度从高到低
    final radius = maxRadius * _easeOutCubic(progress);
    final alpha = ((1.0 - progress) * 120).round().clamp(0, 120);

    // 绘制主圆
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withAlpha(alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );

    // 内圈更亮
    if (progress < 0.7) {
      final innerRadius = radius * 0.6;
      final innerAlpha = ((1.0 - progress / 0.7) * 80).round().clamp(0, 80);
      canvas.drawCircle(
        center,
        innerRadius,
        Paint()
          ..color = Colors.white.withAlpha(innerAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );
    }
  }

  double _easeOutCubic(double t) => 1.0 - math.pow(1.0 - t, 3).toDouble();

  @override
  bool shouldRepaint(covariant _RipplePainter old) =>
      old.progress != progress || old.center != center;
}
