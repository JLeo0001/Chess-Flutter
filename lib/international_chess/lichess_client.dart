import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dartchess/dartchess.dart';

/// 云端国际象棋引擎客户端 — 双后端 + 内置 AI 回退
///
/// 后端链：
///   1. chess-api.com（按需 Stockfish，即时计算，无缓存依赖）
///   2. lichess.org Cloud Eval（免费缓存数据）
///
/// 两个都失败 → 返回 null → 调用方走内置 AI
class LichessClient {
  static const String _chessApiUrl = 'https://chess-api.com/v1';
  static const String _lichessUrl = 'https://lichess.org/api/cloud-eval';

  /// 查找最佳走法
  ///
  /// 依次尝试 chess-api.com → LiChess Cloud Eval
  /// 全部失败返回 null，由调用方回退到内置 AI
  static Future<NormalMove?> findBestMove(
    Position<Chess> position, {
    List<NormalMove>? legalMoves,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final fen = position.fen;
    final moves = legalMoves ?? _getMoves(position);

    // 后端 1: chess-api.com（按需计算，无 404）
    try {
      final move = await _tryChessApi(fen, moves, timeout);
      if (move != null) return move;
    } catch (_) {}

    // 后端 2: LiChess Cloud Eval（免费缓存）
    try {
      final move = await _tryLichess(fen, moves, timeout);
      if (move != null) return move;
    } catch (_) {}

    return null;
  }

  // ═══════════════════ chess-api.com ═══════════════════

  static Future<NormalMove?> _tryChessApi(
    String fen,
    List<NormalMove> legalMoves,
    Duration timeout,
  ) async {
    final url = Uri.parse(_chessApiUrl);
    final body = jsonEncode({'fen': fen, 'depth': 10});

    final response = await http
        .post(url, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(timeout);

    if (response.statusCode != 200) {
      debugPrint('[ChessApi] 返回 ${response.statusCode}');
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final moveStr = data['move'] as String?;
    if (moveStr == null || moveStr.isEmpty) {
      debugPrint('[ChessApi] 无走法返回');
      return null;
    }

    final move = Move.parse(moveStr);
    if (move is! NormalMove) return null;

    // 验证合法性
    for (final m in legalMoves) {
      if (m.from == move.from && m.to == move.to &&
          m.promotion == move.promotion) {
        final eval = data['eval'];
        debugPrint('[ChessApi] $moveStr eval=$eval depth=${data["depth"]}');
        return m;
      }
    }

    debugPrint('[ChessApi] 走法不在合法走法列表中: $moveStr');
    return null;
  }

  // ═══════════════════ LiChess Cloud Eval ═══════════════════

  static Future<NormalMove?> _tryLichess(
    String fen,
    List<NormalMove> legalMoves,
    Duration timeout,
  ) async {
    final encoded = Uri.encodeComponent(fen);
    final url = Uri.parse('$_lichessUrl?fen=$encoded&multiPv=1');

    final response = await http.get(url).timeout(timeout);

    if (response.statusCode != 200) {
      debugPrint('[LiChess] API 返回 ${response.statusCode}，无缓存数据');
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final pvs = data['pvs'] as List?;
    if (pvs == null || pvs.isEmpty) return null;

    final bestPv = pvs[0] as Map<String, dynamic>;
    final movesStr = bestPv['moves'] as String?;
    if (movesStr == null || movesStr.isEmpty) return null;

    final uci = movesStr.split(' ').first;
    final move = Move.parse(uci);
    if (move is! NormalMove) return null;

    // 验证合法性
    for (final m in legalMoves) {
      if (m.from == move.from && m.to == move.to &&
          m.promotion == move.promotion) {
        final cp = bestPv['cp'];
        debugPrint('[LiChess] $uci cp=$cp depth=${data["depth"]}');
        return m;
      }
    }

    debugPrint('[LiChess] 走法不在合法走法列表中: $uci');
    return null;
  }

  // ═══════════════════ 工具 ═══════════════════

  static List<NormalMove> _getMoves(Position<Chess> pos) {
    final list = <NormalMove>[];
    for (final entry in pos.legalMoves.entries) {
      for (final to in entry.value.squares) {
        list.add(NormalMove(from: entry.key, to: to));
      }
    }
    return list;
  }
}
