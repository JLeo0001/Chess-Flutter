import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 国际象棋引擎选择管理
///
/// - builtin — 内置 Dart AI（离线可用）
/// - lichess — LiChess Cloud Eval API（在线优先，失败时自动回退内置 AI）
class ChessEngineProvider extends ChangeNotifier {
  static const String _prefsEngine = 'chess_engine_type';

  String _engineType = 'builtin'; // builtin | lichess
  bool _initialized = false;

  String get engineType => _engineType;
  bool get isBuiltin => _engineType == 'builtin';
  bool get isLichess => _engineType == 'lichess';
  bool get initialized => _initialized;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _engineType = prefs.getString(_prefsEngine) ?? 'builtin';
    _initialized = true;
    notifyListeners();
  }

  Future<void> setBuiltin() async {
    _engineType = 'builtin';
    await _save();
    notifyListeners();
  }

  Future<void> setLichess() async {
    _engineType = 'lichess';
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsEngine, _engineType);
  }

  String get displayName {
    if (isBuiltin) return '内置 AI（离线）';
    return 'LiChess 云端（在线）';
  }
}
