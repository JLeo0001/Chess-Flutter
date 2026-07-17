import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../tictactoe/ttt_game.dart';

/// 井字棋棋盘视图 — 直接转译自 TicTacToeView.java
class TicTacToeBoardView extends StatefulWidget {
  final TicTacToeGame game;
  final ValueChanged<Offset>? onCellTouched;
  const TicTacToeBoardView({super.key, required this.game, this.onCellTouched});

  @override
  State<TicTacToeBoardView> createState() => _TicTacToeBoardViewState();
}

class _TicTacToeBoardViewState extends State<TicTacToeBoardView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  int _animRow = -1, _animCol = -1;
  double _animProgress = 1.0;
  int _previewRow = -1, _previewCol = -1;

  double _winLineSx = 0, _winLineSy = 0, _winLineEx = 0, _winLineEy = 0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() => setState(() => _animProgress = _animCtrl.value));

    widget.game.setListener(_TTTListener(
      onPiecePlaced: (row, col, player) {
        _animRow = row;
        _animCol = col;
        _animCtrl.forward(from: 0);
      },
      onGameOver: (winner, sr, sc, er, ec) {
        if (sr >= 0 && sc >= 0 && er >= 0 && ec >= 0) {
          _winLineSx = sr.toDouble();
          _winLineSy = sc.toDouble();
          _winLineEx = er.toDouble();
          _winLineEy = ec.toDouble();
        }
      },
      onGameReset: () {
        _animRow = -1;
        _animCol = -1;
        _animCtrl.reset();
        _winLineSx = _winLineSy = _winLineEx = _winLineEy = 0;
        setState(() => _animProgress = 1.0);
      },
    ));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Color _xColor(bool night) =>
      night ? const Color(0xFFFFB4AB) : const Color(0xFFC62828);
  Color _oColor(bool night) =>
      night ? const Color(0xFF89CFF0) : const Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final size = math.min(w, h);
        final padding = size * 0.08;
        final boardSize = size - padding * 2;
        final cellSize = boardSize / TicTacToeGame.boardSize;
        final piecePadding = cellSize * 0.22;
        final gl = (w - boardSize) / 2;
        final gt = (h - boardSize) / 2;

        // 胜利连线坐标（需要格子坐标转像素）
        final winLineSx = _winLineSx >= 0
            ? gl + _winLineSy * cellSize + cellSize / 2
            : 0.0;
        final winLineSy = _winLineSy >= 0
            ? gt + _winLineSx * cellSize + cellSize / 2
            : 0.0;
        final winLineEx = _winLineEx >= 0
            ? gl + _winLineEy * cellSize + cellSize / 2
            : 0.0;
        final winLineEy = _winLineEy >= 0
            ? gt + _winLineEx * cellSize + cellSize / 2
            : 0.0;

        return GestureDetector(
          onTapDown: (d) {
            final col = ((d.localPosition.dx - gl) / cellSize).floor();
            final row = ((d.localPosition.dy - gt) / cellSize).floor();
            if (row >= 0 &&
                row < TicTacToeGame.boardSize &&
                col >= 0 &&
                col < TicTacToeGame.boardSize) {
              setState(() {
                _previewRow = row;
                _previewCol = col;
              });
            }
          },
          onTapUp: (d) {
            if (_previewRow >= 0 && _previewCol >= 0) {
              widget.onCellTouched
                  ?.call(Offset(_previewRow.toDouble(), _previewCol.toDouble()));
            }
            setState(() {
              _previewRow = -1;
              _previewCol = -1;
            });
          },
          onTapCancel: () =>
              setState(() { _previewRow = -1; _previewCol = -1; }),
          child: CustomPaint(
            size: Size.infinite,
            painter: _TTTPainter(
              game: widget.game,
              night: night,
              cellSize: cellSize,
              piecePadding: piecePadding,
              gl: gl,
              gt: gt,
              boardSize: boardSize,
              animRow: _animRow,
              animCol: _animCol,
              animProgress: _animProgress,
              previewRow: _previewRow,
              previewCol: _previewCol,
              winLineSx: winLineSx,
              winLineSy: winLineSy,
              winLineEx: winLineEx,
              winLineEy: winLineEy,
              xColor: _xColor(night),
              oColor: _oColor(night),
            ),
          ),
        );
      },
    );
  }
}

class _TTTPainter extends CustomPainter {
  final TicTacToeGame game;
  final bool night;
  final double cellSize, piecePadding, gl, gt, boardSize;
  final int animRow, animCol;
  final double animProgress;
  final int previewRow, previewCol;
  final double winLineSx, winLineSy, winLineEx, winLineEy;
  final Color xColor, oColor;

  _TTTPainter({
    required this.game,
    required this.night,
    required this.cellSize,
    required this.piecePadding,
    required this.gl,
    required this.gt,
    required this.boardSize,
    required this.animRow,
    required this.animCol,
    required this.animProgress,
    required this.previewRow,
    required this.previewCol,
    required this.winLineSx,
    required this.winLineSy,
    required this.winLineEx,
    required this.winLineEy,
    required this.xColor,
    required this.oColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = night ? const Color(0xFF1C1B1F) : const Color(0xFFFEF7FF);
    final gridColor =
        night ? const Color(0xFF938F99) : const Color(0xFF79747E);
    final boardArea = cellSize * TicTacToeGame.boardSize;

    canvas.drawColor(bg, BlendMode.src);

    // 网格线（原版 TicTacToeView.java drawGrid）
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (int i = 1; i < TicTacToeGame.boardSize; i++) {
      final pos = gt + i * cellSize;
      canvas.drawLine(Offset(gl, pos), Offset(gl + boardArea, pos), gridPaint);
      canvas.drawLine(Offset(gl + i * cellSize, gt),
          Offset(gl + i * cellSize, gt + boardArea), gridPaint);
    }
    // 外边框
    canvas.drawRect(Rect.fromLTWH(gl, gt, boardArea, boardArea), gridPaint);

    // 棋子（原版 drawPieces）
    final b = game.board;
    for (int r = 0; r < TicTacToeGame.boardSize; r++) {
      for (int c = 0; c < TicTacToeGame.boardSize; c++) {
        if (b[r][c] == TicTacToeGame.empty) continue;
        final cx = gl + c * cellSize + cellSize / 2;
        final cy = gt + r * cellSize + cellSize / 2;
        double scale = 1.0;
        if (r == animRow && c == animCol && animProgress < 1.0) {
          scale = _easeOutBack(animProgress);
        }
        if (b[r][c] == TicTacToeGame.x) {
          _drawX(canvas, cx, cy, scale);
        } else {
          _drawO(canvas, cx, cy, scale);
        }
      }
    }

    // 胜利连线（原版 drawWinLine）
    if (game.isGameOver &&
        game.winner != TicTacToeGame.empty &&
        winLineSx != 0) {
      canvas.drawLine(
        Offset(winLineSx, winLineSy),
        Offset(winLineEx, winLineEy),
        Paint()
          ..color = const Color(0xFFB3261E)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }

    // 预览（原版 drawPreview）
    if (previewRow >= 0 &&
        previewCol >= 0 &&
        !game.isGameOver &&
        b[previewRow][previewCol] == TicTacToeGame.empty) {
      final cx = gl + previewCol * cellSize + cellSize / 2;
      final cy = gt + previewRow * cellSize + cellSize / 2;
      final cp = game.currentPlayer;
      final half = (cellSize / 2 - piecePadding) * 0.707;
      if (cp == TicTacToeGame.x) {
        final p = Paint()
          ..color = xColor.withAlpha(60)
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
            Offset(cx - half, cy - half), Offset(cx + half, cy + half), p);
        canvas.drawLine(
            Offset(cx + half, cy - half), Offset(cx - half, cy + half), p);
      } else {
        canvas.drawCircle(
            Offset(cx, cy),
            cellSize / 2 - piecePadding,
            Paint()
              ..color = oColor.withAlpha(60)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 7);
      }
    }
  }

  void _drawX(Canvas c, double cx, double cy, double scale) {
    final half = (cellSize / 2 - piecePadding) * scale;
    final offset = half * 0.707;
    c.save();
    c.translate(cx, cy);
    final p = Paint()
      ..color = xColor
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    c.drawLine(const Offset(0, 0) - Offset(offset, offset),
        const Offset(0, 0) + Offset(offset, offset), p);
    c.drawLine(const Offset(0, 0) + Offset(offset, -offset),
        const Offset(0, 0) - Offset(offset, -offset), p);
    c.restore();
  }

  void _drawO(Canvas c, double cx, double cy, double scale) {
    final radius = (cellSize / 2 - piecePadding) * scale;
    c.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = oColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7);
  }

  double _easeOutBack(double t) {
    const c1 = 1.70158, c3 = c1 + 1;
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2);
  }

  @override
  bool shouldRepaint(covariant _TTTPainter old) => true;
}

class _TTTListener extends OnGameListener {
  final void Function(int row, int col, int player) cbPiecePlaced;
  final void Function(int winner, int sr, int sc, int er, int ec) cbGameOver;
  final VoidCallback cbGameReset;

  _TTTListener({
    required void Function(int row, int col, int player) onPiecePlaced,
    required void Function(int winner, int sr, int sc, int er, int ec)
        onGameOver,
    required VoidCallback onGameReset,
  })  : cbPiecePlaced = onPiecePlaced,
        cbGameOver = onGameOver,
        cbGameReset = onGameReset;

  @override
  void onPiecePlaced(int row, int col, int player) =>
      cbPiecePlaced(row, col, player);
  @override
  void onGameOver(int winner, int sr, int sc, int er, int ec) =>
      cbGameOver(winner, sr, sc, er, ec);
  @override
  void onGameReset() => cbGameReset();
}
