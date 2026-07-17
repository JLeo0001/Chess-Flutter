import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'themes/app_theme.dart';
import 'models/theme_provider.dart';
import 'models/chess_engine_provider.dart';
import 'models/log_provider.dart';
import 'pages/menu_page.dart';
import 'pages/mode_page.dart';
import 'pages/game_page.dart';
import 'pages/cc_game_page.dart';
import 'pages/ic_game_page.dart';
import 'pages/tutorial_page.dart';
import 'pages/settings_page.dart';
import 'pages/about_page.dart';
import 'pages/log_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/engine_selection_page.dart';
import 'pages/poker_game_page.dart';
import 'pages/uno_game_page.dart';
import 'pages/doudizhu_game_page.dart';
import 'pages/go_game_page.dart';
import 'pages/spider_game_page.dart';
import 'widgets/theme_reveal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // 日志系统（持久化到文件）
  final lp = LogProvider.ensure();
  lp.init();

  // 拦截所有 debugPrint / 错误
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    lp.e('[FLUTTER]', '${details.exception}\\n${details.stack}');
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    lp.e('[PLATFORM]', '$error\\n$stack');
    return true;
  };
  final originalDebugPrint = debugPrint;
  debugPrint = (message, {wrapWidth}) {
    originalDebugPrint(message, wrapWidth: wrapWidth);
    final msg = message?.toString() ?? 'null';
    if (msg.length > 500) {
      lp.d('[APP]', '${msg.substring(0, 500)}...');
    } else {
      lp.d('[APP]', msg);
    }
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
        ChangeNotifierProvider(create: (_) => ChessEngineProvider()..load()),
        ChangeNotifierProvider.value(value: logProv),
      ],
      child: const ChessApp(),
    ),
  );
}

class ChessApp extends StatefulWidget {
  const ChessApp({super.key});

  @override
  State<ChessApp> createState() => _ChessAppState();
}

class _ChessAppState extends State<ChessApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  void _toggleTheme(BuildContext context) {
    final newMode = context.read<ThemeProvider>().toggleManual();
    final labels = {ThemeMode.light: '日间', ThemeMode.dark: '夜间', ThemeMode.system: '系统'};
    log('SETTINGS', '手动切换主题 → ${labels[newMode] ?? newMode}');
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return DynamicColorBuilder(
      builder: (lightScheme, darkScheme) {
        // 系统支持动态取色时更新全局色彩
        if (lightScheme != null && darkScheme != null) {
          AppThemeColors.updateFromDynamic(
            lightScheme: lightScheme,
            darkScheme: darkScheme,
          );
        }

        return MaterialApp(
          title: '弈',
          debugShowCheckedModeBanner: false,
          theme: lightScheme != null
              ? AppTheme.lightFromScheme(lightScheme)
              : AppTheme.lightTheme(),
          darkTheme: darkScheme != null
              ? AppTheme.darkFromScheme(darkScheme)
              : AppTheme.darkTheme(),
          themeMode: themeProvider.themeMode,
          initialRoute: '/onboarding',
          navigatorKey: _navigatorKey,
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/onboarding':
                return _page(const OnboardingPage());
              case '/':
                return _page(const MenuPage());
              case '/mode':
                final gameArg = settings.arguments is String
                    ? settings.arguments as String
                    : 'gobang';
                return _page(ModePage(gameType: gameArg));
              case '/game/gobang':
              case '/game/tictactoe':
                final args = settings.arguments as Map<String, dynamic>?;
                final isPvE = args?['mode'] == 'pve';
                final gameType = settings.name == '/game/gobang' ? 'gobang' : 'tictactoe';
                return _page(GamePage(gameType: gameType, isPvE: isPvE));
              case '/game/go':
                final goArgs = settings.arguments as Map<String, dynamic>?;
                return _page(GoGamePage(isPvE: goArgs?['mode'] == 'pve'));
              case '/game/chinese_chess':
                final ccArgs = settings.arguments as Map<String, dynamic>?;
                return _page(ChineseChessGamePage(isPvE: ccArgs?['mode'] == 'pve'));
              case '/game/international_chess':
                final icArgs = settings.arguments as Map<String, dynamic>?;
                return _page(InternationalChessGamePage(isPvE: icArgs?['mode'] == 'pve'));
              case '/tutorial':
                String gameType = 'gobang';
                if (settings.arguments is String) gameType = settings.arguments as String;
                return _page(TutorialPage(gameType: gameType));
              case '/settings':
                return _page(const SettingsPage());
              case '/about':
                return _page(const AboutPage());
              case '/logs':
                log('NAV', '日志终端');
                return _page(const LogPage());
              case '/engine_select':
                return _page(const EngineSelectionPage());
              case '/poker':
                final pokerArgs = settings.arguments as Map<String, dynamic>?;
                return _page(PokerGamePage(variant: pokerArgs?['variant'] as String? ?? 'draw'));
              case '/uno':
                final unoArgs = settings.arguments as Map<String, dynamic>?;
                return _page(UnoGamePage(playerCount: unoArgs?['players'] as int? ?? 2));
              case '/doudizhu':
                return _page(const DoudizhuGamePage());
              case '/spider':
                final spArgs = settings.arguments as Map<String, dynamic>?;
                return _page(SpiderGamePage(suitCount: spArgs?['suits'] as int? ?? 1));
              default:
                return _page(const MenuPage());
            }
          },
          builder: (context, child) {
            return ThemeRipple(
              key: ThemeRipple.globalKey,
              onToggleTheme: () => _toggleTheme(context),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }

  /// 页面路由 — 弹簧缓动滑入 + 淡入
  PageRouteBuilder _page(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: anim,
            curve: const Cubic(0.2, 1.0, 0.3, 1.0),
          )),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: anim,
              curve: const Interval(0, 0.5, curve: Curves.easeIn),
            ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
    );
  }
}
