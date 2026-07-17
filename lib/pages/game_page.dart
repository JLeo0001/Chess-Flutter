import 'dart:async';
import 'package:flutter/material.dart';
import '../gobang/gobang_game.dart';
import '../gobang/gobang_ai.dart';
import '../tictactoe/ttt_game.dart';
import '../tictactoe/ttt_ai.dart';
import '../widgets/board_view.dart';
import '../widgets/ttt_board_view.dart';
import '../widgets/game_shell.dart';

/// 通用游戏页面（五子棋 + 井字棋）
///
/// 使用 GameShell 提供统一 M3 外观。
class GamePage extends StatefulWidget {
  final String gameType;
  final bool isPvE;
  const GamePage({super.key, required this.gameType, required this.isPvE});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late GobangGame _gobangGame;
  late TicTacToeGame _tttGame;
  GobangAI? _gobangAI;
  TicTacToeAI? _tttAI;
  bool _aiThinking = false;

  int _gameState = 0; // 0=waiting, 1=lottery, 2=playing, 3=over

  // 颜色分配
  int _bottomColor = GobangGame.black, _topColor = GobangGame.white;
  int _humanCol = GobangGame.black;
  int _aiCol = GobangGame.white;

  String _bottomLabel = '黑棋', _topLabel = '白棋';
  String _bottomS = '', _topS = '';

  bool get _isGobang => widget.gameType == 'gobang';

  // 开桌动画
  int _lotteryCnt = 0;
  static const _ltTotal = 12;

  @override
  void initState() {
    super.initState();
    _gobangGame = GobangGame();
    _tttGame = TicTacToeGame();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLottery());
  }

  // ═══ 开桌动画 ═══

  void _startLottery() {
    setState(() {
      _gameState = 1;
      _lotteryCnt = 0;
      _bottomS = '';
      _topS = '';
      _bottomLabel = '';
      _topLabel = '';
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
          _bottomColor = _isGobang ? GobangGame.black : TicTacToeGame.x;
          _topColor = _isGobang ? GobangGame.white : TicTacToeGame.o;
          _humanCol = _bottomColor;
          _aiCol = _topColor;
        } else {
          _bottomColor = _isGobang ? GobangGame.white : TicTacToeGame.o;
          _topColor = _isGobang ? GobangGame.black : TicTacToeGame.x;
          _humanCol = _bottomColor;
          _aiCol = _topColor;
        }
        if (_isGobang) {
          _gobangAI = GobangAI(_aiCol);
          _gobangGame.setStartingPlayer(GobangGame.black);
        } else {
          _tttAI = TicTacToeAI(_aiCol);
          _tttGame.setStartingPlayer(TicTacToeGame.x);
        }
        _bottomLabel = '你';
        _topLabel = 'AI';
      } else {
        if (_isGobang) {
          _bottomColor = bottomIsBlack ? GobangGame.black : GobangGame.white;
          _topColor = bottomIsBlack ? GobangGame.white : GobangGame.black;
        } else {
          _bottomColor = bottomIsBlack ? TicTacToeGame.x : TicTacToeGame.o;
          _topColor = bottomIsBlack ? TicTacToeGame.o : TicTacToeGame.x;
        }
        _bottomLabel = _bottomColor == (_isGobang ? GobangGame.black : TicTacToeGame.x) ? '黑棋' : '白棋';
        _topLabel = _topColor == (_isGobang ? GobangGame.black : TicTacToeGame.x) ? '黑棋' : '白棋';
      }
    });

    Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _gameState = 2;
        _bottomS = '🎯';
        _topS = '';
      });
      if (widget.isPvE && _isAITurn()) _scheduleAI();
    });
  }

  // ═══ AI ═══

  bool _isAITurn() {
    if (_isGobang) return !_gobangGame.isGameOver && _gobangGame.currentPlayer == _aiCol;
    return !_tttGame.isGameOver && _tttGame.currentPlayer == _aiCol;
  }

  void _scheduleAI() {
    _aiThinking = true;
    _updateUI();
    Timer(const Duration(milliseconds: 500), _doAI);
  }

  void _doAI() {
    if (_isGobang) {
      if (_gobangGame.isGameOver) {
        _aiThinking = false;
        _updateUI();
        _endGame();
        return;
      }
      final move = _gobangAI!.findBestMove(_gobangGame.board);
      if (move != null) _gobangGame.placePiece(move[0], move[1]);
      _aiThinking = false;
      _updateUI();
      if (_gobangGame.isGameOver) _endGame();
    } else {
      if (_tttGame.isGameOver) {
        _aiThinking = false;
        _updateUI();
        _endGame();
        return;
      }
      final move = _tttAI!.findBestMove(_tttGame.board);
      if (move != null) _tttGame.placePiece(move[0], move[1]);
      _aiThinking = false;
      _updateUI();
      if (_tttGame.isGameOver) _endGame();
    }
  }

  // ═══ 触摸 ═══

  void _onGobangTouch(Offset pos) {
    if (_gameState != 2 || _gobangGame.isGameOver || _aiThinking) return;
    if (widget.isPvE && _gobangGame.currentPlayer != _humanCol) return;
    final row = pos.dx.round(), col = pos.dy.round();
    if (_gobangGame.placePiece(row, col)) {
      _updateUI();
      if (_gobangGame.isGameOver) {
        _endGame();
      } else if (widget.isPvE && _gobangGame.currentPlayer == _aiCol) {
        _scheduleAI();
      }
    }
  }

  void _onTTTTouch(Offset pos) {
    if (_gameState != 2 || _tttGame.isGameOver || _aiThinking) return;
    if (widget.isPvE && _tttGame.currentPlayer != _humanCol) return;
    final row = pos.dx.round(), col = pos.dy.round();
    if (_tttGame.placePiece(row, col)) {
      _updateUI();
      if (_tttGame.isGameOver) {
        _endGame();
      } else if (widget.isPvE && _tttGame.currentPlayer == _aiCol) {
        _scheduleAI();
      }
    }
  }

  // ═══ UI ═══

  void _endGame() => setState(() => _gameState = 3);

  void _reset() {
    if (_isGobang) _gobangGame.reset();
    else _tttGame.reset();
    _gobangAI = null;
    _tttAI = null;
    _aiThinking = false;
    _gameState = 0;
    _startLottery();
  }

  void _updateUI() {
    final over = _isGobang ? _gobangGame.isGameOver : _tttGame.isGameOver;
    if (_gameState == 3 || over) {
      final w = _isGobang ? _gobangGame.winner : _tttGame.winner;
      setState(() {
        if (w == _bottomColor) {
          _bottomS = '🏆 获胜';
          _topS = '—';
        } else if (w == _topColor) {
          _topS = '🏆 获胜';
          _bottomS = '—';
        } else {
          _topS = '平局';
          _bottomS = '平局';
        }
      });
      return;
    }
    if (_aiThinking) {
      setState(() {
        _bottomS = '🎯';
        _topS = 'AI 思考中…';
      });
      return;
    }
    final cur = _isGobang ? _gobangGame.currentPlayer : _tttGame.currentPlayer;
    setState(() {
      _bottomS = cur == _bottomColor ? '🎯' : '';
      _topS = cur == _bottomColor ? '' : '🎯';
    });
  }

  String _resultTitle() {
    final w = _isGobang ? _gobangGame.winner : _tttGame.winner;
    if (_isGobang) {
      if (w == GobangGame.black) return widget.isPvE
          ? (_humanCol == GobangGame.black ? '🎉 你获胜！' : '😔 AI 获胜')
          : '⚫ 黑棋获胜！';
      if (w == GobangGame.white) return widget.isPvE
          ? (_humanCol == GobangGame.white ? '🎉 你获胜！' : '😔 AI 获胜')
          : '⚪ 白棋获胜！';
    } else {
      if (w == TicTacToeGame.x) return widget.isPvE
          ? (_humanCol == TicTacToeGame.x ? '🎉 你获胜！' : '😔 AI 获胜')
          : '✖ 先手获胜！';
      if (w == TicTacToeGame.o) return widget.isPvE
          ? (_humanCol == TicTacToeGame.o ? '🎉 你获胜！' : '😔 AI 获胜')
          : '⭕ 后手获胜！';
    }
    return '🤝 平局';
  }

  Widget _indicator(bool night) {
    if (_isGobang) {
      return StoneIndicator(isBlack: _bottomColor == GobangGame.black);
    }
    return XOIndicator(isX: _bottomColor == TicTacToeGame.x);
  }

  String get _statusTop {
    if (_gameState == 3 || _gobangGame.isGameOver || _tttGame.isGameOver) return _topS;
    if (_gameState == 1) return _topS;
    return _topS;
  }

  String get _statusBottom {
    if (_gameState == 3 || _gobangGame.isGameOver || _tttGame.isGameOver) return _bottomS;
    if (_gameState == 1) return _bottomS;
    return _bottomS;
  }

  bool get _isOver {
    if (_gameState == 3) return true;
    if (_isGobang) return _gobangGame.isGameOver;
    return _tttGame.isGameOver;
  }

  @override
  Widget build(BuildContext context) {
    final n = Theme.of(context).brightness == Brightness.dark;

    return GameShell(
      topLabel: _topLabel.isEmpty ? (_isGobang ? '白棋' : 'O') : _topLabel,
      topStatus: _statusTop,
      bottomLabel: _bottomLabel.isEmpty ? '你' : _bottomLabel,
      bottomStatus: _statusBottom,
      topIndicator: _isGobang
          ? StoneIndicator(isBlack: _topColor == GobangGame.black)
          : XOIndicator(isX: _topColor == TicTacToeGame.x),
      bottomIndicator: _indicator(n),
      builder: (_) => _isGobang
          ? GobangBoardView(game: _gobangGame, onCellTouched: _onGobangTouch)
          : TicTacToeBoardView(game: _tttGame, onCellTouched: _onTTTTouch),
      onBack: () => Navigator.pop(context),
      onReset: _reset,
      showResult: _isOver,
      resultTitle: _resultTitle(),
      lotteryCount: _gameState == 1 ? _lotteryCnt : -1,
      onLotteryFinished: () {},
    );
  }
}
