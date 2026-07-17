<div align="center">

# ♔ 弈 — Chess-Flutter

> 多合一棋牌游戏 · 10 种经典玩法 · 内置 AI · 日夜主题

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.27-02569B?logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/version-1.0.0-blue" alt="v1.0.0"/>
  <img src="https://img.shields.io/badge/Android-8%2B-34A853?logo=android&logoColor=white" alt="Android 8+"/>
  <img src="https://img.shields.io/badge/license-MIT-yellow" alt="MIT"/>
  <img src="https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Linux%20%7C%20Windows%20%7C%20macOS-blue" alt="Platform"/>
</p>

</div>

---

## 📥 下载

| 版本 | 文件 | 架构 | 大小 |
|:---|:---|:---|:---|
| **最新版** | `Chess-Flutter-universal.apk` | 通用（所有设备） | ~40 MB |
| | `Chess-Flutter-arm64-v8a.apk` | 现代安卓手机 (2016+) | ~35 MB |
| | `Chess-Flutter-armeabi-v7a.apk` | 老旧安卓手机 | ~32 MB |
| | `Chess-Flutter-x86_64.apk` | 模拟器 / Chromebook | ~35 MB |

> 📲 前往 **[GitHub Releases](https://github.com/JLeo0001/Chess-Flutter/releases)** 下载最新 APK。
> 推荐下载 `arm64-v8a` 版本（更小更快），如果安装失败请用 `universal` 版本。

---

## 🎮 游戏一览

| | 游戏 | 类型 | 模式 | AI 强度 | 特色 |
|:---:|:---|:---:|:---:|:---:|:---|
| ♟️ | **国际象棋** | 棋类 | 🤖 人机 · 👥 双人 | ⭐⭐⭐⭐⭐ | **云端 StockFish 引擎**（LiChess API） |
| ⚫ | **围棋** | 棋类 | 🤖 人机 · 👥 双人 | ⭐⭐⭐⭐ | 混合启发式引擎·中国规则数子 |
| 🏯 | **中国象棋** | 棋类 | 🤖 人机 · 👥 双人 | ⭐⭐⭐⭐ | Alpha-Beta 搜索·历史启发 |
| ⚪ | **五子棋** | 棋类 | 🤖 人机 · 👥 双人 | ⭐⭐⭐ | 棋型评分·启发式搜索 |
| ❌ | **井字棋** | 棋类 | 🤖 人机 · 👥 双人 | ⭐⭐⭐ | Minimax·必不败策略 |
| 🃏 | **斗地主** | 牌类 | 🤖 1v2 人机 | ⭐⭐⭐⭐ | 叫地主·炸弹·火箭·飞机 |
| 🎯 | **德州扑克** | 牌类 | 🤖 人机 | ⭐⭐⭐ | 7选5 牌型评估 |
| ♠️ | **换牌扑克** | 牌类 | 🤖 人机 | ⭐⭐⭐ | 5 张抽换 |
| 🌈 | **UNO** | 牌类 | 🤖 人机 | ⭐⭐⭐ | 标准规则·功能牌动画 |
| 🕷️ | **蜘蛛纸牌** | 牌类 | 👤 单人 | ⭐⭐ | 三难度·单/双/四色 |

---

## ✨ 核心特性

### 🧠 国际象棋：云端 StockFish 引擎

国际象棋联机时每步调用 **LiChess Cloud Eval API**，使用世界最强开源引擎 StockFish 在线分析局面：

- 🌐 **有网络时** → 云端 StockFish 分析（depth 20+），走法精准
- 📴 **无网络 / 无缓存** → 自动回退内置 AI（深度 4），不影响游戏
- 🔄 **每步独立** — 不锁定，有网就用云，没网就本地

其他 9 款游戏均使用**内置 AI 引擎**，无需网络。

### 🎨 视觉体验

- 🌓 **日夜主题** — 一键切换，800ms 波纹动画
- 🃏 **卡牌动画** — 发牌、翻牌、出牌流畅过渡
- 💣 **特效反馈** — 炸弹、火箭、UNO 功能牌动画
- 🎨 **Material You 设计** — 自适应主题色
- 🖼️ **自适应图标** — 跟随系统主题形状

### 🎯 游戏体验

- 📖 **内置教程** — 全部 10 款游戏都有从零开始的详细图文教程
- 👥 **双人对弈** — 五子棋、井字棋、中国象棋、国际象棋、围棋支持双人同屏
- 🤖 **AI 多级难度** — 从新手到高手均可对战

### ⚙️ 技术规格

- 🔧 **纯 Dart 实现** — 全量 AI 逻辑用 Dart 编写，不含原生二进制
- 📦 **轻盈体积** — APK 仅 ~16-40 MB（去除了 StockFish 本地引擎）
- 🌍 **跨平台架构** — Android / iOS / Linux / Windows / macOS
- 🔄 **CI/CD** — GitHub Actions 自动构建多架构 APK

---

## 🚀 安装与运行

### 普通用户（一键安装）

1. 从 **[Releases](https://github.com/JLeo0001/Chess-Flutter/releases)** 下载 APK
2. 在手机上打开 APK 文件安装
3. 首次打开需允许「安装未知来源应用」

### 开发者（本地运行）

```bash
# 克隆
git clone https://github.com/JLeo0001/Chess-Flutter.git
cd Chess-Flutter

# 环境要求
# Flutter ≥ 3.27 · Dart ≥ 3.5

# 安装依赖
flutter pub get

# 运行
flutter run

# 构建 APK
flutter build apk --release           # 通用 APK
flutter build apk --release --split-per-abi  # 分架构 APK
```

---

## 📸 截图

<!-- 在此添加应用截图 -->
<!-- ![主菜单](screenshots/menu.png) -->
<!-- ![国际象棋](screenshots/chess.png) -->
<!-- ![围棋](screenshots/go.png) -->
<!-- ![斗地主](screenshots/doudizhu.png) -->

> 🖼️ 截图后续补充 — 欢迎贡献！

---

## 📱 支持设备

| 要求 | 说明 |
|:---|:---|
| **Android** | 8.0 (Oreo) 及以上 |
| **存储** | 约 80 MB 安装空间 |
| **网络** | 国际象棋云 AI 需要网络；其他游戏完全离线可用 |
| **权限** | 无需特殊权限 |

---

## 🤖 AI 技术一览

| 游戏 | AI 算法 | 搜索深度 | 说明 |
|:---|:---|:---:|:---|
| 国际象棋 (云) | LiChess Cloud Eval (StockFish) | depth 20+ | 云端分析，免费无需注册 |
| 国际象棋 (本地) | Alpha-Beta + 历史启发 + 杀手走法 | 4 | 无网络自动回退 |
| 中国象棋 | Alpha-Beta + 空着搜索 + 将军延伸 | 5 | MVV-LVA 走法排序 |
| 围棋 | 四层混合启发式引擎 | — | 基础评估 + 形状连接 + 领地厚薄 + 危机反应 |
| 五子棋 | 棋型评分 + 启发式搜索 | — | 连五/活四/冲四/活三 多维评分 |
| 井字棋 | Minimax | 全部 | 必不败策略 |
| 斗地主 | 手牌分析 + 出牌策略 | — | 叫地主 / 拆牌 / 顶牌 AI |
| 德州扑克 | 牌型评估 + 下注决策 | — | 7选5 最优组合 |
| UNO | 智能出牌策略 | — | 功能牌优先级 |

---

## 📄 项目结构

```
Chess-Flutter/
├── lib/
│   ├── main.dart                  # 应用入口
│   ├── themes/                    # 主题系统（日夜模式）
│   ├── pages/                     # UI 页面
│   │   ├── menu_page.dart         # 主菜单
│   │   ├── mode_page.dart         # 模式选择
│   │   ├── game_page.dart         # 五子棋 / 井字棋
│   │   ├── cc_game_page.dart      # 中国象棋
│   │   ├── ic_game_page.dart      # 国际象棋（含 LiChess 云端）
│   │   ├── go_game_page.dart      # 围棋
│   │   ├── poker_game_page.dart   # 扑克
│   │   ├── uno_game_page.dart     # UNO
│   │   ├── spider_game_page.dart  # 蜘蛛纸牌
│   │   ├── doudizhu_game_page.dart# 斗地主
│   │   └── tutorial_page.dart     # 教程页
│   ├── gobang/                    # 五子棋逻辑 + AI
│   ├── tictactoe/                 # 井字棋逻辑 + AI
│   ├── chinese_chess/             # 中国象棋逻辑 + AI
│   ├── international_chess/       # 国际象棋逻辑 + AI + LiChess API
│   ├── go/                        # 围棋逻辑 + AI
│   ├── poker/                     # 扑克引擎
│   ├── uno/                       # UNO 引擎
│   ├── spider/                    # 蜘蛛纸牌引擎
│   ├── doudizhu/                  # 斗地主引擎
│   └── widgets/                   # 通用 UI 组件
├── android/                       # Android 原生层
├── ios/                           # iOS 原生层
└── scripts/                       # 构建脚本
```

---

## 🤝 贡献

欢迎 Issue 和 PR！

1. 🍴 Fork 本仓库
2. 🌿 创建特性分支 (`git checkout -b feat/xxx`)
3. 💾 提交更改 (`git commit -m 'feat: xxx'`)
4. 📤 推送到分支 (`git push origin feat/xxx`)
5. 🔀 创建 Pull Request

---

## 📜 许可证

[MIT License](LICENSE) © 2026 JasonLeoZhou

---

<p align="center">
  <a href="https://github.com/JLeo0001/Chess-Flutter">GitHub</a>
  ·
  <a href="https://github.com/JLeo0001/Chess-Flutter/issues">反馈问题</a>
  ·
  <a href="https://github.com/JLeo0001/Chess-Flutter/releases">下载 APK</a>
</p>
<p align="center"><sub>Made with ❤️ & Flutter</sub></p>
