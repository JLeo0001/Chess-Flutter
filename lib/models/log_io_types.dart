/// 平台条件导入：Web 用 stub，Native 用真实 dart:io
/// 实际被平台使用的只有满足条件的那一个，另一个仅用于编译通过。
export 'log_io_stub.dart' if (dart.library.io) 'log_io_real.dart';
