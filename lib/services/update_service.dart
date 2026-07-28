import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static const _repoOwner = 'JLeo0001';
  static const _repoName = 'Chess-Flutter';
  static const _directUrl = 'https://github.com/';

  static const proxyUrls = [
    'https://gh-proxy.com/',
    'https://ghproxy.net/',
    'https://ghproxy.homeboyc.cn/',
    'https://moeyy.cn/gh-proxy/',
    'https://github.akams.cn/',
    'https://gh.zwy.one/',
    'https://gh.llkk.cc/',
    'https://ghfile.geekertao.top/',
    'https://ghproxy.cxkpro.top/',
    'https://git.yylx.win/',
    'https://gh.h233.eu.org/',
    'https://cdn.crashmc.com/',
    'https://cors.isteed.cc/',
    'https://fastgit.cc/',
    'https://ghfast.top/',
    'https://gh.monlor.com/',
    'https://mirror.ghproxy.com/',
    'https://gh.con.sh/',
    'https://gh.api.99988866.xyz/',
    'https://gitdl.cn/',
  ];

  static String? _currentVersion;

  static Future<String> get currentVersion async {
    if (_currentVersion != null) return _currentVersion!;
    try {
      final yaml = await rootBundle.loadString('pubspec.yaml');
      final match = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(yaml);
      if (match != null) {
        final v = match.group(1)!;
        _currentVersion = v.contains('+') ? v.split('+').first : v;
        return _currentVersion!;
      }
    } catch (_) {}
    _currentVersion = '0.0.0';
    return _currentVersion!;
  }

  static Future<UpdateCheckResult?> silentCheck() async {
    final curVer = await currentVersion;
    final release = await fetchLatestRelease();
    if (release == null) return null;
    if (!isNewer(curVer, release.version)) return null;
    final results = <_ProxyLatency>[];
    for (final url in proxyUrls) {
      final t = await _pingUrl(url);
      results.add(_ProxyLatency(url, t));
    }
    results.sort((a, b) => (a.latency ?? 999999).compareTo(b.latency ?? 999999));
    final topProxies = results
        .where((r) => r.latency != null)
        .take(3)
        .map((r) => r.url)
        .toList();
    final asset = findPlatformAsset(release.assets);
    return UpdateCheckResult(
      fastestProxy: topProxies.isNotEmpty ? topProxies.first : _directUrl,
      version: release.version,
      topProxies: topProxies,
      assetName: asset?.name,
      downloadUrl: asset?.downloadUrl,
    );
  }

  static Future<int?> _pingUrl(String url) async {
    try {
      final sw = Stopwatch()..start();
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      sw.stop();
      if (r.statusCode < 500) return sw.elapsedMilliseconds;
    } catch (_) {}
    return null;
  }

  static Future<ReleaseInfo?> fetchLatestRelease() async {
    try {
      final apiUrl = 'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';
      final r = await http.get(Uri.parse(apiUrl),
          headers: {'Accept': 'application/vnd.github+json'}).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String;
      final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;
      final assets = (data['assets'] as List<dynamic>?)?.map((a) {
        final m = a as Map<String, dynamic>;
        return AssetInfo(name: m['name'] as String, downloadUrl: m['browser_download_url'] as String);
      }).toList() ?? [];
      return ReleaseInfo(version, tagName, assets);
    } catch (_) { return null; }
  }

  static bool isNewer(String current, String latest) {
    final cur = _parseVersion(current);
    final lat = _parseVersion(latest);
    for (int i = 0; i < 3; i++) {
      if (lat[i] > cur[i]) return true;
      if (lat[i] < cur[i]) return false;
    }
    return false;
  }

  static List<int> _parseVersion(String v) {
    final parts = v.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    while (parts.length < 3) parts.add(0);
    return parts;
  }

  static AssetInfo? findPlatformAsset(List<AssetInfo> assets) {
    if (Platform.isAndroid) {
      for (final p in ['android-arm64', 'android-arm32', 'android-x64']) {
        for (final a in assets) {
          if (a.name.contains(p) && a.name.endsWith('.apk')) return a;
        }
      }
    } else if (Platform.isWindows) {
      for (final a in assets) { if (a.name.contains('windows-x64.zip')) return a; }
    } else if (Platform.isLinux) {
      for (final a in assets) { if (a.name.contains('linux-x64.AppImage')) return a; }
    } else if (Platform.isMacOS) {
      for (final a in assets) { if (a.name.contains('macos-x64.dmg')) return a; }
    }
    return null;
  }

  /// 渐进式竞速下载：先跑最快2路，3秒后进度<15%再加2路，省带宽
  static Future<String?> downloadWithProgress({
    required String directUrl,
    required List<String> raceProxies,
    required String saveName,
    required void Function(double progress) onProgress,
    Future<bool> Function()? shouldCancel,
  }) async {
    // 构建所有候选 URL：代理在前，GitHub CDN 直连在后
    final allUrls = <String>[];
    for (final proxy in raceProxies) {
      allUrls.add('${proxy.endsWith('/') ? proxy : '$proxy/'}$directUrl');
    }
    allUrls.add(directUrl); // GitHub CDN (objects.githubusercontent.com)

    final dir = await getTemporaryDirectory();
    final completer = Completer<String?>();
    final finished = <int>{}; // 记录哪些索引已完成/失败
    double _bestProgress = 0;
    int activeCount = allUrls.length;
    bool _secondWaveFired = false;

    Future<void> race(int index) async {
      if (completer.isCompleted) return;
      final url = allUrls[index];
      try {
        final file = File('${dir.path}/${saveName}_$index');
        final request = http.Request('GET', Uri.parse(url));
        final http.StreamedResponse response = await request.send().timeout(
          const Duration(seconds: 120),
          onTimeout: () => throw Exception('timeout'),
        );
        if (response.statusCode != 200 && response.statusCode != 302 && response.statusCode != 301) {
          throw Exception('bad status ${response.statusCode}');
        }
        final total = response.contentLength ?? 0;
        var received = 0;
        final sink = file.openWrite();
        await for (final chunk in response.stream) {
          if (completer.isCompleted) {
            await sink.close();
            response.stream.drain();
            file.deleteSync();
            return;
          }
          if (shouldCancel != null && await shouldCancel()) {
            await sink.close();
            response.stream.drain();
            file.deleteSync();
            if (!completer.isCompleted) completer.complete(null);
            return;
          }
          received += chunk.length;
          sink.add(chunk);
          if (total > 0) {
            final p = received / total;
            if (p > _bestProgress) {
              _bestProgress = p;
              onProgress(p);
            }
          }
        }
        await sink.close();
        if (!completer.isCompleted) {
          final finalFile = File('${dir.path}/$saveName');
          if (finalFile.existsSync()) finalFile.deleteSync();
          file.renameSync(finalFile.path);
          completer.complete(finalFile.path);
        } else {
          file.deleteSync();
        }
      } catch (_) {
        if (!completer.isCompleted) {
          finished.add(index);
          activeCount--;
          if (activeCount <= 0) completer.complete(null);
        }
      }
    }

    // 第一波：前 2 路（如果总共不到 2 路就全跑）
    final firstWave = allUrls.length >= 2 ? 2 : allUrls.length;
    for (int i = 0; i < firstWave; i++) {
      race(i);
    }

    // 3 秒后检查：如果进度不足 15% 且还有待命 URL，启动第二波
    if (allUrls.length > 2) {
      Future.delayed(const Duration(seconds: 3), () {
        if (!completer.isCompleted && !_secondWaveFired && _bestProgress < 0.15) {
          _secondWaveFired = true;
          for (int i = firstWave; i < allUrls.length; i++) {
            if (!finished.contains(i)) {
              race(i);
            }
          }
        }
      });
    }

    return completer.future;
  }

  static Future<UpdateCheckResult?> fullCheck({
    void Function(int tested, int total, String url, int? latency)? onProgress,
  }) async {
    final release = await fetchLatestRelease();
    if (release == null) return null;
    final curVer = await currentVersion;
    final results = <_ProxyLatency>[];
    final total = proxyUrls.length;
    for (int i = 0; i < total; i++) {
      final url = proxyUrls[i];
      onProgress?.call(i, total, url, null);
      final t = await _pingUrl(url);
      onProgress?.call(i + 1, total, url, t);
      results.add(_ProxyLatency(url, t));
    }
    // 按延迟排序，取前 3 个可达的
    results.sort((a, b) => (a.latency ?? 999999).compareTo(b.latency ?? 999999));
    final topProxies = results
        .where((r) => r.latency != null)
        .take(3)
        .map((r) => r.url)
        .toList();
    final fastestUrl = topProxies.isNotEmpty ? topProxies.first : null;
    final fastestLatency = results.isNotEmpty ? results.first.latency : null;
    final hasUpdate = isNewer(curVer, release.version);
    final asset = hasUpdate ? findPlatformAsset(release.assets) : null;
    return UpdateCheckResult(
      fastestProxy: fastestUrl ?? _directUrl,
      fastestLatency: fastestLatency,
      topProxies: topProxies,
      version: release.version,
      isLatest: !hasUpdate,
      assetName: asset?.name,
      downloadUrl: asset?.downloadUrl,
    );
  }
}

class UpdateCheckResult {
  final String fastestProxy;
  final int? fastestLatency;
  final List<String> topProxies;
  final String version;
  final bool isLatest;
  final String? assetName;
  final String? downloadUrl;
  UpdateCheckResult({
    required this.fastestProxy,
    this.fastestLatency,
    this.topProxies = const [],
    required this.version,
    this.isLatest = false,
    this.assetName,
    this.downloadUrl,
  });
}

class ProxyResult {
  final String url;
  final int? latencyMs;
  ProxyResult(this.url, this.latencyMs);
}

class ReleaseInfo {
  final String version;
  final String tagName;
  final List<AssetInfo> assets;
  ReleaseInfo(this.version, this.tagName, this.assets);
}

class AssetInfo {
  final String name;
  final String downloadUrl;
  AssetInfo({required this.name, required this.downloadUrl});
}

class _ProxyLatency {
  final String url;
  final int? latency;
  _ProxyLatency(this.url, this.latency);
}
