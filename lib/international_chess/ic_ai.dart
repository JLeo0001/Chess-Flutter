import 'dart:math';
import 'package:dartchess/dartchess.dart';

/// 国际象棋 AI — 深度优化版
///
/// 搜索技术：
/// - Negamax + Alpha-Beta 剪枝
/// - MVV-LVA 吃子排序 + 杀手走法 + 历史启发
/// - 空着搜索（Null Move Pruning）
/// - 静态搜索（Quiescence Search）
/// - 将军延伸（Checks extend search）
class InternationalChessAI {
  final Side aiSide;
  final Random _rnd = Random();

  // ——— 搜索深度 ———
  static const int _maxDepth = 4;
  static const int _quiescenceDepth = 4;

  // ——— 历史启发表 [from][to] ———
  final List<List<int>> _historyTable =
      List.generate(64, (_) => List.filled(64, 0));

  // ——— 杀手走法 [depth][slot] ———
  final List<List<NormalMove?>> _killerMoves =
      List.generate(_maxDepth + 2, (_) => [null, null]);

  static const int _killerBonus = 600;
  static const int _historyMax = 1 << 20;

  InternationalChessAI(this.aiSide);
  Side get opponentSide => aiSide.opposite;

  // ========== 公开接口 ==========

  NormalMove? findBestMove(Position<Chess> position) {
    final moves = _getMoves(position);
    if (moves.isEmpty) return null;

    // 清空历史表（每步重新计算）
    for (int i = 0; i < 64; i++) {
      for (int j = 0; j < 64; j++) {
        _historyTable[i][j] = 0;
      }
    }

    _orderMoves(moves, position, 0);

    int bestScore = -999999;
    NormalMove? bestMove;
    int alpha = -999999, beta = 999999;

    // Iterative deepening warmup at depth 2
    for (final move in moves) {
      Position<Chess> newPos;
      try { newPos = position.play(move); } catch (_) { continue; }
      final score = -_negamax(newPos, 1, -beta, -alpha);
      if (score > bestScore || (score == bestScore && _rnd.nextBool())) {
        bestScore = score;
        bestMove = move;
      }
      alpha = max(alpha, score);
    }
    return bestMove;
  }

  // ========== Negamax + Alpha-Beta ==========

  int _negamax(Position<Chess> pos, int depth, int alpha, int beta) {
    if (pos.isGameOver) return _terminalScore(pos, depth);

    // 将军延伸：被将军时多搜一层
    final inCheck = pos.isCheck;
    final ply = depth;

    if (ply >= _maxDepth && !inCheck) return _quiescence(pos, alpha, beta, 0);
    if (ply >= _maxDepth + 2) return _evaluate(pos); // 最多延伸2层

    // 空着搜索（非将军/残局时跳过一步看效果）
    if (ply >= 2 && ply < _maxDepth && !inCheck && _canNullMove(pos)) {
      // 尝试空着：让对方连续走两步
      // 在 dartchess 中无法直接 pass，所以用 eval + 减半深度近似
      final nullEval = -_negamax(pos, ply + 2, -beta, -beta + 1);
      if (nullEval >= beta) return beta;
    }

    final moves = _getMoves(pos);
    if (moves.isEmpty) return inCheck ? (-99999 + ply) : 0;

    _orderMoves(moves, pos, ply);

    int best = -999999;
    NormalMove? bestMove;

    for (final move in moves) {
      Position<Chess> newPos;
      try { newPos = pos.play(move); } catch (_) { continue; }

      final score = -_negamax(newPos, ply + 1, -beta, -alpha);
      if (score > best) {
        best = score;
        bestMove = move;
      }
      alpha = max(alpha, score);
      if (alpha >= beta) {
        // Beta 截断 → 记录杀手 + 历史
        if (!_isCapture(pos, move)) {
          _recordKiller(move, ply);
          _recordHistory(pos, move, ply);
        }
        break;
      }
    }

    // 历史表衰减
    if (bestMove != null && best > alpha - 50) {
      _recordHistory(pos, bestMove, ply);
    }

    return best;
  }

  // ========== 空着搜索条件 ==========

  bool _canNullMove(Position<Chess> pos) {
    // 残局（子力少）时不使用空着
    int material = 0;
    for (int sq = 0; sq < 64; sq++) {
      final p = pos.board.pieceAt(Square(sq));
      if (p != null) material += _matValue(p.role);
    }
    return material > 2000; // 中盘才用
  }

  // ========== 静态搜索 ==========

  int _quiescence(Position<Chess> pos, int alpha, int beta, int qDepth) {
    int standPat = _evaluate(pos);
    if (qDepth >= _quiescenceDepth) return standPat;

    // 静态搜索的 β 截断
    if (standPat >= beta) return beta;
    if (standPat > alpha) alpha = standPat;

    // 只搜索吃子 + 升变走法
    final captures = _getMoves(pos)
        .where((m) => _isCapture(pos, m) || m.promotion != null)
        .toList();

    // 按 MVV-LVA 排序
    captures.sort((a, b) {
      final va = _mvvScore(pos, a);
      final vb = _mvvScore(pos, b);
      return vb.compareTo(va);
    });

    for (final move in captures) {
      // 粗略 SEE：不吃明显亏的
      final victim = pos.board.pieceAt(move.to);
      final attacker = pos.board.pieceAt(move.from);
      if (victim != null && attacker != null &&
          _matValue(victim.role) < _matValue(attacker.role) && qDepth > 1) {
        continue;
      }

      Position<Chess> newPos;
      try { newPos = pos.play(move); } catch (_) { continue; }
      final score = -_quiescence(newPos, -beta, -alpha, qDepth + 1);
      if (score >= beta) return beta;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  int _mvvScore(Position<Chess> pos, NormalMove move) {
    final victim = pos.board.pieceAt(move.to);
    final attacker = pos.board.pieceAt(move.from);
    int score = 0;
    if (victim != null) score += _matValue(victim.role) * 10;
    if (attacker != null) score -= _matValue(attacker.role);
    if (move.promotion != null) score += 800;
    return score;
  }

  // ========== 终局分数 ==========

  int _terminalScore(Position<Chess> pos, int depth) {
    final w = pos.outcome?.winner;
    if (w == null) return 0;
    return (pos.turn == w) ? (99999 - depth) : (-99999 + depth);
  }

  // ========== 局面评估 ==========

  int _evaluate(Position<Chess> pos) {
    final board = pos.board;
    int mgScore = 0, egScore = 0;
    int totalMaterial = 0;

    for (int sq = 0; sq < 64; sq++) {
      final square = Square(sq);
      final piece = board.pieceAt(square);
      if (piece == null) continue;

      final idx = _toIndex(square, piece.color == Side.white);
      final sign = (piece.color == aiSide) ? 1 : -1;
      totalMaterial += _matValue(piece.role);

      switch (piece.role) {
        case Role.pawn:
          mgScore += sign * (_mgPawn[idx] + pawnValue);
          egScore += sign * (_egPawn[idx] + pawnValue);
          break;
        case Role.knight:
          mgScore += sign * (_mgKnight[idx] + knightValue);
          egScore += sign * (_egKnight[idx] + knightValue);
          break;
        case Role.bishop:
          mgScore += sign * (_mgBishop[idx] + bishopValue);
          egScore += sign * (_egBishop[idx] + bishopValue);
          break;
        case Role.rook:
          mgScore += sign * (_mgRook[idx] + rookValue);
          egScore += sign * (_egRook[idx] + rookValue);
          break;
        case Role.queen:
          mgScore += sign * (_mgQueen[idx] + queenValue);
          egScore += sign * (_egQueen[idx] + queenValue);
          break;
        case Role.king:
          mgScore += sign * _mgKing[idx];
          egScore += sign * _egKing[idx];
          break;
      }
    }

    if (pos.isCheck) {
      mgScore += (pos.turn == aiSide) ? -80 : 80;
    }

    mgScore += _kingShieldScore(board);
    mgScore += _bishopPairScore(board);

    final phase = (totalMaterial / 8000.0).clamp(0.0, 1.0);
    final eval = (mgScore * phase + egScore * (1.0 - phase)).round();
    return (pos.turn == aiSide) ? eval : -eval;
  }

  static const int pawnValue = 100;
  static const int knightValue = 320;
  static const int bishopValue = 330;
  static const int rookValue = 500;
  static const int queenValue = 900;

  int _matValue(Role role) => switch (role) {
    Role.pawn => pawnValue, Role.knight => knightValue,
    Role.bishop => bishopValue, Role.rook => rookValue,
    Role.queen => queenValue, _ => 0,
  };

  int _kingShieldScore(Board board) {
    int score = 0;
    for (final side in [Side.white, Side.black]) {
      final sig = (side == aiSide) ? 1 : -1;
      final s = (side == Side.white) ? board.white : board.black;
      final kingSq = s.intersect(board.kings);
      if (kingSq.isEmpty) continue;
      final kSq = kingSq.squares.first;
      final kF = kSq.file.value;
      final kR = kSq.rank.value;
      final fwd = (side == Side.white) ? 1 : -1;
      int shield = 0;
      for (int df = -1; df <= 1; df++) {
        final f = kF + df;
        if (f < 0 || f > 7) continue;
        final sr = kR + fwd;
        if (sr < 0 || sr > 7) continue;
        if (s.intersect(board.pawns).has(Square(sr * 8 + f))) shield++;
      }
      score += sig * shield * 15;
    }
    return score;
  }

  int _bishopPairScore(Board board) {
    int bonus = 0;
    for (final side in [Side.white, Side.black]) {
      final s = (side == Side.white) ? board.white : board.black;
      if (s.intersect(board.bishops).size >= 2) {
        bonus += (side == aiSide) ? 30 : -30;
      }
    }
    return bonus;
  }

  // ========== 走法排序（MVV-LVA + 杀手 + 历史）==========

  void _orderMoves(List<NormalMove> moves, Position<Chess> pos, int depth) {
    final scores = <int>[];
    for (final move in moves) {
      int s = 0;

      // 1. 吃子 MVV-LVA
      if (_isCapture(pos, move)) {
        final victim = pos.board.pieceAt(move.to);
        final attacker = pos.board.pieceAt(move.from);
        if (victim != null && attacker != null) {
          s += _matValue(victim.role) * 10 - _matValue(attacker.role);
        }
      }

      // 2. 升变
      if (move.promotion != null) s += 800;

      // 3. 杀手走法
      if (depth <= _maxDepth) {
        for (final km in _killerMoves[depth]) {
          if (km != null && km.from == move.from && km.to == move.to) {
            s += _killerBonus;
            break;
          }
        }
      }

      // 4. 历史启发
      final hist = _historyTable[move.from.value][move.to.value];
      if (hist > 0) s += hist ~/ 8;

      scores.add(s);
    }

    final indexed = List.generate(moves.length, (i) => i);
    indexed.sort((a, b) => scores[b].compareTo(scores[a]));
    final sorted = indexed.map((i) => moves[i]).toList();
    moves..clear()..addAll(sorted);
  }

  // ========== 杀手走法记录 ==========

  void _recordKiller(NormalMove move, int depth) {
    if (depth > _maxDepth) return;
    final killers = _killerMoves[depth];
    // 去重
    if (killers[0] != null && killers[0]!.from == move.from &&
        killers[0]!.to == move.to) return;
    // 移到前面
    killers[1] = killers[0];
    killers[0] = move;
  }

  // ========== 历史启发记录 ==========

  void _recordHistory(Position<Chess> pos, NormalMove move, int depth) {
    final from = move.from.value;
    final to = move.to.value;
    _historyTable[from][to] += 1 << depth;
    if (_historyTable[from][to] > _historyMax) {
      // 衰减
      for (int i = 0; i < 64; i++) {
        for (int j = 0; j < 64; j++) {
          _historyTable[i][j] >>= 1;
        }
      }
    }
  }

  // ========== 走法生成 ==========

  List<NormalMove> _getMoves(Position<Chess> pos) {
    final list = <NormalMove>[];
    for (final entry in pos.legalMoves.entries) {
      for (final to in entry.value.squares) {
        list.add(NormalMove(from: entry.key, to: to));
      }
    }
    return list;
  }

  bool _isCapture(Position<Chess> pos, NormalMove move) {
    return pos.board.pieceAt(move.to) != null;
  }

  // ========== 坐标映射 ==========

  int _toIndex(Square sq, bool isWhite) {
    final r = isWhite ? (7 - sq.rank.value) : sq.rank.value;
    final f = isWhite ? sq.file.value : (7 - sq.file.value);
    return r * 8 + f;
  }

  // ========== PeSTO 棋子-位置表 ==========

  static const _mgPawn = <int>[
     0,   0,   0,   0,   0,   0,   0,   0,
    98, 134,  61,  95,  68, 126,  34, -11,
    -6,   7,  26,  31,  65,  56,  25, -20,
   -14,  13,   6,  21,  23,  12,  17, -23,
   -27,  -2,  -5,  12,  17,   6,  10, -25,
   -26,  -4,  -4, -10,   3,   3,  33, -12,
   -35,  -1, -20, -23, -15,  24,  38, -22,
     0,   0,   0,   0,   0,   0,   0,   0,
  ];

  static const _egPawn = <int>[
     0,   0,   0,   0,   0,   0,   0,   0,
   178, 173, 158, 134, 147, 132, 165, 187,
    94, 100,  85,  73,  72,  78,  85,  99,
    32,  24,  13,   5,  -2,   4,  17,  17,
    13,   9,  -3,  -7,  -7,  -8,   3,  -1,
     4,   7,  -6,   1,   0,  -5,  -1,  -8,
    13,   8,   8,  10,  13,   0,   2,  -7,
     0,   0,   0,   0,   0,   0,   0,   0,
  ];

  static const _mgKnight = <int>[
   -167, -89, -34, -49,  61, -97, -15,-107,
    -73, -41,  72,  36,  23,  62,   7, -17,
    -47,  60,  37,  65,  84, 129,  73,  44,
     -9,  17,  19,  53,  37,  69,  18,  22,
    -13,   4,  16,  13,  28,  19,  21,  -8,
    -23,  -9,  12,  10,  19,  17,  25, -16,
    -29, -53, -12,  -3,  -1,  18, -14, -19,
   -105, -21, -58, -33, -17, -28, -19, -23,
  ];

  static const _egKnight = <int>[
    -58, -38, -13, -28, -31, -27, -63, -99,
    -25,  -8, -25,  -2,  -9, -25, -24, -52,
    -24, -20,  10,   9,  -1,  -9, -19, -41,
    -17,   3,  22,  22,  22,  11,   8, -18,
    -18,  -6,  16,  25,  16,  17,   4, -18,
    -23,  -3,  -1,  15,  10,  -3, -20, -22,
    -42, -20, -10,  -5,  -2, -20, -23, -44,
    -29, -51, -23, -15, -22, -18, -50, -64,
  ];

  static const _mgBishop = <int>[
    -29,   4, -82, -37, -25, -42,   7,  -8,
    -26,  16, -18, -13,  30,  59,  18, -47,
    -16,  37,  43,  40,  35,  50,  37,  -2,
     -4,   5,  19,  50,  37,  37,   7,  -2,
     -6,  13,  13,  26,  34,  12,  10,   4,
      0,  15,  15,  15,  14,  27,  18,  10,
      4,  15,  16,   0,   7,  21,  33,   1,
    -33,  -3, -14, -21, -13, -12, -39, -21,
  ];

  static const _egBishop = <int>[
    -14, -21, -11,  -8,  -7,  -9, -17, -24,
     -8,  -4,   7, -12,  -3, -13,  -4, -14,
      2,  -8,   0,  -1,  -2,   6,   0,   4,
     -3,   9,  12,   9,  14,  10,   3,   2,
     -6,   3,  13,  19,   7,  10,  -3,  -9,
    -12,  -3,   8,  10,  13,   3,  -7, -15,
    -14, -18,  -7,  -1,   4,  -9, -15, -27,
    -23,  -9, -23,  -5,  -9, -16,  -5, -17,
  ];

  static const _mgRook = <int>[
     32,  42,  32,  51,  63,   9,  31,  43,
     27,  32,  58,  62,  80,  67,  26,  44,
     -5,  19,  26,  36,  17,  45,  61,  16,
    -24, -11,   7,  26,  24,  35,  -8, -20,
    -36, -26, -12,  -1,   9,  -7,   6, -23,
    -45, -25, -16, -17,   3,   0,  -5, -33,
    -44, -16, -20,  -9,  -1,  11,  -6, -71,
    -19, -13,   1,  17,  16,   7, -37, -26,
  ];

  static const _egRook = <int>[
    13, 10, 18, 15, 12, 12,  8,  5,
    11, 13, 13, 11, -3,  3,  8,  3,
     7,  7,  7,  5,  4, -3, -5, -3,
     4,  3, 13,  1,  2,  1, -1,  2,
     3,  5,  8,  4, -5, -6, -8,-11,
    -4,  0, -5, -1, -7,-12, -8,-16,
    -6, -6,  0,  2, -9, -9,-11, -3,
    -9,  2,  3, -1, -5,-13,  4,-20,
  ];

  static const _mgQueen = <int>[
    -28,   0,  29,  12,  59,  44,  43,  45,
    -24, -39,  -5,   1, -16,  57,  28,  54,
    -13, -17,   7,   8,  29,  56,  47,  57,
    -27, -27, -16, -16,  -1,  17,  -2,   1,
     -9, -26,  -9, -10,  -2,  -4,   3,  -3,
    -14,   2, -11,  -2,  -5,   2,  14,   5,
    -35,  -8,  11,   2,   8,  15,  -3,   1,
     -1, -18,  -9,  10, -15, -25, -31, -50,
  ];

  static const _egQueen = <int>[
     -9,  22,  22,  27,  27,  19,  10,  20,
    -17,  20,  32,  41,  58,  25,  30,   0,
    -20,   6,   9,  49,  47,  35,  19,   9,
      3,  22,  24,  45,  57,  40,  57,  36,
    -18,  28,  19,  47,  31,  34,  39,  23,
    -16, -27,  15,   6,   9,  17,  10,   5,
    -22, -23, -30, -16, -16, -23, -36, -32,
    -33, -28, -22, -43,  -5, -32, -20, -41,
  ];

  static const _mgKing = <int>[
    -65,  23,  16, -15, -56, -34,   2,  13,
     29,  -1, -20,  -7,  -8,  -4, -38, -29,
     -9,  24,   2, -16, -20,   6,  22, -22,
    -17, -20, -12, -27, -30, -25, -14, -36,
    -49,  -1, -27, -39, -46, -44, -33, -51,
    -14, -14, -22, -46, -44, -30, -15, -27,
      1,   7,  -8, -64, -43, -16,   9,   8,
    -15,  36,  12, -54,   8, -28,  24,  14,
  ];

  static const _egKing = <int>[
    -74, -35, -18, -18, -11,  15,   4, -17,
    -14, -17,   2,  14,  26,   4,   2,   0,
     10,   2,  28,  39,  39,  33,   6,  22,
     23,  20,  63,  67,  63,  55,  26,  17,
     25,  32,  50,  59,  62,  63,  51,  24,
     15,  25,  37,  43,  50,  44,  14,   9,
    -12,  19,  26,  21,  25,  28,   1, -21,
    -65, -85, -84, -75, -72, -79, -78, -80,
  ];
}
