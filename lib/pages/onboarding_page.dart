import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 引导页 — 使用 M3 组件
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_done') != true;
  }

  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
  }

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _currentPage = 0;
  bool _privacyAccepted = false;
  bool _checked = false;

  static const _pages = [
    _OnboardData(Icons.sports_esports, '弈',
        '多合一棋牌游戏\n五子棋 · 井字棋 · 中国象棋 · 国际象棋 · 围棋 · 中国跳棋\n换牌扑克 · 德州扑克 · UNO · 斗地主'),
    _OnboardData(Icons.smart_toy, '人机对战',
        '内置 AI 引擎\n从入门到精通，逐步挑战'),
    _OnboardData(Icons.group, '双人对弈',
        '与朋友面对面切磋\n享受对弈的乐趣'),
    _OnboardData(Icons.psychology, 'Stockfish 引擎',
        '国际象棋集成 Stockfish\n可自由选择引擎与配置参数'),
  ];

  void _finish() async {
    await OnboardingPage.markDone();
    if (mounted) Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!await OnboardingPage.shouldShow() && mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      } else if (mounted) {
        setState(() => _checked = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const Scaffold(body: SizedBox.shrink());
    final cs = Theme.of(context).colorScheme;
    final isLastPage = _currentPage == _pages.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (_currentPage < _pages.length)
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                    onPressed: _finish,
                    child: Text('跳过',
                        style: TextStyle(color: cs.onSurfaceVariant))),
              ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length + 1,
                itemBuilder: (_, index) {
                  if (index < _pages.length) {
                    return _featurePage(_pages[index], cs);
                  }
                  return _privacyPage(cs);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 页面指示器
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length + 1, (i) {
                      final active = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        width: active ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active ? cs.primary : cs.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: isLastPage
                        ? FilledButton(
                            onPressed: _privacyAccepted ? _finish : null,
                            child: const Text('开始使用',
                                style: TextStyle(fontSize: 16)),
                          )
                        : FilledButton(
                            onPressed: () => _controller.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            ),
                            child: const Text('下一步',
                                style: TextStyle(fontSize: 16)),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featurePage(_OnboardData data, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 56, color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: 48),
          Text(data.title,
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(data.subtitle,
              style: TextStyle(
                  fontSize: 16, height: 1.5, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _privacyPage(ColorScheme cs) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
              color: cs.primaryContainer, shape: BoxShape.circle),
          child: Icon(Icons.shield_outlined,
              size: 40, color: cs.onPrimaryContainer),
        ),
        const SizedBox(height: 24),
        Text('隐私与协议',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: cs.onSurface)),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: SingleChildScrollView(
              child: Text(
                '欢迎使用 弈（以下简称"本应用"）。\n\n'
                '一、信息收集\n'
                '本应用是一款完全离线的本地棋类游戏，不收集、不存储、不上传任何用户的个人信息。'
                '包括但不限于：\n'
                '• 不收集您的姓名、邮箱、电话号码\n'
                '• 不收集您的位置信息\n'
                '• 不收集您的设备信息\n'
                '• 不收集您的使用习惯或行为数据\n\n'
                '二、数据存储\n'
                '本应用产生的所有数据（包括但不限于游戏记录、主题偏好设置）'
                '均存储在您的设备本地，不会上传至任何服务器。\n\n'
                '三、网络使用\n'
                '本应用在正常使用过程中不需要网络连接。\n\n'
                '四、第三方服务\n'
                '本应用不集成任何第三方分析、广告或追踪 SDK。\n\n'
                '五、开源许可\n'
                '本应用基于 Flutter 框架开发，遵循 MIT 开源许可协议。\n\n'
                '六、免责声明\n'
                '本应用提供的 AI 对战功能仅供娱乐，不保证棋力的准确性。\n\n'
                '使用本应用即表示您已阅读、理解并同意上述所有条款。',
                style: TextStyle(
                    fontSize: 13, height: 1.7, color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(children: [
            Checkbox(
              value: _privacyAccepted,
              onChanged: (v) => setState(() => _privacyAccepted = v ?? false),
              activeColor: cs.primary,
            ),
            Expanded(
                child: Text('我已阅读并同意隐私政策',
                    style: TextStyle(color: cs.onSurface))),
          ]),
        ),
      ],
    );
  }
}

class _OnboardData {
  final IconData icon;
  final String title, subtitle;
  const _OnboardData(this.icon, this.title, this.subtitle);
}
