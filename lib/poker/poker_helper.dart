import 'dart:math';
import 'package:card_game/card_game.dart';
import 'package:poker_solver/poker_solver.dart';

/// 将 card_game 的 SuitedCard 转为 poker_solver 的字符串格式 (如 "Ah", "Td")
String suitedCardToSolverString(SuitedCard card) {
  String rankStr;
  final v = card.value;
  if (v is AceSuitedCardValue) {
    rankStr = 'A';
  } else if (v is KingSuitedCardValue) {
    rankStr = 'K';
  } else if (v is QueenSuitedCardValue) {
    rankStr = 'Q';
  } else if (v is JackSuitedCardValue) {
    rankStr = 'J';
  } else if (v is NumberSuitedCardValue) {
    rankStr = v.value == 10 ? 'T' : '${v.value}';
  } else {
    rankStr = '?';
  }
  final suitStr = switch (card.suit) {
    CardSuit.hearts => 'h',
    CardSuit.diamonds => 'd',
    CardSuit.clubs => 'c',
    CardSuit.spades => 's',
  };
  return '$rankStr$suitStr';
}

/// 将 card_game 的 SuitedCard 列表转为 poker_solver 的字符串列表
List<String> cardsToSolverStrings(List<SuitedCard> cards) =>
    cards.map(suitedCardToSolverString).toList();

/// 用 poker_solver 比较两手牌，返回 1=player赢, -1=AI赢, 0=平局
int compareHands(List<SuitedCard> player, List<SuitedCard> ai) {
  final h1 = Hand.solveHand(cardsToSolverStrings(player));
  final h2 = Hand.solveHand(cardsToSolverStrings(ai));
  final winners = Hand.winners([h1, h2]);
  if (winners.length == 1) {
    return winners.first == h1 ? 1 : -1;
  }
  return 0;
}

/// 获取手牌名称
String getHandName(List<SuitedCard> cards) {
  final h = Hand.solveHand(cardsToSolverStrings(cards));
  return h.descr ?? h.name;
}

/// 获取 SuitedCard 对应的数值 (A=14, K=13, ..., 2=2)
int cardRankValue(SuitedCard card) {
  final v = card.value;
  if (v is AceSuitedCardValue) return 14;
  if (v is KingSuitedCardValue) return 13;
  if (v is QueenSuitedCardValue) return 12;
  if (v is JackSuitedCardValue) return 11;
  if (v is NumberSuitedCardValue) return v.value;
  return 0;
}

/// 从 7 张牌中选出最佳 5 张（德州扑克用）
List<SuitedCard> bestFiveOfSeven(List<SuitedCard> seven) {
  if (seven.length <= 5) return List.from(seven);

  List<SuitedCard> best = seven.sublist(0, 5);
  // 遍历所有 C(7,5)=21 种组合
  for (int a = 0; a < 7; a++) {
    for (int b = a + 1; b < 7; b++) {
      // 跳过 a, b 两张
      final combo = <SuitedCard>[];
      for (int i = 0; i < 7; i++) {
        if (i != a && i != b) combo.add(seven[i]);
      }
      if (compareHands(combo, best) > 0) {
        best = combo;
      }
    }
  }
  return best;
}

/// AI 换牌策略：返回要换掉的索引列表（最多 3 张）
List<int> aiChooseDiscards(List<SuitedCard> hand) {
  final rng = Random();
  final indices = <int>[];

  // 统计每个 rank 的出现次数
  final rankCounts = <int, List<int>>{};
  for (int i = 0; i < hand.length; i++) {
    final r = cardRankValue(hand[i]);
    rankCounts.putIfAbsent(r, () => []).add(i);
  }

  // 保留对子/三条/四条，换掉单牌
  final keepRanks = <int>{};
  for (final e in rankCounts.entries) {
    if (e.value.length >= 2) keepRanks.add(e.key);
  }

  if (keepRanks.isNotEmpty) {
    for (int i = 0; i < hand.length; i++) {
      if (!keepRanks.contains(cardRankValue(hand[i]))) indices.add(i);
    }
    if (indices.length > 3) {
      indices.shuffle(rng);
      indices.removeRange(3, indices.length);
    }
    return indices;
  }

  // 同花抽牌：4 张同花 → 换 1 张
  final suitCounts = <CardSuit, List<int>>{};
  for (int i = 0; i < hand.length; i++) {
    suitCounts.putIfAbsent(hand[i].suit, () => []).add(i);
  }
  for (final e in suitCounts.entries) {
    if (e.value.length >= 4) {
      final keep = e.value.toSet();
      for (int i = 0; i < hand.length; i++) {
        if (!keep.contains(i)) return [i];
      }
    }
  }

  // 顺子抽牌：4 张连续 → 换不连续的那张
  final sorted = hand.asMap().entries.toList()
    ..sort((a, b) => cardRankValue(a.value).compareTo(cardRankValue(b.value)));
  final vals = sorted.map((e) => cardRankValue(e.value)).toList();
  // 检查是否 4 连
  int consecCount = 1;
  int gapIdx = -1;
  for (int i = 1; i < vals.length; i++) {
    if (vals[i] == vals[i - 1] + 1) {
      consecCount++;
    } else if (vals[i] == vals[i - 1]) {
      // 对子，不计
    } else if (gapIdx == -1) {
      gapIdx = i;
    }
  }
  if (consecCount >= 4 && gapIdx != -1) {
    return [sorted[gapIdx].key];
  }

  // 默认：换掉最小的 1-3 张牌
  final byRank = hand.asMap().entries.toList()
    ..sort((a, b) => cardRankValue(a.value).compareTo(cardRankValue(b.value)));
  for (int i = 0; i < 3 && i < byRank.length; i++) {
    indices.add(byRank[i].key);
  }

  return indices.length > 3 ? indices.sublist(0, 3) : indices;
}
