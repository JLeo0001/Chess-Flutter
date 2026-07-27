import 'dart:async';
import 'package:flutter/material.dart';

/// 游戏页面通用壳 — 使用 Scaffold 原生插槽处理系统安全区
class GameShell extends StatefulWidget {
  final String topLabel, bottomLabel;
  final String topStatus, bottomStatus;
  final Widget? topIndicator, bottomIndicator;
  final Widget Function(BuildContext) builder;
  final VoidCallback onBack, onReset;

  final bool showResult;
  final String? resultTitle;
  final Widget? resultSubtitle;
  final Widget? resultWidget;
  final VoidCallback? onResultAction;
  final String? resultActionLabel;

  final int lotteryCount;
  final VoidCallback onLotteryFinished;

  final Widget? statusBanner;
  final List<Widget>? extraBottomButtons;

  const GameShell({
    super.key,
    required this.topLabel,
    required this.bottomLabel,
    this.topStatus = '',
    this.bottomStatus = '',
    this.topIndicator,
    this.bottomIndicator,
    required this.builder,
    required this.onBack,
    required this.onReset,
    this.showResult = false,
    this.resultTitle,
    this.resultSubtitle,
    this.resultWidget,
    this.onResultAction,
    this.resultActionLabel,
    this.lotteryCount = -1,
    this.onLotteryFinished = _noop,
    this.statusBanner,
    this.extraBottomButtons,
  });

  static void _noop() {}

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final night = Theme.of(context).brightness == Brightness.dark;
    final hlTop = widget.topStatus == '🎯';
    final hlBot = widget.bottomStatus == '🎯';

    // 棋盘内容
    Widget board = widget.builder(context);
    final isLottery = widget.lotteryCount >= 0 && widget.lotteryCount < 12;

    // 结果弹窗
    Widget overlay = const SizedBox.shrink();
    if (widget.showResult) {
      overlay = _resultOverlay(cs, night);
    }

    return Scaffold(
      // ─── 顶栏（翻转） ───
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: _tapBar(
          label: widget.topLabel,
          status: widget.topStatus,
          indicator: widget.topIndicator,
          highlight: hlTop,
          cs: cs,
          flipped: true,
        ),
      ),

      // ─── 棋盘区 ───
      body: Stack(
        children: [
          Column(
            children: [
              if (widget.statusBanner != null) widget.statusBanner!,
              Expanded(child: board),
            ],
          ),
          // 开桌动画覆盖层
          if (isLottery)
            Positioned.fill(
              child: Container(color: cs.surface),
            ),
          if (isLottery)
            Positioned.fill(
              child: _LotteryOverlay(
                count: widget.lotteryCount,
                total: 12,
                onFinished: widget.onLotteryFinished,
              ),
            ),
          // 结果弹窗
          if (widget.showResult)
            Positioned.fill(child: overlay),
        ],
      ),

      // ─── 底栏（玩家） ───
      bottomNavigationBar: _tapBar(
        label: widget.bottomLabel,
        status: widget.bottomStatus,
        indicator: widget.bottomIndicator,
        highlight: hlBot,
        cs: cs,
        flipped: false,
      ),

      // ─── 底部按钮 ───
      persistentFooterButtons: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onBack,
                  child: const Text('返回'),
                ),
              ),
              if (widget.extraBottomButtons != null) ...widget.extraBottomButtons!,
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: widget.onReset,
                  child: const Text('重新开始'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── 结果弹窗 ───
  Widget _resultOverlay(ColorScheme cs, bool night) {
    return Container(
      color: night ? const Color(0x80FFFFFF) : const Color(0x80000000),
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.resultWidget != null)
                  widget.resultWidget!
                else ...[
                  if (widget.resultTitle != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        widget.resultTitle!,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  if (widget.resultSubtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: widget.resultSubtitle!,
                    ),
                ],
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: widget.onResultAction ?? widget.onReset,
                  child: Text(widget.resultActionLabel ?? '再来一局'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── 单条栏（顶栏或底栏） ───
  Widget _tapBar({
    required String label,
    required String status,
    Widget? indicator,
    required bool highlight,
    required ColorScheme cs,
    required bool flipped,
  }) {
    final content = SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: highlight ? cs.secondaryContainer : cs.surface,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (indicator != null) ...[
                indicator,
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (status.isNotEmpty)
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: highlight ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (flipped) {
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..rotateZ(3.1415927),
        child: content,
      );
    }
    return content;
  }
}

/// ─── 开桌动画 ───
class _LotteryOverlay extends StatefulWidget {
  final int count;
  final int total;
  final VoidCallback onFinished;

  const _LotteryOverlay({required this.count, required this.total, required this.onFinished});

  @override
  State<_LotteryOverlay> createState() => _LotteryOverlayState();
}

class _LotteryOverlayState extends State<_LotteryOverlay>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _step = widget.count;
    _animate();
  }

  void _animate() {
    _timer = Timer.periodic(const Duration(milliseconds: 60), (t) {
      if (_step >= widget.total) {
        t.cancel();
        widget.onFinished();
        return;
      }
      if (mounted) setState(() => _step++);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showTarget = _step % 2 == 0;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(showTarget ? '🎯' : '', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 24),
          Text('选择先后手…',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface)),
        ],
      ),
    );
  }
}

/// ─── 棋子指示器 ───
class StoneIndicator extends StatelessWidget {
  final bool isBlack;
  final double size;
  const StoneIndicator({super.key, required this.isBlack, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: isBlack ? const Color(0xFF1C1B1F) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isBlack ? const Color(0xFF49454F) : const Color(0xFFCAC4D0),
          width: 2,
        ),
      ),
    );
  }
}

/// ─── X/O 指示器 ───
class XOIndicator extends StatelessWidget {
  final bool isX;
  final double size;
  const XOIndicator({super.key, required this.isX, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: isX ? CustomPaint(painter: _XPainter()) : CustomPaint(painter: _OPainter()),
    );
  }
}

class _XPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFFE53935)..strokeWidth = 3..strokeCap = StrokeCap.round;
    final s = size.width;
    canvas.drawLine(Offset(2, 2), Offset(s - 2, s - 2), p);
    canvas.drawLine(Offset(s - 2, 2), Offset(2, s - 2), p);
  }
  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

class _OPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF1E88E5)..style = PaintingStyle.stroke..strokeWidth = 3;
    canvas.drawOval(Rect.fromLTWH(2, 2, size.width - 4, size.height - 4), p);
  }
  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

/// ─── 国际象棋方色指示器 ───
class ChessSideIndicator extends StatelessWidget {
  final bool isWhite;
  final double size;
  const ChessSideIndicator({super.key, required this.isWhite, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: isWhite ? Colors.white : const Color(0xFF1C1B1F),
        shape: BoxShape.circle,
        border: Border.all(
          color: isWhite ? const Color(0xFFCAC4D0) : const Color(0xFF49454F),
          width: 2,
        ),
      ),
    );
  }
}
