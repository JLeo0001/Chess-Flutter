import 'dart:async';
import 'package:flutter/material.dart';
import '../gobang/gobang_game.dart';
import '../gobang/gobang_ai.dart';
import '../tictactoe/ttt_game.dart';
import '../tictactoe/ttt_ai.dart';
import '../widgets/board_view.dart';
import '../widgets/ttt_board_view.dart';
import '../themes/app_theme.dart';

/// 通用游戏页面（五子棋 + 井字棋）
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
  int _humanPlayer = GobangGame.black;
  int _aiPlayer = GobangGame.white;
  bool _aiThinking = false;

  static const int _stateWaiting = 0, _stateLottery = 1, _statePlaying = 2, _stateOver = 3;
  int _gameState = _stateWaiting;
  int _bottomColor = GobangGame.black, _topColor = GobangGame.white;
  int _lotteryCount = 0;
  static const int _lotteryTotal = 12;

  String _bottomStatus = '', _topStatus = '';
  String _bottomLabel = '黑棋', _topLabel = '白棋';

  bool get _isGobang => widget.gameType == 'gobang';

  @override
  void initState() {
    super.initState();
    _gobangGame = GobangGame();
    _tttGame = TicTacToeGame();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLottery());
  }

  void _startLottery() {
    setState(() {
      _gameState = _stateLottery;
      _lotteryCount = 0;
      _bottomStatus = ''; _topStatus = '';
      _bottomLabel = ''; _topLabel = '';
    });
    _animateLotteryStep();
  }

  void _animateLotteryStep() {
    if (_lotteryCount >= _lotteryTotal) { _finishLottery(); return; }
    setState(() {
      final hb = _lotteryCount % 2 == 0;
      _bottomStatus = hb ? '🎯' : '';
      _topStatus = hb ? '' : '🎯';
    });
    _lotteryCount++;
    Timer(Duration(milliseconds: 60 + (_lotteryCount - 1) * 18), _animateLotteryStep);
  }

  void _finishLottery() {
    final bottomIsBlack = _isGobang
        ? (DateTime.now().millisecondsSinceEpoch % 2 == 0)
        : (DateTime.now().millisecondsSinceEpoch % 3 == 0);

    if (_isGobang) {
      if (widget.isPvE) {
        if (bottomIsBlack) {
          _bottomColor = GobangGame.black; _topColor = GobangGame.white;
          _humanPlayer = GobangGame.black; _aiPlayer = GobangGame.white;
        } else {
          _bottomColor = GobangGame.white; _topColor = GobangGame.black;
          _humanPlayer = GobangGame.white; _aiPlayer = GobangGame.black;
        }
        _gobangAI = GobangAI(_aiPlayer);
        _gobangGame.setStartingPlayer(GobangGame.black);
      } else {
        _bottomColor = bottomIsBlack ? GobangGame.black : GobangGame.white;
        _topColor = bottomIsBlack ? GobangGame.white : GobangGame.black;
      }
    } else {
      if (widget.isPvE) {
        if (bottomIsBlack) {
          _bottomColor = TicTacToeGame.x; _topColor = TicTacToeGame.o;
          _humanPlayer = TicTacToeGame.x; _aiPlayer = TicTacToeGame.o;
        } else {
          _bottomColor = TicTacToeGame.o; _topColor = TicTacToeGame.x;
          _humanPlayer = TicTacToeGame.o; _aiPlayer = TicTacToeGame.x;
        }
        _tttAI = TicTacToeAI(_aiPlayer);
        _tttGame.setStartingPlayer(TicTacToeGame.x);
      } else {
        _bottomColor = bottomIsBlack ? TicTacToeGame.x : TicTacToeGame.o;
        _topColor = bottomIsBlack ? TicTacToeGame.o : TicTacToeGame.x;
      }
    }
    _applyLabels();
    Timer(const Duration(milliseconds: 500), _startPlaying);
  }

  void _applyLabels() {
    if (_isGobang) {
      if (widget.isPvE) { _bottomLabel = '你'; _topLabel = 'AI'; }
      else { _bottomLabel = _bottomColor == GobangGame.black ? '黑棋' : '白棋';
             _topLabel = _topColor == GobangGame.black ? '黑棋' : '白棋'; }
    } else {
      if (widget.isPvE) { _bottomLabel = '你'; _topLabel = 'AI'; }
      else { _bottomLabel = _bottomColor == TicTacToeGame.x ? 'X' : 'O';
             _topLabel = _topColor == TicTacToeGame.x ? 'X' : 'O'; }
    }
  }

  void _startPlaying() {
    setState(() {
      _gameState = _statePlaying;
      _bottomStatus = ''; _topStatus = '';
      _updateUI();
    });
    if (widget.isPvE && _isCurrentAITurn()) _scheduleAIMove();
  }

  bool _isCurrentAITurn() {
    if (_isGobang) return !_gobangGame.isGameOver && _gobangGame.currentPlayer == _aiPlayer;
    return !_tttGame.isGameOver && _tttGame.currentPlayer == _aiPlayer;
  }

  void _scheduleAIMove() {
    _aiThinking = true;
    _updateUI();
    Timer(const Duration(milliseconds: 500), _performAIMove);
  }

  void _performAIMove() {
    if (_isGobang) {
      if (_gobangGame.isGameOver) { _aiThinking = false; _updateUI(); _showResult(); return; }
      final move = _gobangAI!.findBestMove(_gobangGame.board);
      if (move != null) _gobangGame.placePiece(move[0], move[1]);
      _aiThinking = false;
      _updateUI();
      if (_gobangGame.isGameOver)       if (_gobangGame.isGameOver) _showResult();
    } else {
      if (_tttGame.isGameOver) { _aiThinking = false; _updateUI(); _showResult(); return; }
      final move = _tttAI!.findBestMove(_tttGame.board);
      if (move != null) _tttGame.placePiece(move[0], move[1]);
      _aiThinking = false;
      _updateUI();
      if (_tttGame.isGameOver)       if (_tttGame.isGameOver) _showResult();
    }
  }

  void _onGobangTouch(Offset pos) {
    if (_gameState != _statePlaying || _gobangGame.isGameOver || _aiThinking) return;
    if (widget.isPvE && _gobangGame.currentPlayer != _humanPlayer) return;
    final row = pos.dx.round(), col = pos.dy.round();
    if (_gobangGame.placePiece(row, col)) {
      _updateUI();
      if (_gobangGame.isGameOver) {
        _showResult();
      } else if (widget.isPvE && _gobangGame.currentPlayer == _aiPlayer) _scheduleAIMove();
    }
  }

  void _onTTTTouch(Offset pos) {
    if (_gameState != _statePlaying || _tttGame.isGameOver || _aiThinking) return;
    if (widget.isPvE && _tttGame.currentPlayer != _humanPlayer) return;
    final row = pos.dx.round(), col = pos.dy.round();
    if (_tttGame.placePiece(row, col)) {
      _updateUI();
      if (_tttGame.isGameOver) {
        _showResult();
      } else if (widget.isPvE && _tttGame.currentPlayer == _aiPlayer) _scheduleAIMove();
    }
  }

  void _showResult() => setState(() => _gameState = _stateOver);

  void _resetGame() {
    if (_isGobang) _gobangGame.reset(); else _tttGame.reset();
    _gobangAI = null; _tttAI = null;
    _aiThinking = false;
    _gameState = _stateWaiting;
    _startLottery();
  }

  void _updateUI() {
    final gameOver = _isGobang ? _gobangGame.isGameOver : _tttGame.isGameOver;
    if (_gameState == _stateOver || gameOver) {
      final w = _isGobang ? _gobangGame.winner : _tttGame.winner;
      setState(() {
        if (w == (_isGobang ? GobangGame.black : TicTacToeGame.x)) { _bottomStatus = '🏆 获胜'; _topStatus = '—'; }
        else if (w == (_isGobang ? GobangGame.white : TicTacToeGame.o)) { _topStatus = '🏆 获胜'; _bottomStatus = '—'; }
        else { _topStatus = '平局'; _bottomStatus = '平局'; }
      });
      return;
    }
    if (_gameState != _statePlaying) { setState(() { _bottomStatus = ''; _topStatus = ''; }); return; }
    if (_aiThinking) { setState(() { _bottomStatus = '🎯'; _topStatus = 'AI 思考中…'; }); return; }
    final cur = _isGobang ? _gobangGame.currentPlayer : _tttGame.currentPlayer;
    setState(() {
      if (cur == _bottomColor) { _bottomStatus = '🎯'; _topStatus = ''; }
      else { _topStatus = '🎯'; _bottomStatus = ''; }
    });
  }

  String _getResultTitle() {
    final w = _isGobang ? _gobangGame.winner : _tttGame.winner;
    if (_isGobang) {
      if (w == GobangGame.black) return widget.isPvE
          ? (_humanPlayer == GobangGame.black ? '🎉 你获胜！' : '😔 AI 获胜')
          : '⚫ 黑棋获胜！';
      if (w == GobangGame.white) return widget.isPvE
          ? (_humanPlayer == GobangGame.white ? '🎉 你获胜！' : '😔 AI 获胜')
          : '⚪ 白棋获胜！';
    } else {
      if (w == TicTacToeGame.x) return widget.isPvE
          ? (_humanPlayer == TicTacToeGame.x ? '🎉 你获胜！' : '😔 AI 获胜')
          : '✖ 先手获胜！';
      if (w == TicTacToeGame.o) return widget.isPvE
          ? (_humanPlayer == TicTacToeGame.o ? '🎉 你获胜！' : '😔 AI 获胜')
          : '⭕ 后手获胜！';
    }
    return '🤝 平局';
  }

  /// 顶栏：用 SizedBox 强制 56px 高度 + DecoratedBox 设背景，确保绝对渲染
  Widget _buildIndicator(int color, bool isGobang) {
    if (isGobang) {
      final isBlack = color == GobangGame.black;
      return Container(
        width: 14, height: 14,
        decoration: BoxDecoration(
          color: isBlack ? const Color(0xFF1C1B1F) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isBlack ? const Color(0xFF49454F) : const Color(0xFFCAC4D0),
            width: 2,
          ),
        ),
      );
    } else {
      final isX = color == TicTacToeGame.x;
      return SizedBox(
        width: 14, height: 14,
        child: isX
            ? CustomPaint(painter: _XIndicatorPainter())
            : CustomPaint(painter: _OIndicatorPainter()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;

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

    // 去掉 SafeArea 和 Stack，最简布局：直接 Scaffold body = Column
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
            if (_gameState >= _statePlaying) _buildIndicator(_topColor, _isGobang),
            if (_gameState >= _statePlaying) const SizedBox(width: 10),
            Expanded(child: Text(_topLabel.isEmpty ? _isGobang ? '白棋' : 'O' : _topLabel,
              style: TextStyle(fontSize: 16, color: AppThemeColors.title(night)), overflow: TextOverflow.ellipsis)),
            Text(_topStatus, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppThemeColors.primary(night))),
          ]),
        ),
      ),
      body: Stack(children: [
        _isGobang
            ? GobangBoardView(game: _gobangGame, onCellTouched: _onGobangTouch)
            : TicTacToeBoardView(game: _tttGame, onCellTouched: _onTTTTouch),
        overlay,
      ]),
      bottomNavigationBar: SizedBox(height: 56, child: DecoratedBox(
        decoration: BoxDecoration(color: hlBot ? (night ? AppThemeColors.nightHighlight : AppThemeColors.dayHighlight) : AppThemeColors.bg(night)),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _buildIndicator(_bottomColor, _isGobang), const SizedBox(width: 10),
            Expanded(child: Text(_bottomLabel.isEmpty ? '你' : _bottomLabel,
              style: TextStyle(fontSize: 16, color: AppThemeColors.title(night)), overflow: TextOverflow.ellipsis)),
            Text(_bottomStatus, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppThemeColors.primary(night))),
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

class _XIndicatorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final s = size.width;
    canvas.drawLine(Offset(2, 2), Offset(s - 2, s - 2), paint);
    canvas.drawLine(Offset(s - 2, 2), Offset(2, s - 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OIndicatorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E88E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
