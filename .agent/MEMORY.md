# Project Memory

## Reference Project
- The original Python implementation is at `../bilibili-summary` (i.e., `/Users/jakevin/code/bilibili-summary`)
- It uses `bilibili-api-python`, `anthropic` SDK, and stores config in `.env.local`
- Key config: `ANTHROPIC_BASE_URL=https://open.bigmodel.cn/api/anthropic`, default model `GLM-4-FlashX-250414`
- Always refer to the Python version when unsure about API patterns or business logic

## Build
- Uses `xcodegen` to generate Xcode project from `project.yml`
- Code signing is disabled (`CODE_SIGNING_ALLOWED: "NO"`)
- Because of this, Keychain is NOT available (OSStatus -34018). Settings use UserDefaults instead.
- Must verify both `xcodebuild` CLI and Xcode GUI builds succeed

## Storage
- Settings (API URL, token, model) are stored in UserDefaults (not Keychain)
- Bilibili credentials (sessdata, bili_jct) also use UserDefaults
- This matches the Python version's security level (.env.local = plain text)

## B站 API Notes
- `/x/space/wbi/arc/search` requires WBI signing (w_rid + wts)
- WBI signing is implemented in `WBIService.swift`
- AI subtitle URLs may be empty initially; `SubtitleService` has retry logic (up to 3 attempts, 2s delay)
- `NetworkClient.biliRequest()` must be used (not raw URLSession) — includes required User-Agent and Referer headers
