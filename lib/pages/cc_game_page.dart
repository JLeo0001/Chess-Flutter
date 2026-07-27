import 'dart:async';
import 'package:flutter/material.dart';
import '../chinese_chess/cc_game.dart';
import '../chinese_chess/cc_ai.dart';
import '../widgets/cc_board_view.dart';
import '../widgets/game_shell.dart';

/// 中国象棋游戏页面 — 使用 GameShell 提供统一 M3 外观
class ChineseChessGamePage extends StatefulWidget {
  final bool isPvE;
  const ChineseChessGamePage({super.key, required this.isPvE});

  @override
  State<ChineseChessGamePage> createState() => _ChineseChessGamePageState();
}

class _ChineseChessGamePageState extends State<ChineseChessGamePage> {
  late ChineseChessGame _game;
  ChineseChessAI? _ai;
  int? _selectedRow, _selectedCol;
  List<List<int>> _legalMoves = [];
  bool _aiThinking = false;
  final _boardKey = GlobalKey<ChineseChessBoardViewState>();

  int _gameState = 0; // 0=waiting, 1=lottery, 2=playing, 3=over
  int _humanColor = ChineseChessGame.red;
  int _aiColor = ChineseChessGame.black;
  int _bottomColor = ChineseChessGame.red;
  int _lotteryCnt = 0;
  static const _ltTotal = 12;

  String _bottomS = '', _topS = '';
  String _bottomLabel = '红方', _topLabel = '黑方';

  @override
  void initState() {
    super.initState();
    _game = ChineseChessGame();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startGame());
  }

  void _startGame() {
    setState(() {
      _gameState = 1;
      _lotteryCnt = 0;
      _bottomS = '';
      _topS = '';
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
    final bottomIsRed = DateTime.now().millisecondsSinceEpoch % 2 == 0;
    if (widget.isPvE) {
      if (bottomIsRed) {
        _bottomColor = ChineseChessGame.red;
        _humanColor = ChineseChessGame.red;
        _aiColor = ChineseChessGame.black;
        _bottomLabel = '你 (红)';
        _topLabel = 'AI (黑)';
      } else {
        _bottomColor = ChineseChessGame.black;
        _humanColor = ChineseChessGame.black;
        _aiColor = ChineseChessGame.red;
        _bottomLabel = '你 (黑)';
        _topLabel = 'AI (红)';
      }
      _game.setFlipped(_humanColor == ChineseChessGame.black);
      _ai = ChineseChessAI(_aiColor);
    } else {
      _bottomColor = bottomIsRed ? ChineseChessGame.red : ChineseChessGame.black;
      _bottomLabel = bottomIsRed ? '红方' : '黑方';
      _topLabel = bottomIsRed ? '黑方' : '红方';
      _game.setFlipped(!bottomIsRed);
    }
    _game.placeAllPieces(_game.isFlipped);
    _game.setStartingPlayer(ChineseChessGame.red);

    Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _gameState = 2;
        _bottomS = '🎯';
        _topS = '';
        _selectedRow = null;
        _selectedCol = null;
        _legalMoves = [];
      });
      if (widget.isPvE && _game.currentPlayer == _aiColor) _scheduleAI();
    });
  }

  void _scheduleAI() {
    _aiThinking = true;
    _updateUI();
    Timer(const Duration(milliseconds: 600), _doAI);
  }

  void _doAI() {
    if (_game.isGameOver) {
      _aiThinking = false;
      _updateUI();
      _endGame();
      return;
    }
    final move = _ai!.findBestMove(_game);
    if (move != null && move.length >= 4) {
      final fr = move[0], fc = move[1], tr = move[2], tc = move[3];
      _game.move(fr, fc, tr, tc);
      _selectedRow = null;
      _selectedCol = null;
      _boardKey.currentState?.startMoveAnimation(fr, fc, tr, tc, () {
        if (mounted) {
          setState(() {
            _aiThinking = false;
            _updateUI();
          });
          if (_game.isGameOver) _endGame();
        }
      });
    } else {
      _aiThinking = false;
      _updateUI();
    }
  }

  void _onCellTouched(int packed) {
    if (_gameState != 2 || _game.isGameOver || _aiThinking) return;
    if (widget.isPvE && _game.currentPlayer != _humanColor) return;
    final row = packed >> 4, col = packed & 0xF;

    if (_selectedRow == null) {
      final piece = _game.board[row][col];
      if (piece != ChineseChessGame.empty &&
          ChineseChessGame.getColor(piece) == _game.currentPlayer) {
        setState(() {
          _selectedRow = row;
          _selectedCol = col;
          _legalMoves = _game.getLegalMoves(row, col);
        });
      }
    } else {
      if (row == _selectedRow && col == _selectedCol) {
        setState(() {
          _selectedRow = null;
          _selectedCol = null;
          _legalMoves = [];
        });
        return;
      }
      final piece = _game.board[row][col];
      if (piece != ChineseChessGame.empty &&
          ChineseChessGame.getColor(piece) == _game.currentPlayer) {
        setState(() {
          _selectedRow = row;
          _selectedCol = col;
          _legalMoves = _game.getLegalMoves(row, col);
        });
        return;
      }
      final isLegal = _legalMoves.any((m) => m[0] == row && m[1] == col);
      if (isLegal) {
        final fr = _selectedRow!, fc = _selectedCol!;
        _game.move(fr, fc, row, col);
        setState(() {
          _selectedRow = null;
          _selectedCol = null;
          _legalMoves = [];
        });
        _boardKey.currentState?.startMoveAnimation(fr, fc, row, col, () {
          if (mounted) {
            setState(() => _updateUI());
            if (_game.isGameOver) {
              _endGame();
            } else if (widget.isPvE && _game.currentPlayer == _aiColor) {
              _scheduleAI();
            }
          }
        });
      } else {
        setState(() {
          _selectedRow = null;
          _selectedCol = null;
          _legalMoves = [];
        });
      }
    }
  }

  void _endGame() => setState(() {
    _gameState = 3;
    _updateUI();
  });

  void _reset() {
    _game.reset();
    _ai = null;
    _aiThinking = false;
    _selectedRow = null;
    _selectedCol = null;
    _legalMoves = [];
    _gameState = 0;
    _startGame();
  }

  void _updateUI() {
    if (_game.isGameOver || _gameState == 3) {
      final w = _game.winner;
      if (w == ChineseChessGame.red) {
        if (widget.isPvE && _humanColor == ChineseChessGame.red) {
          _bottomS = '🏆 获胜';
          _topS = '—';
        } else if (widget.isPvE) {
          _bottomS = '—';
          _topS = '🏆 获胜';
        } else {
          _bottomS = '🏆 红胜';
          _topS = '—';
        }
      } else if (w == ChineseChessGame.black) {
        if (widget.isPvE && _humanColor == ChineseChessGame.black) {
          _bottomS = '🏆 获胜';
          _topS = '—';
        } else if (widget.isPvE) {
          _bottomS = '—';
          _topS = '🏆 获胜';
        } else {
          _bottomS = '—';
          _topS = '🏆 黑胜';
        }
      } else {
        _bottomS = '平局';
        _topS = '平局';
      }
      return;
    }
    if (_aiThinking) {
      _bottomS = '🎯';
      _topS = 'AI 思考中…';
      return;
    }
    if (_game.currentPlayer == _bottomColor) {
      _bottomS = '🎯';
      _topS = '';
    } else {
      _topS = '🎯';
      _bottomS = '';
    }
  }

  String _resultTitle() {
    final w = _game.winner;
    if (w == ChineseChessGame.red) {
      return widget.isPvE
          ? (_humanColor == ChineseChessGame.red ? '🎉 你获胜！' : '😔 AI 获胜')
          : '🔴 红方获胜！';
    }
    if (w == ChineseChessGame.black) {
      return widget.isPvE
          ? (_humanColor == ChineseChessGame.black ? '🎉 你获胜！' : '😔 AI 获胜')
          : '⚫ 黑方获胜！';
    }
    return '🤝 平局';
  }

  bool get _isOver => _gameState == 3 || _game.isGameOver;
  bool get _inCheck =>
      _gameState == 2 && !_game.isGameOver && _game.isInCheck(_game.currentPlayer);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GameShell(
      topLabel: _topLabel.isEmpty ? '黑方' : _topLabel,
      topStatus: _topS,
      bottomLabel: _bottomLabel.isEmpty ? '你' : _bottomLabel,
      bottomStatus: _bottomS,
      builder: (_) => ChineseChessBoardView(
        key: _boardKey,
        game: _game,
        onCellTouched: _onCellTouched,
        selectedRow: _selectedRow,
        selectedCol: _selectedCol,
        legalMoves: _legalMoves,
      ),
      onBack: () => Navigator.pop(context),
      onReset: _reset,
      showResult: _isOver,
      resultTitle: _resultTitle(),
      lotteryCount: _gameState == 1 ? _lotteryCnt : -1,
      onLotteryFinished: () {},
      statusBanner: _inCheck
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.red.withAlpha(60),
              child: Text(
                '将军！',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }
}
