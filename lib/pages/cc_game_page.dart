import 'dart:async';
import 'package:flutter/material.dart';
import '../chinese_chess/cc_game.dart';
import '../chinese_chess/cc_ai.dart';
import '../widgets/cc_board_view.dart';
import '../themes/app_theme.dart';

/// 中国象棋游戏页面 — 1:1 移植自 ChineseChessActivity.java
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

  static const int _stateWaiting = 0, _stateLottery = 1, _statePlaying = 2, _stateOver = 3;
  int _gameState = _stateWaiting;
  int _humanColor = ChineseChessGame.red;
  int _aiColor = ChineseChessGame.black;
  int _bottomColor = ChineseChessGame.red;
  int _lotteryCount = 0;
  static const int _lotteryTotal = 12;

  String _bottomStatus = '', _topStatus = '';
  String _bottomLabel = '红方', _topLabel = '黑方';

  // 动画相关 — 照搬原版 Activity.startMoveAnimation

  @override
  void initState() {
    super.initState();
    _game = ChineseChessGame();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startGame());
  }

  void _startGame() {
    setState(() { _gameState = _stateLottery; _lotteryCount = 0; _bottomStatus = ''; _topStatus = ''; });
    _animateLotteryStep();
  }

  void _animateLotteryStep() {
    if (_lotteryCount >= _lotteryTotal) { _finishLottery(); return; }
    setState(() {
      final hb = _lotteryCount % 2 == 0;
      _bottomStatus = hb ? '🎯' : ''; _topStatus = hb ? '' : '🎯';
    });
    _lotteryCount++;
    Timer(Duration(milliseconds: 60 + (_lotteryCount - 1) * 18), _animateLotteryStep);
  }

  void _finishLottery() {
    final bottomIsRed = DateTime.now().millisecondsSinceEpoch % 2 == 0;
    if (widget.isPvE) {
      if (bottomIsRed) {
        _bottomColor = ChineseChessGame.red; _humanColor = ChineseChessGame.red; _aiColor = ChineseChessGame.black;
        _bottomLabel = '你 (红)'; _topLabel = 'AI (黑)';
      } else {
        _bottomColor = ChineseChessGame.black; _humanColor = ChineseChessGame.black; _aiColor = ChineseChessGame.red;
        _bottomLabel = '你 (黑)'; _topLabel = 'AI (红)';
      }
      _game.setFlipped(_humanColor == ChineseChessGame.black);
      _ai = ChineseChessAI(_aiColor);
    } else {
      _bottomColor = bottomIsRed ? ChineseChessGame.red : ChineseChessGame.black;
      _bottomLabel = bottomIsRed ? '红方' : '黑方'; _topLabel = bottomIsRed ? '黑方' : '红方';
      _game.setFlipped(!bottomIsRed);
    }
    _game.placeAllPieces(_game.isFlipped);
    _game.setStartingPlayer(ChineseChessGame.red);
    Timer(const Duration(milliseconds: 500), _startPlaying);
  }

  void _startPlaying() {
    setState(() {
      _gameState = _statePlaying;
      _bottomStatus = '🎯'; _topStatus = '';
      _selectedRow = null; _selectedCol = null; _legalMoves = [];
    });
    if (widget.isPvE && _game.currentPlayer == _aiColor) _scheduleAIMove();
  }

  void _scheduleAIMove() {
    _aiThinking = true;
    setState(() => _updateUI());
    Timer(const Duration(milliseconds: 600), _performAIMove);
  }

  void _performAIMove() {
    if (_game.isGameOver) { _aiThinking = false; _updateUI(); _showResult(); return; }
    final move = _ai!.findBestMove(_game);
    if (move != null && move.length >= 4) {
      final fr = move[0], fc = move[1], tr = move[2], tc = move[3];
      
      _game.move(fr, fc, tr, tc);
             _selectedRow = null; _selectedCol = null;
      _boardKey.currentState?.startMoveAnimation(fr, fc, tr, tc, () {
        if (mounted) setState(() { _aiThinking = false; _updateUI(); if (_game.isGameOver) { _showResult(); } });
      });
    } else {
      _aiThinking = false;
      _updateUI();
    }
  }

  void _onCellTouched(int packed) {
    if (_gameState != _statePlaying || _game.isGameOver || _aiThinking) return;
    if (widget.isPvE && _game.currentPlayer != _humanColor) return;
    final row = packed >> 4, col = packed & 0xF;

    if (_selectedRow == null) {
      final piece = _game.board[row][col];
      if (piece != ChineseChessGame.empty && ChineseChessGame.getColor(piece) == _game.currentPlayer) {
        setState(() { _selectedRow = row; _selectedCol = col; _legalMoves = _game.getLegalMoves(row, col); });
      }
    } else {
      if (row == _selectedRow && col == _selectedCol) {
        setState(() { _selectedRow = null; _selectedCol = null; _legalMoves = []; });
        return;
      }
      final piece = _game.board[row][col];
      if (piece != ChineseChessGame.empty && ChineseChessGame.getColor(piece) == _game.currentPlayer) {
        setState(() { _selectedRow = row; _selectedCol = col; _legalMoves = _game.getLegalMoves(row, col); });
        return;
      }
      final isLegal = _legalMoves.any((m) => m[0] == row && m[1] == col);
      if (isLegal) {
        final fr = _selectedRow!, fc = _selectedCol!;
        
        _game.move(fr, fc, row, col);
                 setState(() { _selectedRow = null; _selectedCol = null; _legalMoves = []; });
        // 照搬原版：走子后启动滑动动画，回调中更新UI
        _boardKey.currentState?.startMoveAnimation(fr, fc, row, col, () {
          if (mounted) { setState(() { _updateUI(); });
            if (_game.isGameOver) { _showResult(); }
            else if (widget.isPvE && _game.currentPlayer == _aiColor) _scheduleAIMove();
          }
        });
      } else {
        setState(() { _selectedRow = null; _selectedCol = null; _legalMoves = []; });
      }
    }
  }

  void _showResult() => setState(() { _gameState = _stateOver; _updateUI(); });

  void _resetGame() {
    _game.reset(); _ai = null; _aiThinking = false;
    _selectedRow = null; _selectedCol = null; _legalMoves = [];
    _gameState = _stateWaiting;
    _startGame();
  }

  void _updateUI() {
    if (_game.isGameOver || _gameState == _stateOver) {
      final w = _game.winner;
      if (w == ChineseChessGame.red) {
        if (widget.isPvE && _humanColor == ChineseChessGame.red) { _bottomStatus = '🏆 获胜'; _topStatus = '—'; }
        else if (widget.isPvE) { _bottomStatus = '—'; _topStatus = '🏆 获胜'; }
        else { _bottomStatus = '🏆 红胜'; _topStatus = '—'; }
      } else if (w == ChineseChessGame.black) {
        if (widget.isPvE && _humanColor == ChineseChessGame.black) { _bottomStatus = '🏆 获胜'; _topStatus = '—'; }
        else if (widget.isPvE) { _bottomStatus = '—'; _topStatus = '🏆 获胜'; }
        else { _bottomStatus = '—'; _topStatus = '🏆 黑胜'; }
      } else { _bottomStatus = '平局'; _topStatus = '平局'; }
      return;
    }
    if (_aiThinking) { _bottomStatus = '🎯'; _topStatus = 'AI 思考中…'; return; }
    if (_game.currentPlayer == _bottomColor) { _bottomStatus = '🎯'; _topStatus = ''; }
    else { _topStatus = '🎯'; _bottomStatus = ''; }
  }

  String _getResultTitle() {
    final w = _game.winner;
    if (w == ChineseChessGame.red) return widget.isPvE
        ? (_humanColor == ChineseChessGame.red ? '🎉 你获胜！' : '😔 AI 获胜')
        : '🔴 红方获胜！';
    if (w == ChineseChessGame.black) return widget.isPvE
        ? (_humanColor == ChineseChessGame.black ? '🎉 你获胜！' : '😔 AI 获胜')
        : '⚫ 黑方获胜！';
    return '🤝 平局';
  }

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final isCheck = _gameState == _statePlaying && _game.isInCheck(_game.currentPlayer);

    Widget overlay = const SizedBox.shrink();
    if (_gameState == _stateOver) {
      overlay = Positioned.fill(
        child: Container(
          color: AppThemeColors.overlay(night),
          child: Center(
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: AppThemeColors.divider(night), width: 1)),
              color: AppThemeColors.highlight(night),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_getResultTitle(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppThemeColors.title(night))),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _resetGame,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppThemeColors.filledBtn(night),
                      foregroundColor: AppThemeColors.filledBtnText(night),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(80))),
                    child: const Text('再来一局'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    final hlTop = _gameState == _statePlaying && _topStatus == '🎯';
    final hlBot = _gameState == _statePlaying && _bottomStatus == '🎯';

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        backgroundColor: hlTop ? (night ? AppThemeColors.nightHighlight : AppThemeColors.dayHighlight) : AppThemeColors.bg(night),
        elevation: 0, automaticallyImplyLeading: false, titleSpacing: 16,
        title: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..rotateZ(3.1415927),
          child: Row(children: [
            Expanded(child: Text(_topLabel.isEmpty ? '黑方' : _topLabel,
              style: TextStyle(fontSize: 16, color: AppThemeColors.title(night)), overflow: TextOverflow.ellipsis)),
            Text(_topStatus, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppThemeColors.primary(night))),
          ]),
        ),
      ),
      body: Stack(children: [
        Column(children: [
          if (isCheck)
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.red.withAlpha(60),
              child: const Text('将军！', textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFB3261E), fontWeight: FontWeight.bold))),
          Expanded(child: ChineseChessBoardView(key: _boardKey, game: _game, onCellTouched: _onCellTouched,
            selectedRow: _selectedRow, selectedCol: _selectedCol, legalMoves: _legalMoves,
          )),
        ]),
        overlay,
      ]),
      bottomNavigationBar: SizedBox(height: 56, child: DecoratedBox(
        decoration: BoxDecoration(color: hlBot ? (night ? AppThemeColors.nightHighlight : AppThemeColors.dayHighlight) : AppThemeColors.bg(night)),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(child: Text(_bottomLabel.isEmpty ? '你' : _bottomLabel,
              style: TextStyle(fontSize: 16, color: AppThemeColors.title(night)), overflow: TextOverflow.ellipsis)),            Text(_bottomStatus, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppThemeColors.primary(night))),
          ])),
        ),
      ),
      persistentFooterButtons: [Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(foregroundColor: AppThemeColors.primary(night),
              side: BorderSide(color: AppThemeColors.primary(night), width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(80))),
            child: const Text('返回'))),
          const SizedBox(width: 16),
          Expanded(child: FilledButton(onPressed: _gameState >= _stateLottery ? _resetGame : null,
            style: FilledButton.styleFrom(backgroundColor: AppThemeColors.filledBtn(night),
              foregroundColor: AppThemeColors.filledBtnText(night),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(80))),
            child: const Text('重新开始'))),
        ]),
      )],
    );
  }
}
