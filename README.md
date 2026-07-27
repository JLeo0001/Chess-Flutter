<div align="center">

# ♔ 弈 — Chess-Flutter

> 多合一棋牌游戏 · 10 种经典玩法 · 内置 AI · 日夜主题 · 全平台

<p align="center">
  <img src="https://img.shields.io/github/actions/workflow/status/JLeo0001/Chess-Flutter/build.yml?branch=main&label=CI&logo=github&style=flat-square" alt="CI"/>
  <img src="https://img.shields.io/github/v/release/JLeo0001/Chess-Flutter?label=version&logo=flutter&style=flat-square" alt="Release"/>
  <img src="https://img.shields.io/badge/Flutter-3.27-02569B?logo=flutter&logoColor=white&style=flat-square" alt="Flutter"/>
  <img src="https://img.shields.io/badge/license-MIT-yellow?style=flat-square" alt="MIT"/>
  <br>
  <img src="https://img.shields.io/badge/Android-8%2B-34A853?logo=android&logoColor=white&style=flat-square" alt="Android 8+"/>
  <img src="https://img.shields.io/badge/iOS-13%2B-000000?logo=apple&logoColor=white&style=flat-square" alt="iOS 13+"/>
  <img src="https://img.shields.io/badge/Web-PWA-4285F4?logo=googlechrome&logoColor=white&style=flat-square" alt="Web PWA"/>
  <img src="https://img.shields.io/badge/Windows-10%2B-0078D6?logo=windows&logoColor=white&style=flat-square" alt="Windows 10+"/>
  <img src="https://img.shields.io/badge/Linux-GTK3-E95420?logo=linux&logoColor=white&style=flat-square" alt="Linux"/>
  <img src="https://img.shields.io/badge/macOS-12%2B-000000?logo=apple&logoColor=white&style=flat-square" alt="macOS 12+"/>
</p>

<p align="center">
  <a href="#-下载">📥 下载</a> ·
  <a href="#-游戏一览">🎮 游戏</a> ·
  <a href="#-核心特性">✨ 特性</a> ·
  <a href="#-技术栈">⚙️ 技术</a> ·
  <a href="#-开发指南">🚀 开发</a> ·
  <a href="#-项目结构">📁 结构</a> ·
  <a href="#-贡献">🤝 贡献</a>
</p>

</div>

---

## 📥 下载

### Android

| 架构 | 文件 | 适用设备 | 推荐 |
|:---|:---|---|---:|
| **arm64-v8a** | `Chess-Flutter-*-arm64.apk` | 2016年后安卓手机 | ⭐ **首选** |
| armeabi-v7a | `Chess-Flutter-*-arm32.apk` | 老旧安卓手机 | |
| x86_64 | `Chess-Flutter-*-x86_64.apk` | 模拟器 / Chromebook | |
| universal | `Chess-Flutter-*-universal.apk` | 所有设备（体积最大） | |

<p align="center">
  <a href="https://github.com/JLeo0001/Chess-Flutter/releases/latest">
    <img src="https://img.shields.io/badge/⬇_下载最新_APK-34A853?style=for-the-badge&logo=android&logoColor=white" alt="Download APK"/>
  </a>
</p>

> 💡 推荐下载 **arm64-v8a** 版本（体积更小、速度更快）。如果安装失败请使用 universal 版本。

### 其他平台

| 平台 | 构建产物 | 获取方式 |
|:---|:---|---:|
| 🌐 **Web (PWA)** | `Chess-Flutter-*-web.zip` | CI artifact，解压部署到任意静态服务器 |
| 🐧 **Linux** | `*-x86_64.AppImage` / `*.deb` / `*.tar.gz` | **AppImage**: 双击运行 · **deb**: `sudo dpkg -i` · **tar.gz**: 解压运行 |
| 🪟 **Windows** | `Chess-Flutter-*-windows-x64.zip` | 解压 → 运行 `chess_app.exe` |
| 🍎 **macOS** | `弈-*-macos.dmg` | 双击 → 拖到 Applications 文件夹 |
| 📱 **iOS** | `弈-*-ios.ipa`（unsigned，需签名安装） | CI artifact 或本地构建（需 Apple Developer 账号） |

> 所有平台的构建产物均可从 **[GitHub Actions](https://github.com/JLeo0001/Chess-Flutter/actions)** 的 CI artifact 下载。  
> 正式发布版本见 **[GitHub Releases](https://github.com/JLeo0001/Chess-Flutter/releases)**。

---

## 🎮 游戏一览

| | 游戏 | 类型 | 模式 | AI 强度 | 特色 |
|:---:|:---|:---:|:---:|:---:|:---|
| ♟️ | **国际象棋** | 棋类 | 🤖 人机 · 👥 双人 | ⭐⭐⭐⭐⭐ | **云端 StockFish 引擎**（LiChess API） |
| ⚫ | **围棋** | 棋类 | 🤖 人机 · 👥 双人 | ⭐⭐⭐⭐ | 混合启发式引擎 · 中国规则数子 |
| 🏯 | **中国象棋** | 棋类 | 🤖 人机 · 👥 双人 | ⭐⭐⭐⭐ | Alpha-Beta 搜索 · 历史启发 |
| ⚪ | **五子棋** | 棋类 | 🤖 人机 · 👥 双人 | ⭐⭐⭐ | 棋型评分 · 启发式搜索 |
| ❌ | **井字棋** | 棋类 | 🤖 人机 · 👥 双人 | ⭐⭐⭐ | Minimax · 必不败策略 |
| 🃏 | **斗地主** | 牌类 | 🤖 1v2 人机 | ⭐⭐⭐⭐ | 叫地主 · 炸弹 · 火箭 · 飞机 |
| 🎯 | **德州扑克** | 牌类 | 🤖 人机 | ⭐⭐⭐ | 7选5 牌型评估 |
| ♠️ | **换牌扑克** | 牌类 | 🤖 人机 | ⭐⭐⭐ | 5 张抽换 |
| 🌈 | **UNO** | 牌类 | 🤖 人机 | ⭐⭐⭐ | 标准规则 · 功能牌动画 |
| 🕷️ | **蜘蛛纸牌** | 牌类 | 👤 单人 | ⭐⭐ | 三难度 · 单/双/四色 |

---

## ✨ 核心特性

### 🧠 国际象棋：云端 StockFish 引擎

国际象棋每步调用 **LiChess Cloud Eval API**，使用世界最强开源引擎 StockFish 在线分析局面：

- 🌐 **有网络时** → 云端 StockFish 分析（depth 20+），走法精准
- 📴 **无网络 →** 自动回退内置 AI（深度 4），不影响游戏
- 🔄 **每步独立** — 不锁定，有网就用云，没网就本地

其他 9 款游戏均使用 **纯 Dart 内置 AI 引擎**，完全离线可用。

### 🎨 视觉体验

| 特性 | 说明 |
|:---|:---|
| 🌓 **日夜主题** | 一键切换，800ms 圆形扩散波纹动画（Pixel-like） |
| 🎨 **Material You** | 自适应系统主题色（Android 12+） |
| 🃏 **卡牌动画** | 发牌、翻牌、出牌流畅过渡 |
| 💣 **特效反馈** | 炸弹、火箭、UNO 功能牌动画 |
| 🖼️ **自适应图标** | 跟随系统主题形状（Android 13+） |

### 🎯 游戏体验

- 📖 **内置教程** — 全部 10 款游戏都有从零开始的详细图文教程
- 👥 **双人对弈** — 五子棋、井字棋、中国象棋、国际象棋、围棋支持双人同屏
- 🤖 **AI 多级难度** — 从新手到高手均可对战
- 📝 **完整日志系统** — 调试信息持久化，支持搜索与导出

---

## ⚙️ 技术栈

| 领域 | 技术 |
|:---|:---|
| **框架** | Flutter 3.27 · Dart 3.5+ |
| **设计语言** | Material Design 3 · Dynamic Color |
| **状态管理** | Provider |
| **持久化** | SharedPreferences · 文件日志系统 |
| **国际象棋** | dartchess · chessground · LiChess Cloud Eval API |
| **牌类引擎** | poker_solver · card_game |
| **日夜切换** | Custom CircularReveal (800ms) |
| **CI/CD** | GitHub Actions（6 平台并行构建） |
| **最低支持** | Android 8.0 · iOS 13.0 · Windows 10 · macOS 12 · Linux GTK3 |

### 跨平台架构

```
┌─────────────────────────────────────────────────────┐
│                      Dart UI Code                    │
│    (lib/ — 100% shared, no platform-specific code)  │
├──────────┬──────────┬──────┬──────┬──────┬──────────┤
│ Android  │   iOS    │ Web  │Win   │Linux │  macOS   │
│  (Kotlin) │ (Swift)  │(HTML)│(C++) │(C++) │ (Swift)  │
└──────────┴──────────┴──────┴──────┴──────┴──────────┘
```

---

## 🚀 开发指南

### 前置条件

```bash
# 安装 Flutter
# 详见 https://docs.flutter.dev/get-started/install

# 验证
flutter doctor
```

### 快速开始

```bash
# 克隆
git clone https://github.com/JLeo0001/Chess-Flutter.git
cd Chess-Flutter

# 安装依赖
flutter pub get

# 运行（自动检测平台）
flutter run
```

### 构建发布

| 平台 | 命令 | 额外要求 |
|:---|:---|---:|
| **Android** | `flutter build apk --release --split-per-abi` | — |
| **iOS** | `cd ios && pod install && cd .. && flutter build ios --release --no-codesign` | macOS + Xcode |
| **Web** | `flutter build web --release` | — |
| **Windows** | `flutter build windows --release` | Visual Studio 2022 |
| **Linux** | `flutter build linux --release` | `cmake ninja-build libgtk-3-dev` |
| **macOS** | `flutter build macos --release` | macOS + Xcode |

### Docker 构建（Linux / Web）

```bash
docker run --rm -v $PWD:/app -w /app ghcr.io/cirruslabs/flutter:3.27 \
  sh -c "flutter pub get && flutter build web --release"
```

---

## 🤖 AI 技术一览

| 游戏 | AI 算法 | 搜索深度 | 说明 |
|:---|:---|:---:|:---|
| 国际象棋 (云) | LiChess Cloud Eval (StockFish) | depth 20+ | 云端分析，免费无需注册 |
| 国际象棋 (本地) | Alpha-Beta + 历史启发 + 杀手走法 | 4 | 无网络自动回退 |
| 中国象棋 | Alpha-Beta + 空着搜索 + 将军延伸 | 5 | MVV-LVA 走法排序 |
| 围棋 | 四层混合启发式引擎 | — | 基础评估 + 形状连接 + 领地判断 + 危机反应 |
| 五子棋 | 棋型评分 + 启发式搜索 | — | 连五/活四/冲四/活三 多维评分 |
| 井字棋 | Minimax | 全部 | 必不败策略 |
| 斗地主 | 手牌分析 + 出牌策略 | — | 叫地主 / 拆牌 / 顶牌 AI |
| 德州扑克 | 牌型评估 + 下注决策 | — | 7选5 最优组合 |
| UNO | 智能出牌策略 | — | 功能牌优先级 |
| 蜘蛛纸牌 | — | — | 纯操作，无 AI 对手 |

---

## 📄 项目结构

```
Chess-Flutter/
├── lib/                              # Dart 源码（100% 跨平台）
│   ├── main.dart                     # 应用入口
│   ├── themes/                       # 主题系统（日夜模式）
│   ├── models/                       # 状态管理（日志/主题/引擎）
│   ├── pages/                        # UI 页面
│   │   ├── menu_page.dart            # 主菜单
│   │   ├── mode_page.dart            # 模式选择
│   │   ├── game_shell.dart           # 共享游戏容器组件
│   │   ├── game_page.dart            # 五子棋 / 井字棋
│   │   ├── cc_game_page.dart         # 中国象棋
│   │   ├── ic_game_page.dart         # 国际象棋（含 LiChess 云端）
│   │   ├── go_game_page.dart         # 围棋
│   │   ├── poker_game_page.dart      # 扑克
│   │   ├── uno_game_page.dart        # UNO
│   │   ├── spider_game_page.dart     # 蜘蛛纸牌
│   │   ├── doudizhu_game_page.dart   # 斗地主
│   │   └── tutorial_page.dart        # 教程页
│   ├── {gobang,tictactoe,...}/        # 各游戏逻辑 + AI
│   ├── widgets/                      # 通用 UI 组件
│   └── third_party/                  # 第三方移植组件
├── android/                          # Android 原生层
├── ios/                              # iOS 原生层
├── web/                              # Web PWA 配置
├── windows/                          # Windows 原生层
├── linux/                            # Linux 原生层
├── macos/                            # macOS 原生层
├── test/                             # 单元测试
├── scripts/                          # 构建脚本
└── .github/workflows/                # CI/CD（6 平台自动构建）
```

---

## 🤝 贡献

欢迎 Issue 和 PR！无论是新游戏、AI 改进、UI 优化还是文档修正。

```bash
# 1. Fork 本仓库
# 2. 创建特性分支
git checkout -b feat/my-feature

# 3. 确保代码通过分析
flutter analyze

# 4. 提交
git commit -m 'feat: add my feature'
git push origin feat/my-feature

# 5. 创建 Pull Request
```

### 开发约定

- **分支命名**: `feat/xxx`, `fix/xxx`, `docs/xxx`, `refactor/xxx`
- **提交信息**: [Conventional Commits](https://www.conventionalcommits.org/) 风格
- **代码风格**: 遵循 `flutter_lints` 推荐规则
- **测试**: 新逻辑尽量附带单元测试

---

## 📜 许可证

[MIT License](LICENSE) © 2026 JasonLeoZhou

---

<p align="center">
  <a href="https://github.com/JLeo0001/Chess-Flutter">
    <img src="https://img.shields.io/badge/GitHub-JLeo0001/Chess--Flutter-181717?logo=github&style=for-the-badge" alt="GitHub"/>
  </a>
  <a href="https://github.com/JLeo0001/Chess-Flutter/issues">
    <img src="https://img.shields.io/badge/🐛_反馈问题-FF6B6B?style=for-the-badge" alt="Issues"/>
  </a>
  <a href="https://github.com/JLeo0001/Chess-Flutter/releases">
    <img src="https://img.shields.io/badge/📦_下载_APK-34A853?style=for-the-badge" alt="Releases"/>
  </a>
</p>

<p align="center"><sub>Made with ❤️, ☕, and <a href="https://flutter.dev">Flutter</a></sub></p>
