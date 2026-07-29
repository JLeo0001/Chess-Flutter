import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'circular_reveal_painter.dart';

class CircularThemeRevealOverlay extends StatefulWidget {
  const CircularThemeRevealOverlay({required this.child, super.key});

  final Widget child;

  static CircularThemeRevealOverlayState? of(BuildContext context) {
    return context
        .findAncestorStateOfType<CircularThemeRevealOverlayState>();
  }

  static Offset getCenterFromContext(BuildContext context) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;

    final Offset position = box.localToGlobal(Offset.zero);
    final Size size = box.size;

    return Offset(
      position.dx + size.width / 2,
      position.dy + size.height / 2,
    );
  }

  @override
  CircularThemeRevealOverlayState createState() =>
      CircularThemeRevealOverlayState();
}

class CircularThemeRevealOverlayState extends State<CircularThemeRevealOverlay>
    with SingleTickerProviderStateMixin {
  final GlobalKey _repaintKey = GlobalKey();
  late AnimationController _controller;
  late Animation<double> _animation;

  ui.Image? _snapshot;
  Offset? _center;
  bool _isAnimating = false;
  bool _isReverse = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
      reverseCurve: Curves.easeInExpo,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  Future<void> startTransition({
    required Offset center,
    required VoidCallback onThemeChange,
    required bool reverse,
  }) async {
    if (_isAnimating) return;

    final ui.Image? capturedImage = await _captureSnapshot();
    if (capturedImage == null) {
      onThemeChange();
      return;
    }

    setState(() {
      _snapshot = capturedImage;
      _center = center;
      _isAnimating = true;
      _isReverse = reverse;
    });

    await Future.delayed(const Duration(milliseconds: 30));

    onThemeChange();

    await Future.delayed(const Duration(milliseconds: 20));

    await _controller.forward(from: 0.0);

    if (_isReverse) {
      await Future.delayed(const Duration(milliseconds: 16));
    }

    if (mounted) {
      setState(() {
        _isAnimating = false;
        _isReverse = false;
        _snapshot?.dispose();
        _snapshot = null;
        _center = null;
      });
    }

    _controller.reset();
  }

  Future<ui.Image?> _captureSnapshot() async {
    try {
      await Future.delayed(const Duration(milliseconds: 20));

      final RenderRepaintBoundary? boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        return null;
      }

      if (!mounted) return null;

      final double pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      return image;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RepaintBoundary(key: _repaintKey, child: widget.child),
        if (_isAnimating && _snapshot != null && _center != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (BuildContext context, Widget? child) {
                  return CustomPaint(
                    painter: CircularRevealPainter(
                      image: _snapshot!,
                      center: _center!,
                      progress: _animation.value,
                      isReverse: _isReverse,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
