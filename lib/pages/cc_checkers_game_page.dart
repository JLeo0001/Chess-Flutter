import 'dart:async';
import 'package:flutter/material.dart';
import '../chinese_checkers/cc_checkers_game.dart';
import '../chinese_checkers/cc_checkers_ai.dart';
import '../widgets/cc_checkers_board_view.dart';
import '../widgets/game_shell.dart';

/// 中国跳棋游戏页面
class ChineseCheckersGamePage extends StatefulWidget {
  final int numPlayers;
  const ChineseCheckersGamePage({super.key, required this.numPlayers});

  @override
  State<ChineseCheckersGamePage> createState() => _ChineseCheckersGamePageState();
}

class _ChineseCheckersGamePageState extends State<ChineseCheckersGamePage> {
  late ChineseCheckersGame _game;
  List<CCAi?> _ais = [];
  int _humanPlayer = 1;
  bool _aiThinking = false;

  int _state = 0; // 0=waiting, 1=lottery, 2=playing, 3=over
  int _lotteryCnt = 0;
  static const _ltTotal = 12;

  String _label = '';
  String _status = '';

  @override
  void initState() {
    super.initState();
    _game = ChineseCheckersGame(numPlayers: widget.numPlayers);
    _ais = List.filled(widget.numPlayers + 1, null);
    for (int p = 1; p <= widget.numPlayers; p++) {
      if (p != _humanPlayer) {
        _ais[p] = CCAi(p, widget.numPlayers, _game);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLottery());
  }

  void _startLottery() {
    setState(() {
      _state = 1;
      _lotteryCnt = 0;
      _label = '';
      _status = '';
    });
    _animateLottery();
  }

  void _animateLottery() {
    Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (_lotteryCnt >= _ltTotal) {
        t.cancel();
        _finishLottery();
        return;
      }
      setState(() => _lotteryCnt++);
    });
  }

  void _finishLottery() {
    // 随机决定人类玩家的颜色（营地位置）
    final rng = DateTime.now().millisecondsSinceEpoch % widget.numPlayers + 1;
    _humanPlayer = rng;

    // 重建AI
    _ais = List.filled(widget.numPlayers + 1, null);
    for (int p = 1; p <= widget.numPlayers; p++) {
      if (p != _humanPlayer) {
        _ais[p] = CCAi(p, widget.numPlayers, _game);
      }
    }

    setState(() {
      _label = '你（${_colorName(_game.playerColor(_humanPlayer))}）';
    });

    Timer(const Duration(milliseconds: 400), _startPlaying);
  }

  void _startPlaying() {
    _state = 2;
    _updateUI();
    if (_isAITurn()) _scheduleAI();
  }

  bool _isAITurn() =>
      !_game.isGameOver &&
      _game.currentPlayer != _humanPlayer &&
      _ais[_game.currentPlayer] != null;

  void _scheduleAI() {
    _aiThinking = true;
    _updateUI();
    Timer(const Duration(milliseconds: 400), _doAI);
  }

  void _doAI() {
    if (_game.isGameOver) {
      _aiThinking = false;
      _updateUI();
      _endGame();
      return;
    }

    final ai = _ais[_game.currentPlayer];
    if (ai == null) {
      _aiThinking = false;
      _updateUI();
      return;
    }

    final move = ai.findBestMove();
    if (move != null) {
      // 通过 tapCell 执行：先选中，再走到目标
      _game.tapCell(move[0]); // 选中
      _game.tapCell(move[1]); // 移动
    }

    _aiThinking = false;
    _updateUI();

    if (_game.isGameOver) {
      _endGame();
      return;
    }

    // 检查下一个玩家是否AI
    if (_isAITurn()) {
      _scheduleAI();
    }
  }

  void _onCellTap(int index) {
    if (_state != 2 || _game.isGameOver || _aiThinking) return;
    if (_game.currentPlayer != _humanPlayer) return;

    _game.tapCell(index);
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
    _ais = List.filled(widget.numPlayers + 1, null);
    for (int p = 1; p <= widget.numPlayers; p++) {
      if (p != _humanPlayer) {
        _ais[p] = CCAi(p, widget.numPlayers, _game);
      }
    }
    _aiThinking = false;
    _state = 0;
    _startLottery();
  }

  void _updateUI() {
    if (_state == 3 || _game.isGameOver) {
      setState(() {
        _status = _game.winner == _humanPlayer ? '🏆 你赢了！' : 'AI 获胜';
      });
      return;
    }
    if (_aiThinking) {
      setState(() => _status = 'AI思考中…');
      return;
    }
    final cur = _game.currentPlayer;
    setState(() {
      _status = cur == _humanPlayer ? '轮到你走棋' : '等待AI走棋';
    });
  }

  String _colorName(int colorIdx) {
    const names = ['', '红', '蓝', '绿', '橙', '紫', '黄'];
    return colorIdx < names.length ? names[colorIdx] : '$colorIdx';
  }

  String get _resultTitle {
    if (_game.winner == _humanPlayer) return '🎉 你获胜！';
    return 'AI 获胜';
  }

  String get _resultDetail {
    final w = _game.winner;
    return '${_colorName(w == _humanPlayer ? _game.playerColor(w) : _game.playerColor(w))}方率先占领目标营地';
  }

  @override
  Widget build(BuildContext context) {
    final isOver = _state == 3 || _game.isGameOver;

    Widget resultWidget = Column(mainAxisSize: MainAxisSize.min, children: [
      Text(_resultTitle,
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface)),
      const SizedBox(height: 6),
      Text(_resultDetail,
          style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 12),
      Text('移动步数: ${_game.moveCount}',
          style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);

    return GameShell(
      topLabel: '${widget.numPlayers}人对战',
      topStatus: _state == 2 ? _status : '',
      bottomLabel: _label.isEmpty
          ? '${widget.numPlayers}人对战'
          : _label,
      bottomStatus: _state == 2 ? '' : _status,
      builder: (_) => CCBoardView(
        game: _game,
        onCellTapped: _onCellTap,
        playerColor: _game.playerColor(_humanPlayer),
      ),
      onBack: () => Navigator.pop(context),
      onReset: _reset,
      showResult: isOver,
      resultWidget: resultWidget,
      lotteryCount: _state == 1 ? _lotteryCnt : -1,
      onLotteryFinished: () {},
    );
  }
}
