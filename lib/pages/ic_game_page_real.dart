import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import '../international_chess/ic_ai.dart';
import '../international_chess/lichess_client.dart';
import '../models/chess_engine_provider.dart';
import '../widgets/game_shell.dart';

/// 国际象棋游戏页面 — 基于 chessground + dartchess
///
/// 使用 GameShell 提供统一 M3 外观。
class InternationalChessGamePage extends StatefulWidget {
  final bool isPvE;
  const InternationalChessGamePage({super.key, required this.isPvE});

  @override
  State<InternationalChessGamePage> createState() =>
      _InternationalChessGamePageState();
}

class _InternationalChessGamePageState
    extends State<InternationalChessGamePage> {
  Position<Chess> _position = Chess.initial;

  int _gameState = 0; // 0=waiting, 1=lottery, 2=playing, 3=over
  int _lotteryCount = 0;
  static const _lotteryTotal = 12;

  Side _humanSide = Side.white;
  Side _aiSide = Side.black;
  Side _bottomSide = Side.white;
  Side _topSide = Side.black;

  InternationalChessAI? _ai;
  bool _aiThinking = false;
  String _engineLabel = 'AI';
  bool _useLichess = false;
  bool _lastMoveWasLichess = false;

  String _bottomLabel = '白方', _topLabel = '黑方';
  String _bottomStatus = '', _topStatus = '';
  NormalMove? _lastMove;

  NormalMove? _pendingPromotion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initEngine());
  }

  Side get _sideToMove => _position.turn;

  void _initEngine() {
    if (!widget.isPvE) {
      _startGame();
      return;
    }
    final engineProv = context.read<ChessEngineProvider>();
    _useLichess = engineProv.isLichess;
    _engineLabel = engineProv.isBuiltin ? '内置AI' : 'LiChess';
    _ai = InternationalChessAI(_aiSide);
    _startGame();
  }

  void _startGame() {
    _position = Chess.initial;
    _gameState = 1;
    _lotteryCount = 0;
    _bottomStatus = '';
    _topStatus = '';
    _lastMove = null;
    _pendingPromotion = null;
    _animateLottery();
  }

  void _animateLottery() {
    Timer.periodic(const Duration(milliseconds: 60), (t) {
      if (_lotteryCount >= _lotteryTotal) {
        t.cancel();
        _finishLottery();
        return;
      }
      setState(() {
        _lotteryCount++;
        _bottomStatus = _lotteryCount % 2 == 0 ? '🎯' : '';
        _topStatus = _lotteryCount % 2 == 0 ? '' : '🎯';
      });
    });
  }

  void _finishLottery() {
    final bottomIsWhite = DateTime.now().millisecondsSinceEpoch % 2 == 0;
    if (widget.isPvE) {
      if (bottomIsWhite) {
        _bottomSide = Side.white;
        _topSide = Side.black;
        _humanSide = Side.white;
        _aiSide = Side.black;
        _bottomLabel = '你 (白)';
        _topLabel = '$_engineLabel (黑)';
      } else {
        _bottomSide = Side.black;
        _topSide = Side.white;
        _humanSide = Side.black;
        _aiSide = Side.white;
        _bottomLabel = '你 (黑)';
        _topLabel = '$_engineLabel (白)';
      }
      _ai = InternationalChessAI(_aiSide);
    } else {
      _bottomSide = bottomIsWhite ? Side.white : Side.black;
      _topSide = bottomIsWhite ? Side.black : Side.white;
      _bottomLabel = bottomIsWhite ? '白方' : '黑方';
      _topLabel = bottomIsWhite ? '黑方' : '白方';
    }
    Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _gameState = 2;
        _bottomStatus = '🎯';
        _topStatus = '';
      });
      if (widget.isPvE && _sideToMove == _aiSide) _scheduleAI();
    });
  }

  ValidMoves get _validMoves {
    if (_gameState != 2 || _aiThinking) return IMap(const {});
    if (widget.isPvE && _sideToMove != _humanSide) return IMap(const {});
    final map = <Square, ISet<Square>>{};
    for (final entry in _position.legalMoves.entries) {
      map[entry.key] = ISet(entry.value.squares);
    }
    return IMap(map);
  }

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

  void _onPlayerMove(NormalMove move, {bool? isDrop}) {
    if (_gameState != 2 || _position.isGameOver || _aiThinking) return;
    if (widget.isPvE && _sideToMove != _humanSide) return;

    final piece = _position.board.pieceAt(move.from);
    if (piece != null && piece.role == Role.pawn) {
      final rank = move.to.rank;
      if ((_humanSide == Side.white && rank == Rank.eighth) ||
          (_humanSide == Side.black && rank == Rank.first)) {
        setState(() => _pendingPromotion = move);
        return;
      }
    }
    _applyMove(move);
  }

  void _onPromotionSelection(Role? role) {
    if (role == null || _pendingPromotion == null) {
      _pendingPromotion = null;
      return;
    }
    final move = NormalMove(
        from: _pendingPromotion!.from,
        to: _pendingPromotion!.to,
        promotion: role);
    _pendingPromotion = null;
    _applyMove(move);
  }

  void _applyMove(NormalMove move) {
    Position<Chess> newPos;
    try {
      newPos = _position.play(move);
    } catch (_) {
      return;
    }
    setState(() {
      _position = newPos;
      _lastMove = move;
      _updateStatus();
    });
    if (_position.isGameOver) {
      _endGame();
    } else if (widget.isPvE && _sideToMove == _aiSide) {
      _scheduleAI();
    }
  }

  void _scheduleAI() {
    _aiThinking = true;
    _updateStatus();
    Timer(const Duration(milliseconds: 300), _performAI);
  }

  Future<void> _performAI() async {
    if (_position.isGameOver) {
      _aiThinking = false;
      _updateStatus();
      _endGame();
      return;
    }

    NormalMove? move;
    _lastMoveWasLichess = false;

    if (_useLichess) {
      move = await LichessClient.findBestMove(
        _position,
        legalMoves: _getMoves(_position),
        timeout: const Duration(seconds: 3),
      );
      if (move != null) _lastMoveWasLichess = true;
    }

    if (move == null && _ai != null) {
      move = _ai!.findBestMove(_position);
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
        if (_position.isGameOver) _endGame();
      } catch (_) {
        _aiThinking = false;
        if (mounted) _updateStatus();
      }
    } else {
      _aiThinking = false;
      if (mounted) _updateStatus();
    }
  }

  void _updateStatus() {
    if (_position.isGameOver) return;
    if (_aiThinking) {
      _bottomStatus = '🎯';
      _topStatus = '${_lastMoveWasLichess ? "LiChess" : _engineLabel} 思考中…';
      return;
    }
    if (_sideToMove == _bottomSide) {
      _bottomStatus = '🎯';
      _topStatus = '';
    } else {
      _topStatus = '🎯';
      _bottomStatus = '';
    }
  }

  void _endGame() => setState(() => _gameState = 3);

  void _reset() {
    _position = Chess.initial;
    _ai = null;
    _aiThinking = false;
    _lastMove = null;
    _pendingPromotion = null;
    _lastMoveWasLichess = false;
    _gameState = 0;
    _startGame();
  }

  String get _resultTitle {
    final w = _position.outcome?.winner;
    if (_position.isCheckmate) {
      if (w == Side.white) {
        return widget.isPvE
            ? (_humanSide == Side.white ? '🎉 你获胜！' : '😔 $_engineLabel 获胜')
            : '⚪ 白方获胜！';
      }
      if (w == Side.black) {
        return widget.isPvE
            ? (_humanSide == Side.black ? '🎉 你获胜！' : '😔 $_engineLabel 获胜')
            : '⚫ 黑方获胜！';
      }
    }
    if (_position.isStalemate) return '🤝 逼和（无子可走）';
    if (w == null) {
      if (_position.isInsufficientMaterial) return '🤝 和棋（子力不足）';
      return '🤝 平局';
    }
    if (w == Side.white) {
      return widget.isPvE
          ? (_humanSide == Side.white ? '🎉 你获胜！' : '😔 $_engineLabel 获胜')
          : '⚪ 白方获胜！';
    }
    return widget.isPvE
        ? (_humanSide == Side.black ? '🎉 你获胜！' : '😔 $_engineLabel 获胜')
        : '⚫ 黑方获胜！';
  }

  String get _resultSubtitle {
    if (_position.isCheckmate) return '将杀（Checkmate）';
    if (_position.isStalemate) return '无合法走法，但未被将军';
    if (_position.isInsufficientMaterial) return '双方均无足够子力将杀';
    return '';
  }

  bool get _isOver => _gameState == 3 || _position.isGameOver;
  bool get _boardInteractive =>
      _gameState == 2 && !_aiThinking &&
      (!widget.isPvE || _sideToMove == _humanSide);
  bool get _isCheck =>
      _position.isCheck && _gameState == 2 && !_position.isGameOver;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final night = Theme.of(context).brightness == Brightness.dark;

    return GameShell(
      topLabel: _topLabel.isEmpty ? '黑方' : _topLabel,
      topStatus: _topStatus,
      bottomLabel: _bottomLabel.isEmpty ? '你' : _bottomLabel,
      bottomStatus: _bottomStatus,
      topIndicator: ChessSideIndicator(isWhite: _topSide == Side.white),
      bottomIndicator: ChessSideIndicator(isWhite: _bottomSide == Side.white),
      builder: (_) => LayoutBuilder(
        builder: (context, constraints) {
          final boardSize = constraints.maxWidth < constraints.maxHeight
              ? constraints.maxWidth
              : constraints.maxHeight;
          return Center(
            child: SizedBox(
              width: boardSize,
              height: boardSize,
              child: Chessboard(
                size: boardSize,
                orientation: _bottomSide,
                fen: _position.fen,
                lastMove: _lastMove,
                game: _boardInteractive
                    ? GameData(
                        playerSide: widget.isPvE
                            ? (_humanSide == Side.white
                                ? PlayerSide.white
                                : PlayerSide.black)
                            : PlayerSide.both,
                        sideToMove: _sideToMove,
                        validMoves: _validMoves,
                        promotionMove: _pendingPromotion,
                        onMove: _onPlayerMove,
                        onPromotionSelection: _onPromotionSelection,
                        isCheck: _position.isCheck,
                      )
                    : null,
                settings: ChessboardSettings(
                  colorScheme:
                      night ? ChessboardColorScheme.brown : ChessboardColorScheme.brown,
                  pieceAssets: PieceSet.meridaAssets,
                  enableCoordinates: true,
                  showLastMove: true,
                  showValidMoves: true,
                  animationDuration: const Duration(milliseconds: 200),
                  pieceShiftMethod: PieceShiftMethod.either,
                  autoQueenPromotion: false,
                ),
              ),
            ),
          );
        },
      ),
      onBack: () => Navigator.pop(context),
      onReset: _reset,
      showResult: _isOver,
      resultTitle: _resultTitle,
      resultSubtitle: _resultSubtitle.isNotEmpty
          ? Text(_resultSubtitle,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))
          : null,
      lotteryCount: _gameState == 1 ? _lotteryCount : -1,
      onLotteryFinished: () {},
      statusBanner: _isCheck
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.red.withAlpha(60),
              child: Text(
                '将军！',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: cs.error, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }
}
