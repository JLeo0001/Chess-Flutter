/// 中国跳棋游戏逻辑
///
/// 棋盘：六角星形，共121个孔位。
/// 每位玩家10枚棋子，从己方营地跳到正对面营地即获胜。
/// 走法：(1) 相邻步 — 走到相邻空位；(2) 跳跃 — 隔一子跳到对称空位，可连跳。

class ChineseCheckersGame {
  /// 空位标记
  static const int empty = 0;

  /// 玩家数
  final int numPlayers;

  /// 所有121个棋位（轴向坐标 q, r）
  final List<HexPos> positions;

  /// 轴向坐标 → positions 索引的映射
  final Map<String, int> _posIndex;

  /// 相邻索引缓存（6方向）
  final List<List<int>> _neighbors;

  /// 营地：6个营地，每个10个索引
  final List<List<int>> camps;

  /// 棋盘状态：positions[i] 被哪位玩家占据（0=空，1..numPlayers）
  late List<int> board;

  int _currentPlayer = 1;
  bool _gameOver = false;
  int _winner = 0;

  /// 选中棋子的索引（-1=未选中）
  int _selectedIndex = -1;

  /// 选中棋子的合法目标索引集合
  Set<int> _validTargets = {};

  /// 当前玩家可点击（升起）的棋子索引集合
  Set<int> _pickablePieces = {};

  /// 移动历史（用于悔棋）
  final List<_MoveRecord> _moveHistory = [];

  OnCCGameListener? _listener;

  ChineseCheckersGame({required this.numPlayers})
      : positions = _generateBoard(),
        _posIndex = {},
        _neighbors = [],
        camps = List.generate(6, (_) => []) {
    if (!const {2, 3, 4, 6}.contains(numPlayers)) {
      throw ArgumentError.value(
        numPlayers,
        'numPlayers',
        '中国跳棋仅支持 2、3、4 或 6 人',
      );
    }

    // 构建坐标→索引映射
    for (int i = 0; i < positions.length; i++) {
      _posIndex['${positions[i].q},${positions[i].r}'] = i;
    }

    // 预计算相邻关系
    for (int i = 0; i < positions.length; i++) {
      _neighbors.add(_computeNeighbors(i));
    }

    // 计算6个营地
    _computeCamps();

    reset();
  }

  // ————— 公开属性 —————

  int get currentPlayer => _currentPlayer;
  bool get isGameOver => _gameOver;
  int get winner => _winner;
  int get selectedIndex => _selectedIndex;
  Set<int> get validTargets => _validTargets;
  Set<int> get pickablePieces => _pickablePieces;
  int get moveCount => _moveHistory.length;
  int get centerIndex => _posIndex['0,0']!;

  // ————— 玩家索引 -> 颜色编号（1..6）对外 —————

  /// 当前玩家所用的颜色编号（1..6）基于玩家索引和营地方案
  int playerColor(int playerIdx) {
    return _playerCamp(playerIdx) + 1; // 1-indexed
  }

  /// 营地索引（0..5）
  int _playerCamp(int playerIdx) {
    switch (numPlayers) {
      case 2:
        return playerIdx == 1 ? 0 : 3;
      case 3:
        return [0, 2, 4][playerIdx - 1];
      case 4:
        return [0, 1, 3, 4][playerIdx - 1];
      case 6:
        return playerIdx - 1;
      default:
        return playerIdx - 1;
    }
  }

  /// 目标营地索引（正对面，偏移3）
  int _targetCamp(int playerIdx) {
    return (_playerCamp(playerIdx) + 3) % 6;
  }

  /// 玩家是否已完成（所有棋子在目标营地）
  bool isPlayerFinished(int playerIdx) {
    final target = _targetCamp(playerIdx);
    for (final idx in camps[target]) {
      if (board[idx] != playerIdx) return false;
    }
    return true;
  }

  void setListener(OnCCGameListener l) => _listener = l;

  /// 玩家营地索引（公开给AI使用）
  int playerCampIdx(int playerIdx) => _playerCamp(playerIdx);

  /// 目标营地索引（公开给AI使用）
  int targetCampIdx(int playerIdx) => _targetCamp(playerIdx);

  // ========== 生成棋盘 ==========

  /// 生成六角星形棋盘的121个孔位
  static List<HexPos> _generateBoard() {
    final cells = <HexPos>[];
    final seen = <String>{};

    // 中央六边形，半径4（使用立方坐标约束）
    for (int q = -4; q <= 4; q++) {
      for (int r = -4; r <= 4; r++) {
        final s = -q - r;
        if (s.abs() <= 4) {
          final key = '$q,$r';
          if (!seen.contains(key)) {
            seen.add(key);
            cells.add(HexPos(q, r));
          }
        }
      }
    }

    // 6个三角形臂
    // +z 臂: z∈[5,8], x∈[-4,-1], y = -x-z
    for (int z = 5; z <= 8; z++) {
      for (int x = -4; x <= -1; x++) {
        final y = -x - z;
        if (y >= -4 && y <= -1) {
          final key = '$x,$y';
          if (!seen.contains(key)) {
            seen.add(key);
            cells.add(HexPos(x, y));
          }
        }
      }
    }

    // -z 臂: z∈[-8,-5], x∈[0,4], y = -x-z
    for (int z = -8; z <= -5; z++) {
      for (int x = 0; x <= 4; x++) {
        final y = -x - z;
        if (y >= 0 && y <= 4) {
          final key = '$x,$y';
          if (!seen.contains(key)) {
            seen.add(key);
            cells.add(HexPos(x, y));
          }
        }
      }
    }

    // +x 臂: x∈[5,8], y∈[-4,-1], z = -x-y
    for (int x = 5; x <= 8; x++) {
      for (int y = -4; y <= -1; y++) {
        final z = -x - y;
        if (z >= -4 && z <= -1) {
          final key = '$x,$y';
          if (!seen.contains(key)) {
            seen.add(key);
            cells.add(HexPos(x, y));
          }
        }
      }
    }

    // -x 臂: x∈[-8,-5], y∈[0,4], z = -x-y
    for (int x = -8; x <= -5; x++) {
      for (int y = 0; y <= 4; y++) {
        final z = -x - y;
        if (z >= 0 && z <= 4) {
          final key = '$x,$y';
          if (!seen.contains(key)) {
            seen.add(key);
            cells.add(HexPos(x, y));
          }
        }
      }
    }

    // +y 臂: y∈[5,8], x∈[-4,-1], z = -x-y
    for (int y = 5; y <= 8; y++) {
      for (int x = -4; x <= -1; x++) {
        final z = -x - y;
        if (z >= -4 && z <= -1) {
          final key = '$x,$y';
          if (!seen.contains(key)) {
            seen.add(key);
            cells.add(HexPos(x, y));
          }
        }
      }
    }

    // -y 臂: y∈[-8,-5], x∈[0,4], z = -x-y
    for (int y = -8; y <= -5; y++) {
      for (int x = 0; x <= 4; x++) {
        final z = -x - y;
        if (z >= 0 && z <= 4) {
          final key = '$x,$y';
          if (!seen.contains(key)) {
            seen.add(key);
            cells.add(HexPos(x, y));
          }
        }
      }
    }

    return cells;
  }

  /// 计算6个营地（每个10个棋位）
  void _computeCamps() {
    // 营地0: +z臂  z∈[5,8], x∈[-4,-1]
    // 营地1: +x臂  x∈[5,8], y∈[-4,-1]
    // 营地2: -y臂  y∈[-8,-5], x∈[0,4]
    // 营地3: -z臂  z∈[-8,-5], x∈[0,4]
    // 营地4: -x臂  x∈[-8,-5], y∈[0,4]
    // 营地5: +y臂  y∈[5,8], x∈[-4,-1]

    for (int i = 0; i < positions.length; i++) {
      final p = positions[i];
      final x = p.q, y = p.r, z = -x - y;

      if (z >= 5 && z <= 8) {
        camps[0].add(i); // +z = 顶
      }
      if (x >= 5 && x <= 8) {
        camps[1].add(i); // +x = 右上
      }
      if (y <= -5 && y >= -8) {
        camps[2].add(i); // -y = 右下
      }
      if (z <= -5 && z >= -8) {
        camps[3].add(i); // -z = 底
      }
      if (x <= -5 && x >= -8) {
        camps[4].add(i); // -x = 左下
      }
      if (y >= 5 && y <= 8) {
        camps[5].add(i); // +y = 左上
      }
    }

    // 保证每个营地恰好10个
    for (int c = 0; c < 6; c++) {
      assert(camps[c].length == 10,
          'Camp $c has ${camps[c].length} cells, expected 10');
    }
  }

  // ========== 邻居计算 ==========

  /// 六边形6个方向（轴向坐标）
  static const _dirs = [
    [0, -1],
    [1, -1],
    [1, 0],
    [0, 1],
    [-1, 1],
    [-1, 0],
  ];

  List<int> _computeNeighbors(int idx) {
    final p = positions[idx];
    final neighbors = <int>[];
    for (final d in _dirs) {
      final nq = p.q + d[0], nr = p.r + d[1];
      final key = '$nq,$nr';
      final ni = _posIndex[key];
      if (ni != null) neighbors.add(ni);
    }
    return neighbors;
  }

  // ========== 操作 ==========

  void reset() {
    board = List.filled(positions.length, empty);
    _currentPlayer = 1;
    _gameOver = false;
    _winner = 0;
    _selectedIndex = -1;
    _validTargets = {};
    _moveHistory.clear();

    // 将棋子放入各玩家营地
    for (int p = 1; p <= numPlayers; p++) {
      final camp = camps[_playerCamp(p)];
      for (final idx in camp) {
        board[idx] = p;
      }
    }

    _updatePickable();
    _listener?.onGameReset();
  }

  /// 点击棋位：选中 / 走子
  /// 返回 true 表示操作成功
  bool tapCell(int index) {
    if (_gameOver || index < 0 || index >= positions.length) return false;

    // 如果已选中棋子且点击的是合法目标 → 走子
    if (_selectedIndex >= 0 && _validTargets.contains(index)) {
      _doMove(_selectedIndex, index);
      return true;
    }

    // 如果点击的是当前玩家的棋子 → 选中
    if (board[index] == _currentPlayer) {
      _selectedIndex = index;
      _validTargets = _computeValidTargets(index);
      _listener?.onSelectionChanged(index, _validTargets);
      return true;
    }

    // 点击其他 → 取消选中
    _selectedIndex = -1;
    _validTargets = {};
    _listener?.onSelectionChanged(-1, {});
    return false;
  }

  /// 取消选中
  void clearSelection() {
    _selectedIndex = -1;
    _validTargets = {};
    _listener?.onSelectionChanged(-1, {});
  }

  // ========== 走法计算 ==========

  /// 计算某棋子的所有合法目标
  Set<int> _computeValidTargets(int fromIdx) {
    final targets = <int>{};

    // 相邻步：6个方向，走到相邻空位
    for (final nb in _neighbors[fromIdx]) {
      if (board[nb] == empty) {
        targets.add(nb);
      }
    }

    // 跳跃：DFS 查找所有跳链
    final visited = <int>{fromIdx};
    _findJumps(fromIdx, fromIdx, visited, targets);

    // 不能留在原位
    targets.remove(fromIdx);

    return targets;
  }

  /// DFS 查找所有可通过跳跃到达的位置
  void _findJumps(
    int fromIdx,
    int moveOrigin,
    Set<int> visited,
    Set<int> targets,
  ) {
    for (final nb in _neighbors[fromIdx]) {
      // 连跳开始后原始棋位已经空出，不能再被当作搭桥棋子。
      if (nb == moveOrigin || board[nb] == empty) continue;
      // 相邻有棋子，检查对称位置
      final pFrom = positions[fromIdx];
      final pNb = positions[nb];
      final jumpQ = pNb.q + (pNb.q - pFrom.q);
      final jumpR = pNb.r + (pNb.r - pFrom.r);
      final jumpKey = '$jumpQ,$jumpR';
      final jumpIdx = _posIndex[jumpKey];
      if (jumpIdx == null) continue; // 棋盘外
      if (board[jumpIdx] != empty) continue; // 目标非空
      if (visited.contains(jumpIdx)) continue;

      visited.add(jumpIdx);
      targets.add(jumpIdx);

      // 继续连跳
      _findJumps(jumpIdx, moveOrigin, visited, targets);
    }
  }

  // ========== 执行走子 ==========

  void _doMove(int fromIdx, int toIdx) {
    final player = _currentPlayer;
    final prevBoard = List<int>.from(board);

    // 记录
    _moveHistory.add(_MoveRecord(
      fromIdx: fromIdx,
      toIdx: toIdx,
      player: player,
      prevBoard: prevBoard,
    ));

    // 移动棋子
    board[toIdx] = player;
    board[fromIdx] = empty;

    _selectedIndex = -1;
    _validTargets = {};

    _listener?.onMoveMade(fromIdx, toIdx, player);

    // 检查获胜
    if (isPlayerFinished(player)) {
      _gameOver = true;
      _winner = player;
      _updatePickable();
      _listener?.onGameOver(player);
      return;
    }

    // 下一玩家
    _currentPlayer = (_currentPlayer % numPlayers) + 1;
    _updatePickable();
  }

  /// 更新当前玩家可操作的棋子列表
  void _updatePickable() {
    if (_gameOver) {
      _pickablePieces = {};
      return;
    }
    _pickablePieces = {};
    for (int i = 0; i < board.length; i++) {
      if (board[i] == _currentPlayer) {
        _pickablePieces.add(i);
      }
    }
  }

  // ========== 查找当前玩家所有合法走法 ==========

  /// 返回 [(fromIdx, toIdx), ...]
  List<List<int>> allLegalMoves(int playerIdx) {
    final moves = <List<int>>[];
    for (int i = 0; i < board.length; i++) {
      if (board[i] != playerIdx) continue;
      final targets = _computeValidTargets(i);
      for (final t in targets) {
        moves.add([i, t]);
      }
    }
    return moves;
  }

  /// 执行一次走子（不触发事件，用于AI模拟）
  bool simulateMove(int fromIdx, int toIdx) {
    if (board[fromIdx] == empty || board[toIdx] != empty) return false;
    board[toIdx] = board[fromIdx];
    board[fromIdx] = empty;
    return true;
  }

  /// 撤销一次模拟走子
  void undoSimulate(int fromIdx, int toIdx, int player) {
    board[fromIdx] = player;
    board[toIdx] = empty;
  }

  // ========== 悔棋 ==========

  bool undo() {
    if (_gameOver || _moveHistory.isEmpty) return false;
    final last = _moveHistory.removeLast();
    board = last.prevBoard;
    _currentPlayer = last.player;
    _gameOver = false;
    _winner = 0;
    _selectedIndex = -1;
    _validTargets = {};
    _updatePickable();
    _listener?.onUndo();
    return true;
  }

  // ========== 快照（AI模拟用） ==========

  CCSnapshot saveSnapshot() {
    return CCSnapshot(
      board: List<int>.from(board),
      currentPlayer: _currentPlayer,
      gameOver: _gameOver,
      winner: _winner,
    );
  }

  void restoreSnapshot(CCSnapshot snap) {
    board = List<int>.from(snap.board);
    _currentPlayer = snap.currentPlayer;
    _gameOver = snap.gameOver;
    _winner = snap.winner;
  }

  // ========== 距离计算工具 ==========

  /// 两个棋位之间的六边形距离
  int hexDistance(int idx1, int idx2) {
    final a = positions[idx1], b = positions[idx2];
    final dq = (a.q - b.q).abs();
    final dr = (a.r - b.r).abs();
    final ds = ((a.q + a.r) - (b.q + b.r)).abs();
    return (dq + dr + ds) ~/ 2;
  }

  /// 棋子到目标营地最近距离
  int distanceToCamp(int pieceIdx, int targetCampIdx) {
    int minDist = 999;
    for (final ti in camps[targetCampIdx]) {
      final d = hexDistance(pieceIdx, ti);
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  /// 玩家所有棋子到目标营地的总距离
  int totalDistanceToTarget(int playerIdx) {
    final target = _targetCamp(playerIdx);
    int total = 0;
    for (int i = 0; i < board.length; i++) {
      if (board[i] == playerIdx) {
        total += distanceToCamp(i, target);
      }
    }
    return total;
  }

  /// 玩家在目标营地内已到位的棋子数
  int piecesInTargetCamp(int playerIdx) {
    final target = _targetCamp(playerIdx);
    int count = 0;
    for (final idx in camps[target]) {
      if (board[idx] == playerIdx) count++;
    }
    return count;
  }
}

// ————— 辅助类 —————

class HexPos {
  final int q, r;
  const HexPos(this.q, this.r);

  @override
  String toString() => '($q,$r)';
}

class _MoveRecord {
  final int fromIdx, toIdx, player;
  final List<int> prevBoard;

  _MoveRecord({
    required this.fromIdx,
    required this.toIdx,
    required this.player,
    required this.prevBoard,
  });
}

class CCSnapshot {
  final List<int> board;
  final int currentPlayer;
  final bool gameOver;
  final int winner;

  CCSnapshot({
    required this.board,
    required this.currentPlayer,
    required this.gameOver,
    required this.winner,
  });
}

abstract class OnCCGameListener {
  void onMoveMade(int fromIdx, int toIdx, int player);
  void onGameOver(int winner);
  void onGameReset();
  void onSelectionChanged(int selectedIndex, Set<int> validTargets);
  void onUndo();
}
