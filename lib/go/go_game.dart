/// 围棋游戏逻辑 — 中国规则数子法
class GoGame {
  static const int empty = 0;
  static const int black = 1;
  static const int white = 2;

  final int boardSize;
  late List<List<int>> _board;
  int _currentPlayer = black;
  bool _gameOver = false;
  int _winner = empty;
  int _lastRow = -1, _lastCol = -1;
  int _capturedBlack = 0; // 白棋吃掉的黑色棋子
  int _capturedWhite = 0; // 黑棋吃掉的白色棋子
  int _passCount = 0;

  // 打劫状态 — 记录劫的位置
  int _koRow = -1, _koCol = -1;

  // 死子标记（终局后手动标记）
  final Set<String> _deadStones = {};

  final List<_GoMove> _moveHistory = [];
  int _moveNumber = 0;

  OnGoGameListener? _listener;

  GoGame({this.boardSize = 19}) { reset(); }

  // ————— 公开属性 —————
  List<List<int>> get board => _board;
  int get currentPlayer => _currentPlayer;
  bool get isGameOver => _gameOver;
  int get winner => _winner;
  int get lastRow => _lastRow;
  int get lastCol => _lastCol;
  int get capturedBlack => _capturedBlack;
  int get capturedWhite => _capturedWhite;
  int get moveCount => _moveNumber;
  int get koRow => _koRow;
  int get koCol => _koCol;

  Set<String> get deadStones => _deadStones;

  void setListener(OnGoGameListener l) => _listener = l;
  void setStartingPlayer(int player) => _currentPlayer = player;

  // ========== 落子 ==========

  bool placeStone(int row, int col) {
    if (_gameOver) return false;
    if (!inBounds(row, col)) return false;
    if (_board[row][col] != empty) return false;

    // 禁着点（自杀）
    if (!_wouldCaptureEnemy(row, col, _currentPlayer)) {
      if (!_hasLibertyAfterPlace(row, col, _currentPlayer)) return false;
    }

    // 打劫
    if (_koRow == row && _koCol == col) return false;

    // 保存旧状态
    final prevBoard = _board.map((r) => List<int>.from(r)).toList();
    final prevKoR = _koRow, prevKoC = _koCol;
    final prevCaptB = _capturedBlack, prevCaptW = _capturedWhite;

    // 落子
    _board[row][col] = _currentPlayer;
    _lastRow = row;
    _lastCol = col;

    // 清除旧劫
    _koRow = -1;
    _koCol = -1;

    // 提子
    int captured = _removeDeadOpponentGroups(row, col, _currentPlayer);

    // 检测新劫
    if (captured == 1) _detectKo(row, col);

    _moveNumber++;
    _moveHistory.add(_GoMove(
      row: row, col: col, player: _currentPlayer,
      capturedBlack: _capturedBlack, capturedWhite: _capturedWhite,
      koRow: prevKoR, koCol: prevKoC,
      prevBoard: prevBoard,
      prevCapturedBlack: prevCaptB, prevCapturedWhite: prevCaptW,
    ));
    _passCount = 0;
    _listener?.onStonePlaced(row, col, _currentPlayer);
    _currentPlayer = (_currentPlayer == black) ? white : black;
    return true;
  }

  // ========== Pass ==========

  void pass() {
    if (_gameOver) return;
    _lastRow = -1; _lastCol = -1;
    _koRow = -1; _koCol = -1;
    _moveHistory.add(_GoMove(
      row: -1, col: -1, player: _currentPlayer,
      capturedBlack: _capturedBlack, capturedWhite: _capturedWhite,
      koRow: -1, koCol: -1, isPass: true,
      prevBoard: _board.map((r) => List<int>.from(r)).toList(),
      prevCapturedBlack: _capturedBlack, prevCapturedWhite: _capturedWhite,
    ));
    _passCount++;
    if (_passCount >= 2) {
      _gameOver = true;
      _winner = _determineWinner();
      _listener?.onGameOver(_winner, 0, 0, 0, 0);
    } else {
      _currentPlayer = (_currentPlayer == black) ? white : black;
    }
  }

  // ========== 自杀检测 ==========

  bool _wouldCaptureEnemy(int row, int col, int color) {
    final opp = (color == black) ? white : black;
    for (final d in _dirs) {
      final nr = row + d[0], nc = col + d[1];
      if (inBounds(nr, nc) && _board[nr][nc] == opp) {
        if (!_groupHasLibertyExcluding(nr, nc, row, col)) return true;
      }
    }
    return false;
  }

  bool _hasLibertyAfterPlace(int row, int col, int color) {
    // 先看四周有没有己方空位
    for (final d in _dirs) {
      final nr = row + d[0], nc = col + d[1];
      if (!inBounds(nr, nc)) continue;
      if (_board[nr][nc] == empty) return true;
      if (_board[nr][nc] == color) {
        _board[row][col] = color; // 临时放置
        final group = _getFullGroup(nr, nc);
        bool ok = _anyGroupLiberty(group);
        _board[row][col] = empty; // 恢复
        if (ok) return true;
      }
    }
    return false;
  }

  // ========== 提子 ==========

  int _removeDeadOpponentGroups(int row, int col, int color) {
    final opp = (color == black) ? white : black;
    int total = 0;
    for (final d in _dirs) {
      final nr = row + d[0], nc = col + d[1];
      if (inBounds(nr, nc) && _board[nr][nc] == opp) {
        final group = _getFullGroup(nr, nc);
        if (!_anyGroupLiberty(group)) {
          for (final g in group) {
            _board[g[0]][g[1]] = empty;
            total++;
          }
        }
      }
    }
    if (color == black) _capturedWhite += total;
    else _capturedBlack += total;
    return total;
  }

  // ========== 打劫检测 ==========

  void _detectKo(int row, int col) {
    // 刚落下的子(row,col)，周围有个空位是被提掉的棋子的位置
    // 检查：如果对手在那个空位落子能否吃掉(row,col)且(row,col)只有1子无其他气
    const dirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];
    for (final d in dirs) {
      final nr = row + d[0], nc = col + d[1];
      if (!inBounds(nr, nc) || _board[nr][nc] != empty) continue;
      // (nr,nc) 是刚被提掉的位置（候选劫位）
      // 检查(row,col)除了(nr,nc)之外还有没有气
      final group = _getFullGroup(row, col);
      final libSet = <String>{};
      for (final g in group) {
        for (final d2 in dirs) {
          final nr2 = g[0] + d2[0], nc2 = g[1] + d2[1];
          final key = '$nr2,$nc2';
          if (inBounds(nr2, nc2) && _board[nr2][nc2] == empty && !libSet.contains(key)) {
            libSet.add(key);
          }
        }
      }
      // 除去(nr,nc)后没有气了
      libSet.remove('$nr,$nc');
      if (libSet.isEmpty && group.length == 1) {
        _koRow = nr;
        _koCol = nc;
        return;
      }
    }
  }

  // ========== 连通组操作 ==========

  List<List<int>> _getFullGroup(int row, int col) {
    final color = _board[row][col];
    if (color == empty) return [];
    final visited = <String>{};
    final group = <List<int>>[];
    final queue = <List<int>>[[row, col]];
    visited.add('$row,$col');
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      group.add(cur);
      for (final d in _dirs) {
        final nr = cur[0] + d[0], nc = cur[1] + d[1];
        final k = '$nr,$nc';
        if (inBounds(nr, nc) && _board[nr][nc] == color && !visited.contains(k)) {
          visited.add(k);
          queue.add([nr, nc]);
        }
      }
    }
    return group;
  }

  bool _anyGroupLiberty(List<List<int>> group) {
    for (final g in group) {
      for (final d in _dirs) {
        final nr = g[0] + d[0], nc = g[1] + d[1];
        if (inBounds(nr, nc) && _board[nr][nc] == empty) return true;
      }
    }
    return false;
  }

  bool _groupHasLibertyExcluding(int row, int col, int exR, int exC) {
    final color = _board[row][col];
    final visited = <String>{};
    final queue = <List<int>>[[row, col]];
    visited.add('$row,$col');
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      for (final d in _dirs) {
        final nr = cur[0] + d[0], nc = cur[1] + d[1];
        if (!inBounds(nr, nc)) continue;
        if (nr == exR && nc == exC) continue;
        if (_board[nr][nc] == empty) return true;
        final k = '$nr,$nc';
        if (_board[nr][nc] == color && !visited.contains(k)) {
          visited.add(k);
          queue.add([nr, nc]);
        }
      }
    }
    return false;
  }

  List<int> _groupLiberties(int row, int col) {
    final color = _board[row][col];
    if (color == empty) return [0, 0];
    final visited = <String>{};
    final libSet = <String>{};
    final queue = <List<int>>[[row, col]];
    visited.add('$row,$col');
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      for (final d in _dirs) {
        final nr = cur[0] + d[0], nc = cur[1] + d[1];
        if (!inBounds(nr, nc)) continue;
        final k = '$nr,$nc';
        if (_board[nr][nc] == empty && !libSet.contains(k)) {
          libSet.add(k);
        } else if (_board[nr][nc] == color && !visited.contains(k)) {
          visited.add(k);
          queue.add([nr, nc]);
        }
      }
    }
    return [visited.length, libSet.length]; // [size, liberties]
  }

  // ========== 眼型判断（真眼/假眼）==========

  /// 判断 (row,col) 位置对 color 方是否构成真眼
  /// 眼角（对角位置）必须全部被己方控制
  bool isRealEye(int row, int col, int color) {
    // 该位置必须是己方围住的空点
    if (_board[row][col] != empty) return false;
    // 上下左右必须全部是己方棋子
    for (final d in _dirs) {
      final nr = row + d[0], nc = col + d[1];
      if (!inBounds(nr, nc)) return false; // 边角不能单独作为真眼
      if (_board[nr][nc] != color) return false;
    }
    // 检查眼角（四个对角）
    final corners = [[-1, -1], [-1, 1], [1, -1], [1, 1]];
    int controlled = 0;
    int totalCorners = 0;
    for (final c in corners) {
      final nr = row + c[0], nc = col + c[1];
      if (inBounds(nr, nc)) {
        totalCorners++;
        if (_board[nr][nc] == color) controlled++;
      }
    }
    // 中央眼需控制 3+ 角，边眼需控制全部角，角眼需控制1角
    if (row == 0 || row == boardSize - 1) {
      if (col == 0 || col == boardSize - 1) return controlled >= 1; // 角上的眼
      return controlled >= totalCorners - 0; // 边上的眼（2个角）
    }
    if (col == 0 || col == boardSize - 1) return controlled >= totalCorners; // 边上的眼
    return controlled >= 3; // 中央的眼至少控制3个眼角
  }

  // ========== 终局与计分 ==========

  int _determineWinner() {
    final s = score();
    final b = s.blackTotal, w = s.whiteTotal;
    final total = boardSize * boardSize;
    final komi = 3.75;
    final half = total / 2.0;
    // 中国规则：黑需超过184.25子（185子胜），白需超过176.75子（177子胜）
    if (b > half + komi) return black;
    if (w > half - komi) return white;
    if (b > w) return black;
    if (w > b) return white;
    return empty;
  }

  /// 完整计分：子空皆地 — 中国规则数子法
  ///
  /// 流程：
  /// 1. 将标记为死子的棋子视为空（它们将成为对方领地的一部分）
  /// 2. 统计活子（未被标记的死子）
  /// 3. Flood-fill 空点 → 只接触一方时计为该方领地
  /// 4. 接触双方的空点 → 双活公气 → 双方各计半子
  GameScore score() {
    // 第一步：构建虚拟棋盘，死子视为空
    final workingBoard = List.generate(
      boardSize, (r) => List<int>.filled(boardSize, empty));
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        final key = '$r,$c';
        if (_deadStones.contains(key)) {
          workingBoard[r][c] = empty; // 死子位置变为空
        } else {
          workingBoard[r][c] = _board[r][c];
        }
      }
    }

    // 统计活子
    int blackStones = 0, whiteStones = 0;
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (workingBoard[r][c] == black) blackStones++;
        else if (workingBoard[r][c] == white) whiteStones++;
      }
    }

    // Flood-fill 空点归属
    final visited = <String>{};
    int blackTerritory = 0;
    int whiteTerritory = 0;
    int sharedPoints = 0; // 双活公气点数

    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (visited.contains('$r,$c')) continue;
        if (workingBoard[r][c] != empty) continue;

        // Flood fill 一片空区域
        final region = <List<int>>[];
        final queue = <List<int>>[[r, c]];
        visited.add('$r,$c');
        bool touchesBlack = false, touchesWhite = false;

        while (queue.isNotEmpty) {
          final p = queue.removeAt(0);
          region.add(p);
          for (final d in _dirs) {
            final nr = p[0] + d[0], nc = p[1] + d[1];
            if (!inBounds(nr, nc)) continue;
            final nk = '$nr,$nc';
            if (workingBoard[nr][nc] == black) {
              touchesBlack = true;
            } else if (workingBoard[nr][nc] == white) {
              touchesWhite = true;
            } else if (!visited.contains(nk)) {
              visited.add(nk);
              queue.add([nr, nc]);
            }
          }
        }

        if (touchesBlack && !touchesWhite) {
          blackTerritory += region.length;
        } else if (touchesWhite && !touchesBlack) {
          whiteTerritory += region.length;
        } else if (touchesBlack && touchesWhite) {
          // 双活公气 — 双方各得半子
          sharedPoints += region.length;
        }
        // 都不接触（不可能，除非棋盘全空）
      }
    }

    // 公气半子分配到双方
    final blackHalfShared = sharedPoints / 2.0;
    final whiteHalfShared = sharedPoints / 2.0;

    return GameScore(
      blackStones: blackStones,
      whiteStones: whiteStones,
      blackTerritory: blackTerritory.toDouble() + blackHalfShared,
      whiteTerritory: whiteTerritory.toDouble() + whiteHalfShared,
      capturedByBlack: _capturedWhite,
      capturedByWhite: _capturedBlack,
      sharedPoints: sharedPoints,
    );
  }

  String resultDescription() {
    final s = score();
    final total = boardSize * boardSize;
    final komi = 3.75;
    final half = total / 2.0;
    final b = s.blackTotal, w = s.whiteTotal;

    String detail = '黑 ${s.blackTotalStr} 子 vs 白 ${s.whiteTotalStr} 子'
        '（贴 3¾ 子）';
    if (s.sharedPoints > 0) {
      detail += '，双活公气 ${s.sharedPoints} 点';
    }

    if (b > half + komi) {
      return '黑棋胜 ${(b - half - komi).toStringAsFixed(1)} 子\n$detail';
    } else if (w > half - komi) {
      return '白棋胜 ${(w - half + komi).toStringAsFixed(1)} 子\n$detail';
    }
    if (b > w) return '黑棋胜 ${(b - w).toStringAsFixed(1)} 子\n$detail';
    if (w > b) return '白棋胜 ${(w - b).toStringAsFixed(1)} 子\n$detail';
    return '平局\n$detail';
  }

  int get sharedPoints {
    int cnt = 0;
    final visited = <String>{};
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (visited.contains('$r,$c')) continue;
        if (_board[r][c] != empty) continue;
        // Flood fill
        final queue = <List<int>>[[r, c]];
        visited.add('$r,$c');
        bool tB = false, tW = false;
        int size = 0;
        while (queue.isNotEmpty) {
          final p = queue.removeAt(0);
          size++;
          for (final d in _dirs) {
            final nr = p[0] + d[0], nc = p[1] + d[1];
            if (!inBounds(nr, nc)) continue;
            final nk = '$nr,$nc';
            if (_board[nr][nc] == black) tB = true;
            else if (_board[nr][nc] == white) tW = true;
            else if (!visited.contains(nk)) {
              visited.add(nk);
              queue.add([nr, nc]);
            }
          }
        }
        if (tB && tW) cnt += size;
      }
    }
    return cnt;
  }

  void toggleDeadStone(int row, int col) {
    final key = '$row,$col';
    if (_deadStones.contains(key)) _deadStones.remove(key);
    else _deadStones.add(key);
  }

  void clearDeadStones() => _deadStones.clear();

  // ========== 悔棋 ==========

  bool undo() {
    if (_gameOver || _moveHistory.isEmpty) return false;
    final last = _moveHistory.removeLast();
    for (int r = 0; r < boardSize; r++)
      for (int c = 0; c < boardSize; c++)
        _board[r][c] = last.prevBoard[r][c];

    _currentPlayer = last.player;
    _capturedBlack = last.prevCapturedBlack;
    _capturedWhite = last.prevCapturedWhite;
    _koRow = last.koRow; _koCol = last.koCol;
    _moveNumber--;
    _passCount = 0;
    for (int i = _moveHistory.length - 1; i >= 0 && _moveHistory[i].isPass; i--)
      _passCount++;
    _gameOver = false; _winner = empty;
    _lastRow = _moveHistory.isNotEmpty ? _moveHistory.last.row : -1;
    _lastCol = _moveHistory.isNotEmpty ? _moveHistory.last.col : -1;
    _listener?.onUndo(last.row, last.col);
    return true;
  }

  void reset() {
    _board = List.generate(boardSize, (_) => List.filled(boardSize, empty));
    _currentPlayer = black;
    _gameOver = false; _winner = empty;
    _lastRow = -1; _lastCol = -1;
    _capturedBlack = 0; _capturedWhite = 0;
    _passCount = 0; _moveNumber = 0;
    _koRow = -1; _koCol = -1;
    _deadStones.clear(); _moveHistory.clear();
  }

  bool inBounds(int r, int c) => r >= 0 && r < boardSize && c >= 0 && c < boardSize;

  // ========== 状态快照（用于 AI 模拟的保存/恢复）==========

  /// 保存当前完整游戏状态
  GoGameSnapshot saveSnapshot() {
    return GoGameSnapshot(
      board: _board.map((r) => List<int>.from(r)).toList(),
      currentPlayer: _currentPlayer,
      gameOver: _gameOver,
      winner: _winner,
      lastRow: _lastRow,
      lastCol: _lastCol,
      capturedBlack: _capturedBlack,
      capturedWhite: _capturedWhite,
      passCount: _passCount,
      koRow: _koRow,
      koCol: _koCol,
      deadStones: Set<String>.from(_deadStones),
      moveNumber: _moveNumber,
    );
  }

  /// 恢复之前保存的游戏状态
  void restoreSnapshot(GoGameSnapshot snap) {
    _board = snap.board.map((r) => List<int>.from(r)).toList();
    _currentPlayer = snap.currentPlayer;
    _gameOver = snap.gameOver;
    _winner = snap.winner;
    _lastRow = snap.lastRow;
    _lastCol = snap.lastCol;
    _capturedBlack = snap.capturedBlack;
    _capturedWhite = snap.capturedWhite;
    _passCount = snap.passCount;
    _koRow = snap.koRow;
    _koCol = snap.koCol;
    _deadStones..clear()..addAll(snap.deadStones);
    _moveNumber = snap.moveNumber;
    // 不清空 moveHistory — 但 AI 不应依赖 undo，用快照更安全
  }

  // ========== 工具 ==========

  /// 获取某个颜色的合法落子（用于 AI）
  List<List<int>> validMoves(int color) {
    final moves = <List<int>>[];
    final savedBoard = _board.map((r) => List<int>.from(r)).toList();
    final savedKor = _koRow, savedKoc = _koCol;
    final savedPlayer = _currentPlayer;
    _currentPlayer = color;
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (_board[r][c] != empty) continue;
        if (_koRow == r && _koCol == c) continue;
        if (!_wouldCaptureEnemy(r, c, color) && !_hasLibertyAfterPlace(r, c, color)) continue;
        moves.add([r, c]);
      }
    }
    _board = savedBoard;
    _koRow = savedKor; _koCol = savedKoc;
    _currentPlayer = savedPlayer;
    return moves;
  }

  /// 获取某个组的 liberties 数量
  int groupLibertiesCount(int row, int col) => _groupLiberties(row, col)[1];

  /// 检查某组是否在打吃（只有1气）
  bool isInAtari(int row, int col) => _groupLiberties(row, col)[1] == 1;

  static const _dirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];
}

/// 计分结果 — 中国规则数子法
class GameScore {
  final int blackStones, whiteStones;
  final double blackTerritory, whiteTerritory;
  final int capturedByBlack, capturedByWhite;
  final int sharedPoints; // 双活公气点数（双方各得半子）

  GameScore({
    required this.blackStones, required this.whiteStones,
    required this.blackTerritory, required this.whiteTerritory,
    required this.capturedByBlack, required this.capturedByWhite,
    this.sharedPoints = 0,
  });

  /// 黑棋总计 = 活子 + 领地（含双活半子）
  double get blackTotal => blackStones.toDouble() + blackTerritory;

  /// 白棋总计 = 活子 + 领地（含双活半子）
  double get whiteTotal => whiteStones.toDouble() + whiteTerritory;

  /// 显示用字符串
  String get blackTotalStr {
    final v = blackTotal;
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  String get whiteTotalStr {
    final v = whiteTotal;
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }
}

/// 游戏状态快照（用于 AI 模拟时保存/恢复）
class GoGameSnapshot {
  final List<List<int>> board;
  final int currentPlayer;
  final bool gameOver;
  final int winner;
  final int lastRow, lastCol;
  final int capturedBlack, capturedWhite;
  final int passCount;
  final int koRow, koCol;
  final Set<String> deadStones;
  final int moveNumber;

  GoGameSnapshot({
    required this.board,
    required this.currentPlayer,
    required this.gameOver,
    required this.winner,
    required this.lastRow,
    required this.lastCol,
    required this.capturedBlack,
    required this.capturedWhite,
    required this.passCount,
    required this.koRow,
    required this.koCol,
    required this.deadStones,
    required this.moveNumber,
  });
}

class _GoMove {
  final int row, col, player;
  final int capturedBlack, capturedWhite;
  final int koRow, koCol;
  final List<List<int>> prevBoard;
  final int prevCapturedBlack, prevCapturedWhite;
  final bool isPass;
  _GoMove({
    required this.row, required this.col, required this.player,
    required this.capturedBlack, required this.capturedWhite,
    required this.koRow, required this.koCol,
    required this.prevBoard,
    required this.prevCapturedBlack, required this.prevCapturedWhite,
    this.isPass = false,
  });
}

abstract class OnGoGameListener {
  void onStonePlaced(int row, int col, int player);
  void onGameOver(int winner, int startRow, int startCol, int endRow, int endCol);
  void onGameReset();
  void onUndo(int row, int col);
}
