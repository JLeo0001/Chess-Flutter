import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../themes/app_theme.dart';

/// 关于页面
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶栏
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                    color: AppThemeColors.primary(night),
                  ),
                  const SizedBox(width: 8),
                  Text('关于', style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold,
                      color: AppThemeColors.title(night))),
                ]),
              ),
              Divider(color: AppThemeColors.divider(night)),
              const SizedBox(height: 16),

              // App 头像 + 名称
              Center(
                child: Column(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/app_icon_256.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('弈', style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold,
                      color: AppThemeColors.title(night))),
                  const SizedBox(height: 4),
                  Text('多合一棋牌游戏', style: TextStyle(
                      fontSize: 14, color: AppThemeColors.subtitle(night))),
                  const SizedBox(height: 2),
                  Text('v1.0.0', style: TextStyle(
                      fontSize: 12, color: AppThemeColors.subtitle(night))),
                ]),
              ),
              const SizedBox(height: 24),

              // 游戏列表
              _sectionLabel('包含游戏', night),
              _gameList(night),
              const SizedBox(height: 20),

              // 技术栈
              _sectionLabel('技术栈', night),
              _techCard(night),
              const SizedBox(height: 20),

              // 链接
              _sectionLabel('链接', night),
              _linkCard(night),
              const SizedBox(height: 20),

              // 诊断工具
              _sectionLabel('诊断', night),
              _diagCard(context, night),
              const SizedBox(height: 20),

              // 版权
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'MIT License\n© 2026 JasonLeoZhou',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppThemeColors.subtitle(night), height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, bool night) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(text, style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: AppThemeColors.primary(night))),
    );
  }

  Widget _gameList(bool night) {
    const games = [
      ('♟', '五子棋', '15×15 · 五连珠获胜 · 人机/双人'),
      ('✖', '井字棋', '3×3 · 三连即胜 · 先X后O'),
      ('🐘', '中国象棋', '9×10 · 楚河汉界 · 红先黑后'),
      ('♔', '国际象棋', '8×8 · Stockfish 引擎 · 白先黑后'),
      ('⚫', '围棋', '19×19 · 围地获胜 · 人机/双人'),
      ('🃏', '换牌扑克', '5 张抽牌 · 选牌换牌'),
      ('♠️', '德州扑克', '2 张底牌+5 张公共 · 7 选 5'),
      ('🃏', 'UNO', '2~4 人 · 经典规则 · 人机对战'),
      ('🃏', '斗地主', '三人 · 叫地主 · 1v2 人机'),
      ('🕷️', '蜘蛛纸牌', '单人接龙 · 104 张 · 三种难度'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppThemeColors.divider(night), width: 1),
        ),
        color: AppThemeColors.highlight(night),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            for (int i = 0; i < games.length; i++) ...[
              if (i > 0) const Divider(height: 20),
              Row(children: [
                Text(games[i].$1, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(games[i].$2, style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500,
                          color: AppThemeColors.title(night))),
                      Text(games[i].$3, style: TextStyle(
                          fontSize: 12, color: AppThemeColors.subtitle(night))),
                    ],
                  ),
                ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _techCard(bool night) {
    const items = [
      ('框架', 'Flutter 3.27 · Dart'),
      ('状态管理', 'Provider'),
      ('国际象棋引擎', 'Stockfish (UCI)'),
      ('牌类引擎', 'card_game · poker_solver'),
      ('图标', 'Material You 动态取色'),
      ('CI/CD', 'GitHub Actions'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppThemeColors.divider(night), width: 1),
        ),
        color: AppThemeColors.highlight(night),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 20),
              Row(children: [
                SizedBox(width: 100, child: Text(items[i].$1, style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500,
                    color: AppThemeColors.title(night)))),
                Expanded(child: Text(items[i].$2, style: TextStyle(
                    fontSize: 14, color: AppThemeColors.subtitle(night)))),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _linkCard(bool night) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppThemeColors.divider(night), width: 1),
        ),
        color: AppThemeColors.highlight(night),
        child: Column(children: [
          _linkItem(Icons.code, 'GitHub · 源代码', 'https://github.com/JLeo0001/Chess-Flutter', night),
          const Divider(height: 1, indent: 52),
          _linkItem(Icons.bug_report, '报告问题', 'https://github.com/JLeo0001/Chess-Flutter/issues', night),
          const Divider(height: 1, indent: 52),
          _linkItem(Icons.description, '开源许可 (MIT)', 'https://github.com/JLeo0001/Chess-Flutter/blob/main/LICENSE', night),
        ]),
      ),
    );
  }

  Widget _linkItem(IconData icon, String label, String url, bool night) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 22, color: AppThemeColors.primary(night)),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: TextStyle(
              fontSize: 15, color: AppThemeColors.title(night)))),
          Icon(Icons.open_in_new, size: 16, color: AppThemeColors.subtitle(night)),
        ]),
      ),
    );
  }

  Widget _diagCard(BuildContext context, bool night) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppThemeColors.divider(night), width: 1),
        ),
        color: AppThemeColors.highlight(night),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pushNamed(context, '/logs'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Icon(Icons.terminal, size: 22, color: AppThemeColors.primary(night)),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('日志终端', style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500,
                      color: AppThemeColors.title(night))),
                  Text('查看应用运行日志，含 StockFish 引擎诊断',
                      style: TextStyle(fontSize: 12, color: AppThemeColors.subtitle(night))),
                ],
              )),
              Icon(Icons.chevron_right, color: AppThemeColors.subtitle(night)),
            ]),
          ),
        ),
      ),
    );
  }
}
