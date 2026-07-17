/// 条件导出：Native → 真实国际象棋页面（chessground + dartchess）
/// Web → 占位提示页（无法编译 64-bit 位运算）
export 'ic_game_page_stub.dart' if (dart.library.io) 'ic_game_page_real.dart';
