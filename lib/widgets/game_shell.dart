import 'dart:async';
import 'package:flutter/material.dart';

/// ─── 游戏页面通用壳 ───
///
/// 提取所有游戏页面共同的布局模式：
/// - 上：翻转的对手面板（AppBar）
/// - 中：游戏棋盘（由 builder 提供）
/// - 下：玩家面板（BottomNavigationBar）
/// - 底：返回 + 重新开始按钮
/// - 覆盖层：结果弹窗
/// - 开桌动画：双人/人机随机选先后手
///
/// 使用方式：
/// ```dart
/// GameShell(
///   topLabel: 'AI',
///   topColor: Colors.black,
///   bottomLabel: '你',
///   bottomColor: Colors.white,
///   topIndicator: myWidget,
///   bottomIndicator: myWidget,
///   builder: (context) => MyBoard(),
///   resultTitle: '你赢了！',
///   resultWidget: ...,
///   showResult: _gameOver,
///   onBack: () => Navigator.pop(context),
///   onReset: _reset,
///   hideLottery: false,  // PvP 可隐藏
/// )
/// ```
class GameShell extends StatefulWidget {
  final String topLabel, bottomLabel;
  final String topStatus, bottomStatus;
  final Widget? topIndicator, bottomIndicator;
  final Widget Function(BuildContext) builder;
  final VoidCallback onBack, onReset;

  // 结果弹窗
  final bool showResult;
  final String? resultTitle;
  final Widget? resultSubtitle; // 可选副标题（含计分等信息）
  final Widget? resultWidget;   // 完全自定义结果区（替代 title + subtitle）
  final VoidCallback? onResultAction;
  final String? resultActionLabel;

  // 开桌动画
  final bool noLottery;
  final int lotteryCount;
  final VoidCallback onLotteryFinished;

  // 将军/等状态条（插在棋盘上方）
  final Widget? statusBanner;

  // 底部额外按钮（如围棋的「停一手」）
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
    this.noLottery = false,
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

    // 如果开桌动画未结束，覆盖全屏
    Widget body = widget.builder(context);
    if (widget.lotteryCount >= 0 && widget.lotteryCount < 12) {
      body = _LotteryOverlay(
        count: widget.lotteryCount,
        total: 12,
        onFinished: widget.onLotteryFinished,
      );
    }

    // 结果弹窗
    Widget overlay = const SizedBox.shrink();
    if (widget.showResult) {
      overlay = Positioned.fill(
        child: Container(
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
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─── 顶栏（翻转，对手） ───
            _bar(
              label: widget.topLabel,
              status: widget.topStatus,
              indicator: widget.topIndicator,
              highlight: hlTop,
              night: night,
              cs: cs,
              flipped: true,
            ),

            // ─── 棋盘区 ───
            Expanded(
              child: Stack(
                children: [
                  Column(
                    children: [
                      if (widget.statusBanner != null) widget.statusBanner!,
                      Expanded(child: body),
                    ],
                  ),
                  // 状态覆盖层
                  if (widget.lotteryCount >= 0 && widget.lotteryCount < 12)
                    Positioned.fill(
                      child: Container(color: cs.surface),
                    ),
                  overlay,
                ],
              ),
            ),

            // ─── 底栏（玩家） ───
            _bar(
              label: widget.bottomLabel,
              status: widget.bottomStatus,
              indicator: widget.bottomIndicator,
              highlight: hlBot,
              night: night,
              cs: cs,
              flipped: false,
            ),

            // ─── 底部按钮 ───
            _bottomButtons(night, cs),
          ],
        ),
      ),
    );
  }

  Widget _bar({
    required String label,
    required String status,
    Widget? indicator,
    required bool highlight,
    required bool night,
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

  Widget _bottomButtons(bool night, ColorScheme cs) {
    final buttons = <Widget>[
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
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: buttons,
      ),
    );
  }
}

/// ─── 开桌动画（摇骰/抽签）───
class _LotteryOverlay extends StatefulWidget {
  final int count;
  final int total;
  final VoidCallback onFinished;

  const _LotteryOverlay({
    required this.count,
    required this.total,
    required this.onFinished,
  });

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
          Text(
            showTarget ? '🎯' : '',
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 24),
          Text(
            '选择先后手…',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// ─── 石头子指示器（通用组件） ───
class StoneIndicator extends StatelessWidget {
  final bool isBlack;
  final double size;

  const StoneIndicator({
    super.key,
    required this.isBlack,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
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

/// ─── X/O 指示器（井字棋） ───
class XOIndicator extends StatelessWidget {
  final bool isX;
  final double size;

  const XOIndicator({super.key, required this.isX, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: isX
          ? CustomPaint(painter: _XPainter())
          : CustomPaint(painter: _OPainter()),
    );
  }
}

class _XPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final s = size.width;
    canvas.drawLine(Offset(2, 2), Offset(s - 2, s - 2), paint);
    canvas.drawLine(Offset(s - 2, 2), Offset(2, s - 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E88E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ─── 国际象棋方色指示器 ───
class ChessSideIndicator extends StatelessWidget {
  final bool isWhite;
  final double size;

  const ChessSideIndicator({super.key, required this.isWhite, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
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
