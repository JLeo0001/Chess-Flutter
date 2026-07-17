import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:card_game/card_game.dart';
import '../doudizhu/doudizhu_card.dart';
import '../doudizhu/doudizhu_game.dart';
import '../themes/app_theme.dart';

enum DdzPhase { bidding, playing, result }

class DoudizhuGamePage extends StatefulWidget {
  const DoudizhuGamePage({super.key});
  @override
  State<DoudizhuGamePage> createState() => _DoudizhuGamePageState();
}

class _DoudizhuGamePageState extends State<DoudizhuGamePage>
    with TickerProviderStateMixin {
  static final _rng = Random();

  late DoudizhuGame _game;
  DdzPhase _phase = DdzPhase.bidding;
  int _bidder = 0;
  int _bidValue = 0;

  final Set<int> _selectedIndices = {};
  Timer? _aiTimer;
  List<DdzCombo>? _hints;
  int _hintIdx = 0;

  // ═══ 发牌动画（UNO 风格）═══
  bool _dealing = false;
  int _dealStep = 0;
  int _lastDealStep = 0;
  Timer? _dealTimer;
  late AnimationController _dealFlyCtrl;
  late Animation<Offset> _dealFlyPos;
  late Animation<double> _dealFlyScale;

  // ═══ 出牌动画 ═══
  DdzCombo? _animPlay;
  late AnimationController _playCtrl;
  late Animation<double> _playScale, _playFade;
  late Animation<Offset> _playPos;

  // ═══ 特效 ═══
  String? _effectType;
  late AnimationController _effectCtrl;
  late Animation<double> _effectScale, _effectFade;

  @override
  void initState() {
    super.initState();
    _playCtrl = AnimationController(duration: const Duration(milliseconds: 450), vsync: this);
    _playScale = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _playCtrl, curve: Curves.elasticOut));
    _playPos = Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero).animate(CurvedAnimation(parent: _playCtrl, curve: Curves.fastOutSlowIn));
    _playFade = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _playCtrl, curve: const Interval(0.3, 1.0)));

    _effectCtrl = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _effectScale = Tween<double>(begin: 0.5, end: 2.0).animate(CurvedAnimation(parent: _effectCtrl, curve: Curves.easeOut));
    _effectFade = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _effectCtrl, curve: const Interval(0.3, 1.0)));

    _dealFlyCtrl = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _dealFlyPos = Tween<Offset>(begin: Offset.zero, end: const Offset(0, 0.55)).animate(CurvedAnimation(parent: _dealFlyCtrl, curve: Curves.decelerate));
    _dealFlyScale = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _dealFlyCtrl, curve: Curves.elasticOut));

    _newGame();
  }

  @override
  void dispose() {
    _dealFlyCtrl.dispose(); _playCtrl.dispose(); _effectCtrl.dispose();
    _aiTimer?.cancel(); _dealTimer?.cancel();
    super.dispose();
  }

  String _playerLabel(int p) => p == 0 ? '你' : '玩家$p';

  void _newGame() {
    _aiTimer?.cancel(); _dealTimer?.cancel();
    _game = DoudizhuGame(landlordIdx: _rng.nextInt(3));
    _phase = DdzPhase.bidding; _selectedIndices.clear(); _hints = null;
    _bidder = _game.landlordIdx; _bidValue = 0;
    _animPlay = null; _effectType = null;
    if (_bidder != 0) Future.delayed(const Duration(milliseconds: 500), _aiBid);
    setState(() {});
  }

  // ═══ 叫地主 ═══
  void _humanBid(int value) {
    if (_phase != DdzPhase.bidding) return;
    setState(() {
      if (value > _bidValue) { _bidValue = value; if (value == 3) { _startPlay(); return; } }
      _bidder = (_bidder + 1) % 3;
    });
    if (_bidder != 0) Future.delayed(const Duration(milliseconds: 500), _aiBid);
  }

  void _aiBid() {
    if (_phase != DdzPhase.bidding || _bidder == 0) return;
    final score = _evalHand(_game.hands[_bidder]);
    if (score > 60 && _bidValue < 3) { setState(() { _bidValue = _bidValue < 1 ? 1 : (_bidValue < 2 ? 2 : 3); _startPlay(); }); return; }
    if (score > 35 && _bidValue < 1) { setState(() { _bidValue = 1; _startPlay(); }); return; }
    setState(() { _bidder = (_bidder + 1) % 3; });
    if (_bidder == 0) { if (_bidValue == 0) _showRedeal(); else _startPlay(); }
    else Future.delayed(const Duration(milliseconds: 500), _aiBid);
  }

  int _evalHand(List<DdzCard> h) {
    int s = 0; final rc = <int, int>{}; for (final c in h) rc[c.rank] = (rc[c.rank] ?? 0) + 1;
    for (final e in rc.entries) { if (e.value == 4) s += 20; else if (e.value == 3) s += 8; else if (e.value == 2) s += 3; }
    if (rc.containsKey(16)) s += 10; if (rc.containsKey(17)) s += 20; if (rc.containsKey(15)) s += 8;
    return s;
  }

  void _startPlay() {
    _game = DoudizhuGame(landlordIdx: _bidder);
    _phase = DdzPhase.playing; _selectedIndices.clear(); _hints = null;
    _startDealAnim();
  }

  void _showRedeal() {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('无人叫地主'), content: const Text('重新发牌'),
      actions: [TextButton(onPressed: () { Navigator.pop(context); _newGame(); }, child: const Text('确定'))],
    ));
  }

  // ═══ 发牌动画（UNO 模式）═══
  void _startDealAnim() {
    setState(() { _dealing = true; _dealStep = 0; _lastDealStep = 0; });
    _dealTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      if (_dealStep >= 17 * 3) {
        t.cancel();
        setState(() { _dealing = false; });
        _dealFlyCtrl.reset();
        if (!_game.isPlayerTurn) _doAiTurn(); else setState(() {});
        return;
      }
      setState(() { _dealStep++; });
      if (_dealStep != _lastDealStep) {
        _lastDealStep = _dealStep;
        _dealFlyCtrl.forward(from: 0);
        final target = (_dealStep - 1) % 3;
        final end = target == 0
            ? const Offset(0, 0.55)
            : Offset(target == 1 ? -0.25 : 0.25, -0.55);
        _dealFlyPos = Tween<Offset>(begin: Offset.zero, end: end).animate(CurvedAnimation(parent: _dealFlyCtrl, curve: Curves.decelerate));
      }
    });
  }

  int _dealtToPlayer(int p) {
    if (!_dealing) return _game.hands[p].length;
    if (_dealStep <= p) return 0;
    return 1 + ((_dealStep - p - 1) ~/ 3);
  }

  // ═══ 出牌 ═══
  bool get _canPlay => _phase == DdzPhase.playing && !_game.gameOver && _game.isPlayerTurn && _selectedIndices.isNotEmpty;
  bool get _canPass => _phase == DdzPhase.playing && !_game.gameOver && _game.isPlayerTurn
      && _game.lastPlayerIdx != null && _game.lastPlayerIdx != 0 && _game.passCount < 2;

  void _onCardTap(int idx) {
    if (_phase != DdzPhase.playing || _game.gameOver || !_game.isPlayerTurn) return;
    setState(() {
      if (_selectedIndices.contains(idx)) _selectedIndices.remove(idx); else _selectedIndices.add(idx);
      _hints = null;
    });
  }

  void _doPlay() {
    if (!_canPlay) return;
    final cards = _selectedIndices.map((i) => _game.hands[0][i]).toList();
    final combo = identifyCombo(cards);
    if (combo == null || !_game.playCards(0, cards)) { _showSnack('不能这样出牌'); return; }
    _showPlayAnim(combo, fromPlayer: true);
    setState(() { _selectedIndices.clear(); _hints = null; });
    if (_game.gameOver) { _delayedResult(); return; }
    Future.delayed(const Duration(milliseconds: 500), _doAiTurn);
  }

  void _doPass() {
    if (!_canPass) return;
    _game.pass(0);
    setState(() { _selectedIndices.clear(); _hints = null; });
    _doAiTurn();
  }

  void _showHint() {
    if (!_game.isPlayerTurn) return;
    final leading = _game.lastPlayerIdx == null || _game.lastPlayerIdx == 0 || _game.passCount >= 2;
    _hints = leading ? findAllCombos(_game.hands[0]) : (_game.lastPlay != null ? findBeatingCombos(_game.hands[0], _game.lastPlay!) : null);
    if (_hints == null || _hints!.isEmpty) { _showSnack('没有能出的牌'); return; }
    if (_hints!.length > 1) _hintIdx = (_hintIdx + 1) % _hints!.length;
    setState(() {
      _selectedIndices.clear();
      for (final c in _hints![_hintIdx].cards) {
        final idx = _game.hands[0].indexWhere((h) => h.rank == c.rank && h.suit == c.suit);
        if (idx >= 0) _selectedIndices.add(idx);
      }
    });
  }

  void _doAiTurn() {
    _aiTimer?.cancel();
    _aiTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || _game.gameOver) return;
      final ai = _game.currentPlayer;
      if (ai == 0) { setState(() {}); return; }
      final combo = _game.getAiPlay(ai);
      if (combo != null) { _game.playCards(ai, combo.cards); _showPlayAnim(combo, fromPlayer: false); }
      else { _game.pass(ai); }
      if (_game.gameOver) { _delayedResult(); return; }
      _doAiTurn();
    });
  }

  void _showPlayAnim(DdzCombo combo, {required bool fromPlayer}) {
    _animPlay = combo;
    final y = fromPlayer ? 0.6 : -0.6;
    _playPos = Tween<Offset>(begin: Offset(0, y), end: Offset.zero).animate(CurvedAnimation(parent: _playCtrl, curve: Curves.fastOutSlowIn));
    _playCtrl.reset(); _playCtrl.forward();
    if (combo.type == DdzComboType.bomb) { _showEffect('💣'); }
    else if (combo.type == DdzComboType.rocket) _showEffect('🚀');
    Future.delayed(const Duration(milliseconds: 500), () { if (mounted) setState(() { _animPlay = null; }); });
  }

  void _showEffect(String icon) {
    _effectType = icon; _effectCtrl.reset(); _effectCtrl.forward();
    Future.delayed(const Duration(milliseconds: 700), () { if (mounted) setState(() { _effectType = null; }); });
  }

  void _delayedResult() {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) { setState(() { _phase = DdzPhase.result; }); }
    });
  }
  void _showSnack(String msg) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 800))); }

  // ═══ UI ═══
  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppThemeColors.bg(night),
      appBar: AppBar(
        title: Text(_phase == DdzPhase.result
            ? (_game.winner == 0 ? '🎉 你赢了！' : (_game.playerIsLandlord ? '农民获胜' : '地主获胜'))
            : '斗地主'),
        backgroundColor: AppThemeColors.bg(night), elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.help_outline), tooltip: '教程',
              onPressed: () => Navigator.pushNamed(context, '/tutorial', arguments: 'doudizhu')),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _newGame)],
      ),
      body: SafeArea(child: Stack(children: [
        Column(children: [
          _topBar(night),
          Expanded(child: _centerArea(night)),
          if (_phase == DdzPhase.playing) _actionBar(night),
          if (_phase == DdzPhase.playing) _playerHand(night),
        ]),
        if (_dealing) _dealFly(night),
        if (_animPlay != null && _phase == DdzPhase.playing) _playOverlay(night),
        if (_effectType != null) _effectOverlay(),
      ])),
    );
  }

  Widget _topBar(bool night) {
    return Container(height: 48, padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _aiInfo(1, night), const Spacer(), _aiInfo(2, night),
      ]),
    );
  }

  Widget _aiInfo(int p, bool night) {
    final count = _dealing ? _dealtToPlayer(p) : _game.hands[p].length;
    final isL = _game.landlordIdx == p;
    final cur = _game.currentPlayer == p && !_game.gameOver && _phase == DdzPhase.playing;
    return AnimatedContainer(duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cur ? AppThemeColors.highlight(night) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cur ? AppThemeColors.primary(night) : Colors.transparent, width: 1.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.computer, size: 16, color: cur ? AppThemeColors.primary(night) : AppThemeColors.subtitle(night)),
        const SizedBox(width: 4),
        Text(_playerLabel(p), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cur ? AppThemeColors.primary(night) : AppThemeColors.subtitle(night))),
        if (isL) ...[const SizedBox(width: 3), Container(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(3)), child: const Text('地主', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)))],
        const SizedBox(width: 4),
        AnimatedContainer(duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(color: cur ? AppThemeColors.primary(night) : AppThemeColors.divider(night), borderRadius: BorderRadius.circular(6)),
          child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cur ? AppThemeColors.filledBtnText(night) : AppThemeColors.subtitle(night)))),
      ]),
    );
  }

  Widget _centerArea(bool night) {
    if (_phase == DdzPhase.bidding) return _biddingArea(night);
    if (_phase == DdzPhase.result) return _resultArea(night);
    return _playArea(night);
  }

  Widget _biddingArea(bool night) {
    final isHuman = _bidder == 0;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final _ in _game.bottomCards) _cardBack(42),
      ]),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: AppThemeColors.highlight(night), borderRadius: BorderRadius.circular(10)),
        child: Text('最高叫分: $_bidValue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppThemeColors.primary(night)))),
      const SizedBox(height: 16),
      if (isHuman) ...[
        Text('轮到你了', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppThemeColors.primary(night))),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _bidBtn('不叫', 0, night),
          if (_bidValue < 1) ...[const SizedBox(width: 8), _bidBtn('1分', 1, night)],
          if (_bidValue < 2) ...[const SizedBox(width: 8), _bidBtn('2分', 2, night)],
          if (_bidValue < 3) ...[const SizedBox(width: 8), _bidBtn('3分', 3, night)],
        ]),
      ] else
        Text('${_playerLabel(_bidder)}思考中…', style: TextStyle(fontSize: 15, color: AppThemeColors.subtitle(night))),
      const SizedBox(height: 16),
      SizedBox(height: 80, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8),
        children: _game.hands[0].map((c) => Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: _renderCard(c, 48))).toList())),
    ]));
  }

  Widget _bidBtn(String label, int value, bool night) {
    return FilledButton(onPressed: () => _humanBid(value),
      style: FilledButton.styleFrom(backgroundColor: value == 0 ? AppThemeColors.divider(night) : AppThemeColors.filledBtn(night),
        foregroundColor: value == 0 ? AppThemeColors.subtitle(night) : AppThemeColors.filledBtnText(night),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
      child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)));
  }

  Widget _playArea(bool night) {
    final lp = _game.lastPlay;
    final lpi = _game.lastPlayerIdx;
    final isHumanTurn = _game.isPlayerTurn;

    return Column(children: [
      const SizedBox(height: 4),
      // 底牌
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: AppThemeColors.highlight(night).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('底牌', style: TextStyle(fontSize: 11, color: AppThemeColors.subtitle(night))),
          const SizedBox(width: 6),
          ..._game.bottomCards.map((c) => Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: _renderCard(c, 38))),
        ]),
      ),
      const SizedBox(height: 6),
      // 牌桌中央区
      Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: night ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppThemeColors.divider(night).withValues(alpha: 0.3)),
          ),
          child: Center(
            child: _animPlay == null
                ? (lp != null
                    ? _buildPlayedCards(lp, lpi!, night)
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.play_circle_outline, size: 32, color: AppThemeColors.subtitle(night).withValues(alpha: 0.4)),
                        const SizedBox(height: 8),
                        Text('地主先出牌', style: TextStyle(fontSize: 15, color: AppThemeColors.subtitle(night).withValues(alpha: 0.6))),
                      ]))
                : const SizedBox.shrink(),
          ),
        ),
      ),
      const SizedBox(height: 6),
      // 当前玩家状态
      if (!_game.gameOver)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: isHumanTurn ? AppThemeColors.primary(night).withValues(alpha: 0.15) : AppThemeColors.highlight(night),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (isHumanTurn) ...[
              const Icon(Icons.touch_app, size: 16, color: Colors.green),
              const SizedBox(width: 6),
              Text('轮到你了', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)),
            ] else ...[
              SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppThemeColors.subtitle(night)),
              ),
              const SizedBox(width: 6),
              Text('${_playerLabel(_game.currentPlayer)}思考中…',
                  style: TextStyle(fontSize: 14, color: AppThemeColors.subtitle(night))),
            ],
          ]),
        ),
      const SizedBox(height: 4),
    ]);
  }

  Widget _buildPlayedCards(DdzCombo lp, int lpi, bool night) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppThemeColors.highlight(night),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(lpi == 0 ? Icons.person : Icons.computer, size: 14, color: AppThemeColors.subtitle(night)),
            const SizedBox(width: 4),
            Text(_playerLabel(lpi), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppThemeColors.primary(night))),
          ]),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: lp.cards.map((c) => Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: _renderCard(c, 50))).toList()),
        ]),
      ),
    ]);
  }

  Widget _resultArea(bool night) {
    final w = _game.winner!;
    final isL = _game.landlordIdx == w;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 8),
      Icon(w == 0 ? Icons.emoji_events : Icons.sentiment_dissatisfied, size: 56, color: w == 0 ? Colors.amber : Colors.grey),
      const SizedBox(height: 8),
      Text(w == 0 ? (isL ? '地主获胜！' : '农民获胜！') : (isL ? '地主获胜' : '农民获胜'),
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: w == 0 ? Colors.amber : Colors.redAccent)),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: _newGame, icon: const Icon(Icons.refresh, size: 18), label: const Text('再来一局'),
        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10))),
      const SizedBox(height: 12),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
        for (int p = 1; p <= 2; p++) ...[
          Padding(padding: const EdgeInsets.only(top: 6, bottom: 3),
            child: Text('${_playerLabel(p)} (${_game.landlordIdx == p ? "地主" : "农民"})', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppThemeColors.subtitle(night)))),
          SizedBox(height: 56, child: ListView(scrollDirection: Axis.horizontal,
            children: _game.hands[p].map((c) => Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: _renderCard(c, 40))).toList())),
        ],
      ])),
    ]));
  }

  Widget _actionBar(bool night) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        if (_game.isPlayerTurn) ...[
          Expanded(child: OutlinedButton(onPressed: _canPass ? _doPass : null,
            style: OutlinedButton.styleFrom(foregroundColor: AppThemeColors.subtitle(night), side: BorderSide(color: AppThemeColors.divider(night)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
            child: const Text('不出', style: TextStyle(fontSize: 14)))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: _game.isPlayerTurn ? _showHint : null,
            style: OutlinedButton.styleFrom(foregroundColor: AppThemeColors.primary(night), side: BorderSide(color: AppThemeColors.primary(night)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
            child: Text(_hints != null ? '下一个' : '提示', style: const TextStyle(fontSize: 14)))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: FilledButton(onPressed: _canPlay ? _doPlay : null,
            style: FilledButton.styleFrom(backgroundColor: AppThemeColors.filledBtn(night), foregroundColor: AppThemeColors.filledBtnText(night), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
            child: const Text('出牌', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)))),
        ] else ...[const Spacer(), Text('等待中…', style: TextStyle(fontSize: 14, color: AppThemeColors.subtitle(night))), const Spacer()],
      ]));
  }

  Widget _playerHand(bool night) {
    if (_phase != DdzPhase.playing || _dealing) return const SizedBox(height: 80);
    final hand = _game.hands[0];
    if (hand.isEmpty) return const SizedBox(height: 80);
    final isTurn = _game.isPlayerTurn;
    return ClipRect(
      clipBehavior: Clip.none,
      child: SizedBox(
        height: 120,
        child: ListView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.only(left: 6, right: 6, top: 20),
          children: List.generate(hand.length, (i) {
            final sel = _selectedIndices.contains(i);
            return GestureDetector(
              onTap: isTurn ? () => _onCardTap(i) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: EdgeInsets.only(right: i < hand.length - 1 ? (sel ? -4 : -12) : 0),
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.identity()..translate(0.0, sel ? -16.0 : 0.0),
                  child: _renderCard(hand[i], 52, selected: sel),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ═══ 动画叠加 ═══
  Widget _dealFly(bool night) {
    return IgnorePointer(
      child: AnimatedBuilder(animation: _dealFlyCtrl, builder: (_, __) {
        return SlideTransition(position: _dealFlyPos,
          child: Transform.scale(scale: _dealFlyScale.value,
            child: Opacity(opacity: 1.0 - _dealFlyCtrl.value * 0.3,
              child: Center(child: _cardBack(38)))));  // Changed: no padding around _cardBack
      }),
    );
  }

  Widget _playOverlay(bool night) {
    return IgnorePointer(
      child: AnimatedBuilder(animation: _playCtrl, builder: (_, __) {
        return SlideTransition(position: _playPos,
          child: Opacity(opacity: _playFade.value,
            child: Transform.scale(scale: _playScale.value,
              child: Center(child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center,
                children: _animPlay!.cards.map((c) => Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: _renderCard(c, 50))).toList())))));
      }),
    );
  }

  Widget _effectOverlay() {
    return IgnorePointer(
      child: Container(color: Colors.black54,
        child: Center(
          child: AnimatedBuilder(animation: _effectCtrl, builder: (_, __) {
            return Opacity(opacity: _effectFade.value,
              child: Transform.scale(scale: _effectScale.value,
                child: Container(padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.white60, blurRadius: 30, spreadRadius: 10)]),
                  child: Text(_effectType!, style: const TextStyle(fontSize: 68, fontWeight: FontWeight.w900)))));
          }),
        )),
    );
  }

  // ═══ 卡牌渲染 ═══
  Widget _renderCard(DdzCard card, double size, {bool selected = false}) {
    if (card.isJoker) {
      return Container(width: size, height: size * 1.32,
        decoration: BoxDecoration(
          color: card.isBigJoker ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? Colors.redAccent : Colors.black26, width: selected ? 2.5 : 1),
          boxShadow: selected ? [BoxShadow(color: Colors.redAccent.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1)] : [const BoxShadow(color: Colors.black12, blurRadius: 2)]),
        child: Center(child: Text(card.isBigJoker ? '👑' : '🃏', style: TextStyle(fontSize: size * 0.55))));
    }
    final sc = card.toSuitedCard();
    if (sc == null) return const SizedBox.shrink();
    return AnimatedContainer(duration: const Duration(milliseconds: 200),
      width: size, height: size * 1.32,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? Colors.redAccent : Colors.black26, width: selected ? 2.5 : 1),
        boxShadow: selected ? [BoxShadow(color: Colors.redAccent.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1)] : [const BoxShadow(color: Colors.black12, blurRadius: 2)]),
      child: ClipRRect(borderRadius: BorderRadius.circular(7), child: SuitedCardBuilder(card: sc)));
  }

  Widget _cardBack(double size) {
    return Container(width: size, height: size * 1.32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(colors: [Color(0xFFC62828), Color(0xFF8E0000)]),
        border: Border.all(color: Colors.white24, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)]),
      child: Center(child: Container(width: size * 0.45, height: size * 0.45,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white38, width: 1.5)),
        child: Center(child: Text('🃏', style: TextStyle(fontSize: size * 0.3, color: Colors.white54))))));
  }
}
