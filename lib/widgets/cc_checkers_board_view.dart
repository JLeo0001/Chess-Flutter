import 'dart:math';
import 'package:flutter/material.dart';
import '../chinese_checkers/cc_checkers_game.dart';

/// 中国跳棋棋盘视图
class CCBoardView extends StatefulWidget {
  final ChineseCheckersGame game;
  final void Function(int index)? onCellTapped;
  final int playerColor;

  const CCBoardView({
    super.key,
    required this.game,
    this.onCellTapped,
    this.playerColor = 1,
  });

  @override
  State<CCBoardView> createState() => _CCBoardViewState();
}

class _CCBoardViewState extends State<CCBoardView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  int _animFrom = -1, _animTo = -1;
  double _animProgress = 1.0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() => setState(() => _animProgress = _animCtrl.value));

    widget.game.setListener(_CCListener(
      cbMove: (from, to, player) {
        _animFrom = from;
        _animTo = to;
        _animCtrl.forward(from: 0);
      },
      cbReset: () {
        _animFrom = -1;
        _animTo = -1;
        _animCtrl.reset();
        setState(() => _animProgress = 1.0);
      },
      cbUndo: () {
        _animFrom = -1;
        _animTo = -1;
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
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      // 棋盘在六边形坐标中的范围：q∈[-8,8], r∈[-8,8]
      // 像素范围：width≈sqrt(3)*16*size, height≈3/2*16*size
      // 缩放使棋盘恰好适合可用空间
      final sx = w / (sqrt(3) * 17); // 稍留边距
      final sy = h / (1.5 * 17);
      final cellR = min(sx, sy);

      return GestureDetector(
        onTapUp: (details) {
          final ox = w / 2;
          final oy = h / 2;

          int? bestIdx;
          double bestDist = double.infinity;
          for (int i = 0; i < widget.game.positions.length; i++) {
            final p = widget.game.positions[i];
            final px = ox + _hexToPixelX(p.q, p.r, cellR);
            final py = oy + _hexToPixelY(p.q, p.r, cellR);
            final dx = details.localPosition.dx - px;
            final dy = details.localPosition.dy - py;
            final d = dx * dx + dy * dy;
            if (d < bestDist && d < cellR * cellR * 0.55) {
              bestDist = d;
              bestIdx = i;
            }
          }
          if (bestIdx != null) {
            widget.onCellTapped?.call(bestIdx);
          }
        },
        child: CustomPaint(
          size: Size(w, h),
          painter: _CCBoardPainter(
            game: widget.game,
            night: night,
            animFrom: _animFrom,
            animTo: _animTo,
            animProgress: _animProgress,
            playerColor: widget.playerColor,
            cellR: cellR,
            ox: w / 2,
            oy: h / 2,
          ),
        ),
      );
    });
  }
}

double _hexToPixelX(int q, int r, double size) {
  return size * (sqrt(3) * q + sqrt(3) / 2 * r);
}

double _hexToPixelY(int q, int r, double size) {
  return size * (3.0 / 2 * r);
}

const _playerColors = [
  Color(0xFFFFFFFF),
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFF8E24AA),
  Color(0xFFFDD835),
];

const _playerDarkColors = [
  Color(0xFFFFFFFF),
  Color(0xFFEF5350),
  Color(0xFF42A5F5),
  Color(0xFF66BB6A),
  Color(0xFFFFA726),
  Color(0xFFAB47BC),
  Color(0xFFFFEE58),
];

Color _playerColor(int p, bool night) {
  final c = night ? _playerDarkColors : _playerColors;
  return p >= 0 && p < c.length ? c[p] : Colors.grey;
}

class _CCBoardPainter extends CustomPainter {
  final ChineseCheckersGame game;
  final bool night;
  final int animFrom, animTo;
  final double animProgress;
  final int playerColor;
  final double cellR;
  final double ox, oy;

  _CCBoardPainter({
    required this.game,
    required this.night,
    required this.animFrom,
    required this.animTo,
    required this.animProgress,
    required this.playerColor,
    required this.cellR,
    required this.ox,
    required this.oy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final holeR = cellR * 0.44;  // 孔半径（相邻孔心距≈1.73*cellR，0.44留出间距）
    final pieceR = holeR * 0.82; // 棋子略小于孔

    // 背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = night ? const Color(0xFF1C1B1F) : const Color(0xFFF5F0E8),
    );

    // 所有孔位
    for (int i = 0; i < game.positions.length; i++) {
      final p = game.positions[i];
      final px = ox + _hexToPixelX(p.q, p.r, cellR);
      final py = oy + _hexToPixelY(p.q, p.r, cellR);
      final holeColor = night ? const Color(0xFF1C1B1F) : const Color(0xFF8B6914);
      canvas.drawCircle(Offset(px, py), holeR, Paint()..color = holeColor);
      canvas.drawCircle(
        Offset(px, py), holeR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..color = night ? const Color(0xFF49454F) : const Color(0xFF6B4226),
      );
    }

    // 营地底色
    for (int c = 0; c < 6; c++) {
      final campColor = _playerColor(c + 1, night).withAlpha(25);
      final campPaint = Paint()..color = campColor;
      for (final idx in game.camps[c]) {
        final p = game.positions[idx];
        final px = ox + _hexToPixelX(p.q, p.r, cellR);
        final py = oy + _hexToPixelY(p.q, p.r, cellR);
        canvas.drawCircle(Offset(px, py), holeR * 0.95, campPaint);
      }
    }

    // 绘制棋子
    for (int i = 0; i < game.board.length; i++) {
      final owner = game.board[i];
      if (owner == ChineseCheckersGame.empty) continue;

      final p = game.positions[i];
      double px = ox + _hexToPixelX(p.q, p.r, cellR);
      double py = oy + _hexToPixelY(p.q, p.r, cellR);

      if (i == animTo && animProgress < 1.0 && animFrom >= 0) {
        final fp = game.positions[animFrom];
        final fx = ox + _hexToPixelX(fp.q, fp.r, cellR);
        final fy = oy + _hexToPixelY(fp.q, fp.r, cellR);
        final t = _easeOutBack(animProgress);
        px = fx + (px - fx) * t;
        py = fy + (py - fy) * t;
      }

      final color = _playerColor(owner, night);
      final isCurrent = owner == game.currentPlayer && !game.isGameOver;

      // 阴影
      canvas.drawCircle(
        Offset(px + 1.2, py + 1.2), pieceR,
        Paint()..color = Colors.black.withAlpha(50),
      );

      // 棋子主体
      final gradPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          radius: 1.0,
          colors: [
            Color.lerp(color, Colors.white, 0.35)!,
            color,
            Color.lerp(color, Colors.black, 0.25)!,
          ],
        ).createShader(Rect.fromCircle(center: Offset(px, py), radius: pieceR));
      canvas.drawCircle(Offset(px, py), pieceR, gradPaint);

      // 边框
      canvas.drawCircle(
        Offset(px, py), pieceR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = isCurrent ? Colors.white.withAlpha(180) : color.withAlpha(140),
      );

      // 当前走棋方光环
      if (isCurrent) {
        canvas.drawCircle(
          Offset(px, py), pieceR + 2.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = Colors.white.withAlpha(110),
        );
      }
    }

    // 选中棋子与合法目标
    if (game.selectedIndex >= 0) {
      final sp = game.positions[game.selectedIndex];
      final sx = ox + _hexToPixelX(sp.q, sp.r, cellR);
      final sy = oy + _hexToPixelY(sp.q, sp.r, cellR);
      canvas.drawCircle(
        Offset(sx, sy), pieceR + 3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFFFD600),
      );

      for (final ti in game.validTargets) {
        final tp = game.positions[ti];
        final tx = ox + _hexToPixelX(tp.q, tp.r, cellR);
        final ty = oy + _hexToPixelY(tp.q, tp.r, cellR);
        canvas.drawCircle(
          Offset(tx, ty), holeR * 0.9,
          Paint()..color = const Color(0x604CAF50),
        );
        canvas.drawCircle(
          Offset(tx, ty), holeR * 0.9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFF4CAF50),
        );
      }
    }
  }

  double _easeOutBack(double t) {
    const c1 = 1.70158, c3 = c1 + 1;
    return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2);
  }

  @override
  bool shouldRepaint(covariant _CCBoardPainter old) => true;
}

class _CCListener extends OnCCGameListener {
  final void Function(int from, int to, int player) cbMove;
  final VoidCallback cbReset;
  final VoidCallback cbUndo;

  _CCListener({
    required this.cbMove,
    required this.cbReset,
    required this.cbUndo,
  });

  @override
  void onMoveMade(int fromIdx, int toIdx, int player) =>
      cbMove(fromIdx, toIdx, player);
  @override
  void onGameOver(int winner) {}
  @override
  void onGameReset() => cbReset();
  @override
  void onSelectionChanged(int selectedIndex, Set<int> validTargets) {}
  @override
  void onUndo() => cbUndo();
}
