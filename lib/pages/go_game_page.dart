import 'dart:async';
import 'package:flutter/material.dart';
import '../go/go_game.dart';
import '../go/go_ai.dart';
import '../models/log_provider.dart';
import '../widgets/go_board_view.dart';
import '../themes/app_theme.dart';

class GoGamePage extends StatefulWidget {
  final bool isPvE;
  const GoGamePage({super.key, required this.isPvE});

  @override
  State<GoGamePage> createState() => _GoGamePageState();
}

class _GoGamePageState extends State<GoGamePage> {
  late GoGame _game;
  GoAi? _ai;
  int _humanPlayer = GoGame.black;
  int _aiPlayer = GoGame.white;
  bool _aiThinking = false;

  static const int _sWaiting = 0, _sLottery = 1, _sPlaying = 2, _sOver = 3;
  int _state = _sWaiting;
  int _bottomC = GoGame.black, _topC = GoGame.white;
  int _lotteryCnt = 0;
  static const int _ltTotal = 12;

  String _bottomL = '黑棋', _topL = '白棋';
  String _bottomS = '', _topS = '';

  @override
  void initState() {
    super.initState();
    _game = GoGame(boardSize: 19);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLottery());
  }

  void _startLottery() {
    setState(() { _state = _sLottery; _lotteryCnt = 0; _bottomS = ''; _topS = ''; _bottomL = ''; _topL = ''; });
    _animateLotteryStep();
  }

  void _animateLotteryStep() {
    if (!mounted || _lotteryCnt >= _ltTotal) { _finishLottery(); return; }
    setState(() {
      final hb = _lotteryCnt % 2 == 0;
      _bottomS = hb ? '🎯' : ''; _topS = hb ? '' : '🎯';
    });
    _lotteryCnt++;
    if (!mounted) return;
    Timer(Duration(milliseconds: 60 + (_lotteryCnt - 1) * 18), _animateLotteryStep);
  }

  void _finishLottery() {
    final bottomIsBlack = DateTime.now().millisecondsSinceEpoch % 2 == 0;
    if (widget.isPvE) {
      if (bottomIsBlack) { _bottomC = GoGame.black; _topC = GoGame.white; _humanPlayer = GoGame.black; _aiPlayer = GoGame.white; }
      else { _bottomC = GoGame.white; _topC = GoGame.black; _humanPlayer = GoGame.white; _aiPlayer = GoGame.black; }
      _ai = GoAi(_aiPlayer, 19);
      _game.setStartingPlayer(GoGame.black);
      _bottomL = '你'; _topL = 'AI';
    } else {
      _bottomC = bottomIsBlack ? GoGame.black : GoGame.white;
      _topC = bottomIsBlack ? GoGame.white : GoGame.black;
      _bottomL = _bottomC == GoGame.black ? '黑棋' : '白棋';
      _topL = _topC == GoGame.black ? '黑棋' : '白棋';
    }
    Timer(const Duration(milliseconds: 500), _startPlaying);
  }

  void _startPlaying() {
    setState(() { _state = _sPlaying; _bottomS = ''; _topS = ''; _updateUI(); });
    log('GAME', '围棋新对局 — ${widget.isPvE ? "人机" : "双人"}');
    if (widget.isPvE && _isAITurn()) _scheduleAI();
  }

  bool _isAITurn() => widget.isPvE && !_game.isGameOver && _game.currentPlayer == _aiPlayer;

  void _scheduleAI() { _aiThinking = true; _updateUI(); Timer(const Duration(milliseconds: 300), _doAI); }

  void _doAI() {
    if (!mounted) return;
    if (_game.isGameOver) { _aiThinking = false; _updateUI(); _showResult(); return; }
    final move = _ai!.findBestMove(_game);
    if (move != null) {
      if (!_game.placeStone(move[0], move[1])) _fallbackAI();
    } else { _game.pass(); }
    _aiThinking = false; _updateUI();
    if (_game.isGameOver) _showResult(); else if (_isAITurn()) _scheduleAI();
  }

  /// 安全 fallback：使用游戏引擎自身的 validMoves 来确保走法合法
  void _fallbackAI() {
    final moves = _game.validMoves(_game.currentPlayer);
    if (moves.isNotEmpty) {
      // 尽量找靠近上一步（或棋盘中央）的位置，而非行优先
      final lastR = _game.lastRow, lastC = _game.lastCol;
      if (lastR >= 0 && lastC >= 0) {
        moves.sort((a, b) {
          final da = (a[0] - lastR).abs() + (a[1] - lastC).abs();
          final db = (b[0] - lastR).abs() + (b[1] - lastC).abs();
          return da.compareTo(db);
        });
      }
      for (final m in moves) {
        if (_game.placeStone(m[0], m[1])) return;
      }
    }
    _game.pass();
  }

  void _onTouch(Offset pos) {
    if (_state != _sPlaying || _game.isGameOver || _aiThinking) return;
    if (widget.isPvE && _game.currentPlayer != _humanPlayer) return;
    if (_game.placeStone(pos.dx.round(), pos.dy.round())) {
      _updateUI();
      if (_game.isGameOver) { _showResult(); return; }
      if (_isAITurn()) _scheduleAI();
    }
  }

  void _onPass() {
    if (_state != _sPlaying || _game.isGameOver || _aiThinking) return;
    if (widget.isPvE && _game.currentPlayer != _humanPlayer) return;
    _game.pass(); _updateUI();
    if (_game.isGameOver) { _showResult(); return; }
    if (_isAITurn()) _scheduleAI();
  }

  void _showResult() => setState(() => _state = _sOver);

  void _resetGame() {
    _game.reset(); _ai = null; _aiThinking = false; _state = _sWaiting;
    _startLottery();
  }

  void _updateUI() {
    if (_state == _sOver || _game.isGameOver) {
      final d = _game.resultDescription();
      setState(() {
        if (d.contains('黑棋胜')) { _bottomS = '🏆'; _topS = '—'; }
        else if (d.contains('白棋胜')) { _topS = '🏆'; _bottomS = '—'; }
        else { _topS = '½'; _bottomS = '½'; }
      });
      return;
    }
    if (_aiThinking) { setState(() { _bottomS = '···'; _topS = 'AI…'; }); return; }
    final cur = _game.currentPlayer;
    setState(() {
      if (cur == _bottomC) { _bottomS = '🎯'; _topS = ''; } else { _topS = '🎯'; _bottomS = ''; }
    });
  }

  String _resultTitle() {
    final d = _game.resultDescription();
    if (d.contains('黑棋胜')) return widget.isPvE ? (_humanPlayer == GoGame.black ? '🎉 你获胜！' : '😔 AI 获胜') : '⚫ 黑棋胜！';
    if (d.contains('白棋胜')) return widget.isPvE ? (_humanPlayer == GoGame.white ? '🎉 你获胜！' : '😔 AI 获胜') : '⚪ 白棋胜！';
    return '🤝 平局';
  }

  Widget _stone(int c) {
    final isB = c == GoGame.black;
    return Container(width: 14, height: 14,
      decoration: BoxDecoration(color: isB ? const Color(0xFF1C1B1F) : Colors.white, shape: BoxShape.circle,
        border: Border.all(color: isB ? const Color(0xFF49454F) : const Color(0xFFCAC4D0), width: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final hlTop = _state == _sPlaying && _topS == '🎯';
    final hlBot = _state == _sPlaying && _bottomS == '🎯';

    Widget overlay = const SizedBox.shrink();
    if (_state == _sOver) {
      final s = _game.score();
      overlay = Positioned.fill(
        child: Container(color: AppThemeColors.overlay(night),
          child: Center(child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: AppThemeColors.divider(night), width: 1)),
            color: AppThemeColors.highlight(night),
            child: Padding(padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_resultTitle(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppThemeColors.title(night))),
                const SizedBox(height: 4),
                Text(_game.resultDescription(), textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, height: 1.5, color: AppThemeColors.subtitle(night))),
                const SizedBox(height: 8),
                _scoreR('⚫ 黑方', s.blackStones, s.blackTerritory, s.capturedByBlack, s.blackTotal, night),
                const Divider(height: 12),
                _scoreR('⚪ 白方', s.whiteStones, s.whiteTerritory, s.capturedByWhite, s.whiteTotal, night),
                const SizedBox(height: 20),
                FilledButton(onPressed: _resetGame,
                  style: FilledButton.styleFrom(backgroundColor: AppThemeColors.filledBtn(night),
                    foregroundColor: AppThemeColors.filledBtnText(night),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(80))),
                  child: const Text('再来一局', style: TextStyle(fontSize: 14))),
              ]),
            ),
          )),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        backgroundColor: hlTop ? (night ? AppThemeColors.nightHighlight : AppThemeColors.dayHighlight) : AppThemeColors.bg(night),
        elevation: 0, automaticallyImplyLeading: false, titleSpacing: 16,
        title: Transform(alignment: Alignment.center, transform: Matrix4.identity()..rotateZ(3.1415927),
          child: Row(children: [
            if (_state >= _sPlaying) _stone(_topC), if (_state >= _sPlaying) const SizedBox(width: 10),
            Expanded(child: Text(_topL.isEmpty ? '白棋' : _topL,
                style: TextStyle(fontSize: 16, color: AppThemeColors.title(night)), overflow: TextOverflow.ellipsis)),
            Text(_topS, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppThemeColors.primary(night))),
          ])),
      ),
      body: Stack(children: [GoBoardView(game: _game, onCellTouched: _onTouch), overlay]),
      bottomNavigationBar: SizedBox(height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(color: hlBot ? (night ? AppThemeColors.nightHighlight : AppThemeColors.dayHighlight) : AppThemeColors.bg(night)),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _stone(_bottomC), const SizedBox(width: 10),
              Expanded(child: Text(_bottomL.isEmpty ? '你' : _bottomL,
                  style: TextStyle(fontSize: 16, color: AppThemeColors.title(night)), overflow: TextOverflow.ellipsis)),
              Text(_bottomS, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppThemeColors.primary(night))),
            ])))),
      persistentFooterButtons: [Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(foregroundColor: AppThemeColors.primary(night),
              side: BorderSide(color: AppThemeColors.primary(night), width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(80)),
              padding: const EdgeInsets.symmetric(vertical: 12)),
            child: const Text('返回', style: TextStyle(fontSize: 14)))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton(onPressed: (_state == _sPlaying && !_aiThinking) ? _onPass : null,
            style: OutlinedButton.styleFrom(foregroundColor: AppThemeColors.primary(night),
              side: BorderSide(color: AppThemeColors.primary(night), width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(80)),
              padding: const EdgeInsets.symmetric(vertical: 12)),
            child: const Text('停一手', style: TextStyle(fontSize: 14)))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton(onPressed: _state >= _sLottery ? _resetGame : null,
            style: FilledButton.styleFrom(backgroundColor: AppThemeColors.filledBtn(night),
              foregroundColor: AppThemeColors.filledBtnText(night),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(80)),
              padding: const EdgeInsets.symmetric(vertical: 12)),
            child: const Text('重新开始', style: TextStyle(fontSize: 13)))),
        ])),
      ],
    );
  }

  Widget _scoreR(String label, int stones, double ter, int cap, double total, bool night) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        Expanded(flex: 3, child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppThemeColors.title(night)))),
        _scChip('子', stones, night), const Text('+', style: TextStyle(fontSize: 11)),
        _scChipD('空', ter, night), const Text('+', style: TextStyle(fontSize: 11)),
        _scChip('吃', cap, night), const Text('=', style: TextStyle(fontSize: 11)),
        Text(_totalStr(total), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppThemeColors.primary(night))),
      ]));
  }

  Widget _scChip(String l, int v, bool night) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$v', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppThemeColors.title(night))),
      Text(l, style: TextStyle(fontSize: 10, color: AppThemeColors.subtitle(night))),
    ]);
  }

  Widget _scChipD(String l, double v, bool night) {
    final s = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(s, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppThemeColors.title(night))),
      Text(l, style: TextStyle(fontSize: 10, color: AppThemeColors.subtitle(night))),
    ]);
  }

  String _totalStr(double v) {
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }
}
