import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../themes/app_theme.dart';
import '../uno/uno_card.dart';
import '../uno/uno_game.dart';
import '../uno/uno_ai.dart';

class UnoGamePage extends StatefulWidget {
  final int playerCount;
  const UnoGamePage({super.key, required this.playerCount});
  @override
  State<UnoGamePage> createState() => _UnoGamePageState();
}

class _UnoGamePageState extends State<UnoGamePage>
    with TickerProviderStateMixin {
  late UnoGame _game;
  final UnoAI _ai = UnoAI();
  int? _selectedIdx;
  bool _needsColorPick = false;
  String _status = '';
  Timer? _aiTimer;

  // 发牌
  bool _dealing = false;
  int _dealStep = 0;
  int _lastDealStep = 0;
  Timer? _dealTimer;
  late AnimationController _dealFlyCtrl;
  late Animation<Offset> _dealFlyPos;
  late Animation<double> _dealFlyScale;

  // 出牌动画
  UnoCard? _playedCard;
  double _playStartX = 0;
  late AnimationController _playCtrl;
  late Animation<double> _playScale, _playFade;
  late Animation<Offset> _playPos;

  // 特效动画
  String? _effectType; // skip|reverse|draw2|wild|wild4
  late AnimationController _effectCtrl;
  late Animation<double> _effectScale, _effectFade;

  // 抽牌
  UnoCard? _drawnCard;
  bool _waitingDrawDecision = false;

  static final _rng = Random();

  @override
  void initState() {
    super.initState();
    _playCtrl = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _playScale = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _playCtrl, curve: Curves.elasticOut));
    _playPos = Tween<Offset>(begin: const Offset(0, 0.7), end: Offset.zero).animate(
        CurvedAnimation(parent: _playCtrl, curve: Curves.fastOutSlowIn));
    _playFade = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _playCtrl, curve: const Interval(0.4, 1.0)));

    _effectCtrl = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _effectScale = Tween<double>(begin: 0.5, end: 2.0).animate(
        CurvedAnimation(parent: _effectCtrl, curve: Curves.easeOut));
    _effectFade = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _effectCtrl, curve: const Interval(0.3, 1.0)));

    _game = UnoGame(playerCount: widget.playerCount, startingPlayer: _rng.nextInt(widget.playerCount));
    _dealFlyCtrl = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _dealFlyPos = Tween<Offset>(begin: Offset.zero, end: const Offset(0, 0.6)).animate(
        CurvedAnimation(parent: _dealFlyCtrl, curve: Curves.decelerate));
    _dealFlyScale = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _dealFlyCtrl, curve: Curves.elasticOut));
    _updateStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startDeal());
  }

  @override
  void dispose() {
    _aiTimer?.cancel(); _dealTimer?.cancel();
    _playCtrl.dispose(); _effectCtrl.dispose(); _dealFlyCtrl.dispose();
    super.dispose();
  }

  // ═══ 发牌动画：牌从牌堆飞向目标 ═══
  void _startDeal() {
    setState(() { _dealing = true; _dealStep = 0; _lastDealStep = 0; });
    const interval = Duration(milliseconds: 80);
    _dealTimer = Timer.periodic(interval, (t) {
      final total = widget.playerCount * 7;
      if (_dealStep >= total) {
        t.cancel();
        setState(() { _dealing = false; });
        _dealFlyCtrl.reset();
        _checkAiTurn();
        return;
      }
      setState(() {
        _dealStep++;
      });
      // 飞牌动画：每次新牌触发
      if (_dealStep != _lastDealStep) {
        _lastDealStep = _dealStep;
        _dealFlyCtrl.forward(from: 0);
        // 根据目标设置终点偏移
        final targetPlayer = (_dealStep - 1) % widget.playerCount;
        final end = targetPlayer == 0
            ? const Offset(0, 0.55)  // 飞向玩家（底部）
            : Offset(0, -0.45 + (targetPlayer - 1) * 0.1); // 飞向AI（顶部）
        _dealFlyPos = Tween<Offset>(begin: Offset.zero, end: end).animate(
            CurvedAnimation(parent: _dealFlyCtrl, curve: Curves.decelerate));
      }
    });
  }

  // 发牌中当前玩家已得的牌数
  int _dealtToPlayer(int p) {
    if (!_dealing) return _game.hands[p].length;
    final total = _dealStep;
    // 每个玩家轮发: p 得牌数 = total > p ? 1 + (total-p-1)~/playerCount : 0
    if (total <= p) return 0;
    return 1 + ((total - p - 1) ~/ widget.playerCount);
  }

  int get _dealtToMe => _dealtToPlayer(0);

  // ═══ 特效 ═══
  void _triggerEffect(String type) {
    _effectType = type;
    _effectCtrl.reset();
    _effectCtrl.forward();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() { _effectType = null; });
    });
  }

  Widget _buildEffect(String type) {
    final icon = switch (type) {
      'skip' => '⊘', 'reverse' => '⟲', 'draw2' => '+2',
      'wild' => '★', _ => '+4',
    };
    final hint = switch (type) {
      'skip' => '跳过!', 'reverse' => '反转!', 'draw2' => '罚2张!',
      'wild' => 'Wild!', _ => '+4!',
    };
    return AnimatedBuilder(animation: _effectCtrl, builder: (_, __) {
      return Opacity(opacity: _effectFade.value,
        child: Transform.scale(scale: _effectScale.value,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle, boxShadow: [
                  BoxShadow(color: Colors.white60, blurRadius: 30, spreadRadius: 10)]),
              child: Text(icon, style: TextStyle(
                  fontSize: 72, fontWeight: FontWeight.w900,
                  color: type == 'wild' ? const Color(0xFFD0BCFF) : Colors.white))),
            const SizedBox(height: 12),
            Text(hint, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                color: Colors.white, letterSpacing: 4)),
          ])));
    });
  }

  // ═══ 游戏逻辑 ═══
  void _updateStatus() {
    if (_game.gameOver) {
             _status = _game.winner == 0 ? '你赢了！' : '玩家${_game.winner! + 1}获胜';
    } else if (_game.isPlayerTurn) {
      if (_needsColorPick) _status = '请选择颜色';
      else if (_waitingDrawDecision) _status = '抽到的牌可以出';
      else _status = '轮到你了';
    } else {
      _status = '玩家${_game.currentPlayer + 1}思考中…';
    }
    if (mounted) setState(() {});
  }

  void _showPlay(UnoCard card, {bool fromTop = false}) {
    _playedCard = card;
    // AI 出牌：随机 X 偏移，分布对应顶部玩家栏宽度
    _playStartX = fromTop ? (_rng.nextDouble() - 0.5) * 0.8 : 0;
    // 根据来源位置动态设置飞入起点
    final beginY = fromTop ? -0.6 : 0.7;
    _playPos = Tween<Offset>(begin: Offset(_playStartX, beginY), end: Offset.zero).animate(
        CurvedAnimation(parent: _playCtrl, curve: Curves.fastOutSlowIn));
    _playCtrl.reset(); _playCtrl.forward();
    // 触发特效
    String? effect;
    if (card.type == UnoType.skip) effect = 'skip';
    else if (card.type == UnoType.reverse) effect = 'reverse';
    else if (card.type == UnoType.draw2) effect = 'draw2';
    else if (card.type == UnoType.wild) effect = 'wild';
    else if (card.type == UnoType.wildDraw4) effect = 'wild4';
    if (effect != null) _triggerEffect(effect);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() { _playedCard = null; });
    });
  }

  void _checkAiTurn() {
    if (_game.gameOver) return;
    if (_game.isPlayerTurn) { _updateStatus(); return; }
    _doAiTurn();
  }

  void _doAiTurn() {
    _updateStatus();
    _aiTimer?.cancel();
    _aiTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final idx = _ai.chooseCard(_game, _game.currentPlayer);
      if (idx != null) {
        final card = _game.hands[_game.currentPlayer][idx];
        _showPlay(card, fromTop: true);
        UnoColor? chosen;
        if (card.isWild) chosen = _ai.chooseColor(_game, _game.currentPlayer);
        _game.playCard(_game.currentPlayer, idx, chosenColor: chosen);
      } else {
        _game.drawCard(_game.currentPlayer);
      }
      _updateStatus();
      if (!_game.gameOver) {
        _aiTimer = Timer(const Duration(milliseconds: 600), () {
          if (mounted) _checkAiTurn();
        });
      }
    });
  }

  void _onCardTap(int idx) {
    if (!_game.isPlayerTurn || _game.gameOver || _needsColorPick || _waitingDrawDecision) return;
    final playable = _game.playableIndices(0);
    if (!playable.contains(idx)) { setState(() => _selectedIdx = null); return; }
    final card = _game.hands[0][idx];
    if (card.isWild) { setState(() { _selectedIdx = idx; _needsColorPick = true; }); return; }
    _playNow(idx);
  }

  void _playNow(int idx, {UnoColor? c}) {
    final card = _game.hands[0][idx];
    _showPlay(card);
    _game.playCard(0, idx, chosenColor: c);
    setState(() { _selectedIdx = null; _needsColorPick = false;
      _drawnCard = null; _waitingDrawDecision = false; _updateStatus(); });
    _checkAiTurn();
  }

  void _onColorPick(UnoColor c) { if (_selectedIdx == null) return; _playNow(_selectedIdx!, c: c); }

  void _onDraw() {
    if (!_game.isPlayerTurn || _game.gameOver || _needsColorPick || _waitingDrawDecision) return;
    final card = _game.drawCard(0);
    if (card != null) { setState(() { _drawnCard = card; _waitingDrawDecision = true; _updateStatus(); }); }
    else { setState(() { _selectedIdx = null; _updateStatus(); }); _checkAiTurn(); }
  }

  void _playDrawnCard({UnoColor? c}) { if (_drawnCard == null || !_game.isPlayerTurn) return; _playNow(_game.hands[0].length - 1, c: c); }

  void _keepDrawnCard() { if (!_game.isPlayerTurn) return; _game.passTurn();
    setState(() { _drawnCard = null; _waitingDrawDecision = false; _updateStatus(); }); _checkAiTurn(); }

  void _onDrawnCardTap() { if (_drawnCard == null) return;
    if (_drawnCard!.isWild) { setState(() { _selectedIdx = _game.hands[0].length - 1; _needsColorPick = true; }); }
    else _playDrawnCard(); }

  void _restart() {
    _aiTimer?.cancel(); _dealTimer?.cancel();
    _game = UnoGame(playerCount: widget.playerCount, startingPlayer: _rng.nextInt(widget.playerCount));
    _selectedIdx = null; _needsColorPick = false; _drawnCard = null;
    _waitingDrawDecision = false; _playedCard = null; _playCtrl.reset();
    _effectType = null; _effectCtrl.reset(); _dealFlyCtrl.reset();
    _updateStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startDeal());
  }

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppThemeColors.bg(night),
      appBar: AppBar(title: Text('UNO · ${widget.playerCount}人'),
          backgroundColor: AppThemeColors.bg(night), elevation: 0,
          actions: [IconButton(icon: const Icon(Icons.help_outline), tooltip: '教程',
              onPressed: () => Navigator.pushNamed(context, '/tutorial', arguments: 'uno'))]),
      body: Stack(children: [
        SafeArea(child: Column(children: [
          _opponents(night),
          Expanded(child: _table(night)),
          _statusLine(night),
          _playerHand(night),
          _buttons(night),
          const SizedBox(height: 8),
        ])),
        // 发牌飞牌
        if (_dealing) _dealFly(night),
        // 特效叠加
        if (_effectType != null && !_dealing)
          IgnorePointer(child: Container(color: Colors.black54,
              child: Center(child: _buildEffect(_effectType!)))),
        if (_playedCard != null) _playOverlay(night),
      ]),
    );
  }

  Widget _dealFly(bool night) {
    return IgnorePointer(
      child: AnimatedBuilder(animation: _dealFlyCtrl, builder: (_, __) {
        return SlideTransition(
          position: _dealFlyPos,
          child: Transform.scale(
            scale: _dealFlyScale.value,
            child: Opacity(
              opacity: 1.0 - (_dealFlyCtrl.value * 0.3),
              child: Center(
                child: Container(
                  width: 40, height: 54,
                  decoration: BoxDecoration(
                    color: AppThemeColors.highlight(night),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppThemeColors.primary(night), width: 2),
                    boxShadow: [BoxShadow(
                      color: AppThemeColors.primary(night).withValues(alpha: 0.5),
                      blurRadius: 12, spreadRadius: 2)]),
                  child: const Center(child: Text('U', style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white))),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _playOverlay(bool night) {
    return IgnorePointer(
      child: AnimatedBuilder(animation: _playCtrl, builder: (_, __) {
        return SlideTransition(
          position: _playPos,
          child: Opacity(opacity: _playFade.value,
            child: Transform.scale(scale: _playScale.value,
              child: Center(child: _makeCard(_playedCard!, 72)))));
      }),
    );
  }

  Widget _opponents(bool night) {
    final players = List.generate(widget.playerCount, (i) => i);
    return Container(height: 40, margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (int i = 0; i < players.length; i++) ...[
          if (i > 0) Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 400),
              turns: _game.direction == 1 ? 0.0 : 0.5,
              curve: Curves.easeInOut,
              child: Icon(Icons.arrow_forward,
                size: 12, color: AppThemeColors.subtitle(night).withValues(alpha: 0.5))),
          ),
          _playerChip(players[i], night),
        ],
      ]));
  }

  Widget _playerChip(int p, bool night) {
    final count = _dealing ? _dealtToPlayer(p) : _game.hands[p].length;
    final active = _game.currentPlayer == p && !_game.gameOver;
    final isMe = p == 0;
    return AnimatedContainer(duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? AppThemeColors.highlight(night) : AppThemeColors.bg(night),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? AppThemeColors.primary(night) : AppThemeColors.divider(night),
          width: active ? 2 : 1)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isMe ? Icons.person : Icons.computer, size: 12,
            color: active ? AppThemeColors.primary(night) : AppThemeColors.subtitle(night)),
        const SizedBox(width: 3),
        Text(isMe ? '你' : '玩家$p', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: active ? AppThemeColors.primary(night) : AppThemeColors.subtitle(night))),
        const SizedBox(width: 4),
        AnimatedContainer(duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: active ? AppThemeColors.primary(night) : AppThemeColors.divider(night),
            borderRadius: BorderRadius.circular(6)),
          child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: active ? AppThemeColors.filledBtnText(night) : AppThemeColors.subtitle(night)))),
      ]));
  }

  Widget _table(bool night) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text('当前颜色：', style: TextStyle(fontSize: 12, color: AppThemeColors.subtitle(night))),
        AnimatedContainer(duration: const Duration(milliseconds: 300),
          width: 20, height: 20,
          decoration: BoxDecoration(color: _c(_game.currentColor), shape: BoxShape.circle,
            border: Border.all(color: Colors.white38))),
      ]),
      const SizedBox(height: 12),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Stack(alignment: Alignment.center, children: [
          _makeCard(_game.topCard, 66),
          if (_game.gameOver)
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppThemeColors.highlight(night),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _game.winner == 0 ? Colors.green : Colors.redAccent, width: 2)),
              child: Text(_game.winner == 0 ? '获胜' : '落败',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                      color: _game.winner == 0 ? Colors.green : Colors.redAccent))),
        ]),
        const SizedBox(width: 28),
        GestureDetector(
          onTap: _game.isPlayerTurn && !_game.gameOver && !_needsColorPick && !_waitingDrawDecision ? _onDraw : null,
          child: AnimatedScale(scale: _game.isPlayerTurn && !_game.gameOver && !_needsColorPick && !_waitingDrawDecision ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 300), child: _back(66))),
      ]),
      const SizedBox(height: 4),
      Text('牌堆余${_game.drawPile.length}张', style: TextStyle(fontSize: 11, color: AppThemeColors.subtitle(night))),
    ]));
  }

  Widget _statusLine(bool night) {
    final turn = _game.isPlayerTurn && !_game.gameOver;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (_waitingDrawDecision) ...[
          GestureDetector(onTap: _onDrawnCardTap,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(24)),
              child: Text('出牌', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.green)))),
          const SizedBox(width: 20),
          GestureDetector(onTap: _keepDrawnCard,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(24)),
              child: Text('保留', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.orange)))),
        ] else if (turn && !_needsColorPick)
          Text('点击手牌出牌，或点击牌堆摸牌', style: TextStyle(fontSize: 13, color: AppThemeColors.subtitle(night)))
        else
          Text(_status, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: _game.gameOver ? (_game.winner == 0 ? Colors.green : Colors.redAccent) : AppThemeColors.subtitle(night))),
      ]));
  }

  Widget _playerHand(bool night) {
    final hand = _game.hands[0];
    final showCount = _dealing ? _dealtToMe : hand.length;
    if (showCount == 0 && _dealing) return const SizedBox(height: 100);
    final playable = _game.isPlayerTurn && !_game.gameOver && !_needsColorPick && !_waitingDrawDecision
        ? _game.playableIndices(0).toSet() : <int>{};
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_needsColorPick && _game.isPlayerTurn) _colorPick(),
      ClipRect(clipBehavior: Clip.none,
        child: SizedBox(height: 120,
          child: hand.isEmpty && !_dealing
              ? Center(child: Text('手牌已出完', style: TextStyle(fontSize: 14, color: AppThemeColors.subtitle(night))))
              : ListView.builder(scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 10),
                  itemCount: showCount < hand.length ? showCount : hand.length,
                  itemBuilder: (_, i) {
                    final isDrawn = _waitingDrawDecision && _drawnCard != null && !_dealing && i == hand.length - 1;
                    final ok = playable.contains(i) || isDrawn;
                    return GestureDetector(
                      onTap: () => isDrawn ? _onDrawnCardTap() : _onCardTap(i),
                      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                        width: 56, height: 76,
                        margin: EdgeInsets.only(right: 4, top: ok ? 6 : 18, bottom: ok ? 18 : 6),
                        decoration: BoxDecoration(
                          boxShadow: ok ? [BoxShadow(
                            color: _c(_game.currentColor).withValues(alpha: 0.5),
                            blurRadius: 8, spreadRadius: 2, offset: const Offset(0, 0))] : null),
                        child: _makeCard(hand[i], 56, hl: ok, isDrawn: isDrawn)));
                  })),
      ),
    ]);
  }

  Widget _colorPick() {
    final colors = UnoColor.values.map((c) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(onTap: () {
        if (_waitingDrawDecision) _playDrawnCard(c: c);
        else _onColorPick(c);
      }, child: Container(width: 44, height: 44,
        decoration: BoxDecoration(color: _c(c), shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [BoxShadow(color: _c(c).withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 2)]),
        child: Center(child: Text(_n(c), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white))))),
    )).toList();
    return Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: colors));
  }

  Widget _buttons(bool night) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(foregroundColor: AppThemeColors.primary(night),
            side: BorderSide(color: AppThemeColors.primary(night), width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(80))),
          child: const Text('返回'))),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: FilledButton(
          onPressed: _game.gameOver ? _restart
              : (_game.isPlayerTurn && !_needsColorPick && !_waitingDrawDecision ? _onDraw : null),
          style: FilledButton.styleFrom(backgroundColor: AppThemeColors.filledBtn(night),
            foregroundColor: AppThemeColors.filledBtnText(night),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(80))),
          child: Text(_game.gameOver ? '再来一局' : '摸牌', style: const TextStyle(fontSize: 16))))]));
  }

  // ─── 牌面 ───
  Widget _makeCard(UnoCard card, double s, {bool hl = false, bool isDrawn = false}) {
    final w = s; final h = s * 1.36;
    if (card.isWild) return _wild(w, h);
    final bg = _c(card.color!);
    final fg = card.color == UnoColor.yellow ? Colors.black87 : Colors.white;
    final r = s / 56;
    return Container(width: w, height: h,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10 * r),
        border: Border.all(color: hl || isDrawn ? Colors.white : Colors.white24, width: hl || isDrawn ? 3 : 1.5),
        boxShadow: [BoxShadow(color: hl ? bg.withValues(alpha: 0.7) : (isDrawn ? Colors.amber.withValues(alpha: 0.6) : Colors.black26),
            blurRadius: hl || isDrawn ? 14 : 3, spreadRadius: hl || isDrawn ? 2 : 0, offset: const Offset(0, 1))]),
      child: Stack(children: [
        Positioned(top: 3 * r, left: 4 * r, child: Text(card.label, style: TextStyle(fontSize: 10 * r, fontWeight: FontWeight.w900, color: fg))),
        Positioned(bottom: 3 * r, right: 4 * r, child: Transform.rotate(angle: 3.14159, child: Text(card.label, style: TextStyle(fontSize: 10 * r, fontWeight: FontWeight.w900, color: fg)))),
        Center(child: Container(width: 34 * r, height: 44 * r,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(18 * r)),
          child: Center(child: FittedBox(child: Text(card.label, style: TextStyle(fontSize: 24 * r, fontWeight: FontWeight.w900, color: fg)))))),
      ]));
  }

  Widget _wild(double w, double h) {
    final r = w / 56;
    return Container(width: w, height: h,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10 * r), border: Border.all(color: Colors.white60, width: 2)),
      child: ClipRRect(borderRadius: BorderRadius.circular(9 * r),
        child: Column(children: [
          Expanded(child: Row(children: [
            Expanded(child: Container(color: _c(UnoColor.red))),
            Expanded(child: Container(color: _c(UnoColor.blue)))])),
          Expanded(child: Row(children: [
            Expanded(child: Container(color: _c(UnoColor.green))),
            Expanded(child: Container(color: _c(UnoColor.yellow)))]))])));
  }

  Widget _back(double s) {
    final h = s * 1.36;
    return Container(width: s, height: h,
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
      child: Center(child: Container(width: s * 0.5, height: s * 0.5,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.redAccent, width: 2.5),
            color: Colors.red.withValues(alpha: 0.1)),
        child: const Center(child: Text('U', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white54))))));
  }

  Color _c(UnoColor c) => switch (c) {
    UnoColor.red => const Color(0xFFE53935), UnoColor.blue => const Color(0xFF1E88E5),
    UnoColor.green => const Color(0xFF43A047), UnoColor.yellow => const Color(0xFFFDD835)};
  String _n(UnoColor c) => switch (c) {
    UnoColor.red => '红', UnoColor.blue => '蓝', UnoColor.green => '绿', UnoColor.yellow => '黄'};
}

