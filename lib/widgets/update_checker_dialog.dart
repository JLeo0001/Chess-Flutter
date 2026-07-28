import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';

class UpdateCheckerDialog extends StatefulWidget {
  final bool autoCheck;
  const UpdateCheckerDialog({super.key, this.autoCheck = false});
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

  @override
  void initState() {
    super.initState();
    _speedItems.addAll(UpdateService.proxyUrls.map((u) => _SpeedItem(u)));
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    await _speedTest();
    await _checkVersion();
    if (widget.autoCheck && _isLatest) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
  }

  Future<void> _speedTest() async {
    final results = await UpdateService.speedTest(
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
    final fastest = results.firstWhere((r) => r.latencyMs != null, orElse: () => results.first);
    _fastestProxy = fastest.url;
    _fastestLatency = fastest.latencyMs;
    if (mounted) setState(() {});
  }

  Future<void> _checkVersion() async {
    setState(() => _step = 1);
    final release = await UpdateService.fetchLatestRelease();
    if (release == null) { _isLatest = true; setState(() => _step = 2); return; }
    _latestVersion = release.version;
    _isLatest = !UpdateService.isNewer(UpdateService.currentVersion, release.version);
    if (!_isLatest) {
      final asset = UpdateService.findPlatformAsset(release.assets);
      if (asset != null) { _downloadUrl = asset.downloadUrl; _assetName = asset.name; }
    }
    if (mounted) setState(() => _step = 2);
  }

  Future<void> _startDownload() async {
    if (_downloadUrl == null || _fastestProxy == null) return;
    setState(() { _step = 3; _downloadProgress = 0; });
    final path = await UpdateService.downloadWithProgress(
      directUrl: _downloadUrl!, proxyBase: _fastestProxy!,
      saveName: _assetName ?? 'update',
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(_step == 0 ? 'Checking mirrors...' : _step == 1 ? 'Checking for updates' : _step == 3 ? 'Downloading' : _isLatest ? 'Up to date' : 'New version available', style: TextStyle(color: cs.onSurface)),
      content: SizedBox(width: double.maxFinite, child: _buildContent(cs)),
      actions: _buildActions(cs),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    switch (_step) {
      case 0: return _buildSpeedTest(cs);
      case 1: return _buildChecking(cs);
      case 2: return _buildResult(cs);
      case 3: return _buildDownloadProgress(cs);
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildSpeedTest(ColorScheme cs) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      LinearProgressIndicator(value: _speedItems.isNotEmpty ? _testedCount / _speedItems.length : null),
      const SizedBox(height: 8),
      Text('Tested $_testedCount / ${_speedItems.length} mirrors', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      const SizedBox(height: 12),
      Flexible(
        child: Container(constraints: const BoxConstraints(maxHeight: 200), child: ListView.builder(
          shrinkWrap: true, itemCount: _speedItems.length,
          itemBuilder: (_, i) {
            final item = _speedItems[i];
            final displayUrl = item.url.replaceAll('https://', '').replaceAll('http://', '');
            return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
              Icon(item.tested ? (item.latencyMs != null ? Icons.check_circle_outline : Icons.error_outline) : Icons.schedule, size: 14, color: item.tested ? (item.latencyMs != null ? Colors.green : Colors.red) : cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(child: Text(displayUrl, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
              Text(item.latencyMs != null ? '${item.latencyMs}ms' : item.tested ? '-' : '...', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: item.latencyMs != null ? (item.latencyMs! < 500 ? Colors.green : item.latencyMs! < 1500 ? Colors.orange : Colors.red) : cs.onSurfaceVariant)),
            ]));
          },
        )),
      ),
    ]);
  }

  Widget _buildChecking(ColorScheme cs) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const CircularProgressIndicator(), const SizedBox(height: 16),
      Text('Querying latest release...', style: TextStyle(color: cs.onSurfaceVariant)),
      if (_fastestProxy != null) ...[
        const SizedBox(height: 8),
        Text('Fastest: ${_fastestProxy!.replaceAll('https://', '')}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ],
    ]);
  }

  Widget _buildResult(ColorScheme cs) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_fastestProxy != null && _fastestLatency != null) ...[
        Text('Fastest mirror: ${_fastestProxy!.replaceAll('https://', '')} (${_fastestLatency}ms)', style: TextStyle(fontSize: 12, color: cs.primary)),
        const SizedBox(height: 16),
      ],
      if (_isLatest) ...[
        const Icon(Icons.check_circle, size: 48, color: Colors.green), const SizedBox(height: 12),
        Text('Current ${UpdateService.currentVersion} is the latest', style: TextStyle(color: cs.onSurface)),
      ] else ...[
        Icon(Icons.system_update, size: 48, color: cs.primary), const SizedBox(height: 12),
        Text('v$_latestVersion available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
        const SizedBox(height: 4),
        Text('Current: ${UpdateService.currentVersion}', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        if (_assetName != null) ...[
          const SizedBox(height: 8),
          Text('Package: $_assetName', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ],
    ]);
  }

  Widget _buildDownloadProgress(ColorScheme cs) {
    final pct = (_downloadProgress * 100).toStringAsFixed(0);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_downloadedPath != null && !_downloadError) ...[
        const Icon(Icons.check_circle, size: 48, color: Colors.green), const SizedBox(height: 12),
        Text('Download complete!', style: TextStyle(color: cs.onSurface)),
        if (!Platform.isAndroid) ...[
          const SizedBox(height: 4),
          Text('Saved to temp directory', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ] else if (_downloadError) ...[
        const Icon(Icons.error, size: 48, color: Colors.red), const SizedBox(height: 12),
        Text('Download failed', style: TextStyle(color: cs.onSurface)),
      ] else ...[
        SizedBox(width: 48, height: 48, child: CircularProgressIndicator(value: _downloadProgress)),
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
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Later')),
        FilledButton(onPressed: _startDownload, child: const Text('Download')),
      ];
    }
    return [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(_isLatest || _step == 3 ? 'OK' : 'Cancel'))];
  }
}

class _SpeedItem {
  final String url;
  bool tested = false;
  int? latencyMs;
  _SpeedItem(this.url);
}
