import 'dart:math';
import 'package:card_game/card_game.dart';

/// 蜘蛛纸牌 — 使用 card_game 包
class SpiderGame {
  static const int cols = 10;
  static const int totalSeq = 8;

  final int suitCount;
  final List<List<SuitedCard>> tableau;
  final List<SuitedCard> stock;
  final List<SuitedCard> completed;
  final Set<String> faceUpCards = {};
  int score;
  int moveCount;
  int dealCount;
  bool isGameOver;
  bool isWin;

  SpiderGame({this.suitCount = 1})
      : tableau = List.generate(cols, (_) => []),
        stock = [],
        completed = [],
        score = 500,
        moveCount = 0,
        dealCount = 0,
        isGameOver = false,
        isWin = false;

  bool isFaceUp(int col, int idx) => faceUpCards.contains('${col}_$idx');

  void _setFaceUp(int col, int idx) => faceUpCards.add('${col}_$idx');

  void _clearFaceUpOf(int col) =>
      faceUpCards.removeWhere((k) => k.startsWith('$col'));

  void newGame() {
    for (final c in tableau) c.clear();
    stock.clear();
    completed.clear();
    faceUpCards.clear();
    score = 500;
    moveCount = 0;
    dealCount = 0;
    isGameOver = false;
    isWin = false;

    final suitsPerDeck = switch (suitCount) {
      1 => [CardSuit.spades],
      2 => [CardSuit.spades, CardSuit.hearts],
      _ => [CardSuit.spades, CardSuit.hearts, CardSuit.diamonds, CardSuit.clubs],
    };
    final decksPerSuit = 8 ~/ suitCount;

    final deck = <SuitedCard>[];
    for (final suit in suitsPerDeck) {
      for (int d = 0; d < decksPerSuit; d++) {
        for (int r = 1; r <= 13; r++) {
          deck.add(SuitedCard(suit: suit, value: rankValue(r)));
        }
      }
    }
    deck.shuffle(Random());

    int idx = 0;
    for (int c = 0; c < cols; c++) {
      final count = c < 4 ? 6 : 5;
      for (int i = 0; i < count; i++) {
        tableau[c].add(deck[idx]);
        if (i == count - 1) _setFaceUp(c, i);
        idx++;
      }
    }
    while (idx < deck.length) {
      stock.add(deck[idx++]);
    }
  }

  static SuitedCardValue rankValue(int r) => switch (r) {
    1 => AceSuitedCardValue(),
    11 => JackSuitedCardValue(),
    12 => QueenSuitedCardValue(),
    13 => KingSuitedCardValue(),
    _ => NumberSuitedCardValue(value: r),
  };

  static int rankOf(SuitedCard c) {
    final v = c.value;
    if (v is AceSuitedCardValue) return 1;
    if (v is NumberSuitedCardValue) return v.value;
    if (v is JackSuitedCardValue) return 11;
    if (v is QueenSuitedCardValue) return 12;
    if (v is KingSuitedCardValue) return 13;
    return 0;
  }

  static String rankLabel(SuitedCard c) => switch (rankOf(c)) {
    1 => 'A', 11 => 'J', 12 => 'Q', 13 => 'K', var r => '$r',
  };

  static bool isRed(SuitedCard c) =>
      c.suit == CardSuit.hearts || c.suit == CardSuit.diamonds;

  // ——— 公开操作 ———

  /// 从 col[idx] 开始的牌是否构成 K→A 递减序列
  bool isSeq(int col, int idx) {
    final c = tableau[col];
    if (idx < 0 || idx >= c.length) return false;
    for (int j = idx; j < c.length - 1; j++) {
      if (rankOf(c[j]) != rankOf(c[j + 1]) + 1) return false;
    }
    return true;
  }

  /// 判断能否将 fc[fi] 开始移动至 tc
  bool canMove(int fc, int fi, int tc) {
    final f = tableau[fc], t = tableau[tc];
    if (fi >= f.length || !isSeq(fc, fi)) return false;
    if (t.isEmpty) return true;
    return rankOf(f[fi]) == rankOf(t.last) - 1;
  }

  // ═══ 移动操作 ═══
  // 返回值: (完成1组?，完成列)
  (bool, int) moveSeq(int fc, int fi, int tc) {
    final f = tableau[fc], t = tableau[tc];
    final moving = f.sublist(fi);
    f.removeRange(fi, f.length);

    // 重建 faceUp
    _clearFaceUpOf(fc);
    for (int i = 0; i < f.length; i++) _setFaceUp(fc, i);
    if (f.isNotEmpty && !isFaceUp(fc, f.length - 1)) {
      _setFaceUp(fc, f.length - 1);
    }

    _clearFaceUpOf(tc);
    for (int i = 0; i < t.length; i++) _setFaceUp(tc, i);
    t.addAll(moving);
    for (int i = 0; i < t.length; i++) _setFaceUp(tc, i);

    moveCount++;
    score--;

    return _checkComplete(tc);
  }

  /// 检查并完成序列，返回 (是否完成, 完成列)
  (bool, int) _checkComplete(int col) {
    final c = tableau[col];
    if (c.length < 13) return (false, col);
    final last13 = c.sublist(c.length - 13);
    for (int i = 0; i < 13; i++) {
      if (rankOf(last13[i]) != 13 - i) return (false, col);
    }
    completed.addAll(last13);
    c.removeRange(c.length - 13, c.length);
    score += 100;
    if (c.isNotEmpty && !isFaceUp(col, c.length - 1)) {
      _setFaceUp(col, c.length - 1);
    }
    if (completed.length >= totalSeq * 13) {
      isGameOver = true;
      isWin = true;
    }
    return (true, col);
  }

  /// 发牌
  bool deal() {
    if (isGameOver || stock.isEmpty) return false;
    for (int c = 0; c < cols; c++) {
      if (tableau[c].isEmpty) return false;
    }
    for (int c = 0; c < cols && stock.isNotEmpty; c++) {
      final idx = tableau[c].length;
      tableau[c].add(stock.removeLast());
      _setFaceUp(c, idx);
    }
    dealCount++;
    return true;
  }

  bool get isStuck {
    if (stock.isNotEmpty) return false;
    for (int f = 0; f < cols; f++) {
      final fc = tableau[f];
      for (int fi = fc.length - 1; fi >= 0; fi--) {
        if (!isFaceUp(f, fi)) break;
        if (!isSeq(f, fi)) break;
        for (int t = 0; t < cols; t++) {
          if (t != f && canMove(f, fi, t)) return false;
        }
      }
    }
    isGameOver = true;
    return true;
  }

  bool canDeal() => stock.isNotEmpty && tableau.every((c) => c.isNotEmpty);
}
