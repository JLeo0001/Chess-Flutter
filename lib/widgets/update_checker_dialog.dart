import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';

/// mode='full' 从关于页面手动触发，显示测速过程
/// mode='result' 后台静默测速完成，直接显示更新提示
class UpdateCheckerDialog extends StatefulWidget {
  final String mode;
  final UpdateCheckResult? result;
  const UpdateCheckerDialog({super.key, this.mode = 'full', this.result});
  @override
  State<UpdateCheckerDialog> createState() => _UpdateCheckerDialogState();
}

class _UpdateCheckerDialogState extends State<UpdateCheckerDialog> {
  int _step = 0;
  final List<_SpeedItem> _speedItems = [];
  int _testedCount = 0;
  String? _fastestProxy;
  int? _fastestLatency;
  bool _isLatest = true;
  String? _latestVersion;
  String? _downloadUrl;
  String? _assetName;
  double _downloadProgress = 0;
  String? _downloadedPath;
  bool _downloadError = false;
  bool _checkingFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.mode == 'result' && widget.result != null) {
      _applyResult(widget.result!);
    } else {
      _speedItems.addAll(UpdateService.proxyUrls.map((u) => _SpeedItem(u)));
      WidgetsBinding.instance.addPostFrameCallback((_) => _startFullCheck());
    }
  }

  void _applyResult(UpdateCheckResult r) {
    _fastestProxy = r.fastestProxy;
    _fastestLatency = r.fastestLatency;
    _latestVersion = r.version;
    _isLatest = r.isLatest;
    _downloadUrl = r.downloadUrl;
    _assetName = r.assetName;
    _step = 2;
    if (mounted) setState(() {});
  }

  Future<void> _startFullCheck() async {
    final result = await UpdateService.fullCheck(
      onProgress: (tested, total, url, latency) {
        if (!mounted) return;
        setState(() {
          _testedCount = tested;
          final idx = _speedItems.indexWhere((s) => s.url == url);
          if (idx >= 0) {
            _speedItems[idx].latencyMs = latency;
            _speedItems[idx].tested = true;
          }
          _speedItems.sort((a, b) {
            if (a.tested && b.tested) return (a.latencyMs ?? 99999).compareTo(b.latencyMs ?? 99999);
            if (a.tested) return -1;
            if (b.tested) return 1;
            return 0;
          });
        });
      },
    );
    if (!mounted) return;
    if (result == null) {
      setState(() { _step = 2; _checkingFailed = true; });
      return;
    }
    _applyResult(result);
  }

  Future<void> _startDownload() async {
    if (_downloadUrl == null || _fastestProxy == null) return;
    setState(() { _step = 3; _downloadProgress = 0; });
    final path = await UpdateService.downloadWithProgress(
      directUrl: _downloadUrl!, proxyBase: _fastestProxy!,
      saveName: _assetName ?? '更新包',
      onProgress: (p) { if (mounted) setState(() => _downloadProgress = p); },
    );
    if (!mounted) return;
    if (path != null) {
      _downloadedPath = path; _downloadProgress = 1.0; setState(() {});
      if (Platform.isAndroid) await _installApk(path);
    } else {
      setState(() => _downloadError = true);
    }
  }

  Future<void> _installApk(String path) async {
    try {
      final downloadsDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final destFile = File('${downloadsDir.path}/${_assetName ?? 'update.apk'}');
      if (destFile.path != path) await File(path).copy(destFile.path);
      await launchUrl(Uri.file(destFile.path), mode: LaunchMode.externalApplication);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      try {
        await launchUrl(Uri.file(path), mode: LaunchMode.externalApplication);
        if (mounted) Navigator.of(context).pop();
      } catch (_) { if (mounted) setState(() => _downloadError = true); }
    }
  }

  String get _title {
    if (_step == 0) return '检查更新中…';
    if (_checkingFailed) return '检查失败';
    if (_step == 3) return '下载中';
    if (_isLatest) return '已是最新版本';
    return '发现新版本';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(_title, style: TextStyle(color: cs.onSurface)),
      content: SizedBox(width: double.maxFinite, child: _buildContent(cs)),
      actions: _buildActions(cs),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    if (_checkingFailed) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off, size: 48, color: Colors.orange),
        const SizedBox(height: 12),
        Text('无法连接到更新服务器', style: TextStyle(color: cs.onSurface)),
        const SizedBox(height: 4),
        Text('请检查网络后重试', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
      ]);
    }
    switch (_step) {
      case 0: return _buildSpeedTest(cs);
      case 2: return _buildResult(cs);
      case 3: return _buildDownloadProgress(cs);
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildSpeedTest(ColorScheme cs) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      LinearProgressIndicator(value: _speedItems.isNotEmpty ? _testedCount / _speedItems.length : null),
      const SizedBox(height: 8),
      Text('正在选择最优下载线路…',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
      const SizedBox(height: 12),
      Flexible(
        child: Container(constraints: const BoxConstraints(maxHeight: 200), child: ListView.builder(
          shrinkWrap: true, itemCount: _speedItems.length.clamp(0, 5),
          itemBuilder: (_, i) {
            final item = _speedItems[i];
            return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
              Icon(item.tested ? (item.latencyMs != null ? Icons.check_circle_outline : Icons.error_outline) : Icons.schedule,
                  size: 14, color: item.tested ? (item.latencyMs != null ? Colors.green : Colors.red) : cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('节点 ${i + 1}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              const Spacer(),
              Text(item.latencyMs != null ? '${item.latencyMs}ms' : item.tested ? '超时' : '…',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: item.latencyMs != null ? (item.latencyMs! < 500 ? Colors.green : item.latencyMs! < 1500 ? Colors.orange : Colors.red) : cs.onSurfaceVariant)),
            ]));
          },
        )),
      ),
    ]);
  }

  Widget _buildResult(ColorScheme cs) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_isLatest) ...[
        const Icon(Icons.check_circle, size: 48, color: Colors.green),
        const SizedBox(height: 12),
        Text('当前版本 ${UpdateService.currentVersion} 已是最新',
            style: TextStyle(color: cs.onSurface)),
      ] else ...[
        Icon(Icons.system_update, size: 48, color: cs.primary),
        const SizedBox(height: 12),
        Text('发现新版本 v$_latestVersion',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
        const SizedBox(height: 4),
        Text('当前版本: ${UpdateService.currentVersion}',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        if (_assetName != null) ...[
          const SizedBox(height: 8),
          Text('安装包: $_assetName',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ],
    ]);
  }

  Widget _buildDownloadProgress(ColorScheme cs) {
    final pct = (_downloadProgress * 100).toStringAsFixed(0);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_downloadedPath != null && !_downloadError) ...[
        const Icon(Icons.check_circle, size: 48, color: Colors.green),
        const SizedBox(height: 12),
        Text('下载完成！', style: TextStyle(color: cs.onSurface)),
        if (!Platform.isAndroid) ...[
          const SizedBox(height: 4),
          Text('文件已保存到临时目录', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ] else if (_downloadError) ...[
        const Icon(Icons.error, size: 48, color: Colors.red),
        const SizedBox(height: 12),
        Text('下载失败，请稍后重试', style: TextStyle(color: cs.onSurface)),
      ] else ...[
        SizedBox(width: 48, height: 48,
            child: CircularProgressIndicator(value: _downloadProgress)),
        const SizedBox(height: 16),
        Text('$pct%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface)),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: _downloadProgress),
      ],
    ]);
  }

  List<Widget> _buildActions(ColorScheme cs) {
    if (_step == 3 && _downloadedPath == null && !_downloadError) return [];
    if (_step == 2 && !_isLatest && _downloadUrl != null) {
      return [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('以后再说')),
        FilledButton(onPressed: _startDownload, child: const Text('立即下载')),
      ];
    }
    return [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('确定'))];
  }
}

class _SpeedItem {
  final String url;
  bool tested = false;
  int? latencyMs;
  _SpeedItem(this.url);
}
