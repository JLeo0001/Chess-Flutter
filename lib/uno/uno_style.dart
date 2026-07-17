import 'package:card_game/card_game.dart';
import 'package:flutter/material.dart';
import 'uno_card.dart';

Color _unoBg(UnoColor c) => switch (c) {
      UnoColor.red => const Color(0xFFE53935),
      UnoColor.blue => const Color(0xFF1E88E5),
      UnoColor.green => const Color(0xFF43A047),
      UnoColor.yellow => const Color(0xFFFDD835),
    };

Color _unoFg(UnoColor c) => switch (c) {
      UnoColor.red => Colors.white,
      UnoColor.blue => Colors.white,
      UnoColor.green => Colors.white,
      UnoColor.yellow => Colors.black87,
    };

CardGameStyle<UnoCard, G> unoCardStyle<G>({double sizeMultiplier = 1}) =>
    CardGameStyle<UnoCard, G>(
      cardSize: Size(56, 80) * sizeMultiplier,
      emptyGroupBuilder: (group, state) => const SizedBox.shrink(),
      cardBuilder: (card, group, flipped, cardState) => AnimatedFlippable(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic,
        isFlipped: flipped,
        front: _UnoCardFace(card: card),
        back: _UnoCardBack(),
      ),
    );

class _UnoCardFace extends StatelessWidget {
  final UnoCard card;
  const _UnoCardFace({required this.card});

  @override
  Widget build(BuildContext context) {
    if (card.isWild) return _buildWild();
    return _buildColored();
  }

  Widget _buildColored() {
    final bg = _unoBg(card.color!);
    final fg = _unoFg(card.color!);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
      ),
      child: Stack(
        children: [
          // 四角小标记
          Positioned(top: 2, left: 4, child: _cornerLabel(fg)),
          Positioned(bottom: 2, right: 4,
              child: Transform.rotate(angle: 3.14159, child: _cornerLabel(fg))),
          // 中心椭圆
          Center(
            child: Container(
              width: 38, height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(card.label,
                      style: TextStyle(
                          fontSize: card.isNumber ? 28 : 20,
                          fontWeight: FontWeight.w900,
                          color: fg)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cornerLabel(Color c) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(card.label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: c)),
      ],
    );
  }

  Widget _buildWild() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white70, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Column(
          children: [
            Expanded(child: Row(children: [
              Expanded(child: Container(color: _unoBg(UnoColor.red))),
              Expanded(child: Container(color: _unoBg(UnoColor.blue))),
            ])),
            Expanded(child: Row(children: [
              Expanded(child: Container(color: _unoBg(UnoColor.green))),
              Expanded(child: Container(color: _unoBg(UnoColor.yellow))),
            ])),
          ],
        ),
      ),
    );
  }
}

class _UnoCardBack extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Center(
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.red, width: 3),
            color: Colors.red.withValues(alpha: 0.15),
          ),
          child: const Center(
            child: Text('U', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white70)),
          ),
        ),
      ),
    );
  }
}
