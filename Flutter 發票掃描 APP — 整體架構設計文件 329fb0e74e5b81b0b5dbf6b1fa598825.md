# Flutter 發票掃描 APP — 整體架構設計文件 (已更新)

# 🎯 使命宣言

打造一款**輕量、離線優先且美觀**的 Flutter 發票掃描 APP：使用者透過內建相機或相簿選取圖片後，即時呼叫本地端 OCR 引擎進行文字截取與欄位辨識。所有結果均儲存於本地 JSON 中，介面直覺、零後端依賴。

---

# 📋 功能邊界與完成現狀

> 目前專案已經完成 MVP (最小可行性產品) 版本，以下為實作的功能清單。

## ✅ MVP 已實作功能

- **內建即時拍攝介面 (`camera`)**：提供半透明疊加層對焦遮罩，不須跳轉第三方相機 APP。
- **相簿選取匯入 (`image_picker`)**：除了拍照外也可讀寫相簿截圖。
- **On-device OCR 辨識 (`google_mlkit_text_recognition`)**：全離線辨識支援繁體中文文字。
- **自研正規表達式發票解析引擎 (InvoiceParser)**：可自動從 OCR 結果中分離出：發票號碼、日期、店家名稱、總消費金額。
- **本地端 JSON 輕量伺服 (`path_provider` + JSON)**：無後端，包含針對實體照片的 File IO 操作與拷貝保存邏輯。
- **現代化介面體驗 (`Riverpod` + `go_router` + `Material 3`)**：順暢的底部導覽列、深色半透明漸層配色、即時重新整理機制。
- **完善的發票詳細頁**：支援圖文並茂地比對驗證錯誤，並支援手動編輯。
- **完整的發票生命週期**：建立、儲存、檢視、手動刪除等完整操作。

## ❌ 尚未納入（未來迭代方向）

- ☁️ 雲端同步 / 備份（iCloud / Google Drive）
- 👤 使用者帳號 / 登入機制
- 🏆 台灣發票中獎對獎功能（需串接財政部 API）
- 📊 時間區間報表 / 各月消費統計圖表功能
- ✂️ 圖片自動邊緣偵測/進階剪裁（目前使用直接處理整張照片）

---

# 🏗️ 整體技術架構

## 架構模式：Clean Architecture + Feature-First

採用 **Clean Architecture** 與 **Feature-First** 資料夾配置，讓元件耦合度達到最低點，便於未來的模組插拔：

- **`core/`** (基礎建設)：常數定義、日期工具、全域主題與樣式設定。
- **`shared/`** (跨模組共用)：自訂 AppBar 共用元件、檔案讀寫底層（LocalStorageService）。
- **`features/`** (特性模組群)：依服務領域切割：
  - **`scanner/`**：攝影機預覽、Riverpod 邏輯處理中樞、ML Kit OCR 呼叫及 Parser 資料轉譯器。
  - **`invoice_list/`**：條列發票紀錄、狀態與 Loading 控制、當月總價顯示卡片。
  - **`invoice_detail/`**：欄位手動修改綁定、圖片呈現、儲存寫回更新本地端。

---

# 📦 核心技術選型一覽

| 相關類別 | 套件包 / 工具 | 選用理由 |
| --- | --- | --- |
| **狀態管理** | `flutter_riverpod` | 簡單的跨頁面數據同步、全域提供 Immutable AsyncValue 狀態支持。 |
| **OCR 視覺辨識** | `google_mlkit_text_recognition` | 高度隱私之終端裝置運算，辨識準確且無呼叫 API 費用。 |
| **相機底層** | `camera` | 提供最原生快速的相機預覽 (`CameraPreview`) 組建供開發者自訂 UI。 |
| **相簿讀取** | `image_picker` | Flutter 官方維護套件，快速打開相簿取用現成文件。 |
| **本地資料庫替代方案** | `path_provider` + JSON | 系統單據量不龐大，使用直接的 JSON Serialize 讀寫減少如 SQLite/Hive 帶來的厚重負載。 |
| **路由與狀態保留** | `go_router` | 運用 `StatefulShellRoute` 以不刷新方式流暢管理底部 NavigationBar。 |

---

# 🗃️ 資料流模型：`InvoiceEntity`

所有傳遞、更新的基礎為強型別發票紀錄實體，於此專案為重點核心：

```json
{
  "id": "e2f1...", // 透過 UUID 動態生成，防止寫入衝突
  "scannedAt": "2026-03-25T...Z", // 使用者存取當下
  "imageLocalPath": ".../Documents/invoices/images/img_e2f1.jpg", 
  "invoiceNumber": "XY-88888888", // 格式化為含有減號
  "date": "2026-03-25",
  "merchantName": "全家便利商店",
  "totalAmount": 160.0,
  "rawOcrText": "...", // 原始未加工的純文字供檢修
  "isManuallyEdited": false
}
```

---

# 🔄 核心業務流程與非同步處理 (Riverpod 篇)

整體核心的非同步流程由 `scanner_provider` 掌控：

1. **使用者點下快門按鈕 (`ScannerPage`):** 觸發原生 CameraController 拍照 (`takePicture()`)。
2. **傳遞至 ScannerNotifier (`scanner_provider.dart`):** 接手檔案路徑並發送 Loading UI。
3. **ML Kit 文字擷取 (`ocr_service.dart`):** `processImage` 抓出純繁體字串。
4. **解析引擎解構 (`invoice_parser.dart`):** 正則解析，補上防呆邏輯。
5. **產生原始發票物件:** 將萃取物件透過 `go_router` 直接傳遞至檢修頁。
6. **手動修正儲存 (`invoice_detail_provider.dart`):** 當使用者敲擊 `save()` 時，檔案寫入本地資料夾並覆寫 `invoices.json`。
7. **首頁重繪 (`invoice_list_provider.dart`):** 強制清單讀取新的歷史紀錄。

---

*本文件已更新並重新排版整理，反映目前專案最新架構與開發狀態。*