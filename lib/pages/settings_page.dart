import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chess_engine_provider.dart';
import '../models/theme_provider.dart';
import '../models/log_provider.dart';

/// 设置页面 — 使用 M3 ListTile + Card
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themeProvider = context.watch<ThemeProvider>();
    final followSystem = themeProvider.followSystem;
    final engineProv = context.watch<ChessEngineProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('显示', style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: cs.primary,
          )),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              SwitchListTile(
                title: const Text('跟随系统'),
                subtitle: Text(followSystem ? '自动跟随系统主题' : '手动切换日/夜模式'),
                value: followSystem,
                onChanged: (v) async {
                  await themeProvider.setFollowSystem(v);
                  log('SETTINGS', '跟随系统主题 → $v');
                },
              ),
              if (!followSystem)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.tertiaryContainer.withAlpha(60),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Icon(Icons.lightbulb_outline, size: 16, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '提示：可在主页用 🌙/☀️ 按钮随时切换模式',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 24),
          Text('游戏', style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: cs.primary,
          )),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.extension, color: cs.primary),
              title: const Text('选择国际象棋引擎'),
              subtitle: Text(engineProv.displayName,
                  style: TextStyle(color: cs.onSurfaceVariant)),
              trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              onTap: () => Navigator.pushNamed(context, '/engine_select'),
            ),
          ),
          const SizedBox(height: 24),
          Text('其他', style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: cs.primary,
          )),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.info_outline, color: cs.primary),
              title: const Text('关于'),
              trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              onTap: () => Navigator.pushNamed(context, '/about'),
            ),
          ),
        ],
      ),
    );
  }
}
