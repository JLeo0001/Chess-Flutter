import 'ttt_game.dart';

/// 井字棋 AI — 1:1 移植自 TicTacToeAI.java
class TicTacToeAI {
  static const int boardSize = 3;
  final int aiColor;
  final int opponentColor;

  TicTacToeAI(this.aiColor)
      : opponentColor = (aiColor == TicTacToeGame.x)
            ? TicTacToeGame.o
            : TicTacToeGame.x;

  List<int>? findBestMove(List<List<int>> board) {
    int bestScore = -1;
    int bestR = -1, bestC = -1;

    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (board[r][c] != TicTacToeGame.empty) continue;
        int score = evaluate(board, r, c);
        if (score > bestScore) {
          bestScore = score;
          bestR = r;
          bestC = c;
        }
      }
    }
    return (bestR == -1) ? null : [bestR, bestC];
  }

  int evaluate(List<List<int>> board, int row, int col) {
    if (board[row][col] != TicTacToeGame.empty) return -1;

    int score = 0;

    board[row][col] = aiColor;
    if (checkWinAt(board, row, col, aiColor)) {
      board[row][col] = TicTacToeGame.empty;
      return 10000;
    }
    board[row][col] = TicTacToeGame.empty;

    board[row][col] = opponentColor;
    if (checkWinAt(board, row, col, opponentColor)) {
      board[row][col] = TicTacToeGame.empty;
      return 5000;
    }
    board[row][col] = TicTacToeGame.empty;

    const dirs = [[0, 1], [1, 0], [1, 1], [1, -1]];
    for (final d in dirs) {
      board[row][col] = aiColor;
      int myCount = countDirection(board, row, col, d[0], d[1], aiColor);
      score += scoreCount(myCount, true);
      board[row][col] = TicTacToeGame.empty;

      board[row][col] = opponentColor;
      int oppCount = countDirection(board, row, col, d[0], d[1], opponentColor);
      score += scoreCount(oppCount, false);
      board[row][col] = TicTacToeGame.empty;
    }

    score += positionBonus(row, col);
    return score;
  }

  int scoreCount(int count, bool isOffense) {
    if (isOffense) {
      if (count >= 3) return 1000;
      if (count == 2) return 100;
      if (count == 1) return 10;
    } else {
      if (count >= 3) return 500;
      if (count == 2) return 80;
      if (count == 1) return 5;
    }
    return 0;
  }

  int countDirection(List<List<int>> board, int row, int col, int dr, int dc, int color) {
    int count = 1;
    int r = row + dr, c = col + dc;
    while (inBounds(r, c) && board[r][c] == color) {
      count++;
      r += dr;
      c += dc;
    }
    r = row - dr;
    c = col - dc;
    while (inBounds(r, c) && board[r][c] == color) {
      count++;
      r -= dr;
      c -= dc;
    }
    return count;
  }

  bool checkWinAt(List<List<int>> board, int row, int col, int color) {
    const dirs = [[0, 1], [1, 0], [1, 1], [1, -1]];
    for (final d in dirs) {
      int count = 1;
      int r = row + d[0], c = col + d[1];
      while (inBounds(r, c) && board[r][c] == color) {
        count++;
        r += d[0];
        c += d[1];
      }
      r = row - d[0];
      c = col - d[1];
      while (inBounds(r, c) && board[r][c] == color) {
        count++;
        r -= d[0];
        c -= d[1];
      }
      if (count >= 3) return true;
    }
    return false;
  }

  int positionBonus(int row, int col) {
    if (row == 1 && col == 1) return 10;
    if ((row == 0 || row == 2) && (col == 0 || col == 2)) return 5;
    return 3;
  }

  bool inBounds(int r, int c) =>
      r >= 0 && r < boardSize && c >= 0 && c < boardSize;
}
