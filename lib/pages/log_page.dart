import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/log_provider.dart';

/// 日志终端页面 — M3 FilterChip + ListTile 风格
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

  LogLevel? _levelFilter;
  String _searchQuery = '';
  String _tagFilter = '';
  bool _showStats = false;
  bool _showSearch = false;

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
    _searchController.addListener(
        () => setState(() => _searchQuery = _searchController.text));
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
        const SnackBar(content: Text('已复制该条日志'), duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final logProv = context.watch<LogProvider>();
    final all = logProv.entries;
    final filtered = _filtered(all);
    final stats = logProv.computeStats();

    return Scaffold(
      appBar: AppBar(
        title: const Text('运行日志'),
        actions: [
          IconButton(
            icon: Icon(_showStats ? Icons.bar_chart : Icons.bar_chart_outlined, size: 20),
            tooltip: '统计',
            onPressed: () => setState(() => _showStats = !_showStats),
          ),
          IconButton(
            icon: Icon(_showSearch ? Icons.search_off : Icons.search, size: 20),
            tooltip: '搜索',
            onPressed: () => setState(() => _showSearch = !_showSearch),
          ),
          Switch(
            value: _autoScroll,
            onChanged: (v) {
              setState(() => _autoScroll = v);
              if (v) _onNewLog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: '复制全部',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: logProv.fullText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: '清空',
            onPressed: () => logProv.clear(),
          ),
        ],
      ),
      body: Column(children: [
        // 搜索栏
        if (_showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索日志内容或标签…',
                prefixIcon: Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        // 过滤芯片
        _filterChips(context, cs, stats),
        const Divider(height: 1),
        // 统计
        if (_showStats) _statsPanel(cs, stats),
        // 日志列表
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 40, color: cs.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text(all.isEmpty ? '暂无日志' : '无匹配日志',
                          style: TextStyle(
                              fontSize: 14, color: cs.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final e = filtered[i];
                    final isExpanded = _expandedIndices.contains(i);
                    return _logEntry(
                      e, isExpanded, i, cs);
                  },
                ),
        ),
        // 底栏
        _bottomBar(cs, all.length, filtered.length, logProv),
      ]),
    );
  }

  Widget _filterChips(BuildContext context, ColorScheme cs, LogStats stats) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          FilterChip(
            label: Text('全部 ${stats.total}'),
            selected: _levelFilter == null,
            onSelected: (_) => setState(() => _levelFilter = null),
          ),
          const SizedBox(width: 4),
          for (final lv in LogLevel.values)
            if (stats.levelCount(lv) > 0)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: FilterChip(
                  label: Text('${lv.short} ${stats.levelCount(lv)}'),
                  selected: _levelFilter == lv,
                  onSelected: (_) => setState(() {
                    _levelFilter = _levelFilter == lv ? null : lv;
                  }),
                ),
              ),
          const SizedBox(width: 8),
          for (final tag in stats.perTag.keys.take(6))
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: FilterChip(
                label: Text('$tag ${stats.tagCount(tag)}'),
                selected: _tagFilter == tag,
                onSelected: (_) => setState(() {
                  _tagFilter = _tagFilter == tag ? '' : tag;
                }),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _statsPanel(ColorScheme cs, LogStats stats) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: cs.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('日志统计',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.primary)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: [
              _statChip('总数', stats.total, null, cs),
              for (final lv in LogLevel.values)
                if (stats.levelCount(lv) > 0)
                  _statChip(lv.short, stats.levelCount(lv),
                      _levelColor(lv, cs), cs),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, int count, Color? color, ColorScheme cs) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (color != null)
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      if (color != null) const SizedBox(width: 3),
      Text('$label:$count',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color ?? cs.onSurface)),
    ]);
  }

  Widget _bottomBar(
      ColorScheme cs, int total, int filtered, LogProvider lp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      color: cs.surfaceContainerHighest,
      child: Row(children: [
        Icon(Icons.filter_list, size: 12, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          total == filtered ? '$total 条' : '$filtered / $total 条',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        if (_levelFilter != null ||
            _tagFilter.isNotEmpty ||
            _searchQuery.isNotEmpty)
          TextButton(
            onPressed: () => setState(() {
              _levelFilter = null;
              _tagFilter = '';
              _searchController.clear();
            }),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('清除过滤',
                style: TextStyle(fontSize: 11, color: cs.primary)),
          ),
        const Spacer(),
        Text('${lp.fullText.length ~/ 1024} KB',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ]),
    );
  }

  Widget _logEntry(LogEntry e, bool isExpanded, int i, ColorScheme cs) {
    final lvColor = _levelColor(e.level, cs);
    return GestureDetector(
      onTap: () => setState(() {
        if (isExpanded) {
          _expandedIndices.remove(i);
        } else {
          _expandedIndices.add(i);
        }
      }),
      onLongPress: () => _copySingle(e),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        margin: const EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(
          color: isExpanded ? lvColor.withAlpha(10) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 28,
                padding:
                    const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: lvColor.withAlpha(35),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(e.level.short,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: lvColor)),
              ),
              const SizedBox(width: 4),
              Text(e.formattedTime,
                  style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: cs.onSurfaceVariant)),
              const SizedBox(width: 4),
              Text(e.tag,
                  style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: _tagColor(e.tag))),
              if (e.stackTrace != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.bug_report, size: 10, color: cs.onSurfaceVariant),
              ],
            ]),
            const SizedBox(height: 2),
            Text(
              e.message,
              maxLines: isExpanded ? 30 : 3,
              overflow:
                  isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontFamily: 'monospace',
                height: 1.4,
                color: e.level.severity >= LogLevel.error.severity
                    ? cs.error
                    : cs.onSurface,
                fontWeight: e.level.severity >= LogLevel.error.severity
                    ? FontWeight.w500
                    : FontWeight.normal,
              ),
            ),
            if (isExpanded && e.stackTrace != null) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(e.stackTrace!,
                    style: TextStyle(
                        fontSize: 9.5,
                        fontFamily: 'monospace',
                        height: 1.3,
                        color: cs.onSurfaceVariant)),
              ),
            ],
            if (!isExpanded && e.message.length > 150)
              Text('⋯ 点击展开',
                  style: TextStyle(
                      fontSize: 9, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Color _levelColor(LogLevel lv, ColorScheme cs) {
    switch (lv) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return cs.primary;
      case LogLevel.warn:
        return Colors.orange;
      case LogLevel.error:
        return cs.error;
      case LogLevel.fatal:
        return Colors.purple;
    }
  }

  Color _tagColor(String tag) {
    final colors = [
      const Color(0xFF64B5F6),
      const Color(0xFF4DD0E1),
      const Color(0xFF81C784),
      const Color(0xFFFFB74D),
      const Color(0xFFBA68C8),
      const Color(0xFFF06292),
      const Color(0xFF4DB6AC),
      const Color(0xFF9575CD),
    ];
    return colors[tag.hashCode.abs() % colors.length];
  }
}
