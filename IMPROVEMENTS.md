# 项目改进记录

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
