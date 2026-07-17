import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/log_provider.dart';
import '../themes/app_theme.dart';

/// 日志终端页面 — 实时滚动、过滤、搜索、颜色编码、复制
class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _autoScroll = true;
  LogProvider? _logProv;

  // 过滤状态
  LogLevel? _levelFilter;
  String _searchQuery = '';
  String _tagFilter = '';
  bool _showStats = false;
  bool _showSearch = false;

  // 展开的日志条目索引
  final _expandedIndices = <int>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lp = context.read<LogProvider>();
    if (_logProv != lp) {
      _logProv?.removeListener(_onNewLog);
      _logProv = lp;
      _logProv?.addListener(_onNewLog);
    }
  }

  @override
  void dispose() {
    _logProv?.removeListener(_onNewLog);
    _logProv = null;
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onNewLog() {
    if (!_autoScroll || _showSearch) return;
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (_) {}
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final atBottom = pos.pixels >= pos.maxScrollExtent - 20;
    if (atBottom != _autoScroll) setState(() => _autoScroll = atBottom);
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  List<LogEntry> _filtered(List<LogEntry> entries) {
    return entries.where((e) {
      if (_levelFilter != null && e.level.severity < _levelFilter!.severity) {
        return false;
      }
      if (_tagFilter.isNotEmpty && !e.tag.contains(_tagFilter)) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!e.message.toLowerCase().contains(q) &&
            !e.tag.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _copySingle(LogEntry entry) {
    Clipboard.setData(ClipboardData(text: entry.toFileLine()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已复制该条日志'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final logProv = context.watch<LogProvider>();
    final all = logProv.entries;
    final filtered = _filtered(all);
    final stats = logProv.computeStats();

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // ═══════ 顶栏 ═══════
          Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Column(children: [
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                  color: AppThemeColors.primary(night),
                ),
                const SizedBox(width: 4),
                Text('运行日志',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                        color: AppThemeColors.title(night))),
                const Spacer(),
                // 统计
                IconButton(
                  icon: Icon(_showStats ? Icons.bar_chart : Icons.bar_chart_outlined,
                      size: 20),
                  tooltip: '统计',
                  onPressed: () => setState(() => _showStats = !_showStats),
                  color: AppThemeColors.primary(night),
                ),
                // 搜索
                IconButton(
                  icon: Icon(_showSearch ? Icons.search_off : Icons.search,
                      size: 20),
                  tooltip: '搜索',
                  onPressed: () => setState(() => _showSearch = !_showSearch),
                  color: AppThemeColors.primary(night),
                ),
                // 自动滚动
                Switch(
                  value: _autoScroll,
                  onChanged: (v) {
                    setState(() => _autoScroll = v);
                    if (v) _onNewLog();
                  },
                  activeColor: AppThemeColors.primary(night),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                // 复制
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: '复制全部',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: logProv.fullText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已复制到剪贴板'),
                          duration: Duration(seconds: 1)),
                    );
                  },
                  color: AppThemeColors.primary(night),
                ),
                // 清空
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: '清空',
                  onPressed: () => logProv.clear(),
                  color: AppThemeColors.subtitle(night),
                ),
              ]),
              // 搜索栏
              if (_showSearch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppThemeColors.title(night),
                    ),
                    decoration: InputDecoration(
                      hintText: '搜索日志内容或标签…',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: AppThemeColors.subtitle(night),
                      ),
                      prefixIcon: Icon(Icons.search, size: 18,
                          color: AppThemeColors.subtitle(night)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, size: 18,
                                  color: AppThemeColors.subtitle(night)),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      filled: true,
                      fillColor: AppThemeColors.highlight(night),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: AppThemeColors.divider(night)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: AppThemeColors.divider(night)),
                      ),
                    ),
                  ),
                ),
              // 过滤芯片
              _buildFilterChips(night, stats),
            ]),
          ),
          Divider(height: 1, color: AppThemeColors.divider(night)),

          // ═══════ 统计面板 ═══════
          if (_showStats) _buildStatsPanel(night, stats),

          // ═══════ 日志列表 ═══════
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined, size: 40,
                            color: AppThemeColors.subtitle(night)),
                        const SizedBox(height: 8),
                        Text(all.isEmpty ? '暂无日志' : '无匹配日志',
                            style: TextStyle(fontSize: 14,
                                color: AppThemeColors.subtitle(night))),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final e = filtered[i];
                      final isExpanded = _expandedIndices.contains(i);
                      return _LogEntryWidget(
                        entry: e,
                        isExpanded: isExpanded,
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedIndices.remove(i);
                            } else {
                              _expandedIndices.add(i);
                            }
                          });
                        },
                        onLongPress: () => _copySingle(e),
                        night: night,
                      );
                    },
                  ),
          ),

          // ═══════ 底栏 ═══════
          _buildBottomBar(night, all.length, filtered.length, logProv),
        ]),
      ),
    );
  }

  // ═══════════════════════ 过滤芯片 ═══════════════════════

  Widget _buildFilterChips(bool night, LogStats stats) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          // 级别过滤
          _FilterChip(
            label: '全部',
            selected: _levelFilter == null,
            count: stats.total,
            night: night,
            onTap: () => setState(() => _levelFilter = null),
          ),
          const SizedBox(width: 4),
          for (final lv in LogLevel.values)
            if (stats.levelCount(lv) > 0)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _FilterChip(
                  label: lv.short,
                  selected: _levelFilter == lv,
                  count: stats.levelCount(lv),
                  color: _levelColor(lv, night),
                  night: night,
                  onTap: () => setState(() {
                    _levelFilter = _levelFilter == lv ? null : lv;
                  }),
                ),
              ),
          const SizedBox(width: 8),
          // 标签过滤
          for (final tag in stats.perTag.keys.take(8))
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _FilterChip(
                label: tag,
                selected: _tagFilter == tag,
                count: stats.tagCount(tag),
                night: night,
                onTap: () => setState(() {
                  _tagFilter = _tagFilter == tag ? '' : tag;
                }),
              ),
            ),
        ]),
      ),
    );
  }

  // ═══════════════════════ 统计面板 ═══════════════════════

  Widget _buildStatsPanel(bool night, LogStats stats) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: AppThemeColors.highlight(night),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('日志统计',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppThemeColors.primary(night))),
          const SizedBox(height: 4),
          Row(children: [
            _statChip('总数', stats.total, null, night),
            for (final lv in LogLevel.values)
              if (stats.levelCount(lv) > 0)
                _statChip(lv.short, stats.levelCount(lv), _levelColor(lv, night), night),
          ]),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 2,
            children: stats.perTag.entries.take(12).map((e) {
              return Text('${e.key}:${e.value}',
                  style: TextStyle(fontSize: 10, fontFamily: 'monospace',
                      color: AppThemeColors.subtitle(night)));
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, int count, Color? color, bool night) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (color != null)
          Container(width: 8, height: 8, decoration: BoxDecoration(
            color: color, shape: BoxShape.circle)),
        if (color != null) const SizedBox(width: 3),
        Text('$label:$count',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: color ?? AppThemeColors.title(night))),
      ]),
    );
  }

  // ═══════════════════════ 底栏 ═══════════════════════

  Widget _buildBottomBar(bool night, int total, int filtered, LogProvider lp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      color: AppThemeColors.highlight(night),
      child: Row(children: [
        Icon(Icons.filter_list, size: 12, color: AppThemeColors.subtitle(night)),
        const SizedBox(width: 4),
        Text(
          total == filtered
              ? '$total 条'
              : '$filtered / $total 条',
          style: TextStyle(fontSize: 11, color: AppThemeColors.subtitle(night)),
        ),
        if (_levelFilter != null || _tagFilter.isNotEmpty || _searchQuery.isNotEmpty)
          TextButton(
            onPressed: () => setState(() {
              _levelFilter = null;
              _tagFilter = '';
              _searchController.clear();
              _searchQuery = '';
            }),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('清除过滤',
                style: TextStyle(fontSize: 11,
                    color: AppThemeColors.primary(night))),
          ),
        const Spacer(),
        Text('${lp.fullText.length ~/ 1024} KB',
            style: TextStyle(fontSize: 11, color: AppThemeColors.subtitle(night))),
      ]),
    );
  }

  // ═══════════════════════ 颜色 ═══════════════════════

  Color _levelColor(LogLevel lv, bool night) {
    switch (lv) {
      case LogLevel.debug: return Colors.grey;
      case LogLevel.info: return night ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);
      case LogLevel.warn: return night ? const Color(0xFFFFD54F) : const Color(0xFFF57F17);
      case LogLevel.error: return night ? const Color(0xFFEF5350) : const Color(0xFFC62828);
      case LogLevel.fatal: return night ? const Color(0xFFCE93D8) : const Color(0xFF6A1B9A);
    }
  }
}

// ═══════════════════════════════════════════════
//  过滤芯片组件
// ═══════════════════════════════════════════════

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final int count;
  final Color? color;
  final bool night;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label, required this.selected, required this.count,
    this.color, required this.night, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? (color ?? AppThemeColors.primary(night)).withAlpha(40)
              : AppThemeColors.highlight(night),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? (color ?? AppThemeColors.primary(night))
                : AppThemeColors.divider(night),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: selected
                    ? (color ?? AppThemeColors.primary(night))
                    : AppThemeColors.title(night),
              )),
          const SizedBox(width: 3),
          Text('$count',
              style: TextStyle(
                fontSize: 10,
                color: selected
                    ? (color ?? AppThemeColors.primary(night))
                    : AppThemeColors.subtitle(night),
              )),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  日志条目组件
// ═══════════════════════════════════════════════

class _LogEntryWidget extends StatelessWidget {
  final LogEntry entry;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool night;

  const _LogEntryWidget({
    required this.entry, required this.isExpanded,
    required this.onTap, required this.onLongPress, required this.night,
  });

  @override
  Widget build(BuildContext context) {
    final lvColor = _levelColor(entry.level, night);
    final tagClr = _tagColor(entry.tag, night);
    final maxLines = isExpanded ? 30 : 3;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        margin: const EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(
          color: isExpanded
              ? lvColor.withAlpha(10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：时间 级别 标签
            Row(children: [
              // 级别指示器
              Container(
                width: 28,
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: lvColor.withAlpha(35),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(entry.level.short,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.bold,
                      color: lvColor,
                    )),
              ),
              const SizedBox(width: 4),
              // 时间
              Text(entry.formattedTime,
                  style: TextStyle(
                    fontSize: 10, fontFamily: 'monospace',
                    color: AppThemeColors.subtitle(night),
                  )),
              const SizedBox(width: 4),
              // 标签
              Text(entry.tag,
                  style: TextStyle(
                    fontSize: 10, fontFamily: 'monospace',
                    color: tagClr, fontWeight: FontWeight.w600,
                  )),
              if (entry.stackTrace != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.bug_report, size: 10,
                    color: AppThemeColors.subtitle(night)),
              ],
            ]),
            const SizedBox(height: 2),
            // 消息
            Text(entry.message,
                maxLines: maxLines,
                overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5, fontFamily: 'monospace',
                  height: 1.4,
                  color: entry.level.severity >= LogLevel.error.severity
                      ? (night ? const Color(0xFFEF9A9A) : const Color(0xFFC62828))
                      : AppThemeColors.title(night),
                  fontWeight: entry.level.severity >= LogLevel.error.severity
                      ? FontWeight.w500
                      : FontWeight.normal,
                )),
            // 堆栈
            if (isExpanded && entry.stackTrace != null) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: night
                      ? const Color(0xFF2D2D2D)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(entry.stackTrace!,
                    style: TextStyle(
                      fontSize: 9.5, fontFamily: 'monospace',
                      height: 1.3,
                      color: AppThemeColors.subtitle(night),
                    )),
              ),
            ],
            // 展开指示
            if (!isExpanded && entry.message.length > 150)
              Text('⋯ 点击展开',
                  style: TextStyle(fontSize: 9,
                      color: AppThemeColors.subtitle(night))),
          ],
        ),
      ),
    );
  }

  Color _levelColor(LogLevel lv, bool night) {
    switch (lv) {
      case LogLevel.debug: return Colors.grey;
      case LogLevel.info: return night ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);
      case LogLevel.warn: return night ? const Color(0xFFFFD54F) : const Color(0xFFF57F17);
      case LogLevel.error: return night ? const Color(0xFFEF5350) : const Color(0xFFC62828);
      case LogLevel.fatal: return night ? const Color(0xFFCE93D8) : const Color(0xFF6A1B9A);
    }
  }

  Color _tagColor(String tag, bool night) {
    final idx = tag.hashCode.abs();
    const colors = [
      Color(0xFF64B5F6), Color(0xFF4DD0E1), Color(0xFF81C784),
      Color(0xFFFFB74D), Color(0xFFBA68C8), Color(0xFFF06292),
      Color(0xFF4DB6AC), Color(0xFF9575CD), Color(0xFFA1887F),
    ];
    return colors[idx % colors.length];
  }
}
