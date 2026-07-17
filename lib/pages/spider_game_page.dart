import 'dart:async';
import 'package:flutter/material.dart';
import 'package:card_game/card_game.dart';
import '../spider/spider_game.dart';

class SpiderGamePage extends StatefulWidget {
  final int suitCount;
  const SpiderGamePage({super.key, this.suitCount = 1});

  @override
  State<SpiderGamePage> createState() => _SpiderGamePageState();
}

class _SpiderGamePageState extends State<SpiderGamePage>
    with TickerProviderStateMixin {
  late SpiderGame _game;
  late int _suitCount;

  int? _selCol;
  int? _selFromIdx;

  // 消除特效
  int? _completeCol;
  late AnimationController _completeCtrl;
  late Animation<double> _completeScale, _completeFade;

  @override
  void initState() {
    super.initState();
    _suitCount = widget.suitCount;

    _completeCtrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _completeScale = Tween<double>(begin: 0.5, end: 2.0).animate(
      CurvedAnimation(parent: _completeCtrl, curve: Curves.easeOut),
    );
    _completeFade = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(parent: _completeCtrl, curve: const Interval(0.2, 1.0)),
    );

    _game = SpiderGame(suitCount: _suitCount);
    _game.newGame();
  }

  @override
  void dispose() {
    _completeCtrl.dispose();
    super.dispose();
  }

  void _newGame(int suits) {
    _completeCtrl.reset();
    setState(() {
      _suitCount = suits;
      _game = SpiderGame(suitCount: suits);
      _game.newGame();
      _selCol = null;
      _selFromIdx = null;
      _completeCol = null;
    });
  }

  // ═══ 交互 ═══
  void _onTapCol(int col) {
    if (_game.isGameOver) return;
    setState(() {
      if (_selCol == null) {
        final idx = _findSelectable(col);
        if (idx != null) {
          _selCol = col;
          _selFromIdx = idx;
        }
      } else if (_selCol == col) {
        _selCol = null;
        _selFromIdx = null;
      } else {
        final fc = _selCol!;
        final fi = _selFromIdx!;
        if (_game.canMove(fc, fi, col)) {
          final (completed, _) = _game.moveSeq(fc, fi, col);
          if (completed) {
            _completeCol = col;
            _completeCtrl.forward(from: 0);
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) setState(() => _completeCol = null);
            });
          }
        }
        _selCol = null;
        _selFromIdx = null;
      }
    });
  }

  int? _findSelectable(int col) {
    final c = _game.tableau[col];
    if (c.isEmpty) return null;
    for (int i = c.length - 1; i >= 0; i--) {
      if (!_game.isFaceUp(col, i)) break;
      if (_game.isSeq(col, i)) return i;
    }
    return null;
  }

  void _onDeal() {
    if (!_game.canDeal()) return;
    setState(() {
      _selCol = null;
      _selFromIdx = null;
      _game.deal();
    });
  }

  // ═══ 布局 ═══
  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF0B6E32);
    final cw = MediaQuery.of(context).size.width;
    final cardW = ((cw - 32) / SpiderGame.cols) - 2;
    final cardH = cardW * 1.4;
    final overlap = cardH * 0.38;
    const backOverlap = 4.0;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        toolbarHeight: 40,
        backgroundColor: const Color(0xFF084A21),
        elevation: 0,
        titleSpacing: 2,
        title: Row(children: [
          const Text('🕷️', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          const Text('蜘蛛纸牌',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70)),
          const SizedBox(width: 6),
          _chip('⭐${_game.score}', Colors.amber),
          const SizedBox(width: 3),
          _chip('📦${_game.stock.length ~/ 10}', Colors.blue.shade200),
          const SizedBox(width: 3),
          _chip('✅${_game.completed.length ~/ 13}', Colors.greenAccent),
          const Spacer(),
          PopupMenuButton<int>(
            initialValue: _suitCount,
            color: Colors.grey.shade800,
            onSelected: _newGame,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 1, child: Text('♠ 单色', style: TextStyle(fontSize: 13))),
              const PopupMenuItem(value: 2, child: Text('♠♥ 双色', style: TextStyle(fontSize: 13))),
              const PopupMenuItem(value: 4, child: Text('♠♥♦♣ 四色', style: TextStyle(fontSize: 13))),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(switch (_suitCount) {
                  1 => '♠单',
                  2 => '♠♥双',
                  _ => '四色',
                }, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                const Icon(Icons.arrow_drop_down,
                    color: Colors.white54, size: 14),
              ]),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 16, color: Colors.white54),
            onPressed: () => _newGame(_suitCount),
            tooltip: '新游戏',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 16, color: Colors.white54),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ]),
      ),
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            // 顶部行
            _topRow(cardW),
            // 10列表格
            Expanded(child: _tableauArea(cardW, cardH, overlap, backOverlap)),
            // 底部
            if (_game.isGameOver) _bottomBar() else _hintBar(),
          ]),
          // 消除特效
          if (_completeCol != null) _completeOverlay(bg),
        ]),
      ),
    );
  }

  Widget _topRow(double cardW) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Row(children: [
        // 已完成
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _game.completed.length ~/ 13,
            padding: EdgeInsets.zero,
            itemBuilder: (_, i) => Container(
              width: 22,
              height: 26,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.greenAccent.withAlpha(80)),
              ),
              child: const Center(
                child: Text('✓',
                    style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
              ),
            ),
          ),
        ),
        // 发牌堆
        GestureDetector(
          onTap: _game.canDeal() ? _onDeal : null,
          child: AnimatedOpacity(
            opacity: _game.canDeal() || _game.stock.isNotEmpty ? 1.0 : 0.3,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width: cardW,
              height: 28,
              decoration: BoxDecoration(
                color: _game.canDeal()
                    ? const Color(0xFF37474F)
                    : const Color(0xFF263238),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _game.canDeal() ? Colors.white38 : Colors.white12,
                ),
              ),
              child: Center(
                child: Text(
                  '📦${_game.stock.isEmpty ? 0 : _game.stock.length ~/ 10}',
                  style: TextStyle(
                    color: _game.canDeal() ? Colors.white70 : Colors.white30,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _tableauArea(
      double cardW, double cardH, double overlap, double backOverlap) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(3, 0, 3, 4),
      child: LayoutBuilder(builder: (_, constraints) {
        final colW = (constraints.maxWidth - 6) / SpiderGame.cols;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(SpiderGame.cols, (col) {
            final cards = _game.tableau[col];
            final sel = col == _selCol;
            return Expanded(
              child: GestureDetector(
                onTap: () => _onTapCol(col),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: sel
                          ? Colors.yellow
                          : (cards.isEmpty
                              ? Colors.white10
                              : Colors.transparent),
                      width: sel ? 2 : 0.5,
                    ),
                    color:
                        cards.isEmpty ? Colors.black.withAlpha(20) : null,
                  ),
                  child: cards.isEmpty
                      ? Center(
                          child: sel
                              ? Icon(Icons.arrow_downward,
                                  size: 18,
                                  color: Colors.yellow.withAlpha(120))
                              : const SizedBox.shrink())
                      : _buildPile(col, cards, colW, overlap, backOverlap),
                ),
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _buildPile(int col, List<SuitedCard> cards, double colW,
      double overlap, double backOverlap) {
    return Stack(
      clipBehavior: Clip.none,
      children: List.generate(cards.length, (i) {
        final card = cards[i];
        final faceUp = _game.isFaceUp(col, i);
        final inSel =
            _selCol == col && _selFromIdx != null && i >= _selFromIdx!;
        final offset = faceUp ? i * overlap : i * backOverlap;

        return Positioned(
          top: offset,
          left: 0,
          right: 0,
          child: _CardWidget(
            card: card,
            faceUp: faceUp,
            highlighted: inSel,
            w: colW,
            h: colW * 1.4,
            selected: inSel,
          ),
        );
      }),
    );
  }

  Widget _completeOverlay(Color bg) {
    return IgnorePointer(
      child: Container(
        color: Colors.black38,
        child: Center(
          child: AnimatedBuilder(
            animation: _completeCtrl,
            builder: (_, __) => Opacity(
              opacity: _completeFade.value,
              child: Transform.scale(
                scale: _completeScale.value,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.white60,
                          blurRadius: 30,
                          spreadRadius: 10)
                    ],
                  ),
                  child: const Text('🎉',
                      style: TextStyle(fontSize: 52)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      color: const Color(0xFF084A21),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _game.isWin ? '🎉 通关！得分: ${_game.score}' : '😔 无路可走',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => _newGame(_suitCount),
            style: TextButton.styleFrom(foregroundColor: Colors.amber),
            child: const Text('再来一局'),
          ),
        ],
      ),
    );
  }

  Widget _hintBar() {
    return Container(
      height: 32,
      color: const Color(0xFF084A21).withAlpha(160),
      child: Center(
        child: Text(
          _selCol != null ? '点击目标列放置' : '点击选牌 → 点击目标列移动',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
      child:
          Text(text, style: TextStyle(color: color, fontSize: 10)),
    );
  }
}

// ═══ 卡牌组件 ═══
class _CardWidget extends StatelessWidget {
  final SuitedCard card;
  final bool faceUp;
  final bool highlighted;
  final double w, h;
  final bool selected;

  const _CardWidget({
    required this.card,
    required this.faceUp,
    this.highlighted = false,
    required this.w,
    required this.h,
    this.selected = false,
  });

  static String _suit(SuitedCard c) => switch (c.suit) {
    CardSuit.spades => '♠',
    CardSuit.hearts => '♥',
    CardSuit.diamonds => '♦',
    CardSuit.clubs => '♣',
  };

  static bool _isRed(SuitedCard c) =>
      c.suit == CardSuit.hearts || c.suit == CardSuit.diamonds;

  static String _rank(SuitedCard c) => switch (SpiderGame.rankOf(c)) {
    1 => 'A', 11 => 'J', 12 => 'Q', 13 => 'K', var r => '$r',
  };

  @override
  Widget build(BuildContext context) {
    if (!faceUp) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A4BA8), Color(0xFF0D2F6B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white.withAlpha(30)),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 1, offset: Offset(0, 1)),
          ],
        ),
        child: Center(
          child: Container(
            width: w * 0.35,
            height: w * 0.35,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withAlpha(40), width: 1.5),
            ),
            child: Center(
              child: Text('🕷️',
                  style: TextStyle(
                      fontSize: w * 0.18, color: Colors.white38)),
            ),
          ),
        ),
      );
    }

    final isRed = _isRed(card);
    final labelColor = isRed ? const Color(0xFFD32F2F) : Colors.black87;
    final suit = _suit(card);
    final rank = _rank(card);
    final r = w / 60;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: selected ? Colors.amber : Colors.black12,
          width: selected ? 2.5 : 0.8,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.amber.withAlpha(120),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : const [
                BoxShadow(
                    color: Colors.black12, blurRadius: 1, offset: Offset(0, 1)),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(children: [
          // 左上角
          Positioned(
            top: 2 * r,
            left: 3 * r,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rank,
                      style: TextStyle(
                          fontSize: 10 * r,
                          fontWeight: FontWeight.w700,
                          color: labelColor)),
                  Text(suit,
                      style: TextStyle(fontSize: 8 * r, color: labelColor)),
                ]),
          ),
          // 右下角（旋转）
          Positioned(
            bottom: 2 * r,
            right: 3 * r,
            child: Transform.rotate(
              angle: 3.14159,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rank,
                        style: TextStyle(
                            fontSize: 10 * r,
                            fontWeight: FontWeight.w700,
                            color: labelColor)),
                    Text(suit,
                        style: TextStyle(fontSize: 8 * r, color: labelColor)),
                  ]),
            ),
          ),
          // 中央大花色
          Center(
            child:
                Text(suit, style: TextStyle(fontSize: 20 * r, color: labelColor.withAlpha(200))),
          ),
          // 选中光晕
          if (selected)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
