import 'dart:math';
import 'gobang_game.dart';

/// 五子棋 AI — Minimax + Alpha-Beta + 模式评分
///
/// 搜索深度 3，含活四/冲四/活三/眠三模式识别
class GobangAI {
  static const int boardSize = 15;
  final int aiColor;
  final int opponentColor;
  final Random _random = Random();

  static const int _maxDepth = 4;
  static const int WIN = 1000000;

  GobangAI(this.aiColor)
      : opponentColor = (aiColor == GobangGame.black)
            ? GobangGame.white
            : GobangGame.black;

  // ========== 公开接口 ==========

  List<int>? findBestMove(List<List<int>> board) {
    int bestScore = -999999;
    int bestR = -1, bestC = -1;
    int alpha = -999999, beta = 999999;

    // 第一步直接走天元
    if (_isEmptyBoard(board)) return [7, 7];

    // 只搜索已有棋子附近2格
    final candidates = _getCandidates(board);
    if (candidates.isEmpty) return [7, 7];

    for (final pos in candidates) {
      final r = pos[0], c = pos[1];
      board[r][c] = aiColor;
      final score = -_negamax(board, 1, -beta, -alpha);
      board[r][c] = GobangGame.empty;

      if (score > bestScore || (score == bestScore && _random.nextBool())) {
        bestScore = score;
        bestR = r;
        bestC = c;
      }
      if (score > alpha) alpha = score;
    }

    return (bestR == -1) ? null : [bestR, bestC];
  }

  // ========== Negamax + Alpha-Beta ==========

  int _negamax(List<List<int>> board, int depth, int alpha, int beta) {
    // 终局检测（上一手已经赢了）
    final lastColor = (depth % 2 == 1) ? opponentColor : aiColor;
    if (_checkWinAtBoard(board, lastColor)) {
      return -(WIN - depth * 10);
    }

    if (depth >= _maxDepth) {
      return _evaluateBoard(board);
    }

    final candidates = _getCandidates(board);
    if (candidates.isEmpty) return 0; // 平局

    // 按启发式排序
    _sortCandidates(candidates, board);

    int best = -999999;
    for (int i = 0; i < min(candidates.length, 15); i++) {
      final r = candidates[i][0], c = candidates[i][1];
      final color = (depth % 2 == 0) ? aiColor : opponentColor;
      board[r][c] = color;

      // 快速检测：下这里直接赢
      if (_checkWinAtBoard(board, color)) {
        board[r][c] = GobangGame.empty;
        return WIN - depth * 10;
      }

      final score = -_negamax(board, depth + 1, -beta, -alpha);
      board[r][c] = GobangGame.empty;

      if (score > best) best = score;
      if (score > alpha) alpha = score;
      if (alpha >= beta) return alpha;
    }

    return best;
  }

  // ========== 候选点获取 ==========

  bool _isEmptyBoard(List<List<int>> board) {
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (board[r][c] != GobangGame.empty) return false;
      }
    }
    return true;
  }

  List<List<int>> _getCandidates(List<List<int>> board) {
    final Set<String> seen = {};
    final candidates = <List<int>>[];

    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (board[r][c] != GobangGame.empty) continue;
        // 检查2格范围内是否有棋子
        if (!_hasNeighbor(board, r, c, 2)) continue;

        final key = '$r,$c';
        if (seen.add(key)) candidates.add([r, c]);
      }
    }
    return candidates;
  }

  bool _hasNeighbor(List<List<int>> board, int row, int col, int dist) {
    for (int dr = -dist; dr <= dist; dr++) {
      for (int dc = -dist; dc <= dist; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = row + dr, nc = col + dc;
        if (_inBounds(nr, nc) && board[nr][nc] != GobangGame.empty) return true;
      }
    }
    return false;
  }

  void _sortCandidates(List<List<int>> candidates, List<List<int>> board) {
    final scored = <_ScoredPos>[];
    for (final pos in candidates) {
      final r = pos[0], c = pos[1];
      int s = _pointScore(board, r, c, aiColor) * 2;
      s += _pointScore(board, r, c, opponentColor);
      s += (7 - (r - 7).abs()) + (7 - (c - 7).abs());
      scored.add(_ScoredPos(r, c, s));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    candidates.clear();
    for (final sp in scored) {
      candidates.add([sp.r, sp.c]);
    }
  }

  // ========== 单点评分（用于排序）==========

  int _pointScore(List<List<int>> board, int row, int col, int color) {
    int score = 0;
    const dirs = [[0, 1], [1, 0], [1, 1], [1, -1]];
    for (final d in dirs) {
      score += _scoreDirection(board, row, col, d[0], d[1], color);
    }
    return score;
  }

  int _scoreDirection(List<List<int>> board, int row, int col, int dr, int dc, int color) {
    int count = 1;
    int openEnds = 0;

    // 正方向
    int r = row + dr, c = col + dc;
    while (_inBounds(r, c) && board[r][c] == color) {
      count++;
      r += dr;
      c += dc;
    }
    if (_inBounds(r, c) && board[r][c] == GobangGame.empty) openEnds++;

    // 反方向
    r = row - dr;
    c = col - dc;
    while (_inBounds(r, c) && board[r][c] == color) {
      count++;
      r -= dr;
      c -= dc;
    }
    if (_inBounds(r, c) && board[r][c] == GobangGame.empty) openEnds++;

    if (count >= 5) return 100000;
    if (count == 4) {
      if (openEnds == 2) return 10000;   // 活四
      if (openEnds == 1) return 1000;    // 冲四
      return 100;
    }
    if (count == 3) {
      if (openEnds == 2) return 1000;    // 活三
      if (openEnds == 1) return 100;     // 眠三
      return 10;
    }
    if (count == 2) {
      if (openEnds == 2) return 100;     // 活二
      if (openEnds == 1) return 10;      // 眠二
      return 1;
    }
    if (count == 1 && openEnds == 2) return 10;
    return 0;
  }

  // ========== 全局评估 ==========

  int _evaluateBoard(List<List<int>> board) {
    int score = 0;

    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (board[r][c] == aiColor) {
          score += (_pointEval(board, r, c, aiColor) * 12) ~/ 10; // 进攻权重 1.2x
        } else if (board[r][c] == opponentColor) {
          score -= _pointEval(board, r, c, opponentColor); // 防守 1.0x
        }
      }
    }
    return score;
  }

  int _pointEval(List<List<int>> board, int row, int col, int color) {
    int score = 0;
    const dirs = [[0, 1], [1, 0], [1, 1], [1, -1]];
    for (final d in dirs) {
      // 只从正向统计，避免重复
      final br = row - d[0], bc = col - d[1];
      if (_inBounds(br, bc) && board[br][bc] == color) continue;
      score += _evalDirection(board, row, col, d[0], d[1], color);
    }
    return score;
  }

  int _evalDirection(List<List<int>> board, int row, int col, int dr, int dc, int color) {
    int count = 1;
    int openEnds = 0;
    bool blocked = false;

    // 正方向
    int r = row + dr, c = col + dc;
    while (_inBounds(r, c) && board[r][c] == color) { count++; r += dr; c += dc; }
    if (_inBounds(r, c) && board[r][c] == GobangGame.empty) openEnds++;
    else blocked = true;

    // 反方向
    r = row - dr; c = col - dc;
    while (_inBounds(r, c) && board[r][c] == color) { count++; r -= dr; c -= dc; }
    if (_inBounds(r, c) && board[r][c] == GobangGame.empty) openEnds++;
    else blocked = true;

    if (count >= 5) return 100000;
    if (count == 4) {
      if (openEnds == 2) return 5000;    // 活四
      if (openEnds == 1) return 500;     // 冲四
      if (blocked) return 50;            // 死四
      return 0;
    }
    if (count == 3) {
      if (openEnds == 2) return 500;     // 活三
      if (openEnds == 1) return 50;      // 眠三（可能发展）
      return 5;
    }
    if (count == 2) {
      if (openEnds == 2) return 50;      // 活二
      if (openEnds == 1) return 5;
      return 1;
    }
    return 0;
  }

  // ========== 胜负判断 ==========

  bool _checkWinAtBoard(List<List<int>> board, int color) {
    const dirs = [[0, 1], [1, 0], [1, 1], [1, -1]];
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (board[r][c] != color) continue;
        for (final d in dirs) {
          int cnt = 1;
          int nr = r + d[0], nc = c + d[1];
          while (_inBounds(nr, nc) && board[nr][nc] == color) { cnt++; nr += d[0]; nc += d[1]; }
          nr = r - d[0]; nc = c - d[1];
          while (_inBounds(nr, nc) && board[nr][nc] == color) { cnt++; nr -= d[0]; nc -= d[1]; }
          if (cnt >= 5) return true;
        }
      }
    }
    return false;
  }

  bool _inBounds(int r, int c) =>
      r >= 0 && r < boardSize && c >= 0 && c < boardSize;
}

class _ScoredPos {
  final int r, c, score;
  _ScoredPos(this.r, this.c, this.score);
}
