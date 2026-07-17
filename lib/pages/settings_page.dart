import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chess_engine_provider.dart';
import '../models/theme_provider.dart';
import '../models/log_provider.dart';
import '../themes/app_theme.dart';

/// 设置页面 — 1:1 移植自 SettingsActivity.java
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();
    final followSystem = themeProvider.followSystem;
    final engineProv = context.watch<ChessEngineProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                  color: AppThemeColors.primary(night),
                ),
                const SizedBox(width: 8),
                Text('设置', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppThemeColors.title(night))),
              ]),
            ),
            Divider(color: AppThemeColors.divider(night)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('显示', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppThemeColors.primary(night))),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppThemeColors.divider(night), width: 1),
                ),
                color: AppThemeColors.highlight(night),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final newVal = !followSystem;
                    await themeProvider.setFollowSystem(newVal);
                    log('SETTINGS', '跟随系统主题 → $newVal');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('跟随系统', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppThemeColors.title(night))),
                            const SizedBox(height: 4),
                            Text(followSystem ? '自动跟随系统主题' : '手动切换日/夜模式',
                                style: TextStyle(fontSize: 14, color: AppThemeColors.subtitle(night))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: followSystem ? AppThemeColors.filledBtn(night) : const Color(0xFF79747E),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(followSystem ? 'ON' : 'OFF',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                                color: followSystem ? AppThemeColors.filledBtnText(night) : Colors.white)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            if (!followSystem)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppThemeColors.divider(night), width: 1),
                  ),
                  color: AppThemeColors.highlight(night),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Text('💡', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('提示：可在主页用 🌙/☀️ 按钮随时切换模式',
                            style: TextStyle(fontSize: 13, color: AppThemeColors.subtitle(night))),
                      ),
                    ]),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('游戏', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppThemeColors.primary(night))),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppThemeColors.divider(night), width: 1),
                ),
                color: AppThemeColors.highlight(night),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.pushNamed(context, '/engine_select'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('选择国际象棋引擎', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppThemeColors.title(night))),
                            const SizedBox(height: 4),
                            Text(engineProv.displayName,
                                style: TextStyle(fontSize: 14, color: AppThemeColors.subtitle(night))),
                          ],
                        ),
                      ),
                      Text('▸', style: TextStyle(fontSize: 20, color: AppThemeColors.primary(night))),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('其他', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppThemeColors.primary(night))),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppThemeColors.divider(night), width: 1),
                ),
                color: AppThemeColors.highlight(night),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.pushNamed(context, '/about'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Expanded(
                        child: Text('关于', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppThemeColors.title(night))),
                      ),
                      Text('▸', style: TextStyle(fontSize: 20, color: AppThemeColors.primary(night))),
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


