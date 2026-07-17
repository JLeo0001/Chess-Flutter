import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// ═══════════════════════════════════════════════════
//  全局快捷入口
// ═══════════════════════════════════════════════════

LogProvider get logProv => LogProvider.ensure();

/// 全局日志（默认 INFO 级别）
void log(String tag, String message) {
  LogProvider.ensure().i(tag, message);
}

/// 全局日志（显式级别）
void logD(String tag, String msg) => LogProvider.ensure().d(tag, msg);
void logI(String tag, String msg) => LogProvider.ensure().i(tag, msg);
void logW(String tag, String msg) => LogProvider.ensure().w(tag, msg);
void logE(String tag, String msg) => LogProvider.ensure().e(tag, msg);
void logF(String tag, String msg) => LogProvider.ensure().f(tag, msg);

// ═══════════════════════════════════════════════════
//  日志级别
// ═══════════════════════════════════════════════════

enum LogLevel {
  debug('DBG', 0, ColorIndex.grey),
  info('INF', 1, ColorIndex.blue),
  warn('WRN', 2, ColorIndex.amber),
  error('ERR', 3, ColorIndex.red),
  fatal('FTL', 4, ColorIndex.purple),
  ;

  final String short;
  final int severity;
  final ColorIndex colorIdx;
  const LogLevel(this.short, this.severity, this.colorIdx);
}

enum ColorIndex { grey, blue, amber, red, purple, green, cyan, pink, orange }

/// 给标签分配固定的颜色索引（标签→颜色映射稳定）
int _tagColorIndex(String tag) {
  final hash = tag.hashCode;
  const colors = [
    ColorIndex.blue,
    ColorIndex.cyan,
    ColorIndex.green,
    ColorIndex.pink,
    ColorIndex.orange,
    ColorIndex.amber,
    ColorIndex.purple,
    ColorIndex.red,
    ColorIndex.grey,
  ];
  return colors[hash.abs() % colors.length].index;
}

// ═══════════════════════════════════════════════════
//  日志条目
// ═══════════════════════════════════════════════════

class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;
  final String? stackTrace;

  /// 颜色索引（用于前端配色）
  int get colorIndex => _tagColorIndex(tag);
  int get levelColorIndex => level.colorIdx.index;

  LogEntry({
    required this.tag,
    required this.message,
    this.level = LogLevel.info,
    DateTime? time,
    this.stackTrace,
  }) : time = time ?? DateTime.now();

  /// ── 格式化到文件行 ──
  /// 格式: 2026-07-19 10:30:45.123 [INF] [TAG] message
  /// 带堆栈: ... [ERR] [TAG] message | stack_line1\nstack_line2
  String toFileLine() {
    final ts = _formatTime(time);
    final msg = stackTrace != null
        ? '$message | ${stackTrace!.replaceAll('\n', '↵')}'
        : message;
    return '$ts [${level.short}] [$tag] $msg';
  }

  /// ── 从文件行还原 ──
  static LogEntry? fromFileLine(String line) {
    try {
      // 日期部分: YYYY-MM-DD HH:mm:ss.SSS
      if (line.length < 26) return null;
      final dateStr = line.substring(0, 23);
      final time = DateTime.tryParse(dateStr);
      if (time == null) return null;

      // [LVL]
      final lvlStart = line.indexOf('[', 23);
      if (lvlStart < 0) return null;
      final lvlEnd = line.indexOf(']', lvlStart);
      if (lvlEnd < 0) return null;
      final lvlStr = line.substring(lvlStart + 1, lvlEnd);
      final level = LogLevel.values.where((l) => l.short == lvlStr).firstOrNull;
      if (level == null) return null;

      // [TAG]
      final tagStart = line.indexOf('[', lvlEnd);
      if (tagStart < 0) return null;
      final tagEnd = line.indexOf(']', tagStart);
      if (tagEnd < 0) return null;
      final tag = line.substring(tagStart + 1, tagEnd);

      // message
      final msg = line.substring(tagEnd + 2);

      // 检查是否有堆栈
      String? stack;
      String cleanMsg = msg;
      final pipeIdx = msg.indexOf(' | ');
      if (pipeIdx > 0) {
        cleanMsg = msg.substring(0, pipeIdx);
        stack = msg.substring(pipeIdx + 3).replaceAll('↵', '\n');
      }

      return LogEntry(
        tag: tag,
        message: cleanMsg,
        level: level,
        time: time,
        stackTrace: stack,
      );
    } catch (_) {
      return null;
    }
  }

  /// 简短时间（用于 UI 显示）
  String get formattedTime {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    final ms = time.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  static String _formatTime(DateTime t) {
    final y = t.year.toString();
    final mo = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    final h = t.hour.toString().padLeft(2, '0');
    final mi = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    final ms = t.millisecond.toString().padLeft(3, '0');
    return '$y-$mo-$d $h:$mi:$s.$ms';
  }
}

// ═══════════════════════════════════════════════════
//  日志统计
// ═══════════════════════════════════════════════════

class LogStats {
  final int total;
  final Map<String, int> perTag; // tag → count
  final Map<LogLevel, int> perLevel; // level → count
  final Map<String, int> perTagLevel; // "tag:level" → count

  LogStats({
    required this.total,
    required this.perTag,
    required this.perLevel,
    required this.perTagLevel,
  });

  int tagCount(String tag) => perTag[tag] ?? 0;
  int levelCount(LogLevel l) => perLevel[l] ?? 0;
  int tagLevelCount(String tag, LogLevel l) => perTagLevel['$tag:${l.short}'] ?? 0;
}

// ═══════════════════════════════════════════════════
//  日志提供者
// ═══════════════════════════════════════════════════

class LogProvider extends ChangeNotifier {
  // ══ 容量 ══
  static const int _maxMemLines = 4000;
  static const int _maxFileLines = 8000;
  static const int _maxFileAgeDays = 7;
  static const String _logDirName = 'logs';
  static const String _logFilePrefix = 'app_';

  // ══ 环形缓冲 ══
  final _lines = Queue<LogEntry>();
  bool _ready = false;

  // ══ 文件句柄 ══
  File? _currentLogFile;
  String? _currentDateStr;

  bool get ready => _ready;
  List<LogEntry> get entries => _lines.toList();

  // ════════════════════════════════════════════
  //  日志入口
  // ════════════════════════════════════════════

  void d(String tag, String msg) => _add(LogLevel.debug, tag, msg);
  void i(String tag, String msg) => _add(LogLevel.info, tag, msg);
  void w(String tag, String msg) => _add(LogLevel.warn, tag, msg);
  void e(String tag, String msg) => _add(LogLevel.error, tag, msg);
  void f(String tag, String msg) => _add(LogLevel.fatal, tag, msg);

  /// 带堆栈的错误日志
  void eWithStack(String tag, String msg, {String? stack}) {
    _add(LogLevel.error, tag, msg, stackTrace: stack);
  }

  void _add(LogLevel level, String tag, String msg, {String? stackTrace}) {
    final entry = LogEntry(
      tag: tag,
      message: msg,
      level: level,
      stackTrace: stackTrace,
    );
    _lines.add(entry);
    while (_lines.length > _maxMemLines) {
      _lines.removeFirst();
    }
    _appendToFile(entry);
    notifyListeners();

    // 高严重度日志输出到 debugPrint
    if (level.severity >= LogLevel.error.severity) {
      debugPrint('[${level.short}] [$tag] $msg');
    }
  }

  /// 清除内存 + 文件
  void clear() {
    _lines.clear();
    _clearCurrentFile();
    notifyListeners();
    // 异步清理文件
    removeOldLogs();
  }

  /// 清空内存（保留文件）
  void clearMemory() {
    _lines.clear();
    notifyListeners();
  }

  // ════════════════════════════════════════════
  //  统计
  // ════════════════════════════════════════════

  LogStats computeStats() {
    final perTag = <String, int>{};
    final perLevel = <LogLevel, int>{};
    final perTagLevel = <String, int>{};
    int total = 0;
    for (final e in _lines) {
      total++;
      perTag[e.tag] = (perTag[e.tag] ?? 0) + 1;
      perLevel[e.level] = (perLevel[e.level] ?? 0) + 1;
      final key = '${e.tag}:${e.level.short}';
      perTagLevel[key] = (perTagLevel[key] ?? 0) + 1;
    }
    return LogStats(
      total: total,
      perTag: perTag,
      perLevel: perLevel,
      perTagLevel: perTagLevel,
    );
  }

  /// 搜索日志
  List<LogEntry> search(
      {String? query, LogLevel? minLevel, String? tag}) {
    return _lines.where((e) {
      if (minLevel != null && e.level.severity < minLevel.severity) {
        return false;
      }
      if (tag != null && !e.tag.contains(tag)) return false;
      if (query != null && query.isNotEmpty) {
        final q = query.toLowerCase();
        if (!e.message.toLowerCase().contains(q) &&
            !e.tag.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // ════════════════════════════════════════════
  //  文件持久化
  // ════════════════════════════════════════════

  Future<void> init() async {
    try {
      final dir = await _ensureLogDir();
      await _cleanOldLogs(dir);

      // 今日日志文件
      _currentDateStr = _todayStr();
      _currentLogFile = File('${dir.path}/${_logFilePrefix}$_currentDateStr.txt');

      // 读取今日已有日志
      if (await _currentLogFile!.exists()) {
        final content = await _currentLogFile!.readAsString();
        final allLines = const LineSplitter().convert(content);
        final recent = allLines.length > _maxMemLines
            ? allLines.sublist(allLines.length - _maxMemLines)
            : allLines;
        for (final line in recent) {
          final entry = LogEntry.fromFileLine(line);
          if (entry != null) {
            _lines.add(entry);
          }
        }
        debugPrint('[Log] 加载 ${_lines.length} 条历史日志');
      }
    } catch (e) {
      debugPrint('[Log] 初始化失败: $e');
    }
    _ready = true;
    i('SYS', '日志系统就绪');
  }

  void _appendToFile(LogEntry entry) {
    try {
      final f = _currentLogFile;
      if (f == null) return;

      // 日期变更 → 换文件
      final today = _todayStr();
      if (_currentDateStr != today) {
        _currentDateStr = today;
        final dir = f.parent;
        _currentLogFile = File('${dir.path}/${_logFilePrefix}$today.txt');
      }

      f.writeAsStringSync(
        '${entry.toFileLine()}\n',
        mode: FileMode.append,
      );
    } catch (_) {}
  }

  void _clearCurrentFile() {
    try {
      _currentLogFile?.writeAsStringSync('');
    } catch (_) {}
  }

  Future<Directory> _ensureLogDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_logDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}';
  }

  /// 删除超龄日志文件
  Future<void> _cleanOldLogs(Directory dir) async {
    try {
      final cutoff = DateTime.now().subtract(
        const Duration(days: _maxFileAgeDays),
      );
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.txt')) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete();
            debugPrint('[Log] 清理旧日志: ${entity.path}');
          }
        }
      }
    } catch (_) {}
  }

  /// 外部调用：裁剪当前文件
  Future<void> trimFile() async {
    try {
      final f = _currentLogFile;
      if (f == null || !await f.exists()) return;
      final content = await f.readAsString();
      final allLines = const LineSplitter().convert(content);
      if (allLines.length > _maxFileLines) {
        final keep = allLines.sublist(allLines.length - _maxFileLines);
        await f.writeAsString('${keep.join('\n')}\n');
      }
    } catch (_) {}
  }

  /// 删除所有过期日志文件
  Future<void> removeOldLogs() async {
    try {
      final dir = await _ensureLogDir();
      await _cleanOldLogs(dir);
    } catch (_) {}
  }

  // ════════════════════════════════════════════
  //  全部日志文本
  // ════════════════════════════════════════════

  String get fullText {
    final buf = StringBuffer();
    for (final e in _lines) {
      buf.writeln(e.toFileLine());
    }
    return buf.toString();
  }

  /// 过滤后的文本
  String filteredText({
    String? query,
    LogLevel? minLevel,
    String? tag,
  }) {
    final filtered = search(query: query, minLevel: minLevel, tag: tag);
    final buf = StringBuffer();
    for (final e in filtered) {
      buf.writeln(e.toFileLine());
    }
    return buf.toString();
  }

  // ══ 单例 ══

  static LogProvider? _instance;
  static LogProvider ensure() {
    _instance ??= LogProvider();
    return _instance!;
  }
}
