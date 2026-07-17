import 'package:flutter/material.dart';

/// 🎯 脉冲动画指示器
class PulseIndicator extends StatefulWidget {
  final Widget child;
  const PulseIndicator({super.key, required this.child});

  @override
  State<PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<PulseIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
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
      builder: (_, child) =>
          Transform.scale(scale: 1.0 + 0.15 * _ctrl.value, child: child),
      child: widget.child,
    );
  }
}
