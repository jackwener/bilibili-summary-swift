# BiliSummary (iOS)

Bilibili 视频 AI 总结器 — iOS 原生客户端，使用 SwiftUI 构建。

> 🐍 Python 桌面版：[bilibili-summary](https://github.com/jackwener/bilibili-summary)

## Features

- **视频总结**：粘贴 Bilibili URL，AI 自动生成结构化笔记
- **UP 主批量**：输入 UID 或用户名，批量总结最新视频（12 并发）
- **收藏夹管理**：WebView 扫码登录，加载收藏夹，一键批量总结
- **总结浏览**：Markdown 原生渲染，分类浏览所有总结
- **ASR 兜底**：无字幕视频自动触发语音转文字流程
- **字幕保存**：自动生成 ASS 字幕文件

## Stack

- **UI**：SwiftUI + iOS 18
- **B 站集成**：原生 HTTP API + WBI 签名
- **AI 总结**：Anthropic-compatible API（智谱 GLM / Claude）
- **项目管理**：XcodeGen (`project.yml`)
- **存储**：UserDefaults（设置）+ 文件系统（总结 / 字幕）

## Quick Start

### 前置条件

- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)：`brew install xcodegen`

### 构建运行

```bash
# 生成 Xcode 项目
xcodegen generate

# 命令行构建
xcodebuild -scheme BiliSummary -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# 或直接用 Xcode 打开
open BiliSummary.xcodeproj
```

### 配置

1. 运行 App → 设置 Tab
2. 填写 **API Base URL**（如 `https://open.bigmodel.cn/api/anthropic`）
3. 填写 **Auth Token**
4. 模型默认 `GLM-4-FlashX-250414`，可点击"获取模型列表"自动发现

## Project Layout

```text
BiliSummary/
├── App/                # 入口 + TabView
├── Models/             # 数据模型 (VideoInfo, Subtitle, Summary...)
├── Services/           # 业务逻辑
│   ├── AIService       # AI API 调用 (Anthropic Messages API)
│   ├── BilibiliAPI     # B站 API 客户端
│   ├── BilibiliAuth    # 登录 + Cookie 管理
│   ├── NetworkClient   # 网络层 (User-Agent, Referer)
│   ├── SubtitleService # 字幕获取 + 重试
│   ├── StorageService  # 文件读写 (summary/, ass/)
│   └── WBIService      # WBI 签名算法
├── ViewModels/         # MVVM ViewModel 层
├── Views/              # SwiftUI 视图
│   ├── Auth/           # 登录页
│   ├── Components/     # 通用组件 (Markdown 渲染)
│   ├── Favorites/      # 收藏夹
│   ├── Home/           # 首页 (URL/UP主 总结)
│   ├── Settings/       # 设置页
│   ├── Summary/        # 总结浏览/详情
│   └── User/           # UP主视频总结
└── Utils/              # 常量 + 扩展
project.yml             # XcodeGen 项目配置
```

## AI Prompt

总结输出格式：**内容整理** → **核心观点** → **行动建议**

## License

MIT
