import 'dart:math';
import 'package:flutter/material.dart';
import '../go/go_game.dart';

/// 围棋棋盘视图
class GoBoardView extends StatefulWidget {
  final GoGame game;
  final ValueChanged<Offset>? onCellTouched;

  const GoBoardView({super.key, required this.game, this.onCellTouched});

  @override
  State<GoBoardView> createState() => _GoBoardViewState();
}

class _GoBoardViewState extends State<GoBoardView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  int _animRow = -1, _animCol = -1;
  double _animProgress = 1.0;
  int _previewRow = -1, _previewCol = -1;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() => setState(() => _animProgress = _animCtrl.value));

    widget.game.setListener(_GoGameListener(
      onStonePlaced: (row, col, player) {
        _animRow = row;
        _animCol = col;
        _animCtrl.forward(from: 0);
      },
      onGameReset: () {
        _animRow = -1;
        _animCol = -1;
        _animCtrl.reset();
        setState(() => _animProgress = 1.0);
      },
      onUndo: (row, col) {
        _animRow = -1;
        _animCol = -1;
        _animCtrl.reset();
        setState(() => _animProgress = 1.0);
      },
    ));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onPanDown: (d) {
        final s = context.size!;
        final bs = min(s.width, s.height);
        final padding = bs * 0.04;
        final cellSize = (bs - padding * 2) / (widget.game.boardSize - 1);
        final total = cellSize * (widget.game.boardSize - 1);
        final gl = (s.width - total) / 2;
        final gt = (s.height - total) / 2;
        final col = ((d.localPosition.dx - gl) / cellSize).round();
        final row = ((d.localPosition.dy - gt) / cellSize).round();
        final sz = widget.game.boardSize;
        if (row >= 0 && row < sz && col >= 0 && col < sz) {
          setState(() { _previewRow = row; _previewCol = col; });
        }
      },
      onPanEnd: (_) {
        if (_previewRow >= 0 && _previewCol >= 0) {
          widget.onCellTouched?.call(Offset(_previewRow.toDouble(), _previewCol.toDouble()));
        }
        setState(() { _previewRow = -1; _previewCol = -1; });
      },
      onPanCancel: () => setState(() { _previewRow = -1; _previewCol = -1; }),
      child: CustomPaint(
        size: Size.infinite,
        painter: _GoBoardPainter(
          boardSize: widget.game.boardSize,
          board: widget.game.board,
          lastRow: widget.game.lastRow,
          lastCol: widget.game.lastCol,
          currentPlayer: widget.game.currentPlayer,
          isGameOver: widget.game.isGameOver,
          capturedBlack: widget.game.capturedBlack,
          capturedWhite: widget.game.capturedWhite,
          night: night,
          animRow: _animRow, animCol: _animCol, animProgress: _animProgress,
          previewRow: _previewRow, previewCol: _previewCol,
        ),
      ),
    );
  }
}

class _GoBoardPainter extends CustomPainter {
  final int boardSize;
  final List<List<int>> board;
  final int lastRow, lastCol;
  final int currentPlayer;
  final bool isGameOver;
  final int capturedBlack, capturedWhite;
  final bool night;
  final int animRow, animCol;
  final double animProgress;
  final int previewRow, previewCol;

  _GoBoardPainter({
    required this.boardSize,
    required this.board,
    required this.lastRow, required this.lastCol,
    required this.currentPlayer,
    required this.isGameOver,
    required this.capturedBlack, required this.capturedWhite,
    required this.night,
    required this.animRow, required this.animCol, required this.animProgress,
    required this.previewRow, required this.previewCol,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = min(size.width, size.height);
    final padding = total * 0.04;
    final boardArea = total - padding * 2;
    final cellSize = boardArea / (boardSize - 1);
    final pieceRadius = cellSize * 0.42;
    final gridLeft = (size.width - boardArea) / 2;
    final gridTop = (size.height - boardArea) / 2;

    // 棋盘背景 — 木色质感
    final boardBg = night
        ? const Color(0xFF2B2930)
        : const Color(0xFFDCB879);
    final boardBgDark = night
        ? const Color(0xFF222128)
        : const Color(0xFFC8A56A);
    final rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(gridLeft - pieceRadius, gridTop - pieceRadius,
          boardArea + pieceRadius * 2, boardArea + pieceRadius * 2),
      Radius.circular(pieceRadius),
    );
    final bgPaint = Paint()..shader = LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [boardBg, boardBgDark],
    ).createShader(rRect.outerRect);
    canvas.drawRRect(rRect, bgPaint);
    canvas.drawRRect(rRect, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = night ? const Color(0xFF49454F) : const Color(0xFFB8956A));

    // 网格
    final gridColor = night ? const Color(0xFF938F99) : const Color(0xFF6B4226);
    final gridPaint = Paint()..color = gridColor..strokeWidth = 0.8;
    for (int i = 0; i < boardSize; i++) {
      final pos = gridTop + i * cellSize;
      canvas.drawLine(Offset(gridLeft, pos), Offset(gridLeft + boardArea, pos), gridPaint);
      canvas.drawLine(Offset(gridLeft + i * cellSize, gridTop),
          Offset(gridLeft + i * cellSize, gridTop + boardArea), gridPaint);
    }

    // 星位
    final stars = _getStarPoints(boardSize);
    final starR = pieceRadius * 0.2;
    for (final s in stars) {
      canvas.drawCircle(
        Offset(gridLeft + s[1] * cellSize, gridTop + s[0] * cellSize),
        starR, Paint()..color = gridColor);
    }

    // 棋子
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (board[r][c] == GoGame.empty) continue;
        final cx = gridLeft + c * cellSize, cy = gridTop + r * cellSize;
        double radius = pieceRadius;
        if (r == animRow && c == animCol && animProgress < 1.0) {
          radius = max(pieceRadius * _easeOutBack(animProgress), 1.0);
        }
        _drawStone(canvas, cx, cy, radius, board[r][c]);
      }
    }

    // 最后落子标记（小红点）
    if (lastRow >= 0 && lastCol >= 0) {
      final lx = gridLeft + lastCol * cellSize;
      final ly = gridTop + lastRow * cellSize;
      if (!(lastRow == animRow && lastCol == animCol && animProgress < 1.0)) {
        canvas.drawCircle(Offset(lx, ly), pieceRadius * 0.25,
          Paint()..color = const Color(0xFFB3261E));
      }
    }

    // 预览半透明棋子
    if (previewRow >= 0 && previewCol >= 0 && !isGameOver &&
        board[previewRow][previewCol] == GoGame.empty) {
      final cx = gridLeft + previewCol * cellSize;
      final cy = gridTop + previewRow * cellSize;
      final p = Paint();
      p.color = (currentPlayer == GoGame.black)
          ? const Color(0xFF1C1B1F).withAlpha(60)
          : Colors.white.withAlpha(60);
      canvas.drawCircle(Offset(cx, cy), pieceRadius, p);
    }

    // 棋盘下方显示提子数
    final textStyle = TextStyle(
      color: night ? Colors.white70 : Colors.black54,
      fontSize: cellSize * 0.5,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: '● $capturedWhite   ○ $capturedBlack',
        style: textStyle,
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(
      gridLeft + boardArea / 2 - tp.width / 2,
      gridTop + boardArea + padding * 0.5,
    ));
  }

  void _drawStone(Canvas c, double cx, double cy, double r, int player) {
    if (player == GoGame.black) {
      final p = Paint()..shader = RadialGradient(
        center: Alignment(-0.3, -0.3), radius: 1,
        colors: [const Color(0xFF5C5B60), const Color(0xFF1C1B1F)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      c.drawCircle(Offset(cx, cy), r, p);
      c.drawCircle(Offset(cx, cy), r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF49454F));
    } else {
      final p = Paint()..shader = RadialGradient(
        center: Alignment(-0.3, -0.3), radius: 1,
        colors: [Colors.white, const Color(0xFFE8E8E8)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      c.drawCircle(Offset(cx, cy), r, p);
      c.drawCircle(Offset(cx, cy), r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFB0B0B0));
    }
  }

  List<List<int>> _getStarPoints(int size) {
    if (size == 19) {
      return [
        [3, 3], [3, 9], [3, 15],
        [9, 3], [9, 9], [9, 15],
        [15, 3], [15, 9], [15, 15],
      ];
    } else if (size == 13) {
      return [
        [3, 3], [3, 9], [6, 6],
        [9, 3], [9, 9],
      ];
    } else if (size == 9) {
      return [
        [2, 2], [2, 6], [4, 4], [6, 2], [6, 6],
      ];
    }
    return [];
  }

  double _easeOutBack(double t) {
    const c1 = 1.70158, c3 = c1 + 1;
    return 1 + c3 * pow(t - 1, 3).toDouble() + c1 * pow(t - 1, 2).toDouble();
  }

  @override
  bool shouldRepaint(covariant _GoBoardPainter old) => true;
}

class _GoGameListener extends OnGoGameListener {
  final void Function(int row, int col, int player) cbStonePlaced;
  final VoidCallback cbGameReset;
  final void Function(int row, int col) cbUndo;

  _GoGameListener({
    required void Function(int row, int col, int player) onStonePlaced,
    required VoidCallback onGameReset,
    required void Function(int row, int col) onUndo,
  })  : cbStonePlaced = onStonePlaced,
        cbGameReset = onGameReset,
        cbUndo = onUndo;

  @override
  void onStonePlaced(int row, int col, int player) => cbStonePlaced(row, col, player);
  @override
  void onGameOver(int winner, int startRow, int startCol, int endRow, int endCol) {}
  @override
  void onGameReset() => cbGameReset();
  @override
  void onUndo(int row, int col) => cbUndo(row, col);
}
