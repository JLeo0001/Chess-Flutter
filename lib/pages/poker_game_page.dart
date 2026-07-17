import 'dart:math';
import 'package:card_game/card_game.dart';
import 'package:flutter/material.dart';
import '../poker/poker_helper.dart';
import '../themes/app_theme.dart';

enum PokerPhase { dealing, discard, drawing, holdemDeal, flop, turn, river, showdown }

class PokerGamePage extends StatefulWidget {
  final String variant;
  const PokerGamePage({super.key, this.variant = 'draw'});
  @override
  State<PokerGamePage> createState() => _PokerGamePageState();
}

class _PokerGamePageState extends State<PokerGamePage> {
  static final _rng = Random();
  bool get _isDraw => widget.variant == 'draw';
  bool get _isHoldem => widget.variant == 'holdem';

  List<SuitedCard> _deck = [];
  List<SuitedCard> _playerHand = [];
  List<SuitedCard> _aiHand = [];
  List<SuitedCard> _communityCards = [];

  PokerPhase _phase = PokerPhase.dealing;
  final Set<int> _selectedIndices = {};
  bool _aiRevealed = false;
  String? _resultTitle;
  String? _playerHandName;
  String? _aiHandName;
  bool _playerWon = false;
  bool _isDrawGame = false;

  @override
  void initState() {
    super.initState();
    _newDeck();
    WidgetsBinding.instance.addPostFrameCallback((_) => _deal());
  }

  void _newDeck() => _deck = List<SuitedCard>.from(SuitedCard.deck)..shuffle(_rng);

  void _deal() {
    if (_deck.length < 12) _newDeck();
    _playerHand.clear(); _aiHand.clear(); _communityCards.clear();
    _selectedIndices.clear(); _aiRevealed = false;
    _resultTitle = null; _playerHandName = null; _aiHandName = null;
    _playerWon = false; _isDrawGame = false;

    if (_isDraw) {
      _playerHand = List.generate(5, (_) => _deck.removeAt(0));
      _aiHand = List.generate(5, (_) => _deck.removeAt(0));
      setState(() => _phase = PokerPhase.discard);
    } else {
      _playerHand = List.generate(2, (_) => _deck.removeAt(0));
      _aiHand = List.generate(2, (_) => _deck.removeAt(0));
      _communityCards = List.generate(5, (_) => _deck.removeAt(0));
      setState(() => _phase = PokerPhase.holdemDeal);
    }
  }

  void _toggleSelect(int index) {
    if (_phase != PokerPhase.discard) return;
    setState(() {
      if (_selectedIndices.contains(index)) _selectedIndices.remove(index);
      else if (_selectedIndices.length < 3) _selectedIndices.add(index);
    });
  }

  void _discard() {
    if (_phase != PokerPhase.discard) return;
    setState(() => _phase = PokerPhase.drawing);
    if (_deck.length < 6) _newDeck();
    final sorted = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
    for (final i in sorted) _playerHand[i] = _deck.removeAt(0);
    final aiDiscards = aiChooseDiscards(_aiHand);
    final aiSorted = aiDiscards..sort((a, b) => b.compareTo(a));
    for (final i in aiSorted) _aiHand[i] = _deck.removeAt(0);
    _selectedIndices.clear();
    Future.delayed(const Duration(milliseconds: 500), _showdown);
  }

  void _nextHoldemPhase() {
    setState(() {
      switch (_phase) {
        case PokerPhase.holdemDeal: _phase = PokerPhase.flop; break;
        case PokerPhase.flop: _phase = PokerPhase.turn; break;
        case PokerPhase.turn: _phase = PokerPhase.river; break;
        case PokerPhase.river: _showdown(); break;
        default: break;
      }
    });
  }

  void _showdown() {
    String pName, aName; int result;
    if (_isDraw) {
      result = compareHands(_playerHand, _aiHand);
      pName = getHandName(_playerHand);
      aName = getHandName(_aiHand);
    } else {
      final p7 = [..._playerHand, ..._communityCards];
      final a7 = [..._aiHand, ..._communityCards];
      result = compareHands(bestFiveOfSeven(p7), bestFiveOfSeven(a7));
      pName = getHandName(bestFiveOfSeven(p7));
      aName = getHandName(bestFiveOfSeven(a7));
    }
    setState(() {
      _phase = PokerPhase.showdown; _aiRevealed = true;
      _playerHandName = pName; _aiHandName = aName;
      if (result > 0) { _resultTitle = '你获胜！'; _playerWon = true; }
      else if (result < 0) { _resultTitle = 'AI 获胜'; _playerWon = false; }
      else { _resultTitle = '平局'; _isDrawGame = true; }
    });
  }

  int get _visibleCC {
    if (_phase == PokerPhase.river || _phase == PokerPhase.showdown) return 5;
    if (_phase == PokerPhase.flop) return 3;
    if (_phase == PokerPhase.turn) return 4;
    return 0;
  }

  List<SuitedCard> get _visCC => _communityCards.take(_visibleCC).toList();
  List<SuitedCard> get _hidCC => _communityCards.skip(_visibleCC).toList();

  String get _actionLabel {
    switch (_phase) {
      case PokerPhase.showdown: return '再来一局';
      case PokerPhase.discard: return '换牌';
      case PokerPhase.holdemDeal: return '翻公牌';
      case PokerPhase.flop: return '转牌';
      case PokerPhase.turn: return '河牌';
      case PokerPhase.river: return '开牌';
      default: return '…';
    }
  }

  bool get _actionEnabled {
    if (_phase == PokerPhase.showdown) return true;
    if (_isDraw) return _phase == PokerPhase.discard;
    return _phase == PokerPhase.holdemDeal || _phase == PokerPhase.flop ||
           _phase == PokerPhase.turn || _phase == PokerPhase.river;
  }

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppThemeColors.bg(night),
      appBar: AppBar(title: Text(_isDraw ? '换牌扑克' : '德州扑克'),
          backgroundColor: AppThemeColors.bg(night), elevation: 0,
          actions: [IconButton(icon: const Icon(Icons.help_outline), tooltip: '教程',
              onPressed: () => Navigator.pushNamed(context, '/tutorial', arguments: widget.variant == 'holdem' ? 'poker_holdem' : 'poker_draw'))]),
      body: SafeArea(child: Column(children: [
        const SizedBox(height: 8),
        _aiZone(night),
        if (_isHoldem) _communityZone(night),
        _statusBar(night),
        _playerZone(night),
        const Spacer(),
        _actionBar(night),
        const SizedBox(height: 16),
      ])),
    );
  }

  Widget _aiZone(bool night) {
    final cards = _aiRevealed
        ? _aiHand.map((c) => _pokerCard(c)).toList()
        : List.generate(_aiHand.length, (_) => const _CardBack());
    return Column(children: [
      _label('AI', night, icon: Icons.computer),
      const SizedBox(height: 8),
      SizedBox(height: 100, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: cards)),
      if (_aiHandName != null)
        Padding(padding: const EdgeInsets.only(top: 4),
          child: Text(_aiHandName!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
              color: AppThemeColors.primary(night)))),
    ]);
  }

  Widget _communityZone(bool night) {
    final cc = <Widget>[
      ..._visCC.map((c) => _pokerCard(c)),
      ...List.generate(_hidCC.length, (_) => const _CardBack()),
      if (_visCC.isEmpty && _hidCC.isEmpty) ...List.generate(5, (_) => const _PokerSlot()),
    ];
    return Column(children: [
      const SizedBox(height: 4),
      Divider(indent: 48, endIndent: 48, color: AppThemeColors.divider(night)),
      _label('公共牌', night),
      const SizedBox(height: 8),
      SizedBox(height: 100, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: cc)),
      Divider(indent: 48, endIndent: 48, color: AppThemeColors.divider(night)),
    ]);
  }

  Widget _statusBar(bool night) {
    String text; Color color;
    switch (_phase) {
      case PokerPhase.dealing: text = '发牌中…'; color = AppThemeColors.subtitle(night); break;
      case PokerPhase.discard:
        text = _selectedIndices.isEmpty ? '点击选牌（最多3张）' : '已选 $_selectedIndices 张，点击换牌';
        color = AppThemeColors.subtitle(night); break;
      case PokerPhase.drawing: text = '换牌中…'; color = AppThemeColors.subtitle(night); break;
      case PokerPhase.holdemDeal: text = '点击下方按钮翻公牌'; color = AppThemeColors.subtitle(night); break;
      case PokerPhase.flop: text = '三张公牌已翻开'; color = AppThemeColors.subtitle(night); break;
      case PokerPhase.turn: text = '第四张公牌已翻开'; color = AppThemeColors.subtitle(night); break;
      case PokerPhase.river: text = '全部公牌已翻开，点击开牌'; color = AppThemeColors.subtitle(night); break;
      case PokerPhase.showdown: text = '$_resultTitle'; color = _playerWon ? Colors.green : (_isDrawGame ? Colors.orange : Colors.redAccent); break;
    }
    return Padding(padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)));
  }

  Widget _playerZone(bool night) {
    final cards = List.generate(_playerHand.length, (i) {
      final sel = _phase == PokerPhase.discard && _selectedIndices.contains(i);
      return GestureDetector(
        onTap: () => _toggleSelect(i),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 250),
          padding: EdgeInsets.only(bottom: sel ? 16.0 : 0.0),
          child: _pokerCard(_playerHand[i], selected: sel),
        ),
      );
    });
    return Column(children: [
      _label('你', night, icon: Icons.person),
      const SizedBox(height: 8),
      SizedBox(height: 110, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: cards)),
      if (_playerHandName != null)
        Padding(padding: const EdgeInsets.only(top: 4),
          child: Text(_playerHandName!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
              color: AppThemeColors.primary(night)))),
    ]);
  }

  Widget _actionBar(bool night) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(foregroundColor: AppThemeColors.primary(night),
            side: BorderSide(color: AppThemeColors.primary(night), width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(80))),
          child: const Text('返回'))),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: FilledButton(
          onPressed: _actionEnabled ? () {
            if (_phase == PokerPhase.showdown) _deal();
            else if (_isDraw) _discard();
            else _nextHoldemPhase();
          } : null,
          style: FilledButton.styleFrom(backgroundColor: AppThemeColors.filledBtn(night),
            foregroundColor: AppThemeColors.filledBtnText(night),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(80))),
          child: Text(_actionLabel, style: const TextStyle(fontSize: 16)))),
      ]));
  }

  Widget _label(String text, bool night, {IconData? icon}) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (icon != null) Icon(icon, size: 16, color: AppThemeColors.subtitle(night)),
      if (icon != null) const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppThemeColors.subtitle(night))),
    ]);
  }

  Widget _pokerCard(SuitedCard card, {bool selected = false}) {
    return AnimatedContainer(duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: 58, height: 86,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? Colors.redAccent : Colors.black26, width: selected ? 3 : 1),
        boxShadow: [BoxShadow(
          color: selected ? Colors.redAccent.withValues(alpha: 0.5) : Colors.black26,
          blurRadius: selected ? 12 : 3, offset: Offset(0, selected ? 4 : 1))]),
      child: ClipRRect(borderRadius: BorderRadius.circular(7),
        child: SuitedCardBuilder(card: card)));
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack();
  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.symmetric(horizontal: 3),
      width: 58, height: 86,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(colors: [Color(0xFFC62828), Color(0xFF8E0000)]),
        border: Border.all(color: Colors.white24, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)]),
      child: Center(child: Container(width: 30, height: 30,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white38, width: 1.5)),
        child: const Center(child: Text('♠', style: TextStyle(fontSize: 16, color: Colors.white54))))));
  }
}

class _PokerSlot extends StatelessWidget {
  const _PokerSlot();
  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.symmetric(horizontal: 3),
      width: 58, height: 86,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12, width: 1.5, strokeAlign: BorderSide.strokeAlignInside)));
  }
}
