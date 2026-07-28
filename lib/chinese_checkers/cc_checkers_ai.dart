/// 中国跳棋 AI — 启发式评估 + 贪心选择
///
/// 策略：
/// 1. 生成所有合法走法
/// 2. 对每个走法模拟执行并评分
/// 3. 评分维度：
///    - 距离收益：走子后到目标营地总距离的减少量（权重最高）
///    - 跳跃奖励：连跳步数越多越好
///    - 到位奖励：棋子进入目标营地
///    - 搭桥奖励：棋子留在中间位置便于后续跳跃
/// 4. 选择最高分走法

import 'dart:math';
import 'cc_checkers_game.dart';

class CCAi {
  final int aiPlayer;
  final int numPlayers;
  final ChineseCheckersGame game;
  final Random _rnd = Random();

  /// 评分权重
  static const int _distanceWeight = 100;
  static const int _jumpBonus = 80;
  static const int _enterCampBonus = 500;
  static const int _leaveCampPenalty = -200;
  static const int _bridgeBonus = 30;
  static const int _advanceFromHome = 60;
  static const int _jitterRange = 15;

  CCAi(this.aiPlayer, this.numPlayers, this.game);

  /// 查找最佳走法，返回 [fromIdx, toIdx] 或 null
  List<int>? findBestMove() {
    final moves = game.allLegalMoves(aiPlayer);
    if (moves.isEmpty) return null;
    if (moves.length == 1) return moves[0];

    final distBefore = game.totalDistanceToTarget(aiPlayer);

    final scored = <_ScoredMove>[];

    for (final m in moves) {
      final fromIdx = m[0], toIdx = m[1];
      game.simulateMove(fromIdx, toIdx);

      int score = 0;

      // 距离收益
      final distAfter = game.totalDistanceToTarget(aiPlayer);
      score += (distBefore - distAfter) * _distanceWeight;

      // 跳跃步数
      final jumpDist = game.hexDistance(fromIdx, toIdx);
      if (jumpDist > 1) {
        score += (jumpDist - 1) * _jumpBonus;
      }

      // 进入/离开目标营地
      final targetCamp = game.targetCampIdx(aiPlayer);
      final wasInCamp = game.camps[targetCamp].contains(fromIdx);
      final nowInCamp = game.camps[targetCamp].contains(toIdx);

      if (nowInCamp && !wasInCamp) score += _enterCampBonus;
      if (wasInCamp && !nowInCamp) score += _leaveCampPenalty;

      // 从己方营地出发
      final homeCamp = game.playerCampIdx(aiPlayer);
      if (game.camps[homeCamp].contains(fromIdx)) {
        score += _advanceFromHome;
      }

      // 搭桥位置
      final centerDist = game.hexDistance(toIdx, game.positions.length ~/ 2);
      if (centerDist <= 4 && !nowInCamp) score += _bridgeBonus;

      // 优先移动后方棋子
      final pieceDist = game.distanceToCamp(toIdx, targetCamp);
      score += (10 - pieceDist.clamp(0, 10)) * 5;

      // 随机抖动
      score += _rnd.nextInt(_jitterRange * 2 + 1) - _jitterRange;

      game.undoSimulate(fromIdx, toIdx, aiPlayer);
      scored.add(_ScoredMove(fromIdx, toIdx, score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final best = scored.first;
    final ties = scored.where((s) => s.score == best.score).toList();
    final picked = ties[_rnd.nextInt(ties.length)];

    return [picked.fromIdx, picked.toIdx];
  }
}

class _ScoredMove {
  final int fromIdx, toIdx, score;
  _ScoredMove(this.fromIdx, this.toIdx, this.score);
}
