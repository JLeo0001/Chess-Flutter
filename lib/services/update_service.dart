import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static const _currentVersion = '1.0.2';
  static const _repoOwner = 'JLeo0001';
  static const _repoName = 'Chess-Flutter';
  static const _directUrl = 'https://github.com/';

  static const proxyUrls = [
    'https://gh-proxy.com/',
    'https://ghproxy.net/',
    'https://ghproxy.homeboyc.cn/',
    'https://ghp.ci/',
    'https://moeyy.cn/gh-proxy/',
    'https://github.akams.cn/',
    'https://gh.zwy.one/',
    'https://raw.ihtw.moe/',
    'https://gh.llkk.cc/',
    'https://gh.xxooo.cf/',
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
    'https://ghproxy.it/',
    'https://gh.jasonzeng.dev/',
  ];

  static Future<UpdateCheckResult?> silentCheck() async {
    final release = await fetchLatestRelease();
    if (release == null) return null;

    final hasUpdate = isNewer(_currentVersion, release.version);
    if (!hasUpdate) return null;

    final fastest = await _findFastestProxy();
    final asset = findPlatformAsset(release.assets);
    return UpdateCheckResult(
      fastestProxy: fastest ?? _directUrl,
      version: release.version,
      assetName: asset?.name,
      downloadUrl: asset?.downloadUrl,
    );
  }

  static Future<String?> _findFastestProxy() async {
    String? bestUrl;
    int? bestTime;
    for (final url in proxyUrls) {
      final t = await _pingUrl(url);
      if (t != null && (bestTime == null || t < bestTime)) {
        bestTime = t;
        bestUrl = url;
      }
    }
    return bestUrl;
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

  static String get currentVersion => _currentVersion;

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

  static Future<String?> downloadWithProgress({
    required String directUrl,
    required String proxyBase,
    required String saveName,
    required void Function(double progress) onProgress,
  }) async {
    final bool isDirect = proxyBase == _directUrl;
    final downloadUrl = isDirect
        ? directUrl
        : '${proxyBase.endsWith('/') ? proxyBase : '$proxyBase/'}${Uri.parse(directUrl).host}${Uri.parse(directUrl).path}';
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$saveName');
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await request.send().timeout(const Duration(minutes: 30));
      if (response.statusCode != 200) return null;
      final total = response.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite();
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) onProgress(received / total);
      }
      await sink.close();
      return file.path;
    } catch (_) { return null; }
  }

  static Future<UpdateCheckResult?> fullCheck({
    void Function(int tested, int total, String url, int? latency)? onProgress,
  }) async {
    // 先查版本（直接调 GitHub API，不走代理）
    final release = await fetchLatestRelease();
    if (release == null) return null;

    // 测速找最快代理（github.com 兜底）
    String? fastestUrl;
    int? fastestLatency;
    final total = proxyUrls.length;
    for (int i = 0; i < total; i++) {
      final url = proxyUrls[i];
      onProgress?.call(i, total, url, null);
      final t = await _pingUrl(url);
      onProgress?.call(i + 1, total, url, t);
      if (t != null && (fastestLatency == null || t < fastestLatency)) {
        fastestLatency = t;
        fastestUrl = url;
      }
    }

    final hasUpdate = isNewer(_currentVersion, release.version);
    final asset = hasUpdate ? findPlatformAsset(release.assets) : null;

    return UpdateCheckResult(
      fastestProxy: fastestUrl ?? _directUrl,
      fastestLatency: fastestLatency,
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
  final String version;
  final bool isLatest;
  final String? assetName;
  final String? downloadUrl;
  UpdateCheckResult({
    required this.fastestProxy,
    this.fastestLatency,
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
