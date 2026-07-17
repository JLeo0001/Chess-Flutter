/// 中国象棋游戏逻辑 — 1:1 移植自 ChineseChessGame.java
class ChineseChessGame {
  static const int cols = 9, rows = 10;
  static const int empty = 0, red = 1, black = 2;
  static const int king = 1, advisor = 2, bishop = 3;
  static const int knight = 4, rook = 5, cannon = 6, pawn = 7;

  final List<List<int>> _board = List.generate(rows, (_) => List.filled(cols, empty));
  int _currentPlayer = red;
  bool _gameOver = false;
  int _winner = empty;
  bool _flipped = false;

  int _lastFromRow = -1, _lastFromCol = -1;
  int _lastToRow = -1, _lastToCol = -1;
  int _lastCaptured = empty;

  int _redKingRow = 9, _redKingCol = 4;
  int _blackKingRow = 0, _blackKingCol = 4;

  OnGameListener? _listener;

  void setListener(OnGameListener l) => _listener = l;

  List<List<int>> get board => _board;
  int get currentPlayer => _currentPlayer;
  bool get isGameOver => _gameOver;
  int get winner => _winner;
  bool get isFlipped => _flipped;
  final List<_MoveRecord> _undoStack = [];

  int get lastFromRow => _lastFromRow;
  int get lastFromCol => _lastFromCol;
  int get lastToRow => _lastToRow;
  int get lastToCol => _lastToCol;

  static int encodePiece(int color, int type) => (color << 3) | type;
  static int getColor(int piece) => piece >> 3;
  static int getType(int piece) => piece & 0x7;

  String getPieceName(int piece) {
    if (piece == empty) return '';
    final t = getType(piece), c = getColor(piece);
    switch (t) {
      case king:   return c == red ? '帥' : '将';
      case advisor: return c == red ? '仕' : '士';
      case bishop: return c == red ? '相' : '象';
      case knight: return c == red ? '傌' : '馬';
      case rook:   return c == red ? '俥' : '車';
      case cannon: return c == red ? '炮' : '砲';
      case pawn:   return c == red ? '兵' : '卒';
      default: return '?';
    }
  }

  void setFlipped(bool flip) => _flipped = flip;

  void setStartingPlayer(int player) => _currentPlayer = player;

  void placeAllPieces([bool flip = false]) {
    for (int r = 0; r < rows; r++)
      for (int c = 0; c < cols; c++)
        _board[r][c] = empty;

    _flipped = flip;
    int topColor = flip ? red : black;
    int bottomColor = flip ? black : red;

    // 上方 (rows 0-4)
    _board[0][0] = encodePiece(topColor, rook);
    _board[0][1] = encodePiece(topColor, knight);
    _board[0][2] = encodePiece(topColor, bishop);
    _board[0][3] = encodePiece(topColor, advisor);
    _board[0][4] = encodePiece(topColor, king);
    _board[0][5] = encodePiece(topColor, advisor);
    _board[0][6] = encodePiece(topColor, bishop);
    _board[0][7] = encodePiece(topColor, knight);
    _board[0][8] = encodePiece(topColor, rook);
    _board[2][1] = encodePiece(topColor, cannon);
    _board[2][7] = encodePiece(topColor, cannon);
    _board[3][0] = encodePiece(topColor, pawn);
    _board[3][2] = encodePiece(topColor, pawn);
    _board[3][4] = encodePiece(topColor, pawn);
    _board[3][6] = encodePiece(topColor, pawn);
    _board[3][8] = encodePiece(topColor, pawn);

    // 下方 (rows 5-9)
    _board[9][0] = encodePiece(bottomColor, rook);
    _board[9][1] = encodePiece(bottomColor, knight);
    _board[9][2] = encodePiece(bottomColor, bishop);
    _board[9][3] = encodePiece(bottomColor, advisor);
    _board[9][4] = encodePiece(bottomColor, king);
    _board[9][5] = encodePiece(bottomColor, advisor);
    _board[9][6] = encodePiece(bottomColor, bishop);
    _board[9][7] = encodePiece(bottomColor, knight);
    _board[9][8] = encodePiece(bottomColor, rook);
    _board[7][1] = encodePiece(bottomColor, cannon);
    _board[7][7] = encodePiece(bottomColor, cannon);
    _board[6][0] = encodePiece(bottomColor, pawn);
    _board[6][2] = encodePiece(bottomColor, pawn);
    _board[6][4] = encodePiece(bottomColor, pawn);
    _board[6][6] = encodePiece(bottomColor, pawn);
    _board[6][8] = encodePiece(bottomColor, pawn);

    if (flip) {
      _redKingRow = 0; _redKingCol = 4;
      _blackKingRow = 9; _blackKingCol = 4;
    } else {
      _redKingRow = 9; _redKingCol = 4;
      _blackKingRow = 0; _blackKingCol = 4;
    }
  }

  List<int> _palaceRange(int color) {
    if (color == red) return _flipped ? [0, 2, 3, 5] : [7, 9, 3, 5];
    return _flipped ? [7, 9, 3, 5] : [0, 2, 3, 5];
  }

  List<List<int>> getLegalMoves(int row, int col) {
    final moves = <List<int>>[];
    final piece = _board[row][col];
    if (piece == empty || getColor(piece) != _currentPlayer) return moves;
    final t = getType(piece);
    switch (t) {
      case king:   _getKingMoves(row, col, piece, moves); break;
      case advisor: _getAdvisorMoves(row, col, piece, moves); break;
      case bishop: _getBishopMoves(row, col, piece, moves); break;
      case knight: _getKnightMoves(row, col, piece, moves); break;
      case rook:   _getRookMoves(row, col, piece, moves); break;
      case cannon: _getCannonMoves(row, col, piece, moves); break;
      case pawn:   _getPawnMoves(row, col, piece, moves); break;
    }
    return moves.where((m) => _isMoveLegal(row, col, m[0], m[1])).toList();
  }

  bool _isMoveLegal(int fr, int fc, int tr, int tc) {
    final captured = _board[tr][tc];
    _board[tr][tc] = _board[fr][fc];
    _board[fr][fc] = empty;
    final oldRedR = _redKingRow, oldRedC = _redKingCol;
    final oldBlackR = _blackKingRow, oldBlackC = _blackKingCol;
    final piece = _board[tr][tc];
    if (getType(piece) == king) {
      if (getColor(piece) == red) { _redKingRow = tr; _redKingCol = tc; }
      else { _blackKingRow = tr; _blackKingCol = tc; }
    }
    final inCheck = _isInCheck(_currentPlayer);
    _board[fr][fc] = _board[tr][tc];
    _board[tr][tc] = captured;
    _redKingRow = oldRedR; _redKingCol = oldRedC;
    _blackKingRow = oldBlackR; _blackKingCol = oldBlackC;
    return !inCheck;
  }

  bool _isInCheck(int color) {
    final kr = color == red ? _redKingRow : _blackKingRow;
    final kc = color == red ? _redKingCol : _blackKingCol;
    final enemy = color == red ? black : red;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final p = _board[r][c];
        if (p == empty || getColor(p) != enemy) continue;
        if (_canAttack(r, c, kr, kc, p)) return true;
      }
    }
    if (_redKingCol == _blackKingCol) {
      bool blocked = false;
      final minR = _redKingRow < _blackKingRow ? _redKingRow : _blackKingRow;
      final maxR = _redKingRow > _blackKingRow ? _redKingRow : _blackKingRow;
      for (int r = minR + 1; r < maxR; r++) {
        if (_board[r][_redKingCol] != empty) { blocked = true; break; }
      }
      if (!blocked) return true;
    }
    return false;
  }

  bool isInCheck(int color) => _isInCheck(color);

  bool _canAttack(int r, int c, int tr, int tc, int piece) {
    final t = getType(piece), dr = tr - r, dc = tc - c;
    final adr = dr.abs(), adc = dc.abs();
    switch (t) {
      case king: {
        final cc = getColor(piece);
        final palace = (cc == red) ? _palaceRange(black) : _palaceRange(red);
        if (adr <= 1 && adc <= 1 && adr + adc == 1 &&
            tr >= palace[0] && tr <= palace[1] && tc >= palace[2] && tc <= palace[3]) return true;
        return false;
      }
      case advisor: {
        final cc = getColor(piece);
        final palace = (cc == red) ? _palaceRange(black) : _palaceRange(red);
        if (adr == 1 && adc == 1 &&
            tr >= palace[0] && tr <= palace[1] && tc >= palace[2] && tc <= palace[3]) return true;
        return false;
      }
      case bishop:
        if (adr != 2 || adc != 2) return false;
        return _board[r + dr ~/ 2][c + dc ~/ 2] == empty;
      case knight:
        if (adr == 2 && adc == 1) return _board[r + (dr > 0 ? 1 : -1)][c] == empty;
        if (adr == 1 && adc == 2) return _board[r][c + (dc > 0 ? 1 : -1)] == empty;
        return false;
      case rook:
        return _isLineClear(r, c, tr, tc);
      case cannon:
        if (r != tr && c != tc) return false;
        int count = 0;
        if (r == tr) {
          for (int cc = (c < tc ? c + 1 : tc + 1); cc < (c < tc ? tc : c); cc++) {
            if (_board[r][cc] != empty) count++;
          }
        } else {
          for (int rr = (r < tr ? r + 1 : tr + 1); rr < (r < tr ? tr : r); rr++) {
            if (_board[rr][c] != empty) count++;
          }
        }
        return count == 1;
      case pawn: {
        final pColor = getColor(piece);
        final forward = (pColor == red) ? (_flipped ? 1 : -1) : (_flipped ? -1 : 1);
        if (dr == forward && dc == 0) return true;
        if (pColor == red) {
          if ((_flipped && r >= 5) || (!_flipped && r <= 4)) {
            if (dr == 0 && adc == 1) return true;
          }
        } else {
          if ((_flipped && r <= 4) || (!_flipped && r >= 5)) {
            if (dr == 0 && adc == 1) return true;
          }
        }
        return false;
      }
    }
    return false;
  }

  bool _isLineClear(int r, int c, int tr, int tc) {
    if (r == tr) {
      for (int cc = (c < tc ? c + 1 : tc + 1); cc < (c < tc ? tc : c); cc++) {
        if (_board[r][cc] != empty) return false;
      }
      return true;
    }
    if (c == tc) {
      for (int rr = (r < tr ? r + 1 : tr + 1); rr < (r < tr ? tr : r); rr++) {
        if (_board[rr][c] != empty) return false;
      }
      return true;
    }
    return false;
  }

  void _getKingMoves(int r, int c, int piece, List<List<int>> moves) {
    final color = getColor(piece);
    final pr = _palaceRange(color);
    const dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]];
    for (final d in dirs) {
      final nr = r + d[0], nc = c + d[1];
      if (nr < pr[0] || nr > pr[1] || nc < pr[2] || nc > pr[3]) continue;
      final target = _board[nr][nc];
      if (target == empty || getColor(target) != color) moves.add([nr, nc]);
    }
    if (_redKingCol == _blackKingCol) {
      final ekr = color == red ? _blackKingRow : _redKingRow;
      moves.add([ekr, c]);
    }
  }

  void _getAdvisorMoves(int r, int c, int piece, List<List<int>> moves) {
    final color = getColor(piece);
    final pr = _palaceRange(color);
    const dirs = [[1, 1], [1, -1], [-1, 1], [-1, -1]];
    for (final d in dirs) {
      final nr = r + d[0], nc = c + d[1];
      if (nr < pr[0] || nr > pr[1] || nc < pr[2] || nc > pr[3]) continue;
      final target = _board[nr][nc];
      if (target == empty || getColor(target) != color) moves.add([nr, nc]);
    }
  }

  void _getBishopMoves(int r, int c, int piece, List<List<int>> moves) {
    final color = getColor(piece);
    const dirs = [[2, 2], [2, -2], [-2, 2], [-2, -2]];
    for (final d in dirs) {
      final nr = r + d[0], nc = c + d[1];
      if (nr < 0 || nr > 9 || nc < 0 || nc > 8) continue;
      if (color == red) {
        if ((_flipped && nr > 4) || (!_flipped && nr < 5)) continue;
      } else {
        if ((_flipped && nr < 5) || (!_flipped && nr > 4)) continue;
      }
      if (_board[r + d[0] ~/ 2][c + d[1] ~/ 2] != empty) continue;
      final target = _board[nr][nc];
      if (target == empty || getColor(target) != color) moves.add([nr, nc]);
    }
  }

  void _getKnightMoves(int r, int c, int piece, List<List<int>> moves) {
    final color = getColor(piece);
    const movesDirs = [[2, 1], [2, -1], [-2, 1], [-2, -1], [1, 2], [1, -2], [-1, 2], [-1, -2]];
    const blocks = [[1, 0], [1, 0], [-1, 0], [-1, 0], [0, 1], [0, -1], [0, 1], [0, -1]];
    for (int i = 0; i < 8; i++) {
      final nr = r + movesDirs[i][0], nc = c + movesDirs[i][1];
      if (nr < 0 || nr > 9 || nc < 0 || nc > 8) continue;
      if (_board[r + blocks[i][0]][c + blocks[i][1]] != empty) continue;
      final target = _board[nr][nc];
      if (target == empty || getColor(target) != color) moves.add([nr, nc]);
    }
  }

  void _getRookMoves(int r, int c, int piece, List<List<int>> moves) {
    final color = getColor(piece);
    const dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]];
    for (final d in dirs) {
      int nr = r + d[0], nc = c + d[1];
      while (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
        final target = _board[nr][nc];
        if (target == empty) moves.add([nr, nc]);
        else {
          if (getColor(target) != color) moves.add([nr, nc]);
          break;
        }
        nr += d[0]; nc += d[1];
      }
    }
  }

  void _getCannonMoves(int r, int c, int piece, List<List<int>> moves) {
    final color = getColor(piece);
    const dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]];
    for (final d in dirs) {
      int nr = r + d[0], nc = c + d[1];
      bool jumped = false;
      while (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
        final target = _board[nr][nc];
        if (!jumped) {
          if (target == empty) moves.add([nr, nc]);
          else jumped = true;
        } else {
          if (target != empty) {
            if (getColor(target) != color) moves.add([nr, nc]);
            break;
          }
        }
        nr += d[0]; nc += d[1];
      }
    }
  }

  void _getPawnMoves(int r, int c, int piece, List<List<int>> moves) {
    final color = getColor(piece);
    final forward = (color == red) ? (_flipped ? 1 : -1) : (_flipped ? -1 : 1);
    final nr = r + forward;
    if (nr >= 0 && nr <= 9) {
      final target = _board[nr][c];
      if (target == empty || getColor(target) != color) moves.add([nr, c]);
    }
    bool crossed = false;
    if (color == red) crossed = _flipped ? (r >= 5) : (r <= 4);
    else crossed = _flipped ? (r <= 4) : (r >= 5);
    if (crossed) {
      for (final dc in [-1, 1]) {
        final nc = c + dc;
        if (nc < 0 || nc > 8) continue;
        final target = _board[r][nc];
        if (target == empty || getColor(target) != color) moves.add([r, nc]);
      }
    }
  }

  bool move(int fr, int fc, int tr, int tc) {
    if (_gameOver) return false;
    final piece = _board[fr][fc];
    if (piece == empty || getColor(piece) != _currentPlayer) return false;
    final legal = getLegalMoves(fr, fc);
    if (!legal.any((m) => m[0] == tr && m[1] == tc)) return false;

    _lastFromRow = fr; _lastFromCol = fc;
    _lastToRow = tr; _lastToCol = tc;
    _lastCaptured = _board[tr][tc];

    // 保存 undo 记录
    _undoStack.add(_MoveRecord(
      fr: fr, fc: fc, tr: tr, tc: tc,
      captured: _lastCaptured,
      prevRedKR: _redKingRow, prevRedKC: _redKingCol,
      prevBlackKR: _blackKingRow, prevBlackKC: _blackKingCol,
      prevPlayer: _currentPlayer, prevGameOver: _gameOver, prevWinner: _winner,
    ));

    _board[tr][tc] = piece;
    _board[fr][fc] = empty;
    if (getType(piece) == king) {
      if (getColor(piece) == red) { _redKingRow = tr; _redKingCol = tc; }
      else { _blackKingRow = tr; _blackKingCol = tc; }
    }
    if (getType(_lastCaptured) == king) {
      _gameOver = true; _winner = _currentPlayer;
      _listener?.onGameOver(_winner);
      return true;
    }
    _currentPlayer = (_currentPlayer == red) ? black : red;
    if (_isCheckmate(_currentPlayer)) {
      _gameOver = true;
      _winner = (_currentPlayer == red) ? black : red;
      _listener?.onGameOver(_winner);
    }
    _listener?.onPieceMoved(fr, fc, tr, tc, _board[tr][tc]);
    return true;
  }

  bool _isCheckmate(int color) {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final p = _board[r][c];
        if (p != empty && getColor(p) == color && getLegalMoves(r, c).isNotEmpty) return false;
      }
    }
    return true;
  }

  bool isCheckmate(int color) => _isCheckmate(color);

  void reset() {
    for (int r = 0; r < rows; r++)
      for (int c = 0; c < cols; c++)
        _board[r][c] = empty;
    _currentPlayer = red;
    _gameOver = false;
    _winner = empty;
    _flipped = false;
    _lastFromRow = _lastFromCol = _lastToRow = _lastToCol = -1;
    _lastCaptured = empty;
    _undoStack.clear();
    _listener?.onGameReset();
  }

  /// 回退一步棋（供 AI 搜索用）
  bool undo() {
    if (_undoStack.isEmpty) return false;
    final rec = _undoStack.removeLast();

    // 恢复棋盘
    _board[rec.fr][rec.fc] = _board[rec.tr][rec.tc];
    _board[rec.tr][rec.tc] = rec.captured;

    // 恢复将帅位置
    _redKingRow = rec.prevRedKR; _redKingCol = rec.prevRedKC;
    _blackKingRow = rec.prevBlackKR; _blackKingCol = rec.prevBlackKC;

    // 恢复游戏状态
    _currentPlayer = rec.prevPlayer;
    _gameOver = rec.prevGameOver;
    _winner = rec.prevWinner;

    // 恢复最后走子（用上一个记录的）
    if (_undoStack.isNotEmpty) {
      final prev = _undoStack.last;
      _lastFromRow = prev.fr; _lastFromCol = prev.fc;
      _lastToRow = prev.tr; _lastToCol = prev.tc;
      _lastCaptured = prev.captured;
    } else {
      _lastFromRow = _lastFromCol = _lastToRow = _lastToCol = -1;
      _lastCaptured = empty;
    }
    return true;
  }
}

abstract class OnGameListener {
  void onPieceMoved(int fromRow, int fromCol, int toRow, int toCol, int piece);
  void onGameOver(int winner);
  void onGameReset();
}

/// Undo 记录
class _MoveRecord {
  final int fr, fc, tr, tc, captured;
  final int prevRedKR, prevRedKC, prevBlackKR, prevBlackKC;
  final int prevPlayer;
  final bool prevGameOver;
  final int prevWinner;

  _MoveRecord({
    required this.fr, required this.fc, required this.tr, required this.tc,
    required this.captured,
    required this.prevRedKR, required this.prevRedKC,
    required this.prevBlackKR, required this.prevBlackKC,
    required this.prevPlayer,
    required this.prevGameOver, required this.prevWinner,
  });
}
