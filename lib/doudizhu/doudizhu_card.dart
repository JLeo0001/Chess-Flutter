import 'dart:math';
import 'package:card_game/card_game.dart';

/// 斗地主卡牌 rank 值
class DdzRank {
  static const int r3 = 3, r4 = 4, r5 = 5, r6 = 6, r7 = 7, r8 = 8, r9 = 9;
  static const int r10 = 10, rJ = 11, rQ = 12, rK = 13, rA = 14, r2 = 15;
  static const int smallJoker = 16, bigJoker = 17;

  static String label(int rank) {
    switch (rank) {
      case 11: return 'J';
      case 12: return 'Q';
      case 13: return 'K';
      case 14: return 'A';
      case 15: return '2';
      case 16: return '小';
      case 17: return '大';
      default: return '$rank';
    }
  }
}

/// 斗地主卡牌
class DdzCard {
  final int rank; // 3..17
  final int suit; // 0=none(Joker), 1=♠, 2=♥, 3=♣, 4=♦

  const DdzCard(this.rank, this.suit);

  bool get isJoker => rank >= 16;
  bool get isBigJoker => rank == 17;
  bool get isSmallJoker => rank == 16;
  String get rankLabel => DdzRank.label(rank);
  String get suitLabel => ['', '♠', '♥', '♣', '♦'][suit];
  String get label => isJoker ? (isBigJoker ? '大王' : '小王') : '$rankLabel$suitLabel';
  bool get isRed => suit == 2 || suit == 4;

  /// 转为 SuitedCard（用于 card_game 渲染），Joker 返回 null
  SuitedCard? toSuitedCard() {
    if (isJoker) return null;
    final suitMap = [CardSuit.spades, CardSuit.hearts, CardSuit.clubs, CardSuit.diamonds];
    final value = _rankToValue(rank);
    return SuitedCard(value: value, suit: suitMap[suit - 1]);
  }

  static SuitedCardValue _rankToValue(int r) {
    switch (r) {
      case 14: return AceSuitedCardValue();
      case 13: return KingSuitedCardValue();
      case 12: return QueenSuitedCardValue();
      case 11: return JackSuitedCardValue();
      case 15: return NumberSuitedCardValue(value: 2);
      default: return NumberSuitedCardValue(value: r);
    }
  }

  static final List<DdzCard> deck = _buildDeck();
  static List<DdzCard> _buildDeck() {
    final list = <DdzCard>[];
    for (int r = 3; r <= 15; r++) {
      for (int s = 1; s <= 4; s++) list.add(DdzCard(r, s));
    }
    list.add(DdzCard(16, 0));
    list.add(DdzCard(17, 0));
    return list;
  }

  static int compare(DdzCard a, DdzCard b) => b.rank.compareTo(a.rank);
}

/// 牌型
enum DdzComboType {
  single, pair, triple, triplePlus1, triplePlus2,
  straight, dStraight, tStraight, airplane1, airplane2,
  bomb, rocket,
}

/// 一手出牌
class DdzCombo {
  final DdzComboType type;
  final int primaryRank;
  final int length;
  final List<DdzCard> cards;

  const DdzCombo({
    required this.type, required this.primaryRank, required this.length, required this.cards,
  });

  int get cardCount => cards.length;

  bool canBeat(DdzCombo other) {
    if (type == DdzComboType.rocket) return true;
    if (other.type == DdzComboType.rocket) return false;
    if (type == DdzComboType.bomb) {
      if (other.type == DdzComboType.bomb) return primaryRank > other.primaryRank;
      return true;
    }
    if (other.type == DdzComboType.bomb) return false;
    if (type != other.type) return false;
    if (cardCount != other.cardCount) return false;
    return primaryRank > other.primaryRank;
  }
}

// ═══ 牌型检测 ═══

Map<int, int> _rankCounts(List<DdzCard> hand) {
  final m = <int, int>{};
  for (final c in hand) m[c.rank] = (m[c.rank] ?? 0) + 1;
  return m;
}

DdzCombo? identifyCombo(List<DdzCard> cards) {
  if (cards.isEmpty) return null;
  final n = cards.length;
  final rc = _rankCounts(cards);
  final ranks = rc.keys.toList()..sort();
  final rv = rc.values.toList()..sort();

  if (n == 2 && cards.any((c) => c.isBigJoker) && cards.any((c) => c.isSmallJoker)) {
    return DdzCombo(type: DdzComboType.rocket, primaryRank: 17, length: 1, cards: List<DdzCard>.from(cards));
  }
  if (n == 4 && rc.length == 1) {
    return DdzCombo(type: DdzComboType.bomb, primaryRank: ranks.first, length: 1, cards: List<DdzCard>.from(cards));
  }
  if (n == 1) {
    return DdzCombo(type: DdzComboType.single, primaryRank: cards[0].rank, length: 1, cards: List<DdzCard>.from(cards));
  }
  if (n == 2 && rc.length == 1 && !cards[0].isJoker) {
    return DdzCombo(type: DdzComboType.pair, primaryRank: ranks.first, length: 1, cards: List<DdzCard>.from(cards));
  }
  if (n == 3 && rc.length == 1 && ranks.first < 16) {
    return DdzCombo(type: DdzComboType.triple, primaryRank: ranks.first, length: 1, cards: List<DdzCard>.from(cards));
  }
  if (n == 4 && rv.length == 2 && rv.contains(3) && rv.contains(1)) {
    final tripleRank = rc.entries.firstWhere((e) => e.value == 3).key;
    return DdzCombo(type: DdzComboType.triplePlus1, primaryRank: tripleRank, length: 1, cards: List<DdzCard>.from(cards));
  }
  if (n == 5 && rv.length == 2 && rv.contains(3) && rv.contains(2)) {
    final tripleRank = rc.entries.firstWhere((e) => e.value == 3).key;
    return DdzCombo(type: DdzComboType.triplePlus2, primaryRank: tripleRank, length: 1, cards: List<DdzCard>.from(cards));
  }
  if (n >= 5 && rc.values.every((v) => v == 1) && ranks.last - ranks.first == n - 1 && ranks.last < 15 && ranks.first >= 3) {
    return DdzCombo(type: DdzComboType.straight, primaryRank: ranks.last, length: n, cards: List<DdzCard>.from(cards));
  }
  if (n >= 6 && n % 2 == 0 && rc.values.every((v) => v == 2) && ranks.last - ranks.first == ranks.length - 1 && ranks.last < 15 && ranks.first >= 3) {
    return DdzCombo(type: DdzComboType.dStraight, primaryRank: ranks.last, length: ranks.length, cards: List<DdzCard>.from(cards));
  }
  if (n >= 6 && n % 3 == 0 && rc.values.every((v) => v == 3) && ranks.last - ranks.first == ranks.length - 1 && ranks.last < 15 && ranks.first >= 3) {
    return DdzCombo(type: DdzComboType.tStraight, primaryRank: ranks.last, length: ranks.length, cards: List<DdzCard>.from(cards));
  }

  // 飞机
  final triples = <int>[];
  for (final e in rc.entries) {
    if (e.value >= 3 && e.key < 15) triples.add(e.key);
  }
  if (triples.length >= 2) {
    triples.sort();
    final tripleSets = <List<int>>[];
    List<int> current = [triples.first];
    for (int i = 1; i < triples.length; i++) {
      if (triples[i] == triples[i - 1] + 1) current.add(triples[i]);
      else { tripleSets.add(List<int>.from(current)); current = [triples[i]]; }
    }
    tripleSets.add(current);
    for (final ts in tripleSets) {
      if (ts.length < 2) continue;
      final tc = ts.length;
      final rem = n - tc * 3;
      if (rem == tc && rem > 0) {
        final tmp = Map<int, int>.from(rc);
        for (final r in ts) tmp[r] = (tmp[r] ?? 0) - 3;
        final total = tmp.values.fold(0, (a, b) => a + b);
        if (total == tc && tmp.values.every((v) => v == 0 || v == 1)) {
          final s = List<DdzCard>.from(cards)..sort((a, b) => b.rank.compareTo(a.rank));
          return DdzCombo(type: DdzComboType.airplane1, primaryRank: ts.last, length: tc, cards: s);
        }
      }
      if (rem == tc * 2 && rem > 0) {
        final tmp = Map<int, int>.from(rc);
        for (final r in ts) tmp[r] = (tmp[r] ?? 0) - 3;
        final total = tmp.values.fold(0, (a, b) => a + b);
        if (total == rem && tmp.values.every((v) => v == 0 || v == 2)) {
          final s = List<DdzCard>.from(cards)..sort((a, b) => b.rank.compareTo(a.rank));
          return DdzCombo(type: DdzComboType.airplane2, primaryRank: ts.last, length: tc, cards: s);
        }
      }
      if (rem == 0 && tc >= 2) {
        final s = List<DdzCard>.from(cards)..sort((a, b) => b.rank.compareTo(a.rank));
        return DdzCombo(type: DdzComboType.tStraight, primaryRank: ts.last, length: tc, cards: s);
      }
    }
  }
  return null;
}

/// 查找能压过的组合
List<DdzCombo> findBeatingCombos(List<DdzCard> hand, DdzCombo lastPlay) {
  if (lastPlay.type == DdzComboType.rocket || hand.isEmpty) return [];
  final result = <DdzCombo>[];
  final rc = _rankCounts(hand);
  final sorted = List<DdzCard>.from(hand)..sort(DdzCard.compare);

  if (rc.containsKey(16) && rc.containsKey(17)) {
    result.add(DdzCombo(type: DdzComboType.rocket, primaryRank: 17, length: 1, cards: [DdzCard(16, 0), DdzCard(17, 0)]));
  }
  for (final e in rc.entries) {
    if (e.value == 4 && (lastPlay.type != DdzComboType.bomb || e.key > lastPlay.primaryRank)) {
      result.add(DdzCombo(type: DdzComboType.bomb, primaryRank: e.key, length: 1, cards: sorted.where((c) => c.rank == e.key).toList()));
    }
  }

  switch (lastPlay.type) {
    case DdzComboType.single:
      for (final c in sorted) {
        if (c.rank > lastPlay.primaryRank) result.add(DdzCombo(type: DdzComboType.single, primaryRank: c.rank, length: 1, cards: [c]));
      }
      break;
    case DdzComboType.pair:
      for (final e in rc.entries) {
        if (e.value >= 2 && e.key > lastPlay.primaryRank && e.key < 16) {
          result.add(DdzCombo(type: DdzComboType.pair, primaryRank: e.key, length: 1, cards: sorted.where((c) => c.rank == e.key).take(2).toList()));
        }
      }
      break;
    case DdzComboType.triple:
      for (final e in rc.entries) {
        if (e.value >= 3 && e.key > lastPlay.primaryRank && e.key < 16) {
          result.add(DdzCombo(type: DdzComboType.triple, primaryRank: e.key, length: 1, cards: sorted.where((c) => c.rank == e.key).take(3).toList()));
        }
      }
      break;
    case DdzComboType.triplePlus1:
      for (final e in rc.entries) {
        if (e.value >= 3 && e.key > lastPlay.primaryRank && e.key < 16) _addT3k(sorted, e.key, 1, result);
      }
      break;
    case DdzComboType.triplePlus2:
      for (final e in rc.entries) {
        if (e.value >= 3 && e.key > lastPlay.primaryRank && e.key < 16) _addT3k(sorted, e.key, 2, result);
      }
      break;
    case DdzComboType.straight:
      final len = lastPlay.cardCount;
      for (int s = 3; s + len - 1 <= 14; s++) {
        final e = s + len - 1;
        if (e <= lastPlay.primaryRank) continue;
        final p = <DdzCard>[];
        bool ok = true;
        for (int r = s; r <= e; r++) {
          final cards = sorted.where((c) => c.rank == r).toList();
          if (cards.isEmpty) { ok = false; break; }
          p.add(cards.first);
        }
        if (ok) { p.sort(DdzCard.compare); result.add(DdzCombo(type: DdzComboType.straight, primaryRank: e, length: len, cards: p)); }
      }
      break;
    case DdzComboType.dStraight:
      final pc = lastPlay.length;
      for (int s = 3; s + pc - 1 <= 14; s++) {
        final e = s + pc - 1;
        if (e <= lastPlay.primaryRank) continue;
        final p = <DdzCard>[]; bool ok = true;
        for (int r = s; r <= e; r++) {
          final cards = sorted.where((c) => c.rank == r).toList();
          if (cards.length < 2) { ok = false; break; }
          p.addAll(cards.take(2));
        }
        if (ok) { p.sort(DdzCard.compare); result.add(DdzCombo(type: DdzComboType.dStraight, primaryRank: e, length: pc, cards: p)); }
      }
      break;
    case DdzComboType.tStraight:
      final tc = lastPlay.length;
      for (int s = 3; s + tc - 1 <= 14; s++) {
        final e = s + tc - 1;
        if (e <= lastPlay.primaryRank) continue;
        final p = <DdzCard>[]; bool ok = true;
        for (int r = s; r <= e; r++) {
          final cards = sorted.where((c) => c.rank == r).toList();
          if (cards.length < 3) { ok = false; break; }
          p.addAll(cards.take(3));
        }
        if (ok) { p.sort(DdzCard.compare); result.add(DdzCombo(type: DdzComboType.tStraight, primaryRank: e, length: tc, cards: p)); }
      }
      break;
    case DdzComboType.airplane1:
      _findPlane(sorted, lastPlay.length, true, lastPlay.primaryRank, result);
      break;
    case DdzComboType.airplane2:
      _findPlane(sorted, lastPlay.length, false, lastPlay.primaryRank, result);
      break;
    default: break;
  }
  return result;
}

void _addT3k(List<DdzCard> sorted, int tripleRank, int kt, List<DdzCombo> result) {
  final triples = sorted.where((c) => c.rank == tripleRank).take(3).toList();
  final others = sorted.where((c) => c.rank != tripleRank).toList();
  if (kt == 1) {
    if (others.isNotEmpty) result.add(DdzCombo(type: DdzComboType.triplePlus1, primaryRank: tripleRank, length: 1, cards: [...triples, others.first]));
  } else {
    final rc = _rankCounts(others);
    for (final e in rc.entries) {
      if (e.value >= 2 && e.key != tripleRank) {
        result.add(DdzCombo(type: DdzComboType.triplePlus2, primaryRank: tripleRank, length: 1, cards: [...triples, ...others.where((c) => c.rank == e.key).take(2)]));
      }
    }
  }
}

void _findPlane(List<DdzCard> sorted, int tc, bool ws, int minR, List<DdzCombo> result) {
  final rc = _rankCounts(sorted);
  final triples = <int>[];
  for (final e in rc.entries) { if (e.value >= 3 && e.key < 15) triples.add(e.key); }
  triples.sort();
  for (int i = 0; i + tc - 1 < triples.length; i++) {
    if (triples[i] + tc - 1 != triples[i + tc - 1]) continue;
    final end = triples[i] + tc - 1;
    if (end <= minR) continue;
    final picked = <DdzCard>[];
    final remaining = <DdzCard>[...sorted];
    for (int r = triples[i]; r <= end; r++) {
      final cards = sorted.where((c) => c.rank == r).take(3).toList();
      picked.addAll(cards);
      remaining.removeWhere((c) => cards.contains(c));
    }
    if (ws) {
      final kickers = remaining.take(tc).toList();
      if (kickers.length == tc) { picked.addAll(kickers); picked.sort(DdzCard.compare); result.add(DdzCombo(type: DdzComboType.airplane1, primaryRank: end, length: tc, cards: picked)); }
    } else {
      final pairs = <DdzCard>[];
      for (final e in _rankCounts(remaining).entries) { if (e.value >= 2) pairs.addAll(remaining.where((c) => c.rank == e.key).take(2)); }
      if (pairs.length >= tc) { picked.addAll(pairs.take(tc * 2)); picked.sort(DdzCard.compare); result.add(DdzCombo(type: DdzComboType.airplane2, primaryRank: end, length: tc, cards: picked)); }
    }
  }
}

/// 所有合法组合（领出用）
List<DdzCombo> findAllCombos(List<DdzCard> hand) {
  if (hand.isEmpty) return [];
  final result = <DdzCombo>[];
  final sorted = List<DdzCard>.from(hand)..sort(DdzCard.compare);
  final rc = _rankCounts(sorted);

  for (final c in sorted) result.add(DdzCombo(type: DdzComboType.single, primaryRank: c.rank, length: 1, cards: [c]));
  for (final e in rc.entries) {
    if (e.value >= 2 && e.key < 16) result.add(DdzCombo(type: DdzComboType.pair, primaryRank: e.key, length: 1, cards: sorted.where((c) => c.rank == e.key).take(2).toList()));
    if (e.value >= 3 && e.key < 16) {
      result.add(DdzCombo(type: DdzComboType.triple, primaryRank: e.key, length: 1, cards: sorted.where((c) => c.rank == e.key).take(3).toList()));
      _addT3k(sorted, e.key, 1, result); _addT3k(sorted, e.key, 2, result);
    }
  }
  for (int len = 5; len <= 12; len++) {
    for (int s = 3; s + len - 1 <= 14; s++) {
      final e = s + len - 1; final p = <DdzCard>[]; bool ok = true;
      for (int r = s; r <= e; r++) { final cards = sorted.where((c) => c.rank == r).toList(); if (cards.isEmpty) { ok = false; break; } p.add(cards.first); }
      if (ok) { p.sort(DdzCard.compare); result.add(DdzCombo(type: DdzComboType.straight, primaryRank: e, length: len, cards: p)); }
    }
  }
  for (int len = 3; len <= 10; len++) {
    for (int s = 3; s + len - 1 <= 14; s++) {
      final e = s + len - 1; final p = <DdzCard>[]; bool ok = true;
      for (int r = s; r <= e; r++) { final cards = sorted.where((c) => c.rank == r).toList(); if (cards.length < 2) { ok = false; break; } p.addAll(cards.take(2)); }
      if (ok) { p.sort(DdzCard.compare); result.add(DdzCombo(type: DdzComboType.dStraight, primaryRank: e, length: len, cards: p)); }
    }
  }
  for (int len = 2; len <= 6; len++) {
    for (int s = 3; s + len - 1 <= 14; s++) {
      final e = s + len - 1; final p = <DdzCard>[]; bool ok = true;
      for (int r = s; r <= e; r++) { final cards = sorted.where((c) => c.rank == r).toList(); if (cards.length < 3) { ok = false; break; } p.addAll(cards.take(3)); }
      if (ok) {
        p.sort(DdzCard.compare);
        result.add(DdzCombo(type: DdzComboType.tStraight, primaryRank: e, length: len, cards: List<DdzCard>.from(p)));
        final remaining = sorted.where((c) => !p.contains(c)).toList();
        if (remaining.length >= len) { final c2 = [...p, ...remaining.take(len)]; c2.sort(DdzCard.compare); result.add(DdzCombo(type: DdzComboType.airplane1, primaryRank: e, length: len, cards: c2)); }
        if (remaining.length >= len * 2) {
          final pairs = <DdzCard>[];
          for (final e2 in _rankCounts(remaining).entries) { if (e2.value >= 2) { pairs.addAll(remaining.where((c) => c.rank == e2.key).take(2)); if (pairs.length >= len * 2) break; } }
          if (pairs.length >= len * 2) { final c2 = [...p, ...pairs.take(len * 2)]; c2.sort(DdzCard.compare); result.add(DdzCombo(type: DdzComboType.airplane2, primaryRank: e, length: len, cards: c2)); }
        }
      }
    }
  }
  for (final e in rc.entries) {
    if (e.value == 4) result.add(DdzCombo(type: DdzComboType.bomb, primaryRank: e.key, length: 1, cards: sorted.where((c) => c.rank == e.key).toList()));
  }
  if (rc.containsKey(16) && rc.containsKey(17)) {
    result.add(DdzCombo(type: DdzComboType.rocket, primaryRank: 17, length: 1, cards: [DdzCard(16, 0), DdzCard(17, 0)]));
  }
  return result;
}
