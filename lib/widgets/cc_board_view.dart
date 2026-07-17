import 'dart:math';
import 'package:flutter/material.dart';
import '../chinese_chess/cc_game.dart';

/// 中国象棋棋盘视图 — 1:1 移植自 ChineseChessView.java
class ChineseChessBoardView extends StatefulWidget {
  final ChineseChessGame game;
  final ValueChanged<int>? onCellTouched;
  final int? selectedRow, selectedCol;
  final List<List<int>>? legalMoves;

  const ChineseChessBoardView({
    super.key, required this.game, this.onCellTouched,
    this.selectedRow, this.selectedCol, this.legalMoves,
  });

  @override
  State<ChineseChessBoardView> createState() => ChineseChessBoardViewState();
}

class ChineseChessBoardViewState extends State<ChineseChessBoardView>
    with SingleTickerProviderStateMixin {
  // 动画
  bool _animating = false;
  int _animFromRow = -1, _animFromCol = -1;
  int _animToRow = -1, _animToCol = -1;
  double _animProgress = 1.0;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() => setState(() => _animProgress = _animCtrl.value));
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  void startMoveAnimation(int fromRow, int fromCol, int toRow, int toCol, VoidCallback onEnd) {
    _animFromRow = fromRow; _animFromCol = fromCol;
    _animToRow = toRow; _animToCol = toCol;
    _animating = true;
    _animProgress = 0.0;
    _animCtrl.forward(from: 0).then((_) {
      _animating = false;
      _animFromRow = -1; _animFromCol = -1;
      _animToRow = -1; _animToCol = -1;
      _animProgress = 1.0;
      onEnd();
    });
  }

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTapDown: (details) {
        final pos = _getCell(details.localPosition, context);
        if (pos != null) widget.onCellTouched?.call(pos);
      },
      child: CustomPaint(
        size: Size.infinite,
        painter: _ChineseChessPainter(
          game: widget.game, night: night,
          selectedRow: widget.selectedRow, selectedCol: widget.selectedCol,
          legalMoves: widget.legalMoves,
          animating: _animating, animFromRow: _animFromRow, animFromCol: _animFromCol,
          animToRow: _animToRow, animToCol: _animToCol, animProgress: _animProgress,
        ),
      ),
    );
  }

  int? _getCell(Offset localPos, BuildContext context) {
    final size = context.size!;
    final boardSize = min(size.width, size.height);
    final padding = boardSize * 0.08;
    final cellSize = (boardSize - padding * 2) / (ChineseChessGame.cols - 1);
    final gl = (size.width - (boardSize - padding * 2)) / 2;
    final gt = (size.height - (boardSize - padding * 2)) / 2;
    final col = ((localPos.dx - gl) / cellSize).round();
    final row = ((localPos.dy - gt) / cellSize).round();
    if (row >= 0 && row < ChineseChessGame.rows && col >= 0 && col < ChineseChessGame.cols) {
      // 避免太偏远的点击被误判
      final dx = localPos.dx - (gl + col * cellSize);
      final dy = localPos.dy - (gt + row * cellSize);
      if (dx * dx + dy * dy > cellSize * cellSize * 0.3) return null;
      return (row << 4) | col;
    }
    return null;
  }
}

class _ChineseChessPainter extends CustomPainter {
  final ChineseChessGame game; final bool night;
  final int? selectedRow, selectedCol;
  final List<List<int>>? legalMoves;
  final bool animating;
  final int animFromRow, animFromCol, animToRow, animToCol;
  final double animProgress;

  _ChineseChessPainter({required this.game, required this.night,
    this.selectedRow, this.selectedCol, this.legalMoves,
    required this.animating, required this.animFromRow, required this.animFromCol,
    required this.animToRow, required this.animToCol, required this.animProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final boardSize = min(size.width, size.height);
    final padding = boardSize * 0.08;
    final boardArea = boardSize - padding * 2;
    final cellSize = boardArea / (ChineseChessGame.cols - 1);
    final pieceRadius = cellSize * 0.42; // 原版 0.42
    final gl = (size.width - boardArea) / 2;
    final gt = (size.height - boardArea) / 2;

    final bg = night ? const Color(0xFF2B2930) : const Color(0xFFF5DEB3);
    canvas.drawColor(bg, BlendMode.src);

    // 外框
    final outerPaint = Paint()..color = night ? const Color(0xFF4A4458) : const Color(0xFF4E342E)
      ..style = PaintingStyle.stroke..strokeWidth = 4;
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(gl - cellSize * 0.7, gt - cellSize * 0.7,
        (ChineseChessGame.cols - 1) * cellSize + cellSize * 1.4,
        (ChineseChessGame.rows - 1) * cellSize + cellSize * 1.4),
      Radius.circular(cellSize * 0.15)), outerPaint);

    // 内背景
    final innerBgPaint = Paint()..color = night ? const Color(0xFF3B383E) : const Color(0xFFF5DEB3);
    canvas.drawRect(Rect.fromLTWH(gl - cellSize * 0.5, gt - cellSize * 0.5,
      (ChineseChessGame.cols - 1) * cellSize + cellSize,
      (ChineseChessGame.rows - 1) * cellSize + cellSize), innerBgPaint);

    final lineColor = night ? const Color(0xFF938F99) : const Color(0xFF5D4037);
    final gridPaint = Paint()..color = lineColor..strokeWidth = 2;
    final gridFillPaint = Paint()..color = lineColor..style = PaintingStyle.stroke..strokeWidth = 2;

    // 网格线
    canvas.drawRect(Rect.fromLTWH(gl, gt, (ChineseChessGame.cols - 1) * cellSize, (ChineseChessGame.rows - 1) * cellSize), gridFillPaint);

    for (int r = 0; r < ChineseChessGame.rows; r++) {
      final y = gt + r * cellSize;
      canvas.drawLine(Offset(gl, y), Offset(gl + (ChineseChessGame.cols - 1) * cellSize, y),
        Paint()..color = lineColor..strokeWidth = 1.2);
    }

    for (int c = 0; c < ChineseChessGame.cols; c++) {
      final x = gl + c * cellSize;
      if (c == 0 || c == ChineseChessGame.cols - 1) {
        canvas.drawLine(Offset(x, gt), Offset(x, gt + 9 * cellSize), gridPaint);
      } else {
        canvas.drawLine(Offset(x, gt), Offset(x, gt + 4 * cellSize), gridPaint);
        canvas.drawLine(Offset(x, gt + 5 * cellSize), Offset(x, gt + 9 * cellSize), gridPaint);
      }
    }

    // 楚河汉界 — 左"楚 河"右"汉 界"，照搬原版
    final riverPaint = TextStyle(color: lineColor, fontSize: cellSize * 0.4);
    final tpLeft = TextPainter(
      text: TextSpan(text: '楚  河', style: riverPaint),
      textDirection: TextDirection.ltr,
    )..layout();
    tpLeft.paint(canvas, Offset(gl + 2 * cellSize - tpLeft.width / 2, gt + 4.5 * cellSize - tpLeft.height / 2));
    final tpRight = TextPainter(
      text: TextSpan(text: '汉  界', style: riverPaint),
      textDirection: TextDirection.ltr,
    )..layout();
    tpRight.paint(canvas, Offset(gl + 6 * cellSize - tpRight.width / 2, gt + 4.5 * cellSize - tpRight.height / 2));

    // 九宫斜线
    final palacePaint = Paint()..color = lineColor..strokeWidth = 1.2;
    canvas.drawLine(Offset(gl + 3 * cellSize, gt), Offset(gl + 5 * cellSize, gt + 2 * cellSize), palacePaint);
    canvas.drawLine(Offset(gl + 5 * cellSize, gt), Offset(gl + 3 * cellSize, gt + 2 * cellSize), palacePaint);
    canvas.drawLine(Offset(gl + 3 * cellSize, gt + 7 * cellSize), Offset(gl + 5 * cellSize, gt + 9 * cellSize), palacePaint);
    canvas.drawLine(Offset(gl + 5 * cellSize, gt + 7 * cellSize), Offset(gl + 3 * cellSize, gt + 9 * cellSize), palacePaint);

    // 星位
    const starPts = [[2,1],[2,7],[3,0],[3,2],[3,4],[3,6],[3,8],[6,0],[6,2],[6,4],[6,6],[6,8],[7,1],[7,7]];
    final starR = cellSize * 0.055, starD = starR * 1.8;
    final starPaint = Paint()..color = lineColor;
    for (final p in starPts) {
      final sx = gl + p[1] * cellSize, sy = gt + p[0] * cellSize;
      canvas.drawCircle(Offset(sx - starD, sy - starD), starR, starPaint);
      canvas.drawCircle(Offset(sx + starD, sy - starD), starR, starPaint);
      canvas.drawCircle(Offset(sx - starD, sy + starD), starR, starPaint);
      canvas.drawCircle(Offset(sx + starD, sy + starD), starR, starPaint);
    }

    // 合法走法提示（原版用绿色圆点）
    if (legalMoves != null) {
      final hintPaint = Paint()..color = const Color(0xFF00C853);
      for (final move in legalMoves!) {
        if (move.length >= 2) {
          canvas.drawCircle(Offset(gl + move[1] * cellSize, gt + move[0] * cellSize), cellSize * 0.13, hintPaint);
        }
      }
    }

    // 选中高亮（原版橙框+四角圆点）
    if (selectedRow != null && selectedCol != null) {
      final cx = gl + selectedCol! * cellSize, cy = gt + selectedRow! * cellSize;
      final selPaint = Paint()..color = const Color(0xFFFF6F00)..style = PaintingStyle.stroke..strokeWidth = 5;
      final h = cellSize * 0.44;
      canvas.drawRect(Rect.fromLTWH(cx - h, cy - h, h * 2, h * 2), selPaint);
      final cornerPaint = Paint()..color = const Color(0xFFFF6F00);
      canvas.drawCircle(Offset(cx - h, cy - h), 6, cornerPaint);
      canvas.drawCircle(Offset(cx + h, cy - h), 6, cornerPaint);
      canvas.drawCircle(Offset(cx - h, cy + h), 6, cornerPaint);
      canvas.drawCircle(Offset(cx + h, cy + h), 6, cornerPaint);
    }

    // 绘制棋子
    final board = game.board;
    for (int r = 0; r < ChineseChessGame.rows; r++) {
      for (int c = 0; c < ChineseChessGame.cols; c++) {
        final piece = board[r][c];
        if (piece == ChineseChessGame.empty) continue;
        if (animating && r == animToRow && c == animToCol) continue;
        _drawPieceAt(canvas, gl + c * cellSize, gt + r * cellSize, piece, cellSize, pieceRadius);
      }
    }

    // 动画中的棋子（从起始位置滑动到目标位置）
    if (animating && animProgress < 1.0 && animToRow >= 0 && animToCol >= 0) {
      final piece = board[animToRow][animToCol];
      if (piece != ChineseChessGame.empty) {
        final fx = gl + animFromCol * cellSize, fy = gt + animFromRow * cellSize;
        final tx = gl + animToCol * cellSize, ty = gt + animToRow * cellSize;
        final t = _easeOutQuad(animProgress);
        _drawPieceAt(canvas, fx + (tx - fx) * t, fy + (ty - fy) * t, piece, cellSize, pieceRadius);
      }
    }

    // 最后走法标记（原版蓝色圆点）
    if (game.lastFromRow >= 0) {
      final lastPaint = Paint()..color = const Color(0xFF1565C0);
      canvas.drawCircle(Offset(gl + game.lastFromCol * cellSize, gt + game.lastFromRow * cellSize), cellSize * 0.1, lastPaint);
      canvas.drawCircle(Offset(gl + game.lastToCol * cellSize, gt + game.lastToRow * cellSize), cellSize * 0.1, lastPaint);
    }
  }

  void _drawPieceAt(Canvas c, double cx, double cy, int piece, double cellSize, double pieceR) {
    final color = ChineseChessGame.getColor(piece);
    final isRed = color == ChineseChessGame.red;
    // 旋转判定（与原版逻辑完全一致）
    final rotated = game.isFlipped ? (color == ChineseChessGame.red) : (color == ChineseChessGame.black);

    // 【关键修复】c.translate(cx,cy) + c.rotate(pi) 后，原点移到(cx,cy)
    // 所有绘制必须相对于(0,0)，但原码画圆还在(cx,cy)，导致飞出屏幕
    if (rotated) {
      c.save();
      c.translate(cx, cy);
      c.rotate(pi);

      // 阴影（相对原点0,0）
      c.drawCircle(const Offset(2, 2), pieceR, Paint()..color = const Color(0x30000000));
      // 米黄圆底
      c.drawCircle(Offset.zero, pieceR, Paint()..color = const Color(0xFFFFF8E1));
      // 外圈
      c.drawCircle(Offset.zero, pieceR, Paint()
        ..style = PaintingStyle.stroke..strokeWidth = isRed ? 3 : 2.5
        ..color = isRed ? const Color(0xFFC62828) : const Color(0xFF37474F));
      // 内圈
      c.drawCircle(Offset.zero, pieceR * 0.82, Paint()
        ..style = PaintingStyle.stroke..strokeWidth = 1.5
        ..color = isRed ? const Color(0xFFEF5350) : const Color(0xFF546E7A));
      // 文字
      final text = game.getPieceName(piece);
      final textColor = isRed ? const Color(0xFFC62828) : const Color(0xFF263238);
      final tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(color: textColor, fontSize: pieceR * 1.3, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
      c.restore();
    } else {
      // 不旋转，正常绘制
      // 阴影
      c.drawCircle(Offset(cx + 2, cy + 2), pieceR, Paint()..color = const Color(0x30000000));
      // 米黄圆底
      c.drawCircle(Offset(cx, cy), pieceR, Paint()..color = const Color(0xFFFFF8E1));
      // 外圈
      c.drawCircle(Offset(cx, cy), pieceR, Paint()
        ..style = PaintingStyle.stroke..strokeWidth = isRed ? 3 : 2.5
        ..color = isRed ? const Color(0xFFC62828) : const Color(0xFF37474F));
      // 内圈
      c.drawCircle(Offset(cx, cy), pieceR * 0.82, Paint()
        ..style = PaintingStyle.stroke..strokeWidth = 1.5
        ..color = isRed ? const Color(0xFFEF5350) : const Color(0xFF546E7A));
      // 文字
      final text = game.getPieceName(piece);
      final textColor = isRed ? const Color(0xFFC62828) : const Color(0xFF263238);
      final tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(color: textColor, fontSize: pieceR * 1.3, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
  }

  double _easeOutQuad(double t) => 1 - (1 - t) * (1 - t);

  @override
  bool shouldRepaint(covariant _ChineseChessPainter old) => true;
}
