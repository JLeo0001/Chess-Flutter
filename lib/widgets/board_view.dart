import 'dart:math';
import 'package:flutter/material.dart';
import '../gobang/gobang_game.dart';


/// 五子棋棋盘视图 — 1:1 移植自 BoardView.java
class GobangBoardView extends StatefulWidget {
  final GobangGame game;
  final ValueChanged<Offset>? onCellTouched;

  const GobangBoardView({super.key, required this.game, this.onCellTouched});

  @override
  State<GobangBoardView> createState() => _GobangBoardViewState();
}

class _GobangBoardViewState extends State<GobangBoardView>
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

    // 注册监听器（如原版 setListener）
    widget.game.setListener(_GameListener(
      onPiecePlaced: (row, col, player) {
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
        final boardSize = min(s.width, s.height);
        final padding = boardSize * 0.06;
        final cellSize = (boardSize - padding * 2) / (GobangGame.boardSize - 1);
        final gl = (s.width - (boardSize - padding * 2)) / 2;
        final gt = (s.height - (boardSize - padding * 2)) / 2;
        final col = ((d.localPosition.dx - gl) / cellSize).round();
        final row = ((d.localPosition.dy - gt) / cellSize).round();
        if (row >= 0 && row < GobangGame.boardSize && col >= 0 && col < GobangGame.boardSize) {
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
        painter: _GobangBoardPainter(
          game: widget.game, night: night,
          animRow: _animRow, animCol: _animCol, animProgress: _animProgress,
          previewRow: _previewRow, previewCol: _previewCol,
        ),
      ),
    );
  }
}

class _GobangBoardPainter extends CustomPainter {
  final GobangGame game; final bool night;
  final int animRow, animCol; final double animProgress;
  final int previewRow, previewCol;

  _GobangBoardPainter({required this.game, required this.night,
    required this.animRow, required this.animCol, required this.animProgress,
    required this.previewRow, required this.previewCol});

  @override
  void paint(Canvas canvas, Size size) {
    final boardSize = min(size.width, size.height);
    final padding = boardSize * 0.06;
    final boardArea = boardSize - padding * 2;
    final cellSize = boardArea / (GobangGame.boardSize - 1);
    final pieceRadius = cellSize * 0.4;
    final gridLeft = (size.width - boardArea) / 2;
    final gridTop = (size.height - boardArea) / 2;
    final bg = night ? const Color(0xFF1C1B1F) : const Color(0xFFFEF7FF);
    final variant = night ? const Color(0xFF49454F) : const Color(0xFFE7E0EC);
    final gridColor = night ? const Color(0xFF938F99) : const Color(0xFF79747E);

    canvas.drawColor(bg, BlendMode.src);

    // 棋盘背景
    final total = cellSize * (GobangGame.boardSize - 1);
    final rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(gridLeft - pieceRadius, gridTop - pieceRadius, total + pieceRadius * 2, total + pieceRadius * 2),
      Radius.circular(pieceRadius),
    );
    final bgPaint = Paint()..shader = LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [bg, variant],
    ).createShader(rRect.outerRect);
    canvas.drawRRect(rRect, bgPaint);
    canvas.drawRRect(rRect, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = variant);

    // 网格
    final gridPaint = Paint()..color = gridColor..strokeWidth = 1.5;
    for (int i = 0; i < GobangGame.boardSize; i++) {
      final pos = gridTop + i * cellSize;
      canvas.drawLine(Offset(gridLeft, pos), Offset(gridLeft + total, pos), gridPaint);
      canvas.drawLine(Offset(gridLeft + i * cellSize, gridTop), Offset(gridLeft + i * cellSize, gridTop + total), gridPaint);
    }

    // 星位
    const stars = [[3,3],[3,7],[3,11],[7,3],[7,7],[7,11],[11,3],[11,7],[11,11]];
    final starR = pieceRadius * 0.18;
    for (final s in stars) canvas.drawCircle(Offset(gridLeft + s[1] * cellSize, gridTop + s[0] * cellSize), starR, Paint()..color = gridColor);

    // 棋子
    final b = game.board;
    for (int r = 0; r < GobangGame.boardSize; r++) {
      for (int c = 0; c < GobangGame.boardSize; c++) {
        if (b[r][c] == GobangGame.empty) continue;
        final cx = gridLeft + c * cellSize, cy = gridTop + r * cellSize;
        double radius = pieceRadius;
        if (r == animRow && c == animCol && animProgress < 1.0) radius = max(pieceRadius * _easeOutBack(animProgress), 1.0);
        _drawPiece(canvas, cx, cy, radius, b[r][c]);
      }
    }

    // 最后落子标记
    if (game.lastRow >= 0 && game.lastCol >= 0 && !(game.lastRow == animRow && game.lastCol == animCol && animProgress < 1.0)) {
      canvas.drawCircle(Offset(gridLeft + game.lastCol * cellSize, gridTop + game.lastRow * cellSize), pieceRadius + 4,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = const Color(0xFFB3261E));
    }

    // 预览
    if (previewRow >= 0 && previewCol >= 0 && !game.isGameOver && b[previewRow][previewCol] == GobangGame.empty) {
      final cp = game.currentPlayer;
      final p = Paint();
      p.color = (cp == GobangGame.black) ? const Color(0xFF1C1B1F).withAlpha(80) : Colors.white.withAlpha(80);
      canvas.drawCircle(Offset(gridLeft + previewCol * cellSize, gridTop + previewRow * cellSize), pieceRadius, p);
    }

    // 胜利连线
    if (game.isGameOver && game.winner != GobangGame.empty) {
      canvas.drawLine(
        Offset(gridLeft + game.winStartCol * cellSize, gridTop + game.winStartRow * cellSize),
        Offset(gridLeft + game.winEndCol * cellSize, gridTop + game.winEndRow * cellSize),
        Paint()..color = const Color(0xFFB3261E)..strokeWidth = 5..strokeCap = StrokeCap.round);
    }
  }

  void _drawPiece(Canvas c, double cx, double cy, double r, int player) {
    if (player == GobangGame.black) {
      final p = Paint()..shader = RadialGradient(
        center: Alignment(-0.3, -0.3), radius: 1,
        colors: [const Color(0xFF5C5B60), const Color(0xFF1C1B1F)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      c.drawCircle(Offset(cx, cy), r, p);
      c.drawCircle(Offset(cx, cy), r, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0xFF49454F));
    } else {
      final p = Paint()..shader = RadialGradient(
        center: Alignment(-0.3, -0.3), radius: 1,
        colors: [Colors.white, const Color(0xFFE8E8E8)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      c.drawCircle(Offset(cx, cy), r, p);
      c.drawCircle(Offset(cx, cy), r, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0xFF49454F));
    }
  }

  double _easeOutBack(double t) {
    const c1 = 1.70158, c3 = c1 + 1;
    return 1 + c3 * pow(t - 1, 3).toDouble() + c1 * pow(t - 1, 2).toDouble();
  }

  @override
  bool shouldRepaint(covariant _GobangBoardPainter old) => true;
}

/// 游戏监听器适配
class _GameListener extends OnGameListener {
  final void Function(int row, int col, int player) cbPiecePlaced;
  final VoidCallback cbGameReset;
  final void Function(int row, int col) cbUndo;

  _GameListener({required void Function(int row, int col, int player) onPiecePlaced,
    required VoidCallback onGameReset,
    required void Function(int row, int col) onUndo})
    : cbPiecePlaced = onPiecePlaced, cbGameReset = onGameReset, cbUndo = onUndo;

  @override void onPiecePlaced(int row, int col, int player) => cbPiecePlaced(row, col, player);
  @override void onGameOver(int winner, int startRow, int startCol, int endRow, int endCol) {}
  @override void onGameReset() => cbGameReset();
  @override void onUndo(int row, int col) => cbUndo(row, col);
}
