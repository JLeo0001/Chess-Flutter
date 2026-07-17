import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import '../international_chess/ic_ai.dart';
import '../international_chess/lichess_client.dart';
import '../models/chess_engine_provider.dart';
import '../models/log_provider.dart';
import '../themes/app_theme.dart';

/// 国际象棋游戏页面 — 基于 chessground + dartchess
///
/// 引擎策略：LiChess 云端（在线优先）→ 内置 AI（离线回退）
class InternationalChessGamePage extends StatefulWidget {
  final bool isPvE;
  const InternationalChessGamePage({super.key, required this.isPvE});

  @override
  State<InternationalChessGamePage> createState() => _InternationalChessGamePageState();
}

class _InternationalChessGamePageState extends State<InternationalChessGamePage> {
  Position<Chess> _position = Chess.initial;

  // 游戏状态
  static const int _stateWaiting = 0, _stateLottery = 1, _statePlaying = 2, _stateOver = 3;
  int _gameState = _stateWaiting;
  int _lotteryCount = 0;
  static const int _lotteryTotal = 12;

  // 颜色分配
  Side _humanSide = Side.white;
  Side _aiSide = Side.black;
  Side _bottomSide = Side.white;
  Side _topSide = Side.black;

  // AI
  InternationalChessAI? _ai;
  bool _aiThinking = false;
  String _engineLabel = 'AI';
  bool _useLichess = false;  // 是否优先使用 LiChess 云端
  bool _lastMoveWasLichess = false;  // 上一步是否云端走的（用于标签显示）

  // 界面状态
  String _bottomLabel = '白方', _topLabel = '黑方';
  String _bottomStatus = '', _topStatus = '';
  NormalMove? _lastMove;

  // 升变
  NormalMove? _pendingPromotion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initEngine());
  }

  Side get _sideToMove => _position.turn;

  // ──── 引擎初始化 ────

  void _initEngine() {
    if (!widget.isPvE) {
      _startGame();
      return;
    }

    final engineProv = context.read<ChessEngineProvider>();
    _useLichess = engineProv.isLichess;
    _engineLabel = engineProv.isBuiltin ? '内置AI' : 'LiChess';
    log('ENGINE', '引擎模式: ${engineProv.displayName}');

    // 无论哪种模式，都创建内置 AI 作为回退
    _ai = InternationalChessAI(_aiSide);
    _startGame();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ──── 游戏流程 ────

  void _startGame() {
    _position = Chess.initial;
    _gameState = _stateLottery;
    _lotteryCount = 0;
    _bottomStatus = '';
    _topStatus = '';
    _lastMove = null;
    _pendingPromotion = null;
    log('GAME', '国际象棋新对局 — ${widget.isPvE ? "人机" : "双人"}');
    _animateLotteryStep();
  }

  void _animateLotteryStep() {
    if (!mounted || _lotteryCount >= _lotteryTotal) { _finishLottery(); return; }
    setState(() {
      final hb = _lotteryCount % 2 == 0;
      _bottomStatus = hb ? '🎯' : '';
      _topStatus = hb ? '' : '🎯';
    });
    _lotteryCount++;
    if (!mounted) return;
    Timer(Duration(milliseconds: 60 + (_lotteryCount - 1) * 18), _animateLotteryStep);
  }

  void _finishLottery() {
    final bottomIsWhite = DateTime.now().millisecondsSinceEpoch % 2 == 0;
    if (widget.isPvE) {
      if (bottomIsWhite) {
        _bottomSide = Side.white; _topSide = Side.black;
        _humanSide = Side.white; _aiSide = Side.black;
        _bottomLabel = '你 (白)'; _topLabel = '$_engineLabel (黑)';
      } else {
        _bottomSide = Side.black; _topSide = Side.white;
        _humanSide = Side.black; _aiSide = Side.white;
        _bottomLabel = '你 (黑)'; _topLabel = '$_engineLabel (白)';
      }
      // 重新创建 AI（颜色可能变了）
      _ai = InternationalChessAI(_aiSide);
    } else {
      _bottomSide = bottomIsWhite ? Side.white : Side.black;
      _topSide = bottomIsWhite ? Side.black : Side.white;
      _bottomLabel = bottomIsWhite ? '白方' : '黑方';
      _topLabel = bottomIsWhite ? '黑方' : '白方';
    }
    Timer(const Duration(milliseconds: 500), _startPlaying);
  }

  void _startPlaying() {
    setState(() {
      _gameState = _statePlaying;
      _bottomStatus = '🎯';
      _topStatus = '';
    });
    if (widget.isPvE && _sideToMove == _aiSide) _scheduleAIMove();
  }

  // ──── 合法走法列表 ────

  /// 将 dartchess legalMoves 转为 chessground 的 ValidMoves
  ValidMoves get _validMoves {
    if (_gameState != _statePlaying || _aiThinking) return IMap(const {});
    if (widget.isPvE && _sideToMove != _humanSide) return IMap(const {});
    final map = <Square, ISet<Square>>{};
    for (final entry in _position.legalMoves.entries) {
      map[entry.key] = ISet(entry.value.squares);
    }
    return IMap(map);
  }

  /// 获取合法走法列表（用于 LiChess 验证）
  List<NormalMove> _getMoves(Position<Chess> pos) {
    final list = <NormalMove>[];
    for (final entry in pos.legalMoves.entries) {
      final from = entry.key;
      for (final to in entry.value.squares) {
        list.add(NormalMove(from: from, to: to));
      }
    }
    return list;
  }

  // ──── 玩家走棋 ────

  void _onPlayerMove(NormalMove move, {bool? isDrop}) {
    if (_gameState != _statePlaying || _position.isGameOver || _aiThinking) return;
    if (widget.isPvE && _sideToMove != _humanSide) return;

    final piece = _position.board.pieceAt(move.from);
    if (piece != null && piece.role == Role.pawn) {
      final rank = move.to.rank;
      if ((_humanSide == Side.white && rank == Rank.eighth) ||
          (_humanSide == Side.black && rank == Rank.first)) {
        setState(() { _pendingPromotion = move; });
        return;
      }
    }

    _applyMove(move);
  }

  void _onPromotionSelection(Role? role) {
    if (role == null || _pendingPromotion == null) { _pendingPromotion = null; return; }
    final move = NormalMove(from: _pendingPromotion!.from, to: _pendingPromotion!.to, promotion: role);
    _pendingPromotion = null;
    _applyMove(move);
  }

  void _applyMove(NormalMove move) {
    Position<Chess> newPos;
    try { newPos = _position.play(move); } catch (_) { return; }

    setState(() {
      _position = newPos;
      _lastMove = move;
      _updateStatus();
    });

    if (_position.isGameOver) {
      _showResult();
    } else if (widget.isPvE && _sideToMove == _aiSide) {
      _scheduleAIMove();
    }
  }

  // ──── AI 走棋 ────

  void _scheduleAIMove() {
    _aiThinking = true;
    _updateStatus();
    Timer(const Duration(milliseconds: 300), _performAIMove);
  }

  Future<void> _performAIMove() async {
    if (_position.isGameOver) { _aiThinking = false; _updateStatus(); _showResult(); return; }

    NormalMove? move;
    _lastMoveWasLichess = false;

    // 策略 1: LiChess 云端（每步都试，失败仅回退当前步）
    if (_useLichess) {
      move = await LichessClient.findBestMove(
        _position,
        legalMoves: _getMoves(_position),
        timeout: const Duration(seconds: 3), // 3s 超时，不拖慢节奏
      );
      if (move != null) {
        log('LiChess', '云端走 ${move.from.name} → ${move.to.name}');
        _lastMoveWasLichess = true;
      } else {
        log('LiChess', '双云端均不可用，回退内置 AI');
      }
    }

    // 策略 2: 内置 AI（回退）
    if (move == null && _ai != null) {
      move = _ai!.findBestMove(_position);
      if (move != null) log('AI', '内置引擎走 ${move.from.name} → ${move.to.name}');
    }

    if (move != null && mounted) {
      try {
        final newPos = _position.play(move);
        setState(() {
          _position = newPos;
          _lastMove = move;
          _aiThinking = false;
          _updateStatus();
        });
        if (_position.isGameOver) _showResult();
      } catch (_) {
        _aiThinking = false;
        if (mounted) _updateStatus();
      }
    } else {
      _aiThinking = false;
      if (mounted) _updateStatus();
    }
  }

  // ──── 界面更新 ────

  void _updateStatus() {
    if (_position.isGameOver) return;
    if (_aiThinking) {
      _bottomStatus = '🎯';
      final thinkingLabel = _useLichess ? (_lastMoveWasLichess ? 'LiChess' : '内置AI') : _engineLabel;
      _topStatus = '$thinkingLabel 思考中…';
      return;
    }
    if (_sideToMove == _bottomSide) { _bottomStatus = '🎯'; _topStatus = ''; }
    else { _topStatus = '🎯'; _bottomStatus = ''; }
  }

  void _showResult() => setState(() => _gameState = _stateOver);

  void _resetGame() {
    _position = Chess.initial;
    _ai = null;
    _aiThinking = false;
    _lastMove = null;
    _pendingPromotion = null;
    _lastMoveWasLichess = false;
    _gameState = _stateWaiting;
    _startGame();
  }

  String _getResultTitle() {
    final w = _position.outcome?.winner;
    if (_position.isCheckmate) {
      if (w == Side.white) return widget.isPvE
          ? (_humanSide == Side.white ? '🎉 你获胜！' : '😔 $_engineLabel 获胜')
          : '⚪ 白方获胜！';
      if (w == Side.black) return widget.isPvE
          ? (_humanSide == Side.black ? '🎉 你获胜！' : '😔 $_engineLabel 获胜')
          : '⚫ 黑方获胜！';
    }
    if (_position.isStalemate) return '🤝 逼和（无子可走）';
    if (w == null) {
      if (_position.isInsufficientMaterial) return '🤝 和棋（子力不足）';
      return '🤝 平局';
    }
    if (w == Side.white) return widget.isPvE
        ? (_humanSide == Side.white ? '🎉 你获胜！' : '😔 $_engineLabel 获胜')
        : '⚪ 白方获胜！';
    if (w == Side.black) return widget.isPvE
        ? (_humanSide == Side.black ? '🎉 你获胜！' : '😔 $_engineLabel 获胜')
        : '⚫ 黑方获胜！';
    return '🤝 平局';
  }

  String _getResultSubtitle() {
    if (_position.isCheckmate) return '将杀（Checkmate）';
    if (_position.isStalemate) return '无合法走法，但未被将军';
    if (_position.isInsufficientMaterial) return '双方均无足够子力将杀';
    return '';
  }

  Widget _buildIndicator(Side side) {
    final isWhite = side == Side.white;
    return Container(
      width: 14, height: 14,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: isWhite ? Colors.white : const Color(0xFF1C1B1F),
        shape: BoxShape.circle,
        border: Border.all(color: isWhite ? const Color(0xFFCAC4D0) : const Color(0xFF49454F), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;

    Widget overlay = const SizedBox.shrink();
    if (_gameState == _stateOver) {
      overlay = Positioned.fill(
        child: Container(color: AppThemeColors.overlay(night),
          child: Center(child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: AppThemeColors.divider(night), width: 1)),
            color: AppThemeColors.highlight(night),
            child: Padding(padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_getResultTitle(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppThemeColors.title(night))),
                const SizedBox(height: 4),
                Text(_getResultSubtitle(), style: TextStyle(fontSize: 13, color: AppThemeColors.subtitle(night))),
                const SizedBox(height: 24),
                FilledButton(onPressed: _resetGame,
                  style: FilledButton.styleFrom(backgroundColor: AppThemeColors.filledBtn(night), foregroundColor: AppThemeColors.filledBtnText(night),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(80))),
                  child: const Text('再来一局')),
              ]),
            ),
          )),
        ),
      );
    }

    final hlTop = _gameState == _statePlaying && _topStatus == '🎯';
    final hlBot = _gameState == _statePlaying && _bottomStatus == '🎯';
    final boardInteractive = _gameState == _statePlaying && !_aiThinking &&
        (!widget.isPvE || _sideToMove == _humanSide);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        backgroundColor: hlTop ? (night ? AppThemeColors.nightHighlight : AppThemeColors.dayHighlight) : AppThemeColors.bg(night),
        elevation: 0, automaticallyImplyLeading: false, titleSpacing: 16,
        title: Transform(alignment: Alignment.center, transform: Matrix4.identity()..rotateZ(3.1415927),
          child: Row(children: [
            _buildIndicator(_topSide), const SizedBox(width: 10),
            Expanded(child: Text(_topLabel.isEmpty ? '黑方' : _topLabel,
                style: TextStyle(fontSize: 16, color: AppThemeColors.title(night)), overflow: TextOverflow.ellipsis)),
            Text(_topStatus, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppThemeColors.primary(night))),
          ])),
      ),
      body: Stack(children: [
        Column(children: [
          if (_position.isCheck && _gameState == _statePlaying)
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.red.withAlpha(60),
              child: const Text('将军！', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFB3261E), fontWeight: FontWeight.bold))),
          Expanded(child: LayoutBuilder(builder: (context, constraints) {
            final boardSize = constraints.maxWidth < constraints.maxHeight ? constraints.maxWidth : constraints.maxHeight;
            return Center(child: SizedBox(width: boardSize, height: boardSize,
              child: Chessboard(
                size: boardSize, orientation: _bottomSide, fen: _position.fen, lastMove: _lastMove,
                game: boardInteractive ? GameData(
                  playerSide: widget.isPvE ? (_humanSide == Side.white ? PlayerSide.white : PlayerSide.black) : PlayerSide.both,
                  sideToMove: _sideToMove, validMoves: _validMoves, promotionMove: _pendingPromotion,
                  onMove: _onPlayerMove, onPromotionSelection: _onPromotionSelection, isCheck: _position.isCheck,
                ) : null,
                settings: ChessboardSettings(
                  colorScheme: night ? ChessboardColorScheme.brown : ChessboardColorScheme.brown,
                  pieceAssets: PieceSet.meridaAssets, enableCoordinates: true, showLastMove: true, showValidMoves: true,
                  animationDuration: const Duration(milliseconds: 200), pieceShiftMethod: PieceShiftMethod.either, autoQueenPromotion: false,
                ),
              ),
            ));
          })),
        ]),
        overlay,
      ]),
      bottomNavigationBar: SizedBox(height: 56, child: DecoratedBox(
        decoration: BoxDecoration(color: hlBot ? (night ? AppThemeColors.nightHighlight : AppThemeColors.dayHighlight) : AppThemeColors.bg(night)),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _buildIndicator(_bottomSide), const SizedBox(width: 10),
            Expanded(child: Text(_bottomLabel.isEmpty ? '你' : _bottomLabel,
                style: TextStyle(fontSize: 16, color: AppThemeColors.title(night)), overflow: TextOverflow.ellipsis)),
            Text(_bottomStatus, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppThemeColors.primary(night))),
          ]))),
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
            style: FilledButton.styleFrom(backgroundColor: AppThemeColors.filledBtn(night), foregroundColor: AppThemeColors.filledBtnText(night),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(80))),
            child: const Text('重新开始'))),
        ]),
      )],
    );
  }
}
