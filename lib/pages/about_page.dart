import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 关于页面 — 使用 M3 ListTile + Card
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App 信息
          Center(
            child: Column(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/app_icon_256.png',
                    width: 80, height: 80, fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
              Text('弈',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface)),
              const SizedBox(height: 4),
              Text('多合一棋牌游戏',
                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text('v1.0.1',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(height: 24),

          // 游戏列表
          _section('包含游戏', cs),
          Card(
            child: Column(children: [
              for (final g in [
                ('♟', '五子棋', '15×15 · 五连珠获胜'),
                ('✖', '井字棋', '3×3 · 三连即胜'),
                ('🐘', '中国象棋', '9×10 · 楚河汉界'),
                ('♔', '国际象棋', '8×8 · 多引擎'),
                ('⚫', '围棋', '19×19 · 围地获胜'),
                ('🃏', '换牌扑克', '5 张抽牌 · 选牌换牌'),
                ('♠️', '德州扑克', '2+5 公共牌 · 7选5'),
                ('🃏', 'UNO', '2~4 人 · 经典规则'),
                ('🃏', '斗地主', '三人 · 叫地主 · 1v2'),
                ('🕷️', '蜘蛛纸牌', '单人接龙 · 三种难度'),
              ].indexed) ...[
                if (g.$1 > 0) const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Text(g.$2.$1, style: const TextStyle(fontSize: 18)),
                  title: Text(g.$2.$2,
                      style: TextStyle(
                          fontWeight: FontWeight.w500, color: cs.onSurface)),
                  subtitle: Text(g.$2.$3),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 20),

          // 技术栈
          _section('技术栈', cs),
          Card(
            child: Column(children: [
              for (final t in [
                ('框架', 'Flutter 3.27 · Dart'),
                ('状态管理', 'Provider'),
                ('国际象棋引擎', 'Stockfish (UCI)'),
                ('图标', 'Material You 动态取色'),
                ('CI/CD', 'GitHub Actions'),
              ].indexed) ...[
                if (t.$1 > 0) const Divider(height: 1, indent: 16),
                ListTile(
                  title: Text(t.$2.$1,
                      style: TextStyle(
                          fontWeight: FontWeight.w500, color: cs.onSurface)),
                  trailing: Text(t.$2.$2,
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 20),

          // 链接
          _section('链接', cs),
          Card(
            child: Column(children: [
              _linkTile(context, Icons.code, 'GitHub · 源代码',
                  'https://github.com/JLeo0001/Chess-Flutter'),
              const Divider(height: 1, indent: 56),
              _linkTile(context, Icons.bug_report, '报告问题',
                  'https://github.com/JLeo0001/Chess-Flutter/issues'),
              const Divider(height: 1, indent: 56),
              _linkTile(context, Icons.description, '开源许可 (MIT)',
                  'https://github.com/JLeo0001/Chess-Flutter/blob/main/LICENSE'),
            ]),
          ),
          const SizedBox(height: 20),

          // 诊断
          _section('诊断', cs),
          Card(
            child: ListTile(
              leading: Icon(Icons.terminal, color: cs.primary),
              title: const Text('日志终端'),
              subtitle:
                  const Text('查看应用运行日志，含引擎诊断'),
              trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              onTap: () => Navigator.pushNamed(context, '/logs'),
            ),
          ),
          const SizedBox(height: 20),

          // 版权
          Center(
            child: Text(
              'MIT License\n© 2026 JasonLeoZhou',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: cs.onSurfaceVariant, height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _section(String text, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.primary)),
    );
  }

  Widget _linkTile(
      BuildContext context, IconData icon, String label, String url) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.primary),
      title: Text(label, style: TextStyle(color: cs.onSurface)),
      trailing: Icon(Icons.open_in_new, size: 16, color: cs.onSurfaceVariant),
      onTap: () => launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication),
    );
  }
}
