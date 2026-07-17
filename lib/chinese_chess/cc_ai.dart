import 'dart:math';
import 'cc_game.dart';

/// 中国象棋 AI — 深度优化版
///
/// 搜索技术：
/// - Negamax + Alpha-Beta 剪枝
/// - 吃子排序 + 杀手走法 + 历史启发
/// - 空着搜索（Null Move Pruning）
/// - 静态搜索（只搜吃子）
/// - 将军延伸
class ChineseChessAI {
  static const int kingV = 10000;
  static const int rookV = 600;
  static const int cannonV = 285;
  static const int knightV = 270;
  static const int bishopV = 120;
  static const int advisorV = 120;
  static const int pawnV = 30;
  static const int crossedPawnV = 80;

  static const int _maxDepth = 4;
  static const int _qDepth = 4;

  final int _aiColor;
  final Random _rnd = Random();

  // ——— 历史启发表 [from_r][from_c][to_r][to_c] ———
  // 使用一维映射: idx = ((r*9+c)*10 + tr)*9 + tc
  final Map<int, int> _historyTable = {};

  // ——— 杀手走法 [depth][slot] ———
  final List<List<_KillerKey>> _killers =
      List.generate(_maxDepth + 2, (_) => List.filled(2, _KillerKey(-1, -1, -1, -1)));

  static const int _killerBonus = 500;
  static const int _historyMax = 1 << 16;

  ChineseChessAI(this._aiColor);

  int get _oppColor =>
      _aiColor == ChineseChessGame.red ? ChineseChessGame.black : ChineseChessGame.red;

  // ========== 公开接口 ==========

  List<int>? findBestMove(ChineseChessGame game) {
    _historyTable.clear();
    // 重置杀手表
    for (int d = 0; d <= _maxDepth + 1; d++) {
      _killers[d] = [_KillerKey(-1, -1, -1, -1), _KillerKey(-1, -1, -1, -1)];
    }

    final allMoves = <_ScoredMove>[];
    int alpha = -999999, beta = 999999;

    for (int r = 0; r < ChineseChessGame.rows; r++) {
      for (int c = 0; c < ChineseChessGame.cols; c++) {
        final piece = game.board[r][c];
        if (piece == ChineseChessGame.empty) continue;
        if (ChineseChessGame.getColor(piece) != game.currentPlayer) continue;

        for (final m in game.getLegalMoves(r, c)) {
          final tr = m[0], tc = m[1];
          if (!game.move(r, c, tr, tc)) continue;

          final score = -_negamax(game, 1, -beta, -alpha);
          game.undo();

          allMoves.add(_ScoredMove(r, c, tr, tc, score));
          if (score > alpha) alpha = score;
        }
      }
    }

    if (allMoves.isEmpty) return null;

    allMoves.sort((a, b) {
      int cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      final aCap = game.board[a.tr][a.tc] != ChineseChessGame.empty ? 1 : 0;
      final bCap = game.board[b.tr][b.tc] != ChineseChessGame.empty ? 1 : 0;
      return bCap.compareTo(aCap);
    });

    final topScore = allMoves[0].score;
    final topMoves = allMoves.where((m) => m.score >= topScore - 20).toList();
    final chosen = topMoves[_rnd.nextInt(topMoves.length)];
    return [chosen.fr, chosen.fc, chosen.tr, chosen.tc];
  }

  // ========== Negamax + Alpha-Beta ==========

  int _negamax(ChineseChessGame game, int depth, int alpha, int beta) {
    if (game.isGameOver) return -99999 + depth * 10;

    final inCheck = game.isInCheck(game.currentPlayer);
    final ply = depth;

    if (ply >= _maxDepth && !inCheck) return _quiescence(game, alpha, beta, 0);
    if (ply >= _maxDepth + 2) return _evaluate(game);

    // 空着搜索（非将军/残局）
    if (ply >= 2 && ply < _maxDepth && !inCheck && _canNullMove(game)) {
      // 近似空着：用减半深度的评估模拟空着
      final nullVal = -_negamax(game, depth + 2, -beta, -beta + 1);
      if (nullVal >= beta) return beta;
    }

    // 收集走法
    final moves = <_RawMove>[];
    for (int r = 0; r < ChineseChessGame.rows; r++) {
      for (int c = 0; c < ChineseChessGame.cols; c++) {
        final piece = game.board[r][c];
        if (piece == ChineseChessGame.empty) continue;
        if (ChineseChessGame.getColor(piece) != game.currentPlayer) continue;

        for (final m in game.getLegalMoves(r, c)) {
          final tr = m[0], tc = m[1];
          final target = game.board[tr][tc];
          moves.add(_RawMove(r, c, tr, tc, target));
        }
      }
    }

    if (moves.isEmpty) return -99999 + ply * 10;

    // 走法排序
    _sortMoves(moves, ply);

    int best = -999999;
    _RawMove? bestMove;

    for (final m in moves) {
      if (!game.move(m.fr, m.fc, m.tr, m.tc)) continue;
      final score = -_negamax(game, depth + 1, -beta, -alpha);
      game.undo();

      if (score > best) {
        best = score;
        bestMove = m;
      }
      alpha = max(alpha, score);
      if (alpha >= beta) {
        // Beta 截断 → 记录杀手 + 历史
        if (!m.isCapture) {
          _recordKiller(m, ply);
          _recordHistory(m, ply);
        }
        break;
      }
    }

    if (bestMove != null && best > alpha - 50) {
      _recordHistory(bestMove, ply);
    }

    return best;
  }

  // ========== 空着搜索条件 ==========

  bool _canNullMove(ChineseChessGame game) {
    int material = 0;
    for (int r = 0; r < ChineseChessGame.rows; r++) {
      for (int c = 0; c < ChineseChessGame.cols; c++) {
        final p = game.board[r][c];
        if (p == ChineseChessGame.empty) continue;
        if (ChineseChessGame.getType(p) != ChineseChessGame.king) {
          material += _pieceMaterial(p);
        }
      }
    }
    return material > 1500; // 中盘才用
  }

  // ========== 静态搜索（只搜吃子）==========

  int _quiescence(ChineseChessGame game, int alpha, int beta, int depth) {
    if (depth >= _qDepth) return _evaluate(game);

    int standPat = _evaluate(game);
    if (standPat >= beta) return beta;
    if (standPat > alpha) alpha = standPat;

    // 只搜索吃子走法
    final captures = <_RawMove>[];
    for (int r = 0; r < ChineseChessGame.rows; r++) {
      for (int c = 0; c < ChineseChessGame.cols; c++) {
        final piece = game.board[r][c];
        if (piece == ChineseChessGame.empty) continue;
        if (ChineseChessGame.getColor(piece) != game.currentPlayer) continue;

        for (final m in game.getLegalMoves(r, c)) {
          final tr = m[0], tc = m[1];
          final target = game.board[tr][tc];
          if (target != ChineseChessGame.empty) {
            captures.add(_RawMove(r, c, tr, tc, target));
          }
        }
      }
    }

    captures.sort((a, b) => _pieceMaterial(b.target).compareTo(_pieceMaterial(a.target)));

    for (final m in captures) {
      if (!game.move(m.fr, m.fc, m.tr, m.tc)) continue;
      final score = -_quiescence(game, -beta, -alpha, depth + 1);
      game.undo();
      if (score >= beta) return beta;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  // ========== 走法排序（吃子 + 杀手 + 历史）==========

  void _sortMoves(List<_RawMove> moves, int depth) {
    for (final m in moves) {
      int s = 0;

      // 1. 吃子（MVV）
      if (m.isCapture) {
        s += _pieceMaterial(m.target) + 1000;
      }

      // 2. 杀手走法
      if (depth <= _maxDepth) {
        for (final km in _killers[depth]) {
          if (km.matches(m)) {
            s += _killerBonus;
            break;
          }
        }
      }

      // 3. 历史启发
      final hist = _historyTable[_histKey(m)] ?? 0;
      if (hist > 0) s += hist ~/ 6;

      m.score = s;
    }
    moves.sort((a, b) => b.score.compareTo(a.score));
  }

  // ========== 杀手走法记录 ==========

  void _recordKiller(_RawMove m, int depth) {
    if (depth > _maxDepth) return;
    final killers = _killers[depth];
    // 去重
    if (killers[0].matches(m)) return;
    killers[1] = killers[0];
    killers[0] = _KillerKey(m.fr, m.fc, m.tr, m.tc);
  }

  // ========== 历史启发记录 ==========

  int _histKey(_RawMove m) =>
      ((m.fr * 9 + m.fc) * 10 + m.tr) * 9 + m.tc;

  void _recordHistory(_RawMove m, int depth) {
    final key = _histKey(m);
    final newVal = (_historyTable[key] ?? 0) + (1 << depth);
    _historyTable[key] = newVal;
    if (newVal > _historyMax) {
      // 衰减
      for (final k in _historyTable.keys.toList()) {
        final v = (_historyTable[k] ?? 0) >> 1;
        if (v == 0) {
          _historyTable.remove(k);
        } else {
          _historyTable[k] = v;
        }
      }
    }
  }

  // ========== 子力价值 ==========

  int _pieceMaterial(int piece) {
    final type = ChineseChessGame.getType(piece);
    switch (type) {
      case ChineseChessGame.king: return 10000;
      case ChineseChessGame.rook: return 600;
      case ChineseChessGame.cannon: return 285;
      case ChineseChessGame.knight: return 270;
      case ChineseChessGame.bishop: return 120;
      case ChineseChessGame.advisor: return 120;
      case ChineseChessGame.pawn: return 30;
      default: return 0;
    }
  }

  // ========== 局面评估 ==========

  int _evaluate(ChineseChessGame game) {
    if (game.isGameOver) return game.winner == _aiColor ? 99999 : -99999;

    final board = game.board;
    final flipped = game.isFlipped;
    int score = 0;

    for (int r = 0; r < ChineseChessGame.rows; r++) {
      for (int c = 0; c < ChineseChessGame.cols; c++) {
        final piece = board[r][c];
        if (piece == ChineseChessGame.empty) continue;

        final color = ChineseChessGame.getColor(piece);
        final type = ChineseChessGame.getType(piece);
        final sign = (color == _aiColor) ? 1 : -1;

        score += sign * _pieceValue(type, color, r, flipped);
        score += sign * _positionBonus(type, color, r, c, flipped);
      }
    }

    // 将军
    if (game.isInCheck(_aiColor)) score -= 100;
    if (game.isInCheck(_oppColor)) score += 100;

    // 简单威胁
    score += _simpleThreat(game);

    // 困毙
    if (game.isCheckmate(_oppColor)) score += 50000;

    return score;
  }

  /// 简化的威胁评分
  int _simpleThreat(ChineseChessGame game) {
    int bonus = 0;
    const dirs = [
      [-1, 0], [1, 0], [0, -1], [0, 1],
      [-1, -1], [-1, 1], [1, -1], [1, 1]
    ];
    final board = game.board;

    for (int r = 0; r < ChineseChessGame.rows; r++) {
      for (int c = 0; c < ChineseChessGame.cols; c++) {
        final piece = board[r][c];
        if (piece == ChineseChessGame.empty) continue;
        if (ChineseChessGame.getColor(piece) != _aiColor) continue;

        for (final d in dirs) {
          final nr = r + d[0], nc = c + d[1];
          if (nr < 0 || nr >= ChineseChessGame.rows || nc < 0 || nc >= ChineseChessGame.cols) continue;
          final target = board[nr][nc];
          if (target != ChineseChessGame.empty &&
              ChineseChessGame.getColor(target) != _aiColor) {
            bonus += _pieceMaterial(target) * 3 ~/ 10;
          }
        }
      }
    }
    return bonus ~/ 3;
  }

  // ========== 子力价值 ==========

  int _pieceValue(int type, int color, int row, bool flipped) {
    switch (type) {
      case ChineseChessGame.king: return kingV;
      case ChineseChessGame.rook: return rookV;
      case ChineseChessGame.cannon: return cannonV;
      case ChineseChessGame.knight: return knightV;
      case ChineseChessGame.bishop: return bishopV;
      case ChineseChessGame.advisor: return advisorV;
      case ChineseChessGame.pawn:
        final crossed = color == ChineseChessGame.red
            ? (flipped ? row >= 5 : row <= 4)
            : (flipped ? row <= 4 : row >= 5);
        return crossed ? crossedPawnV : pawnV;
      default: return 0;
    }
  }

  // ========== 位置加分 ==========

  int _positionBonus(int type, int color, int r, int c, bool flipped) {
    final nr = _toRedRow(r, color, flipped);
    final nc = _toRedCol(c, color);
    switch (type) {
      case ChineseChessGame.rook: return _rook[nr][nc];
      case ChineseChessGame.knight: return _knight[nr][nc];
      case ChineseChessGame.cannon: return _cannon[nr][nc];
      case ChineseChessGame.pawn: return _pawn[nr][nc];
      case ChineseChessGame.king: return _king[nr][nc];
      case ChineseChessGame.bishop: return _bishop[nr][nc];
      case ChineseChessGame.advisor: return _advisor[nr][nc];
      default: return 0;
    }
  }

  int _toRedRow(int r, int color, bool flipped) {
    if (color == ChineseChessGame.red) return flipped ? r : 9 - r;
    return flipped ? 9 - r : r;
  }

  int _toRedCol(int c, int color) {
    return color == ChineseChessGame.red ? c : 8 - c;
  }

  // ========== 位置表 ==========

  static const _rook = <List<int>>[
    [14,14,12,18,16,18,12,14,14],
    [16,20,18,24,26,24,18,20,16],
    [12,12,12,18,18,18,12,12,12],
    [12,18,16,22,22,22,16,18,12],
    [12,14,12,18,18,18,12,14,12],
    [12,16,14,20,20,20,14,16,12],
    [6,10,8,14,14,14,8,10,6],
    [4,8,6,14,12,14,6,8,4],
    [8,4,8,16,8,16,8,4,8],
    [-2,10,6,14,12,14,6,10,-2],
  ];

  static const _knight = <List<int>>[
    [4,8,16,12,4,12,16,8,4],
    [4,10,28,16,8,16,28,10,4],
    [12,14,16,20,18,20,16,14,12],
    [8,24,18,24,20,24,18,24,8],
    [6,16,14,18,16,18,14,16,6],
    [4,12,16,14,12,14,16,12,4],
    [2,6,8,6,10,6,8,6,2],
    [0,2,4,4,12,4,4,2,0],
    [2,-4,2,0,8,0,2,-4,2],
    [0,0,2,0,0,0,2,0,0],
  ];

  static const _cannon = <List<int>>[
    [6,4,0,-10,-12,-10,0,4,6],
    [2,2,0,-4,-14,-4,0,2,2],
    [2,2,0,-10,-8,-10,0,2,2],
    [0,0,-2,4,10,4,-2,0,0],
    [0,0,0,2,8,2,0,0,0],
    [-2,0,4,2,6,2,4,0,-2],
    [0,0,0,2,4,2,0,0,0],
    [4,0,8,6,10,6,8,0,4],
    [0,2,4,6,6,6,4,2,0],
    [0,0,2,6,6,6,2,0,0],
  ];

  static const _pawn = <List<int>>[
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0],
    [0,0,-20,0,20,0,-20,0,0],
    [0,0,0,20,30,20,0,0,0],
    [10,20,30,40,50,40,30,20,10],
    [15,30,40,50,60,50,40,30,15],
    [20,30,50,60,70,60,50,30,20],
    [20,30,50,70,80,70,50,30,20],
    [0,0,0,0,0,0,0,0,0],
  ];

  static const _king = <List<int>>[
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0],
    [2,4,4,0,0,0,4,4,2],
    [2,4,4,0,0,0,4,4,2],
    [2,4,4,0,-4,0,4,4,2],
  ];

  static const _bishop = <List<int>>[
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0],
    [0,0,20,0,0,0,20,0,0],
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0],
  ];

  static const _advisor = <List<int>>[
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0],
    [0,0,0,20,0,20,0,0,0],
    [0,0,0,0,22,0,0,0,0],
    [0,0,0,20,0,20,0,0,0],
  ];
}

class _ScoredMove {
  final int fr, fc, tr, tc, score;
  _ScoredMove(this.fr, this.fc, this.tr, this.tc, this.score);
}

class _RawMove {
  final int fr, fc, tr, tc, target;
  int score = 0;
  _RawMove(this.fr, this.fc, this.tr, this.tc, this.target);
  bool get isCapture => target != 0;
}

class _KillerKey {
  final int fr, fc, tr, tc;
  const _KillerKey(this.fr, this.fc, this.tr, this.tc);
  bool matches(_RawMove m) =>
      m.fr == fr && m.fc == fc && m.tr == tr && m.tc == tc;
}
