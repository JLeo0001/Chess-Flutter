import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../themes/app_theme.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  /// 检查是否需要展示引导页
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_done') != true;
  }

  /// 标记引导页已完成
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
    _OnboardData(
      icon: Icons.sports_esports,
      title: '弈',
      subtitle: '多合一棋牌游戏\n五子棋 · 井字棋 · 中国象棋 · 国际象棋 · 围棋\n换牌扑克 · 德州扑克 · UNO · 斗地主',    ),
    _OnboardData(
      icon: Icons.smart_toy,
      title: '人机对战',
      subtitle: '内置 AI 引擎\n从入门到精通，逐步挑战',    ),
    _OnboardData(
      icon: Icons.group,
      title: '双人对弈',
      subtitle: '与朋友面对面切磋\\n享受对弈的乐趣',    ),
    _OnboardData(
      icon: Icons.psychology,
      title: 'Stockfish 引擎',
      subtitle: '国际象棋集成 Stockfish\n可自由选择引擎与配置参数',    ),
  ];

  void _finish() async {
    await OnboardingPage.markDone();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
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
    final night = Theme.of(context).brightness == Brightness.dark;
    final isLastPage = _currentPage == _pages.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 跳过按钮
            if (_currentPage < _pages.length)
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _finish,
                  child: Text('跳过', style: TextStyle(color: AppThemeColors.subtitle(night))),
                ),
              ),
            // 页面内容
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length + 1, // +1 for privacy
                itemBuilder: (context, index) {
                  if (index < _pages.length) {
                    return _buildFeaturePage(_pages[index], night);
                  }
                  return _buildPrivacyPage(night);
                },
              ),
            ),
            // 底部：指示器 + 按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 页面指示器（居中）
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
                          color: active
                              ? AppThemeColors.primary(night)
                              : AppThemeColors.divider(night),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  // 按钮
                  SizedBox(
                    width: double.infinity,
                    child: isLastPage
                        ? FilledButton(
                            onPressed: _privacyAccepted ? _finish : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppThemeColors.filledBtn(night),
                              foregroundColor: AppThemeColors.filledBtnText(night),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(80)),
                            ),
                            child: const Text('开始使用', style: TextStyle(fontSize: 16)),
                          )
                        : FilledButton(
                            onPressed: () => _controller.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppThemeColors.filledBtn(night),
                              foregroundColor: AppThemeColors.filledBtnText(night),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(80)),
                            ),
                            child: const Text('下一步', style: TextStyle(fontSize: 16)),
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

  Widget _buildFeaturePage(_OnboardData data, bool night) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppThemeColors.highlight(night),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 56, color: AppThemeColors.primary(night)),
          ),
          const SizedBox(height: 48),
          Text(
            data.title,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppThemeColors.title(night)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            data.subtitle,
            style: TextStyle(fontSize: 16, height: 1.5, color: AppThemeColors.subtitle(night)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPage(bool night) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: AppThemeColors.highlight(night), shape: BoxShape.circle),
          child: Icon(Icons.shield_outlined, size: 40, color: AppThemeColors.primary(night)),
        ),
        const SizedBox(height: 24),
        Text('隐私与协议', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppThemeColors.title(night))),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppThemeColors.highlight(night),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemeColors.divider(night)),
            ),
            child: SingleChildScrollView(
              child: Text(
                '欢迎使用 弈（以下简称"本应用"）。\n\n'
                '一、信息收集\n'
                '本应用是一款完全离线的本地棋类游戏，不收集、不存储、不上传任何用户的个人信息。包括但不限于：\n'
                '• 不收集您的姓名、邮箱、电话号码\n'
                '• 不收集您的位置信息\n'
                '• 不收集您的设备信息\n'
                '• 不收集您的使用习惯或行为数据\n\n'
                '二、数据存储\n'
                '本应用产生的所有数据（包括但不限于游戏记录、主题偏好设置）均存储在您的设备本地，不会上传至任何服务器。\n'
                '• 主题偏好：存储在本地 SharedPreferences\n'
                '• 首次使用标记：存储在本地 SharedPreferences\n\n'
                '三、网络使用\n'
                '本应用在正常使用过程中不需要网络连接。仅在以下情况可能需要网络：\n'
                '• 从应用商店下载或更新应用\n\n'
                '四、第三方服务\n'
                '本应用不集成任何第三方分析、广告或追踪 SDK。不包含任何形式的广告。\n\n'
                '五、开源许可\n'
                '本应用基于 Flutter 框架开发，遵循 MIT 开源许可协议。\n'
                '源代码地址：https://github.com/JLeo0001/Chess-Flutter\n\n'
                '六、免责声明\n'
                '本应用提供的 AI 对战功能仅供娱乐，不保证棋力的准确性。\n'
                '开发者不对因使用本应用而产生的任何损失承担责任。\n\n'
                '七、联系我们\n'
                '如有任何问题或建议，请通过 GitHub Issues 联系开发者。\n\n'
                '使用本应用即表示您已阅读、理解并同意上述所有条款。',
                style: TextStyle(fontSize: 13, height: 1.7, color: AppThemeColors.subtitle(night)),
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
              activeColor: AppThemeColors.primary(night),
            ),
            Expanded(child: Text('我已阅读并同意隐私政策', style: TextStyle(color: AppThemeColors.title(night)))),
          ]),
        ),
      ],
    );
  }
}

class _OnboardData {
  final IconData icon;
  final String title;
  final String subtitle;
  const _OnboardData({required this.icon, required this.title, required this.subtitle});
}
