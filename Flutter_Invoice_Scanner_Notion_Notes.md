# Flutter 發票掃描 APP — 開發架構與模組全解析筆記

> **導言**
> 此文件是為了協助你未來理解、擴充與交接此專案所撰寫的深度解析筆記。
> 拋開高階的「抽象概念」，這份筆記將深入程式碼結構，告訴你**每一個資料夾在幹嘛**、**每一個核心模組怎麼設計的**，以及**重點物件背後的實際運作邏輯**與常見地雷。強烈建議直接匯入 Notion 作為你的知識庫。

---

## 🏗️ 1. 專案整體架構設計 (Architecture Layout)

本專案強烈採用 **Feature-First (以功能為中心)** 搭配 **Clean Architecture (整潔架構)** 的變體。也就是說，我們不把所有 UI 塞在同一個資料夾，而是「把同一個功能的畫面、業務邏輯、資料處理綁在一起」。

這樣做最大的好處是：**當你要修改「發票掃描」功能時，你只需要打開 `scanner` 資料夾，不需要像無頭蒼蠅一樣在整個專案裡撈檔案。**

### 📂 目錄結構解剖

```text
lib/
├── main.dart                    # 🚀 APP 啟動進入點與路由 (GoRouter) 註冊中心
│
├── core/                        # ⚙️ 核心基礎設施 (全域共用組合)
│   ├── constants/               # 存放不會變動的字串 (如：資料夾名稱 'invoices')
│   ├── theme/                   # Material 3 全域主題、色彩計畫、按鈕樣式定義
│   └── utils/                   # 通用工具函數 (例如：將 DateTime 轉成字串的 DateUtilsHelper)
│
├── features/                    # 🧩 核心功能模組 (Feature-First 的精髓)
│   │
│   ├── main/                    # 👉 主框架模組
│   │   └── presentation/        # 包含 Scaffold 與負責切換分頁的底層導覽列 (MainScreen)
│   │
│   ├── scanner/                 # 👉 📸 掃描與辨識模組 (最複雜的一塊)
│   │   ├── data/                # 負責底層調用: ocr_service (Google ML Kit)、invoice_parser (正規表達式)
│   │   ├── domain/entities/     # 負責資廖結構: invoice_entity (發票實體定義)
│   │   └── presentation/        # 負責畫面與狀態: scanner_page (相機 UI)、scanner_provider (業務邏輯)
│   │
│   ├── invoice_list/            # 👉 📋 發票清單模組
│   │   ├── presentation/        # invoice_list_page (列表畫面)、invoice_list_provider (載入與刪除邏輯)
│   │   └── widgets/             # invoice_card (清單中專用的卡片 UI 元件)
│   │
│   └── invoice_detail/          # 👉 🔍 明細與編輯模組
│       └── presentation/        # invoice_detail_page (單張表單)、invoice_detail_provider (編輯覆寫邏輯)
│
└── shared/                      # 🤝 跨模組共用資源
    ├── services/                # local_storage_service (處理 JSON 的建立、讀取、照片拷貝)
    └── widgets/                 # custom_app_bar (每個畫面頂部帶有漸層色的共用標題列)
```

---

## ⚙️ 2. 核心模組功能詳解

### A. 掃描與辨識模組 (`features/scanner`)
這是 App 心臟所在，包含了使用者互動到產生資料的完整工廠流水線。
- **作用**：控制相機硬體、捕捉影像、呼叫 AI 字元叢集辨識、正則解析。
- **內部協作**：
  1. `scanner_page.dart` (畫面)：建立 `CameraController`，繪製半透明黑色對焦遮罩。使用者按下快門後將 `image Path` 往後丟。
  2. `ocr_service.dart` (辨識)：載入 `google_mlkit_text_recognition` 引擎，這是全離線的。回傳一整坨「發票上所有的純文字」。
  3. `invoice_parser.dart` (解析)：拿著那一坨純文字，用 Regex (正規表達式) 切割，試圖找出「AB-12345678」、「2026-03-25」、「金額」等，組成初始物件。
  4. `scanner_provider.dart` (狀態流)：協調上述三個動作的工作總管。負責顯示 "Loading" 轉圈圈、抓錯，並觸發路由跳轉。

### B. 發票清單模組 (`features/invoice_list`)
使用者開啟 App 的登陸頁面。
- **作用**：展示歷史紀錄、計算當月總開銷、支援下拉刷新與滑動刪除。
- **內部協作**：
  1. `invoice_list_provider.dart`：內部掛載 `AsyncValue` (包含了資料加載中、加載成功、加載失敗三種狀態)。啟動時向 LocalStorage 拿全部檔案並進行 **時間排序 (新到舊)**。
  2. `invoice_list_page.dart`：監聽上述狀態，使用 `ListView.separated` 動態繪製 `invoice_card`。

### C. 明細與編輯模組 (`features/invoice_detail`)
由於 OCR 辨識「絕對不可能」達到 100% 正確率，因此必須要有除錯機制。
- **作用**：預覽拍下的發票照片、讓用戶修改錯誤的發票號碼與金額、最終存進本地資料庫。
- **內部協作**：
  1. `invoice_detail_page.dart`：畫面上使用了多個 `TextEditingController`，我們將一開始 OCR 判定的初始值塞入，用戶可以打字覆蓋它。
  2. `invoice_detail_provider.dart`：當用戶點擊右上角「勾勾」儲存時，這個 Provider 會負責執行永久寫入的動作。

---

## 🔑 3. 重點核心物件 (Key Objects) 詳細剖析

這幾個核心物件是你維護時一定會碰到的。

### 📌 `InvoiceEntity` (發票實體)
- **在哪裡**：`lib/features/scanner/domain/entities/invoice_entity.dart`
- **為什麼重要**：它是貫穿所有畫面的「血管」。這是一個 **Immutable (不可變)** 的強型別物件。
- **設計巧思**：
  - 它擁有 `fromJson` 與 `toJson`，讓它可以輕易被序列化成字串存入 `invoices.json`。
  - 提供了 `copyWith` 方法：在 Riverpod 狀態管理中，我們「不能」直接去改裡面的屬性 (例如 `invoice.amount = 100`)，而是必須產生一個全新拷貝 `invoice.copyWith(amount: 100)` 來觸發畫面重新渲染。這能徹底杜絕資料不同步的 Bug。

### 📌 `ScannerNotifier` (掃描總司令)
- **在哪裡**：`lib/features/scanner/presentation/scanner_provider.dart`
- **為什麼重要**：處理了最複雜的非同步流程 (Async / Await)。
- **執行流程解析**：
  ```dart
  Future<void> processCapturedImage(String imagePath) async {
    // 1. 鎖住畫面，轉圈圈 (isLoading: true)
    state = state.copyWith(isLoading: true, ...);
    
    // 2. 呼叫 OCR Engine
    final rawText = await _ocrService.processImage(imagePath);
    
    // 3. 呼叫 Parser 用正則表達式把廢話過濾掉，提煉出金額和號碼
    final parsedData = InvoiceParser.parse(rawText);
    
    // 4. 產生全新發票 Entity (給予 UUID 唯一碼！)
    final entity = InvoiceEntity(id: Uuid().v4(), ...);
    
    // 5. 狀態更新完畢！觸發 UI 監聽並跳轉到「確認明細頁」
    state = state.copyWith(isLoading: false, result: entity);
  }
  ```

### 📌 `InvoiceParser` (正規表達式解析器)
- **在哪裡**：`lib/features/scanner/data/invoice_parser.dart`
- **為什麼重要**：AI (ML Kit) 只負責「認字」，不管「意思」。這隻檔案是用來賦予文字意義的規則本。
- **設計巧思**：
  - 使用 Regex 取代傳統的 `if-else`。例如 `RegExp(r'[A-Za-z]{2}-?\d{8}')`：
    - `[A-Za-z]{2}`：找前面有兩個隨機英文字。（台灣發票字軌）
    - `-?`：減號可有可無。(有些發票的 - 墨水淡，AI 認不出來)
    - `\d{8}`：必須剛好配對 8 個純數字。
  - **未來維護**：如果全聯或 7-11 發票改版導致金額認不出來，你第一時間就是來改這支檔案裡的特徵匹配規則。

### 📌 `LocalStorageService` (本地輕量資料庫)
- **在哪裡**：`lib/shared/services/local_storage_service.dart`
- **為什麼重要**：取代了厚重的 Hive 或 SQLite 關聯式資料庫。
- **設計巧思**：
  - 呼叫 `path_provider` 的 `getApplicationDocumentsDirectory()`：把資料存放在系統保留給 APP 專用的沙盒中，用戶在手機內建檔案總管裡是找不到也刪不掉的，保護資安。
  - **`copyImageToAppDirectory()`**: 這超級重要。相機剛拍好的照片只是存放在 `tmp/` (暫存快取區)，只要手機重開機就會被系統刪除；我特別寫了這個方法，在用戶按下「儲存發票」時，將照片移動到 APP 專屬文件夾內並用 UUID 重新命名，確保照片永久保存。

## 📦 4. 第三方套件與模組導入指南 (Dependencies)

若未來你要在別台電腦重新執行這個專案，或是要擴充功能，你需要了解以下套件的導入與設置。

### 依賴檔案清單 (`pubspec.yaml`)
本專案的根基仰賴於這些強大的官方或主流開源套件，你必須在 `pubspec.yaml` 中確認它們存在：
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1      # 狀態管理
  go_router: ^13.2.0           # 路由管理
  camera: ^0.10.5+9            # 驅動底層相機預覽
  image_picker: ^1.0.7         # 開啟系統相簿
  google_mlkit_text_recognition: ^0.12.0 # 本機端 OCR 辨識引擎
  path_provider: ^2.1.2        # 拿取 iOS/Android 安全的沙盒路徑
  uuid: ^4.3.3                 # 給予每張發票唯一識別碼
  intl: ^0.19.0                # 時間與貨幣格式化顯示
  google_fonts: ^6.2.1         # 全域字體載入
```

### 系統權限申請 (Permissions)
因為我們用到了**相機**與**相簿**，在建置為真實的 iOS 或 Android 應用程式時，必定要在原生專案檔案內加入權限宣告，否則一按按鈕就會直接閃退：
- **iOS (`ios/Runner/Info.plist`)**:
  ```xml
  <key>NSCameraUsageDescription</key>
  <string>需要相機權限才能掃描發票</string>
  <key>NSPhotoLibraryUsageDescription</key>
  <string>需要相簿權限才能選擇發票截圖</string>
  ```
- **Android (`android/app/src/main/AndroidManifest.xml`)**:
  需宣告 `<uses-permission android:name="android.permission.CAMERA" />`

### 檔案內的模組導入法則 (Import Strategy)
在每一個 Dart 檔案的頂部，我們遵循統一的引入順序：
1. **Dart 內建核心庫** (例如 `import 'dart:io';`)
2. **Flutter 官方套件** (例如 `import 'package:flutter/material.dart';`)
3. **第三方開源套件** (例如 `import 'package:flutter_riverpod/flutter_riverpod.dart';`)
4. **專案內部的自訂模組** (我們一律使用相對路徑，例如 `import '../../core/constants/app_constants.dart';`)。這能確保我們用最短的路徑關聯起同一模組內的其他檔案，實踐低耦合的防線。

---

## 💡 5. 你可能沒有注意到的高級 Flutter 觀念 (補充分享)

我認為以下三點是支撐這個 APP 穩固不崩潰，但比較難從字面上察覺的設計細節：

### ① 路由的魔法：`StatefulShellRoute` (保留分頁狀態)
一般切換分頁 (我的發票 <-> 掃描 <-> 設定) 如果用傳統的方式，點過去再點回來，剛打字打到一半的發票或是滾動到一半的卷軸會「重新回到最上面」。
在 `main.dart` 裡，我選用了 go_router 的 **`StatefulShellRoute.indexedStack`**。它會在背景偷偷把三個分頁「疊加」在一起，切換分頁只是改變透明度，這保證了極致流暢且絕不遺失使用者編輯狀態的體驗。

### ② 記憶體洩漏防堵 (Memory Leak Prevention)
如果沒有正確釋放硬體資源，你的 APP 開十分鐘就會閃退。
- 在 `scanner_page.dart` 的 `dispose()` 裡，我們調用了 `_cameraController?.dispose();`，確保離開掃描頁時把鏡頭還給系統。
- 在 `invoice_detail_page.dart` 中，我們針對所有的文字框進行 `_amountController.dispose();`。
- 在 `ocr_service.dart` 中，我們針對 AI 辨識引擎進行 `_textRecognizer.close();`。
這三步是保持 APP 成為輕快 MVP 的核心安全守則。

### ③ 依賴注入 (Dependency Injection) 的極簡化
在 `scanner_provider.dart` 中，我們在初始化 Notifier 時，是將 `OcrService()` **「當作參數傳進去」** (`ScannerNotifier(OcrService())`)，而不是在裡面才去 `new` 一個。
這個好處是，如果未來你要替這個 APP 寫自動化測試 (Unit Test)，你可以輕易地傳入一個「假裝成功」的 Mock OcrService，而不需要每次測試都真的去開相機。這就叫做「解耦」。

---

> 總結：
> 此 APP 是一個麻雀雖小、五臟俱全的成熟小專案示範。它避開了過度設計 (Over-engineering)，沒有殺雞用牛刀去串接龐大的 Firebase 或是 Sqflite，而是專注於最核心的 On-Device OCR 體驗與效能。
