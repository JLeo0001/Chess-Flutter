import 'dart:math';
import 'doudizhu_card.dart';

/// 玩家角色
enum DdzRole { farmer, landlord }

/// 斗地主游戏状态
class DoudizhuGame {
  final Random _rng = Random();

  final int landlordIdx; // 地主索引（玩家0是真人）
  int currentPlayer = 0; // 当前出牌玩家
  List<List<DdzCard>> hands = []; // 三人手牌
  List<DdzCard> bottomCards = []; // 底牌（3张）

  // 出牌追踪
  DdzCombo? lastPlay; // 上一手出的牌
  int? lastPlayerIdx; // 上家出牌玩家索引
  int passCount = 0; // 连续过牌次数
  int? winner; // 胜者索引

  // 叫地主
  bool biddingDone = false;
  int finalLandlord = 0; // 最终地主
  bool reDeal = false; // 是否需要重新发牌

  DoudizhuGame({required this.landlordIdx}) {
    _init();
  }

  void _init() {
    // 洗牌发牌
    final deck = List<DdzCard>.from(DdzCard.deck)..shuffle(_rng);
    hands = [for (int i = 0; i < 3; i++) <DdzCard>[]];
    for (int i = 0; i < 17; i++) {
      for (int p = 0; p < 3; p++) hands[p].add(deck.removeAt(0));
    }
    bottomCards = deck; // 剩余3张
    // 排序
    for (final h in hands) h.sort(DdzCard.compare);

    // 设定地主和底牌
    finalLandlord = landlordIdx;
    hands[landlordIdx].addAll(bottomCards);
    hands[landlordIdx].sort(DdzCard.compare);
    currentPlayer = landlordIdx;
    lastPlay = null;
    lastPlayerIdx = null;
    passCount = 0;
    winner = null;
    biddingDone = true;
  }

  bool get isPlayerTurn => currentPlayer == 0;
  bool get gameOver => winner != null;
  bool get playerIsLandlord => landlordIdx == 0;
  bool get playerIsFarmer => landlordIdx != 0;

  /// 出牌
  bool playCards(int playerIdx, List<DdzCard> cards) {
    if (gameOver) return false;
    if (currentPlayer != playerIdx) return false;

    // 验证手牌中有这些牌
    final hand = hands[playerIdx];
    final temp = List<DdzCard>.from(hand);
    for (final c in cards) {
      final idx = temp.indexWhere((h) => h.rank == c.rank && h.suit == c.suit);
      if (idx == -1) return false;
      temp.removeAt(idx);
    }

    // 识别牌型
    final combo = identifyCombo(cards);
    if (combo == null) return false;

    // 领出或压过
    if (lastPlayerIdx == null || lastPlayerIdx == playerIdx || passCount >= 2) {
      // 领出，什么都能出
    } else {
      if (!combo.canBeat(lastPlay!)) return false;
    }

    // 执行出牌
    for (final c in cards) hand.removeWhere((h) => h.rank == c.rank && h.suit == c.suit);
    lastPlay = combo;
    lastPlayerIdx = playerIdx;
    passCount = 0;

    // 检查胜利
    if (hand.isEmpty) {
      winner = playerIdx;
      return true;
    }

    // 下个玩家
    _nextPlayer();
    return true;
  }

  /// 过牌
  void pass(int playerIdx) {
    if (gameOver) return;
    if (currentPlayer != playerIdx) return;
    passCount++;
    if (passCount >= 2 && lastPlayerIdx != null) {
      // 两家都过，最后出牌者重新领出
    }
    _nextPlayer();
  }

  void _nextPlayer() {
    currentPlayer = (currentPlayer + 1) % 3;
    // 如果该玩家是最后出牌者且两家都过了，重置
    if (passCount >= 2 && currentPlayer == lastPlayerIdx) {
      passCount = 0;
      lastPlayerIdx = null;
      lastPlay = null;
    }
  }

  /// 获取 AI 出的牌
  DdzCombo? getAiPlay(int playerIdx) {
    if (gameOver) return null;
    if (currentPlayer != playerIdx) return null;
    if (playerIdx == 0) return null; // 不是AI

    final hand = hands[playerIdx];
    final isLeading = lastPlayerIdx == null || lastPlayerIdx == playerIdx || passCount >= 2;

    if (isLeading) {
      return _chooseBestLead(hand, playerIdx);
    } else {
      final combos = findBeatingCombos(hand, lastPlay!);
      if (combos.isEmpty) return null;
      return _chooseBestPlay(combos, hand, playerIdx);
    }
  }

  /// AI 基础策略：尽可能出最小的
  DdzCombo? _chooseBestLead(List<DdzCard> hand, int playerIdx) {
    final combos = findAllCombos(hand);
    if (combos.isEmpty) return null;

    // 从大到小排序，优先出小的
    combos.sort((a, b) {
      // 火箭/炸弹保留
      if (a.type == DdzComboType.rocket) return 1;
      if (b.type == DdzComboType.rocket) return -1;
      if (a.type == DdzComboType.bomb && b.type != DdzComboType.bomb) return 1;
      if (b.type == DdzComboType.bomb && a.type != DdzComboType.bomb) return -1;
      // 按cardCount降序（优先出多张）
      if (a.cardCount != b.cardCount) return b.cardCount.compareTo(a.cardCount);
      // 按primaryRank升序
      return a.primaryRank.compareTo(b.primaryRank);
    });

    // 如果牌很少 (<=4)，出最大的
    if (hand.length <= 4) return combos.last;

    // 优先出单牌/对子
    for (final c in combos) {
      if (c.type == DdzComboType.single || c.type == DdzComboType.pair) {
        // 不出2以上大牌领出
        if (c.primaryRank <= 14) return c;
      }
    }
    for (final c in combos) {
      if (c.type == DdzComboType.triple || c.type == DdzComboType.triplePlus1 || c.type == DdzComboType.triplePlus2) {
        return c;
      }
    }
    // 出最小的顺子
    for (final c in combos) {
      if (c.type == DdzComboType.straight) return c;
    }
    // 出最小的
    return combos.first;
  }

  DdzCombo? _chooseBestPlay(List<DdzCombo> combos, List<DdzCard> hand, int playerIdx) {
    if (combos.isEmpty) return null;
    // 按大小排序
    combos.sort((a, b) => a.primaryRank.compareTo(b.primaryRank));

    // 如果有火箭，留到关键时候（手牌>3时才留）
    if (hand.length > 3) {
      final rockets = combos.where((c) => c.type == DdzComboType.rocket).toList();
      if (rockets.isNotEmpty) {
        final nonRockets = combos.where((c) => c.type != DdzComboType.rocket).toList();
        if (nonRockets.isNotEmpty) return nonRockets.first;
      }
    }

    // 出最小的能压过的
    return combos.first;
  }
}
