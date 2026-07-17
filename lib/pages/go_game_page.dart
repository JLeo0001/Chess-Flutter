import 'dart:async';
import 'package:flutter/material.dart';
import '../go/go_game.dart';
import '../go/go_ai.dart';
import '../widgets/go_board_view.dart';
import '../widgets/game_shell.dart';

/// 围棋游戏页面 — 使用 GameShell 提供统一 M3 外观
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

  int _state = 0; // 0=waiting, 1=lottery, 2=playing, 3=over
  int _bottomC = GoGame.black, _topC = GoGame.white;
  int _lotteryCnt = 0;
  static const _ltTotal = 12;

  String _bottomL = '黑棋', _topL = '白棋';
  String _bottomS = '', _topS = '';

  @override
  void initState() {
    super.initState();
    _game = GoGame(boardSize: 19);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLottery());
  }

  void _startLottery() {
    setState(() {
      _state = 1;
      _lotteryCnt = 0;
      _bottomS = '';
      _topS = '';
      _bottomL = '';
      _topL = '';
    });
    _animateLottery();
  }

  void _animateLottery() {
    Timer.periodic(const Duration(milliseconds: 60), (t) {
      if (_lotteryCnt >= _ltTotal) {
        t.cancel();
        _finishLottery();
        return;
      }
      setState(() {
        _lotteryCnt++;
        _bottomS = _lotteryCnt % 2 == 0 ? '🎯' : '';
        _topS = _lotteryCnt % 2 == 0 ? '' : '🎯';
      });
    });
  }

  void _finishLottery() {
    final bottomIsBlack = DateTime.now().millisecondsSinceEpoch % 2 == 0;
    setState(() {
      if (widget.isPvE) {
        if (bottomIsBlack) {
          _bottomC = GoGame.black; _topC = GoGame.white;
          _humanPlayer = GoGame.black; _aiPlayer = GoGame.white;
        } else {
          _bottomC = GoGame.white; _topC = GoGame.black;
          _humanPlayer = GoGame.white; _aiPlayer = GoGame.black;
        }
        _ai = GoAi(_aiPlayer, 19);
        _game.setStartingPlayer(GoGame.black);
        _bottomL = '你'; _topL = 'AI';
      } else {
        _bottomC = bottomIsBlack ? GoGame.black : GoGame.white;
        _topC = bottomIsBlack ? GoGame.white : GoGame.black;
        _bottomL = _bottomC == GoGame.black ? '黑棋' : '白棋';
        _topL = _topC == GoGame.black ? '黑棋' : '白棋';
      }
    });
    Timer(const Duration(milliseconds: 500), _startPlaying);
  }

  void _startPlaying() {
    setState(() {
      _state = 2;
      _bottomS = '';
      _topS = '';
      _updateUI();
    });
    if (_isAITurn()) _scheduleAI();
  }

  bool _isAITurn() => widget.isPvE && !_game.isGameOver && _game.currentPlayer == _aiPlayer;

  void _scheduleAI() {
    _aiThinking = true;
    _updateUI();
    Timer(const Duration(milliseconds: 300), _doAI);
  }

  void _doAI() {
    if (_game.isGameOver) {
      _aiThinking = false;
      _updateUI();
      _endGame();
      return;
    }
    final move = _ai!.findBestMove(_game);
    if (move != null) {
      if (!_game.placeStone(move[0], move[1])) _fallbackAI();
    } else {
      _game.pass();
    }
    _aiThinking = false;
    _updateUI();
    if (_game.isGameOver) _endGame();
    else if (_isAITurn()) _scheduleAI();
  }

  void _fallbackAI() {
    final moves = _game.validMoves(_game.currentPlayer);
    if (moves.isNotEmpty) {
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
    if (_state != 2 || _game.isGameOver || _aiThinking) return;
    if (widget.isPvE && _game.currentPlayer != _humanPlayer) return;
    if (_game.placeStone(pos.dx.round(), pos.dy.round())) {
      _updateUI();
      if (_game.isGameOver) {
        _endGame();
        return;
      }
      if (_isAITurn()) _scheduleAI();
    }
  }

  void _onPass() {
    if (_state != 2 || _game.isGameOver || _aiThinking) return;
    if (widget.isPvE && _game.currentPlayer != _humanPlayer) return;
    _game.pass();
    _updateUI();
    if (_game.isGameOver) {
      _endGame();
      return;
    }
    if (_isAITurn()) _scheduleAI();
  }

  void _endGame() => setState(() => _state = 3);

  void _reset() {
    _game.reset();
    _ai = null;
    _aiThinking = false;
    _state = 0;
    _startLottery();
  }

  void _updateUI() {
    if (_state == 3 || _game.isGameOver) {
      final d = _game.resultDescription();
      setState(() {
        if (d.contains('黑棋胜')) {
          _bottomS = '🏆';
          _topS = '—';
        } else if (d.contains('白棋胜')) {
          _topS = '🏆';
          _bottomS = '—';
        } else {
          _topS = '½';
          _bottomS = '½';
        }
      });
      return;
    }
    if (_aiThinking) {
      setState(() {
        _bottomS = '···';
        _topS = 'AI…';
      });
      return;
    }
    final cur = _game.currentPlayer;
    setState(() {
      _bottomS = cur == _bottomC ? '🎯' : '';
      _topS = cur == _bottomC ? '' : '🎯';
    });
  }

  String get _resultTitle {
    final d = _game.resultDescription();
    if (d.contains('黑棋胜')) return widget.isPvE
        ? (_humanPlayer == GoGame.black ? '🎉 你获胜！' : '😔 AI 获胜')
        : '⚫ 黑棋胜！';
    if (d.contains('白棋胜')) return widget.isPvE
        ? (_humanPlayer == GoGame.white ? '🎉 你获胜！' : '😔 AI 获胜')
        : '⚪ 白棋胜！';
    return '🤝 平局';
  }

  bool get _isOver => _state == 3 || _game.isGameOver;

  Widget _resultWidget() {
    final s = _game.score();
    
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(_resultTitle,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface)),
      const SizedBox(height: 4),
      Text(_game.resultDescription(),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      _scoreRow('⚫ 黑方', s.blackStones, s.blackTerritory, s.capturedByBlack, s.blackTotal),
      const Divider(height: 12),
      _scoreRow('⚪ 白方', s.whiteStones, s.whiteTerritory, s.capturedByWhite, s.whiteTotal),
    ]);
  }

  Widget _scoreRow(String label, int stones, double ter, int cap, double total) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        Expanded(flex: 3, child: Text(label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface))),
        _chip('子', stones, cs),
        const Text('+', style: TextStyle(fontSize: 11)),
        _chipD('空', ter, cs),
        const Text('+', style: TextStyle(fontSize: 11)),
        _chip('吃', cap, cs),
        const Text('=', style: TextStyle(fontSize: 11)),
        Text(_fmt(total),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.primary)),
      ]),
    );
  }

  Widget _chip(String l, int v, ColorScheme cs) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$v', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
      Text(l, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
    ]);
  }

  Widget _chipD(String l, double v, ColorScheme cs) {
    final s = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(s, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
      Text(l, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
    ]);
  }

  String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return GameShell(
      topLabel: _topL.isEmpty ? '白棋' : _topL,
      topStatus: _topS,
      bottomLabel: _bottomL.isEmpty ? '你' : _bottomL,
      bottomStatus: _bottomS,
      topIndicator: StoneIndicator(isBlack: _topC == GoGame.black),
      bottomIndicator: StoneIndicator(isBlack: _bottomC == GoGame.black),
      builder: (_) => GoBoardView(game: _game, onCellTouched: _onTouch),
      onBack: () => Navigator.pop(context),
      onReset: _reset,
      showResult: _isOver,
      resultWidget: _resultWidget(),
      lotteryCount: _state == 1 ? _lotteryCnt : -1,
      onLotteryFinished: () {},
      extraBottomButtons: [
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: (_state == 2 && !_aiThinking) ? _onPass : null,
            child: const Text('停一手', style: TextStyle(fontSize: 14)),
          ),
        ),
      ],
    );
  }
}
