# 项目改进记录

## 2026-02-20 - Code Review 问题修复

### 🔴 P0 - StorageService 递归死锁修复
**问题**：`addUserFavorite`、`removeUserFavorite`、`isUserFavorited` 在 `favoritesQueue.sync` 内部调用 `loadUserFavorites()` / `saveUserFavorites()`，而后者也使用 `favoritesQueue.sync`，形成递归 sync → 死锁
**修复**：拆分出 `_unsafeLoadFavorites()` / `_unsafeSaveFavorites()` 内部方法（不加锁），外层统一加锁；删除有同样问题的 `isUserFavorited` 方法
**文件改动**：`BiliSummary/Services/StorageService.swift`

### 🟡 P1 - ToastViewModel dismiss 不可取消
**问题**：`ToastViewModel.show()` 使用 `DispatchQueue.main.asyncAfter`，快速连续触发 toast 时旧的 dismiss timer 会错误关闭新 toast
**修复**：改用可取消的 `Task` + `dismissTask?.cancel()`
**文件改动**：`BiliSummary/Views/Components/ToastView.swift`

### 🟡 P1 - @StateObject 包装 singleton 语义不对
**问题**：`UserFavoritesViewModel.shared` 用 `@StateObject` 包装，但 singleton 生命周期不由 View 管理
**修复**：改为 `@ObservedObject`，与 `SummaryDetailView` 保持一致
**文件改动**：
- `BiliSummary/Views/Favorites/FavoritesView.swift`
- `BiliSummary/Views/UserFavorites/UserFavoritesView.swift`

### 🟡 P1 - FavoritesView 重复创建 SummaryListViewModel
**问题**：每次点开详情都 `SummaryListViewModel()`，浪费资源且状态不共享
**修复**：添加 `SummaryListViewModel.shared` 单例，统一使用
**文件改动**：
- `BiliSummary/ViewModels/SummaryListViewModel.swift`
- `BiliSummary/Views/Favorites/FavoritesView.swift`

### 🟢 P2 - saveSummary 死代码清理
**问题**：`authorLine`、`durationStr` 等变量计算后未使用
**修复**：删除未使用的变量，保留实际需要的 `generatedAt` 和 `normalizedCover`
**文件改动**：`BiliSummary/Services/StorageService.swift`

### 🟢 P2 - summarizePrompt 移入 Constants enum
**问题**：`summarizePrompt` 是 top-level `let`，不在 `Constants` enum 内
**修复**：移入 `Constants` enum 作为 `static let`，引用改为 `Constants.summarizePrompt`
**文件改动**：
- `BiliSummary/Utils/Constants.swift`
- `BiliSummary/Services/AIService.swift`

### 🐛 额外 - MarkdownWebView 命名不匹配
**问题**：文件名 `MarkdownWebView.swift` 内的 struct 叫 `MarkdownContentView`，`SummaryListView` 引用 `MarkdownWebView` 编译失败
**修复**：添加 `typealias MarkdownWebView = MarkdownContentView`
**文件改动**：`BiliSummary/Views/Components/MarkdownWebView.swift`

---

## 2026-02-19 - 大力度代码重构 & 组件化

### 重构内容

#### 13. 组件化重构 - 抽取通用组件
**目标**：消除重复代码，提高可维护性
**新增组件**：
- `ToastView.swift` - Toast 提示组件 + ViewModifier
- `EmptyStateView.swift` - 空状态视图组件
- `ProgressSectionView.swift` - 进度显示组件
**重构的视图**：
- `FavoritesView` - 使用 ToastView, EmptyStateView, ProgressSectionView
- `SummaryListView` - 使用 EmptyStateView
- `SummaryDetailView` - 使用 ToastView, EmptyStateView
- `HomeView` - 使用 ProgressSectionView，删除重复的 ProgressSection
- `UserFavoritesView` - 使用 EmptyStateView
**删除的重复代码**：约 200+ 行重复的 Toast/EmptyState/Progress 代码
**文件改动**：
- 新增：`BiliSummary/Views/Components/ToastView.swift`
- 新增：`BiliSummary/Views/Components/EmptyStateView.swift`
- 新增：`BiliSummary/Views/Components/ProgressSectionView.swift`
- 修改：所有使用这些组件的视图文件

---

## 2026-02-19 - 总结进度逻辑修复

### 问题修复

#### 12. 总结进度逻辑问题修复
**问题 1**：`reset()` 方法从未被调用，多次运行任务时进度列表不断累积
**修复**：在 `processBatch` 开始时，如果不在处理中就自动调用 `reset()`
**问题 2**：同一个 bvid 可能重复添加到进度列表
**修复**：添加前检查是否已存在
**问题 3**：ProgressItem 的 id 用 UUID 导致无法去重
**修复**：改用 bvid 作为 id
**文件改动**：`BiliSummary/ViewModels/HomeViewModel.swift`

---

## 2026-02-19 - UP 主搜索建议功能

### 新增功能

#### 11. UP 主搜索建议/自动补全
**功能**：输入 UP 主名字时，自动显示搜索建议列表，类似 B 站原生体验
**实现细节**：
- 输入 2 个字符以上触发搜索
- 300ms 防抖延迟，避免频繁请求
- 显示 UP 主头像、名字、粉丝数、视频数、签名
- 点击建议项自动选中并填充
- 支持直接输入 UID（不触发搜索建议）
**文件改动**：
- `BiliSummary/Models/VideoInfo.swift` - 扩展 SearchUserItem 模型
- `BiliSummary/Services/BilibiliAPI.swift` - 添加 searchUsers 方法
- `BiliSummary/ViewModels/UserSummaryViewModel.swift` - 添加搜索建议逻辑
- `BiliSummary/Views/User/UserSummaryView.swift` - 添加建议列表 UI
- `BiliSummary/Utils/Constants.swift` - 添加搜索相关常量

---

## 2026-02-19 - P2/P3 问题修复 & 用户体验优化

### P2 - 中等问题修复

#### 6. 硬编码的 Magic Numbers
**问题**：项目中存在多处硬编码的数字（8192, 120, 5, 2, 200）
**修复方案**：整理到 `Constants.swift` 中统一管理
**新增常量**：
- `aiMaxTokens = 8192`
- `aiMaxRetries = 5`
- `aiRetryBaseWait = 2` (seconds)
- `aiRequestTimeout = 120` (seconds)
- `taskDelayMs = 200` (milliseconds)
**文件改动**：
- `BiliSummary/Utils/Constants.swift`
- `BiliSummary/Services/AIService.swift`
- `BiliSummary/ViewModels/HomeViewModel.swift`

---

### P3 - 小改进 & 用户体验优化

#### 7. UP 主收藏页面下拉刷新
**改进**：给 UserFavoritesView 添加了 `.refreshable` 修饰符
**文件改动**：`BiliSummary/Views/UserFavorites/UserFavoritesView.swift`

#### 8. 总结详情页分享功能
**改进**：在 SummaryDetailView 右上角添加了系统分享按钮（ShareLink）
**功能**：可以直接分享总结内容给其他 App
**文件改动**：`BiliSummary/Views/Summary/SummaryListView.swift`

#### 9. 收藏夹页面 Toast 提示
**改进**：在 FavoritesView 中添加了和 SummaryDetailView 一样的 Toast 组件
**功能**：收藏/取消收藏 UP 主时会有提示
**文件改动**：`BiliSummary/Views/Favorites/FavoritesView.swift`

#### 10. 收藏夹 UP 主收藏按钮状态同步
**改进**：左滑菜单中的"收藏 UP"按钮现在会显示正确的状态（已收藏/未收藏）
**功能**：已收藏时显示"取消收藏 UP"和橙色，未收藏时显示"收藏 UP"和蓝色
**文件改动**：`BiliSummary/Views/Favorites/FavoritesView.swift`

---

## 2026-02-19 - P0/P1 问题修复

### P0 - 严重问题修复

#### 1. StorageService 数据竞争问题
**问题**：用户收藏的读写没有线程同步，多线程同时调用会导致数据覆盖丢失
**修复方案**：添加 `favoritesQueue` 串行队列，保护用户收藏的所有读写操作
**文件改动**：`BiliSummary/Services/StorageService.swift`

#### 2. SummaryListView 内存泄漏/状态共享问题
**问题**：每次打开 SummaryDetailView 都会创建新的 UserFavoritesViewModel，多个详情页状态不同步
**修复方案**：把 UserFavoritesViewModel 改为单例 (`shared`)
**文件改动**：
- `BiliSummary/ViewModels/UserFavoritesViewModel.swift`
- `BiliSummary/Views/Summary/SummaryListView.swift`

#### 3. UserFavoritesView HomeViewModel 重复创建
**问题**：UserFavoritesView 内部新创建 HomeViewModel，和 MainTabView 中的不同步
**修复方案**：从外部传入 homeVM 参数
**文件改动**：
- `BiliSummary/Views/UserFavorites/UserFavoritesView.swift`
- `BiliSummary/App/MainTabView.swift`

---

### P1 - 中等问题修复

#### 4. KeychainHelper 命名误导
**问题**：文件名是 KeychainHelper，但实际用的是 UserDefaults
**修复方案**：重命名为 AppPreferences.swift
**文件改动**：
- 重命名：`BiliSummary/Services/KeychainHelper.swift` → `AppPreferences.swift`
- 更新所有引用文件：
  - `AIService.swift`
  - `ASRService.swift`
  - `BilibiliAuth.swift`
  - `SettingsViewModel.swift`

#### 5. FavoritesViewModel 重复代码
**问题**：检查 summary 状态的代码在 `loadVideos` 和 `refreshStatusForVideos` 中重复了
**修复方案**：在 StorageService 中添加 `summaryState(title:outputSubdir:)` 辅助方法
**文件改动**：
- `BiliSummary/Services/StorageService.swift`
- `BiliSummary/ViewModels/FavoritesViewModel.swift`

---

### 额外改进

- 在 SummaryDetailView 中添加了收藏/取消收藏 UP 主的 Toast 提示
- SummaryDetailView 中的 userFavVM 改用 @ObservedObject 观察共享单例
