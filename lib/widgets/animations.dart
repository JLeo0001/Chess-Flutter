import 'package:flutter/material.dart';

/// 可复用动效组件 — 全局一致的灵动交互体验

/// 按压缩放按钮包装器
///
/// 按压时缩放到 `scale`，松手后弹簧回弹。
/// 使用 AnimatedScale 而非 AnimationController，避免重建时状态丢失。
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.94,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails _) {
    setState(() => _scale = widget.scale);
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _scale = 1.0);
    // 延迟执行 onTap，让缩放动画先走，避免重建时中断
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onTap?.call();
    });
  }

  void _onTapCancel() {
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}

/// 交错入场动画包装器
///
/// 为列表项提供依次出场的动画效果。
class StaggeredEntry extends StatelessWidget {
  final int index;
  final int itemCount;
  final Widget child;
  final AxisDirection direction;
  final Duration duration;
  final Duration staggerDelay;

  const StaggeredEntry({
    super.key,
    required this.index,
    required this.itemCount,
    required this.child,
    this.direction = AxisDirection.down,
    this.duration = const Duration(milliseconds: 400),
    this.staggerDelay = const Duration(milliseconds: 80),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        final delay = (staggerDelay.inMilliseconds * index) /
            duration.inMilliseconds;
        final t = ((value - delay) / (1.0 - delay)).clamp(0.0, 1.0);

        final Offset offset;
        switch (direction) {
          case AxisDirection.up:
            offset = Offset(0, 30 * (1 - t));
          case AxisDirection.down:
            offset = Offset(0, -30 * (1 - t));
          case AxisDirection.left:
            offset = Offset(30 * (1 - t), 0);
          case AxisDirection.right:
            offset = Offset(-30 * (1 - t), 0);
        }

        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: offset,
            child: Transform.scale(
              scale: 0.9 + 0.1 * t,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// 弹性弹跳图标按钮
class BounceIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;

  const BounceIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      scale: 0.82,
      child: Icon(icon, size: size, color: color),
    );
  }
}

/// 平滑出现的淡入 + 上浮
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final double slideOffset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.slideOffset = 24,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, slideOffset * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// 脉冲闪烁（用于提示动画）
class Pulse extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const Pulse({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Opacity(
          opacity: 0.5 + 0.5 * _ctrl.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
