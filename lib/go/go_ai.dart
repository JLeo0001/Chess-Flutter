import 'dart:math';
import 'go_game.dart';

/// 围棋 AI — 混合架构
///
/// 汲取全网主流算法思路，四层打分：
/// ┌──────────────────────────────────────────────┐
/// │ 层1: 快速启发式初筛 (O(n), n=合法走法数)      │
/// │  提子/打吃/救子/眼检测/星位/随机               │
/// ├──────────────────────────────────────────────┤
/// │ 层2: 形状与连接 (O(n))                        │
/// │  好形加分（跳、飞、尖）、恶形扣分（空三角）     │
/// │  连接己方、切断对方、边线效率                   │
/// ├──────────────────────────────────────────────┤
/// │ 层3: 领地与厚薄 (O(n×regionCount))            │
/// │  Flood-fill 空域归属、死活嗅觉、厚势评价        │
/// ├──────────────────────────────────────────────┤
/// │ 层4: 一维危机反应 (O(topK × m))               │
/// │  对方打吃不应的惩罚、双方对杀的预判            │
/// └──────────────────────────────────────────────┘
class GoAi {
  final int aiColor;
  final int opponentColor;
  final int boardSize;
  final Random _rnd = Random();
  final bool _verbose;

  // ═══════════════ 权重表 ═══════════════

  // 层1: 基础
  static const int _capturePerStone = 400;
  static const int _atariBonus = 300; // 打吃（对方剩1气）
  static const int _reduceLibBonus3to2 = 150; // 紧气 3→2
  static const int _reduceLibBonus4to3 = 80; // 紧气 4→3
  static const int _saveFromAtari = 500; // 救己方脱离打吃
  static const int _selfDefense = 200; // 己方 1→2+ 气
  static const int _eyePenalty = -9999; // 填眼
  static const int _starPoint = 20;
  static const int _jitterRange = 5;

  // 层2: 形状
  static const int _connectBonus = 120; // 连接己方两块
  static const int _cutBonus = 250; // 切断对方
  static const int _emptyTriangle = -150; // 空三角恶形
  static const int _onePointJump = 60; // 跳
  static const int _diagonal = 40; // 飞/尖
  static const int _haneBonus = 80; // 扳
  static const int _thirdLineBonus = 15; // 三线（实地）
  static const int _fourthLineBonus = 10; // 四线（势力）

  // 层3: 领地
  static const int _influenceRadius = 5; // 影响半径
  static const int _influenceWeight = 8; // 影响分/格

  // 层4: 危机
  static const int _ignoreAtari = -400; // 对方打吃不回应
  static const int _semeaiBonus = 300; // 对杀主动

  GoAi(this.aiColor, this.boardSize, {bool verbose = false})
      : _verbose = verbose,
        opponentColor =
            (aiColor == GoGame.black) ? GoGame.white : GoGame.black;

  // ═══════════════ 主入口 ═══════════════

  List<int>? findBestMove(GoGame game) {
    final moves = game.validMoves(aiColor);
    if (moves.isEmpty) return null;
    if (moves.length == 1) return moves[0];

    // ── 层1: 对所有走法快速打分 ──
    final scores = <int>[];
    final snap = game.saveSnapshot();
    for (final m in moves) {
      scores.add(_basicScore(game, m[0], m[1]));
    }
    game.restoreSnapshot(snap);

    // 取 TopK 进入深度评估
    const int topK = 18;
    final indexed = List<int>.generate(moves.length, (i) => i);
    indexed.sort((a, b) => scores[b].compareTo(scores[a]));
    final topIndices = indexed.take(min(topK, indexed.length)).toList();
    final topCandidates =
        topIndices.map((i) => _Candidate(i, moves[i], scores[i])).toList();

    // ── 层2+3+4: 对 TopK 加权评估 ──
    for (final c in topCandidates) {
      int extra = 0;
      extra += _shapeScore(game, c.row, c.col);
      extra += _connectionCutScore(game, c.row, c.col);
      extra += _territoryInfluenceScore(game, c.row, c.col);
      extra += _crisisResponseScore(game, c.row, c.col, topCandidates);
      c.totalScore = c.basicScore + extra;
    }

    // 选最高分
    topCandidates.sort((a, b) => b.totalScore.compareTo(a.totalScore));
    final best = topCandidates.first;

    if (_verbose) {
      print('GoAI: ${moves.length} moves → '
          'top3: ${topCandidates.take(3).map((c) => '[${c.row},${c.col}] '
              'base=${c.basicScore} total=${c.totalScore}').join(', ')}');
    }

    // 同分随机
    final ties = topCandidates
        .where((c) => c.totalScore == best.totalScore)
        .toList();
    final picked = ties[_rnd.nextInt(ties.length)];
    return picked.move;
  }

  // ═══════════════ 层1: 基础启发式 ═══════════════

  int _basicScore(GoGame game, int row, int col) {
    if (game.isRealEye(row, col, aiColor)) return _eyePenalty;

    final snap = game.saveSnapshot();

    // 落子
    final capturedBefore = (aiColor == GoGame.black)
        ? game.capturedBlack
        : game.capturedWhite;
    if (!game.placeStone(row, col)) {
      game.restoreSnapshot(snap);
      return -99999;
    }
    final capturedAfter = (aiColor == GoGame.black)
        ? game.capturedBlack
        : game.capturedWhite;
    final captured = capturedAfter - capturedBefore;

    // 落子后检查四周
    int attack = 0, defend = 0;
    const dirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];
    for (final d in dirs) {
      final nr = row + d[0], nc = col + d[1];
      if (!game.inBounds(nr, nc)) continue;
      final piece = game.board[nr][nc];
      if (piece == opponentColor) {
        final libs = game.groupLibertiesCount(nr, nc);
        if (libs == 1) {
          attack += _atariBonus;
        } else if (libs == 2) {
          attack += _reduceLibBonus3to2;
        } else if (libs == 3) {
          attack += _reduceLibBonus4to3;
        }
      } else if (piece == aiColor) {
        final libs = game.groupLibertiesCount(nr, nc);
        if (libs >= 2) {
          // 不在打吃中 = 安全
          // 但如果落子前在打吃，现在不在 = 救活
        }
      }
    }

    // 检查己方是否脱离打吃：对比落子前自身的气
    // 用快照检查落子前该位置的连接组气数
    // 简化：如果落子前邻居己方组在打吃，落子后不在 = 救活
    // 但快照时 board 是落子前的，己方组在 snap.board 中计算
    for (final d in dirs) {
      final nr = row + d[0], nc = col + d[1];
      if (!game.inBounds(nr, nc)) continue;
      if (snap.board[nr][nc] == aiColor) {
        final beforeLibs = _countGroupLibs(snap.board, nr, nc);
        if (beforeLibs == 1) {
          final afterLibs = game.groupLibertiesCount(nr, nc);
          if (afterLibs >= 2) {
            defend += _saveFromAtari;
          }
        }
      }
    }

    // 自身安全度提升
    for (final d in dirs) {
      final nr = row + d[0], nc = col + d[1];
      if (!game.inBounds(nr, nc)) continue;
      if (snap.board[nr][nc] == aiColor) {
        final beforeLibs = _countGroupLibs(snap.board, nr, nc);
        if (beforeLibs == 2) {
          final afterLibs = game.groupLibertiesCount(nr, nc);
          if (afterLibs >= 3) defend += _selfDefense;
        }
      }
    }

    int score = captured * _capturePerStone + attack + defend;

    // 星位
    if (_isStarPosition(row, col)) {
      bool empty = true;
      for (int r = 0; r < boardSize && empty; r++) {
        for (int c = 0; c < boardSize && empty; c++) {
          if (game.board[r][c] != GoGame.empty) empty = false;
        }
      }
      if (empty) score += _starPoint;
    }

    // 随机
    score += _rnd.nextInt(_jitterRange * 2 + 1) - _jitterRange;

    game.restoreSnapshot(snap);
    return score;
  }

  // ═══════════════ 层2: 形状打分 ═══════════════

  int _shapeScore(GoGame game, int row, int col) {
    final board = game.board;
    int score = 0;

    // ── 空三角形检测 ──
    // 形状:   X .      . X      X X      . .
    //         X X      X X      X .      X X
    //  落子(●) 后形成空三角：
    //    X ● .  或  . X ●  等等
    //    X X .      X X .
    if (_isEmptyTriangle(board, row, col, aiColor)) {
      score += _emptyTriangle;
    }

    // ── 好形：跳、飞、尖 ──
    const dirs4 = [[-1, 0], [1, 0], [0, -1], [0, 1]]; // 四方向
    const diags = [[-1, -1], [-1, 1], [1, -1], [1, 1]];
    const jumps2 = [[-2, 0], [2, 0], [0, -2], [0, 2]];

    // 一路跳
    for (final d in dirs4) {
      final nr = row + d[0], nc = col + d[1];
      if (game.inBounds(nr, nc) && board[nr][nc] == aiColor) {
        // 相邻己子 = 不是跳，是贴
      }
    }
    // 二路跳（大跳/小跳）
    for (final d in jumps2) {
      final nr = row + d[0], nc = col + d[1];
      if (game.inBounds(nr, nc) && board[nr][nc] == aiColor) {
        // 检查中间无子
        final mr = row + d[0] ~/ 2, mc = col + d[1] ~/ 2;
        if (board[mr][mc] == GoGame.empty) {
          score += _onePointJump;
        }
      }
    }
    // 对角（飞/尖）
    for (final d in diags) {
      final nr = row + d[0], nc = col + d[1];
      if (game.inBounds(nr, nc) && board[nr][nc] == aiColor) {
        score += _diagonal;
      }
    }

    // ── 扳（Hane）──
    // 落子在对方棋子斜角且上下左右之一有其棋子
    for (final d in diags) {
      final nr = row + d[0], nc = col + d[1];
      if (game.inBounds(nr, nc) && board[nr][nc] == opponentColor) {
        // 检查对方棋子外侧是否有己方棋子（形成扳头）
        const wrap = {
          '(-1,-1)': [[0, -1], [-1, 0]],
          '(-1,1)': [[0, 1], [-1, 0]],
          '(1,-1)': [[0, -1], [1, 0]],
          '(1,1)': [[0, 1], [1, 0]],
        };
        final key = '(${d[0]},${d[1]})';
        final checks = wrap[key];
        if (checks != null) {
          for (final ck in checks) {
            final cx = nr + ck[0], cy = nc + ck[1];
            if (game.inBounds(cx, cy) && board[cx][cy] == aiColor) {
              score += _haneBonus;
              break;
            }
          }
        }
      }
    }

    // ── 边线效率 ──
    final distToEdge = [
      row, col, boardSize - 1 - row, boardSize - 1 - col
    ].reduce(min);
    if (distToEdge == 2) {
      score += _thirdLineBonus; // 三线
    } else if (distToEdge == 3) {
      score += _fourthLineBonus; // 四线
    }
    // 一路不鼓励（除非特殊情况）
    if (distToEdge == 0) score -= 30;
    if (distToEdge == 1) score -= 10;

    return score;
  }

  /// 检测空三角形
  bool _isEmptyTriangle(List<List<int>> board, int r, int c, int color) {
    bool inB(int rr, int cc) =>
        rr >= 0 && rr < boardSize && cc >= 0 && cc < boardSize;
    // 检查四种空三角模式
    const patterns = [
      [[0, 0], [1, 0], [0, 1]],
      [[0, 0], [1, 0], [0, -1]],
      [[0, 0], [-1, 0], [0, 1]],
      [[0, 0], [-1, 0], [0, -1]],
    ];
    for (final pat in patterns) {
      int count = 0;
      for (final p in pat) {
        final pr = r + p[0], pc = c + p[1];
        if (inB(pr, pc) && board[pr][pc] == color) count++;
      }
      if (count >= 2) {
        int total = count;
        for (final p in pat) {
          final pr = r + p[0], pc = c + p[1];
          if (inB(pr, pc) && board[pr][pc] == GoGame.empty) total++;
        }
        if (total >= 3 && count >= 2) return true;
      }
    }
    return false;
  }

  // ═══════════════ 层2: 连接/切断 ═══════════════

  int _connectionCutScore(GoGame game, int row, int col) {
    final board = game.board;
    int score = 0;

    // ── 连接：落子后是否让多个己方组连通 ──
    // 数落子前四周有多少个独立己方组
    final ownGroups = <int>{};
    const dirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];
    for (final d in dirs) {
      final nr = row + d[0], nc = col + d[1];
      if (!game.inBounds(nr, nc) || board[nr][nc] != aiColor) continue;
      // 标记该组 ID（用组内最小位置做 ID）
      final groupId = _groupMinPos(board, nr, nc, boardSize);
      ownGroups.add(groupId);
    }
    if (ownGroups.length >= 2) {
      score += _connectBonus * (ownGroups.length - 1);
    }

    // ── 切断：落子后是否分离对方邻组的连接 ──
    // 检查落子前，两个对方棋子之间是否通过此位连通
    // 简化：如果落子前四周有2+个对方棋子的组，且它们相邻
    // 更精确的做法：列着对方棋子，看它们是否共享气
    final oppAdjGroups = <int>{};
    for (final d in dirs) {
      final nr = row + d[0], nc = col + d[1];
      if (!game.inBounds(nr, nc) || board[nr][nc] != opponentColor) continue;
      final groupId = _groupMinPos(board, nr, nc, boardSize);
      oppAdjGroups.add(groupId);
    }
    if (oppAdjGroups.length >= 2) {
      score += _cutBonus; // 切断两条龙
    } else if (oppAdjGroups.length == 1) {
      // 单组的情况下，检查是不是"断点"—对方两子对角位于落子周围
      //  对方  ?      ? 对方
      //  ? 落子 ?   ? 落子 ?
      //   ?    ?      ?    ?
      // 如果落子周围有对角位置的对方棋子，且它们属于同组
      // 这可能是一个断点
      const diags = [[-1, -1], [-1, 1], [1, -1], [1, 1]];
      for (final d in diags) {
        final nr = row + d[0], nc = col + d[1];
        if (game.inBounds(nr, nc) && board[nr][nc] == opponentColor) {
          // 斜对角有对方棋子，且其旁边有另一个对方棋子
          for (final d2 in dirs) {
            final nr2 = nr + d2[0], nc2 = nc + d2[1];
            if (nr2 == row && nc2 == col) continue;
            if (game.inBounds(nr2, nc2) && board[nr2][nc2] == opponentColor) {
              score += _cutBonus ~/ 2;
              break;
            }
          }
        }
      }
    }

    return score;
  }

  // ═══════════════ 层3: 领地与影响 ═══════════════

  int _territoryInfluenceScore(GoGame game, int row, int col) {
    // ── 简单领地嗅觉 ──
    // Flood-fill 周围的空域，判断所有权倾向
    int friendlyArea = 0, enemyArea = 0;

    final visited = <int>{};
    final queue = <int>[row * boardSize + col];

    while (queue.isNotEmpty && visited.length < 30) {
      final cur = queue.removeAt(0);
      if (visited.contains(cur)) continue;
      visited.add(cur);
      final cr = cur ~/ boardSize, cc = cur % boardSize;

      const dirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];
      for (final d in dirs) {
        final nr = cr + d[0], nc = cc + d[1];
        if (!game.inBounds(nr, nc)) continue;
        final key = nr * boardSize + nc;
        if (visited.contains(key)) continue;
        if (game.board[nr][nc] == aiColor) {
          friendlyArea++;
        } else if (game.board[nr][nc] == opponentColor) {
          enemyArea++;
        } else if (game.board[nr][nc] == GoGame.empty) {
          queue.add(key);
        }
      }
    }

    int score = 0;
    if (friendlyArea > enemyArea && friendlyArea > 2) {
      score += friendlyArea * 3; // 在己方势力范围内
    }
    if (enemyArea > friendlyArea && enemyArea > 2) {
      score -= enemyArea * 2; // 闯入对方地盘
    }

    // ── 简单厚势评价 ──
    // 落子位置附近己方棋子多且对方少 = 好
    int friendlyInRadius = 0, enemyInRadius = 0;
    for (int dr = -_influenceRadius; dr <= _influenceRadius; dr++) {
      for (int dc = -_influenceRadius; dc <= _influenceRadius; dc++) {
        final nr = row + dr, nc = col + dc;
        if (!game.inBounds(nr, nc)) continue;
        final dist = dr.abs() + dc.abs();
        if (dist > _influenceRadius) continue;
        final weight = _influenceRadius - dist + 1;
        if (game.board[nr][nc] == aiColor) {
          friendlyInRadius += weight;
        } else if (game.board[nr][nc] == opponentColor) {
          enemyInRadius += weight;
        }
      }
    }
    score += (friendlyInRadius - enemyInRadius) * _influenceWeight ~/ 10;

    return score;
  }

  // ═══════════════ 层4: 危机反应 ═══════════════

  int _crisisResponseScore(GoGame game, int row, int col,
      List<_Candidate> candidates) {
    final board = game.board;
    int score = 0;

    // ── 对方是否有即将被打吃的组 ──
    // 如果有且我们在下别处，扣分
    bool opponentInAtari = false;
    bool ownInAtari = false;

    const dirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (board[r][c] == opponentColor && game.isInAtari(r, c)) {
          opponentInAtari = true;
        }
        if (board[r][c] == aiColor && game.isInAtari(r, c)) {
          ownInAtari = true;
          // 当前的候选落子是否在救这块棋？
          for (final d in dirs) {
            final nr = row + d[0], nc = col + d[1];
            if (nr == r && nc == c) {
              // 直接落子在这个对方打吃的位置上？
            }
          }
        }
      }
    }

    // 对方有棋子被打吃，而我们不下在打吃位置 → 扣分
    if (opponentInAtari) {
      bool capturing = false;
      for (final d in dirs) {
        final nr = row + d[0], nc = col + d[1];
        if (!game.inBounds(nr, nc)) continue;
        if (board[nr][nc] == opponentColor && game.isInAtari(nr, nc)) {
          capturing = true;
          break;
        }
      }
      if (!capturing && _isMoveUrgent) {
        score += _ignoreAtari; // 该吃的不吃
      }
    }

    // ── 己方有棋被打吃 ──
    if (ownInAtari) {
      bool defending = false;
      for (final d in dirs) {
        final nr = row + d[0], nc = col + d[1];
        if (!game.inBounds(nr, nc)) continue;
        if (board[nr][nc] == aiColor && game.isInAtari(nr, nc)) {
          defending = true;
          break;
        }
      }
      if (!defending) {
        // 检查落子后是否间接救活
        final snap = game.saveSnapshot();
        game.placeStone(row, col);
        bool saved = false;
        for (final d in dirs) {
          final nr = row + d[0], nc = col + d[1];
          if (game.inBounds(nr, nc) && game.board[nr][nc] == aiColor) {
            if (!game.isInAtari(nr, nc)) {
              // 检查落子前在打吃
              if (nr >= 0 && nr < boardSize && nc >= 0 && nc < boardSize && snap.board[nr][nc] == aiColor) {
                final beforeLibs = _countGroupLibs(snap.board, nr, nc);
                if (beforeLibs == 1) saved = true;
              }
            }
          }
        }
        game.restoreSnapshot(snap);
        if (!saved) score += _ignoreAtari ~/ 2; // 不救己方棋
      }
    }

    // ── 对杀嗅觉 ──
    // 如果对方有2气的棋，我方紧气可能导向对杀
    for (final d in dirs) {
      final nr = row + d[0], nc = col + d[1];
      if (!game.inBounds(nr, nc)) continue;
      if (board[nr][nc] == opponentColor) {
        final libs = game.groupLibertiesCount(nr, nc);
        if (libs == 2) score += _semeaiBonus ~/ 2;
      }
    }

    return score;
  }

  /// 标记当前是否为"紧迫局面"
  bool get _isMoveUrgent => true; // 简化：总考虑危机

  // ═══════════════ 工具函数 ═══════════════

  /// 在指定 board 上计算某位置所属组的气数
  int _countGroupLibs(List<List<int>> board, int row, int col) {
    final color = board[row][col];
    if (color == GoGame.empty) return 0;

    final visited = <int>{};
    final queue = <int>[row * boardSize + col];
    visited.add(row * boardSize + col);
    final libs = <int>{};
    const dirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];

    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      final cr = cur ~/ boardSize, cc = cur % boardSize;
      for (final d in dirs) {
        final nr = cr + d[0], nc = cc + d[1];
        if (nr < 0 || nr >= boardSize || nc < 0 || nc >= boardSize) continue;
        final key = nr * boardSize + nc;
        if (board[nr][nc] == GoGame.empty) {
          libs.add(key);
        } else if (board[nr][nc] == color && !visited.contains(key)) {
          visited.add(key);
          queue.add(key);
        }
      }
    }
    return libs.length;
  }

  /// 找组的最小位置 ID（用于判断组是否相同）
  int _groupMinPos(
      List<List<int>> board, int row, int col, int size) {
    final color = board[row][col];
    if (color == GoGame.empty) return -1;

    final visited = <int>{};
    final queue = <int>[row * size + col];
    visited.add(row * size + col);
    int minPos = row * size + col;
    const dirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];

    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      if (cur < minPos) minPos = cur;
      final cr = cur ~/ size, cc = cur % size;
      for (final d in dirs) {
        final nr = cr + d[0], nc = cc + d[1];
        if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
        final key = nr * size + nc;
        if (board[nr][nc] == color && !visited.contains(key)) {
          visited.add(key);
          queue.add(key);
        }
      }
    }
    return minPos;
  }

  bool _isStarPosition(int r, int c) {
    if (boardSize == 19) {
      const stars = {3, 9, 15};
      return stars.contains(r) && stars.contains(c);
    }
    if (boardSize == 13) {
      return ((r == 3 || r == 9) && (c == 3 || c == 9)) || (r == 6 && c == 6);
    }
    if (boardSize == 9) {
      return ((r == 2 || r == 6) && (c == 2 || c == 6)) || (r == 4 && c == 4);
    }
    return false;
  }
}

/// 候选走法包装
class _Candidate {
  final int index;
  final List<int> move;
  final int basicScore;
  int totalScore;

  int get row => move[0];
  int get col => move[1];

  _Candidate(this.index, this.move, this.basicScore)
      : totalScore = basicScore;
}
