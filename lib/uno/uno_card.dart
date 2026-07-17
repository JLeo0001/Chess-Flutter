import 'dart:math';

enum UnoColor { red, blue, green, yellow }

enum UnoType {
  zero, one, two, three, four, five, six, seven, eight, nine,
  skip, reverse, draw2, wild, wildDraw4,
}

class UnoCard {
  final UnoColor? color; // null = wild
  final UnoType type;

  const UnoCard(this.color, this.type);

  bool get isWild => type == UnoType.wild || type == UnoType.wildDraw4;
  bool get isNumber => type.index <= UnoType.nine.index;
  int? get number => isNumber ? type.index : null;

  String get label {
    switch (type) {
      case UnoType.skip: return '⊘';
      case UnoType.reverse: return '⟲';
      case UnoType.draw2: return '+2';
      case UnoType.wild: return 'W';
      case UnoType.wildDraw4: return '+4';
      default: return '${type.index}';
    }
  }

  /// 是否可以出在 topCard 之上（假设已选了 wild 颜色）
  bool canPlayOn(UnoCard top, {UnoColor? wildColor}) {
    if (isWild) return true;
    if (top.isWild) {
      // top 是 wild，wildColor 已定
      return color == wildColor;
    }
    return color == top.color || type == top.type;
  }

  @override
  bool operator ==(Object other) =>
      other is UnoCard && color == other.color && type == other.type;

  @override
  int get hashCode => Object.hash(color, type);

  @override
  String toString() => '${color?.name ?? "wild"}:$label';
}

/// 标准 UNO 牌组：108 张
List<UnoCard> createUnoDeck() {
  final deck = <UnoCard>[];
  for (final color in UnoColor.values) {
    // 数字 0: 1 张
    deck.add(UnoCard(color, UnoType.zero));
    // 数字 1-9: 各 2 张
    for (int i = 1; i <= 9; i++) {
      deck.add(UnoCard(color, UnoType.values[i]));
      deck.add(UnoCard(color, UnoType.values[i]));
    }
    // 功能牌: 各 2 张
    for (final t in [UnoType.skip, UnoType.reverse, UnoType.draw2]) {
      deck.add(UnoCard(color, t));
      deck.add(UnoCard(color, t));
    }
  }
  // Wild: 4 张, Wild Draw 4: 4 张
  for (int i = 0; i < 4; i++) {
    deck.add(const UnoCard(null, UnoType.wild));
    deck.add(const UnoCard(null, UnoType.wildDraw4));
  }
  return deck;
}

List<UnoCard> shuffledDeck() {
  final d = createUnoDeck();
  d.shuffle(Random());
  return d;
}
