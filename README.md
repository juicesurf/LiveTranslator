# LiveTranslator

macOS 即時英中雙語字幕工具。讀取系統 Live Captions 的英文字幕，用 Apple Translation 翻譯為繁體中文，顯示在可置頂的浮動視窗。

- 英文與中文逐句對照，長句隨視窗寬度換行。
- 等完整句尾（`. ? !`）後翻譯；處理字幕更新、修正與重疊。
- 可調字體、透明度、深淺色與僅中文顯示。
- 上捲查看歷史時暫停自動跟隨，捲回底部後恢復。
- 逐句經過時間，TXT／Markdown 匯出與未儲存提醒。
- 不需 API Key、不使用付費翻譯 API、不上傳第三方服務。字幕預設只留在記憶體，主動儲存才寫入檔案。

## 環境需求

- macOS 26.0 以上，並且系統可使用英文 Live Captions。
- 完整 Xcode（只有 Command Line Tools 不足夠）。首次使用先開啟 Xcode，接受條款並完成元件安裝。
- 本專案目前驗證環境：Apple Silicon M2、macOS 26.5.2、Xcode 26.6、Swift 6.3.3、macOS 26.5 SDK。其他硬體／版本尚未完整驗證。
- 首次準備翻譯模型需要網路；模型及語言支援由系統確認，離線使用仍需在自己的 Mac 實測。

## 用 Terminal 下載、編譯及打包

在 Terminal 逐行執行：

```bash
git clone https://github.com/juicesurf/LiveTranslator.git
cd LiveTranslator
bash scripts/package.sh
```

若已用 GitHub「Code → Download ZIP」下載，解壓縮後，在 Terminal 輸入 `cd `（含空格），將解壓縮的專案資料夾拖入 Terminal，按 Enter，再執行：

```bash
bash scripts/package.sh
```

腳本會使用本機 Xcode 編譯 Release，進行 ad-hoc 簽署並產生：

| 成品 | 位置 |
| --- | --- |
| 可直接啟動的 App | `build/package/Build/Products/Release/LiveTranslator.app` |
| 壓縮包 | `dist/LiveTranslator.zip` |

不需要付費 Apple Developer 帳號、Developer ID、公證或 Xcode Archive 操作。這裡的 Release 是本機編譯設定，並不代表已完成正式發佈簽署。ZIP 會覆蓋先前同名的打包成品，不會包含原始碼或逐字稿。

在專案目錄啟動：

```bash
open build/package/Build/Products/Release/LiveTranslator.app
```

也可以在 Finder 雙擊 App；若要移到「應用程式」，請先結束 App，再移動並從新位置開啟，之後對同一位置的 App 授權。

> 這個流程主要供下載者在自己的 Mac 編譯使用。將此 ad-hoc ZIP 再傳給另一台 Mac，仍可能受到系統安全檢查阻擋；它不是 Developer ID 簽署／公證的安裝包。

## 第一次使用

1. 開啟 macOS「系統設定 → 輔助使用 → 即時字幕／Live Captions」，設定英文，播放英文內容，確認系統字幕本身有文字。
2. 開啟 LiveTranslator，右上角「更多操作」（⋯）選「授予輔助使用權限」。
3. 到「系統設定 → 隱私權與安全性 → 輔助使用」，啟用 **LiveTranslator**。必要時按 +，加入剛編譯的 App。Terminal 的權限不會代替 App 的權限。
4. 在「更多操作」按「準備模型／重試翻譯」，接受 Apple 的模型下載提示。
5. 按「開始擷取」。英文句尾出現後才會翻譯；沒有句尾時顯示「等待完整句子」。

可先停止擷取，再從「更多操作」按「測試英翻繁中」，驗證固定測試句。關閉字幕視窗只停止擷取，不會結束 App；點 Dock 圖示或按 ⌘0 可重開。

## 儲存字幕

工具列「儲存」可選 TXT 或 Markdown。匯出本次全部字幕，包含捲動上方內容，依「經過時間 → 英文 → 中文」排列。時間不是影片播放位置；同一句修正後會保留原時間，停止／重開擷取不歸零，清除後重新計時。

有尚未匯出的字幕、修正或翻譯時，清除或 ⌘Q 會提醒儲存。提醒與後續儲存期間暫停更新；取消或失敗時保留字幕並恢復更新。一般手動匯出不停止擷取，晚於匯出快照的新內容仍視為未儲存。

## 更新程式

先儲存需要的字幕，⌘Q 結束 App，再於原始碼目錄執行：

```bash
git pull --ff-only
bash scripts/package.sh
open build/package/Build/Products/Release/LiveTranslator.app
```

## 常見問題

**`xcodebuild` 找不到完整 Xcode，或顯示 Command Line Tools 錯誤**

先安裝完整 Xcode。若 Xcode 安裝在標準位置，可在確認路徑後執行以下指令；系統會要求管理員密碼：

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

再開啟 Xcode，完成首次設定，重跑打包腳本。若 Xcode 安裝在其他位置，請使用實際路徑。

**重新編譯後顯示需要輔助使用權限**

本機 ad-hoc 簽署可能使舊權限紀錄失效。⌘Q 結束 App，在輔助使用權限清單用 − 移除舊 LiveTranslator，再用 + 加入新的 App，啟用後重新開啟。單純切換開關可能不足。

**一直沒有中文**

先確認模型已準備、系統支援 en → zh-Hant，再確認英文有句尾。若持續沒有標點，程式會等待完整句子，不會用時間或字數強制拆開。「更多操作 → 顯示診斷」可查看狀態與耗時。

**已知限制**

Live Captions 的 Accessibility 階層是系統實作細節，系統更新可能影響讀取。縮寫句尾採保守判斷；完全相同 snapshot 無法區分真正重複說話與畫面未變；沒有重疊的大幅辨識修正仍可能產生額外段落。多螢幕、全螢幕、離線翻譯與模型品質需在各自環境驗證。

## 開發與測試

也可用 Xcode 開啟 `LiveTranslator.xcodeproj`，選 LiveTranslator／My Mac，按 Run。

```bash
swift test --scratch-path build/swift-tests
```

測試涵蓋字幕修正、滾動重疊、分句、翻譯結果版本、時間戳記、匯出、未儲存保護、原生捲動及換行排版。更多架構與手動驗收細節見 [開發紀錄](docs/DEVELOPMENT.md)。
