/// 五子棋游戏逻辑核心 — 1:1 移植自 GobangGame.java
class GobangGame {
  static const int boardSize = 15;
  static const int empty = 0;
  static const int black = 1;
  static const int white = 2;

  final List<List<int>> _board = List.generate(boardSize, (_) => List.filled(boardSize, empty));
  int _currentPlayer = black;
  bool _gameOver = false;
  int _winner = empty;

  int _lastRow = -1, _lastCol = -1;
  int _winStartRow = -1, _winStartCol = -1;
  int _winEndRow = -1, _winEndCol = -1;

  final List<List<int>> _moveHistory = [];

  OnGameListener? _listener;

  // 回调接口
  void setListener(OnGameListener l) => _listener = l;

  List<List<int>> get board => _board;
  int get currentPlayer => _currentPlayer;
  bool get isGameOver => _gameOver;
  int get winner => _winner;
  int get lastRow => _lastRow;
  int get lastCol => _lastCol;
  int get winStartRow => _winStartRow;
  int get winStartCol => _winStartCol;
  int get winEndRow => _winEndRow;
  int get winEndCol => _winEndCol;

  void setStartingPlayer(int player) => _currentPlayer = player;

  bool placePiece(int row, int col) {
    if (_gameOver) return false;
    if (row < 0 || row >= boardSize || col < 0 || col >= boardSize) return false;
    if (_board[row][col] != empty) return false;

    _board[row][col] = _currentPlayer;
    _lastRow = row;
    _lastCol = col;
    _moveHistory.add([row, col, _currentPlayer]);

    _listener?.onPiecePlaced(row, col, _currentPlayer);

    if (checkWin(row, col, _currentPlayer)) {
      _gameOver = true;
      _winner = _currentPlayer;
      _listener?.onGameOver(_winner, _winStartRow, _winStartCol, _winEndRow, _winEndCol);
      return true;
    }

    if (isBoardFull()) {
      _gameOver = true;
      _winner = empty;
      _listener?.onGameOver(empty, -1, -1, -1, -1);
      return true;
    }

    _currentPlayer = (_currentPlayer == black) ? white : black;
    return true;
  }

  bool isBoardFull() {
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (_board[r][c] == empty) return false;
      }
    }
    return true;
  }

  bool checkWin(int row, int col, int player) {
    const dirs = [[0, 1], [1, 0], [1, 1], [1, -1]];
    for (final d in dirs) {
      int count = 1;
      int dr = d[0], dc = d[1];

      int r1 = row + dr, c1 = col + dc;
      while (inBounds(r1, c1) && _board[r1][c1] == player) {
        count++;
        r1 += dr;
        c1 += dc;
      }
      int endR = r1 - dr, endC = c1 - dc;

      int r2 = row - dr, c2 = col - dc;
      while (inBounds(r2, c2) && _board[r2][c2] == player) {
        count++;
        r2 -= dr;
        c2 -= dc;
      }
      int startR = r2 + dr, startC = c2 + dc;

      if (count >= 5) {
        _winStartRow = startR;
        _winStartCol = startC;
        _winEndRow = endR;
        _winEndCol = endC;
        return true;
      }
    }
    return false;
  }

  bool inBounds(int r, int c) =>
      r >= 0 && r < boardSize && c >= 0 && c < boardSize;

  bool undo() {
    if (_gameOver || _moveHistory.isEmpty) return false;
    final last = _moveHistory.removeLast();
    final row = last[0], col = last[1];
    _board[row][col] = empty;
    _currentPlayer = last[2];

    if (_moveHistory.isNotEmpty) {
      final prev = _moveHistory.last;
      _lastRow = prev[0];
      _lastCol = prev[1];
    } else {
      _lastRow = -1;
      _lastCol = -1;
    }

    _listener?.onUndo(row, col);
    return true;
  }

  int get moveCount => _moveHistory.length;

  void reset() {
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        _board[r][c] = empty;
      }
    }
    _currentPlayer = black;
    _gameOver = false;
    _winner = empty;
    _lastRow = -1;
    _lastCol = -1;
    _moveHistory.clear();
    _listener?.onGameReset();
  }
}

abstract class OnGameListener {
  void onPiecePlaced(int row, int col, int player);
  void onGameOver(int winner, int startRow, int startCol, int endRow, int endCol);
  void onGameReset();
  void onUndo(int row, int col);
}
