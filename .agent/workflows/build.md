---
description: Build and verify the BiliSummary iOS project
---

## Build Requirements

> **重要**: 每次修改代码后，必须同时确保 **命令行 build** 和 **Xcode GUI build** 都能成功。
> 仅命令行 `xcodebuild` 成功是不够的！

### 步骤

1. 如果修改了 `project.yml`，先重新生成 Xcode 项目：
```bash
cd /Users/jakevin/code/bilibili-summary-swift && xcodegen generate
```

// turbo
2. 命令行 build 验证：
```bash
cd /Users/jakevin/code/bilibili-summary-swift && xcodebuild -scheme BiliSummary -destination 'platform=iOS Simulator,id=379DB491-22B5-498F-9041-7A0071069B1E' build ONLY_ACTIVE_ARCH=YES 2>&1 | tail -5
```

3. 确认输出包含 `** BUILD SUCCEEDED **`

4. 提醒用户在 Xcode GUI 中也点击 Build (Cmd+B) 验证

### 常见问题

- `Codable` vs `Decodable`：如果一个 `Codable` struct 包含了 `Decodable`-only 的属性，编译会失败。确保整个层级一致。
- Deployment target：使用 `iOS 18.0`，不要用 beta 版本号（如 `26.0`）。
- `SWIFT_ENABLE_EXPLICIT_MODULES: "NO"` 已在 project.yml 中设置，用于解决 Xcode 26.2 beta SDK 的 module 冲突问题。
