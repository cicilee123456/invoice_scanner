# Flutter 發票掃描 APP — 新手手把手完整教學 (Tutorial Guide)

> **準備開始！**
> 這是一份把你當作「第一次寫這種複雜 APP 的初學者」的手把手教學。
> 以下的每一個步驟，我不只會告訴你「要幹嘛」，還會給你「要寫什麼程式碼」，並附上白話文解釋。請依照 Step 1 到 Step 5 的順序，一步一步在你的電腦上實作。

---

## 🛠 Step 1: 專案前置作業與套件安裝 (Environment Setup)

### 1-1. 建立乾淨的專案
請在終端機輸入以下指令建立新專案：
```bash
flutter create invoice_scanner
cd invoice_scanner
```
打開專案後，到 `lib/main.dart` 裡面，把預設畫面上那個「按按鈕數字會增加」的 Demo 程式碼全部刪除，留下最乾淨的 `void main()` 殼子就好。

### 1-2. 安裝必備套件 (`pubspec.yaml`)
> **🚨 新手最大地雷警告 (Dependency Hell)**：
> 很多新手會習慣直接在終端機打 `flutter pub add xxx`，這會幫你抓「全世界最新」的版本。但軟體更新很快，一旦某個最新套件把寫法大翻新（也就是所謂的 Breaking Changes），你照著十天前的網路教學寫出來的程式碼，馬上就會全部亮紅燈報錯！
> 
> **👨‍🏫 安全做法：指定「穩定版本號」！**
> 請直接打開你專案左邊清單裡的 **`pubspec.yaml`** 檔案，滑到接近中間 `dependencies:` 的地方，把我們要用的套件與版本號「手動貼上去」：

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # ⬇️ 請將以下這些我們測試過絕對穩定的版本，貼在 flutter 底下 ⬇️
  
  # ① 狀態與路由管理 (APP 的骨架與大腦)
  flutter_riverpod: ^2.6.1   # 負責取代繁瑣的 setState，掌控資料流
  go_router: ^14.8.1         # 負責實作不刷新的底部導覽列切換
  
  # ② 硬體設備存取 (APP 的手與眼)
  camera: ^0.11.0            # 內嵌相機畫面，直接在 APP 裡掃描
  image_picker: ^1.1.0       # 提供入口開啟系統相簿，選取已拍好的發票
  
  # ③ Google AI 離線辨識引擎 (APP 的大腦皮層)
  google_mlkit_text_recognition: ^0.13.0  # 100% 離線的超強大 OCR 繁中辨識器
  
  # ④ 系統與資料處理工具箱 (APP 的基礎設施)
  path_provider: ^2.1.3      # 尋找手機「隱私不被清除的文件夾」存 JSON
  uuid: ^4.3.3               # 產生如 B97F9-C... 等獨一無二的發票身分證字號
  intl: ^0.19.0              # 把日期換成 2026-03-25，並幫金額加上千分位逗號
  google_fonts: ^8.0.2       # 載入好看的 Noto Sans 等設計字體
```

貼好存檔 (Ctrl+S / Cmd+S) 之後，VS Code 通常會自動幫你執行下載。
如果沒有，請打開終端機輸入：
```bash
flutter pub get
```
這樣就可以 100% 確保你的套件版本跟我教的這份筆記是完美吻合的，絕對不會無故報錯！

### 1-3. 原生系統權限宣告 (非常重要，不加一拍照就閃退！)
既然我們裝了 `camera` (相機) 與 `image_picker` (相簿)，我們就必須跟 iOS 和 Android 系統「報備」，索取使用者的隱私授權。

- **🍎 iOS 用戶**：找到左邊資料夾的 `ios/Runner/Info.plist`，滑到檔案最下方面，在 `</dict>` 之前加上：
  ```xml
  <key>NSCameraUsageDescription</key>
  <string>我們需要相機來掃描您的發票字體</string>
  <key>NSPhotoLibraryUsageDescription</key>
  <string>我們需要相簿來讀取您的發票截圖</string>
  ```
- **🤖 Android 用戶**：找到 `android/app/src/main/AndroidManifest.xml`，在 `<manifest>` 標記底下加上這行：
  ```xml
  <uses-permission android:name="android.permission.CAMERA" />
  ```

---

## 🏗 Step 2: 定義資料模型與儲存空間 (Data & Storage)

> 不要在剛開始就急著畫按鈕！我們先把發票的「資料格」設計好，並處理存檔問題。

### 2-1. 建立發票模型 (`InvoiceEntity`)
請在 `lib` 下建立 `features/scanner/domain/entities/invoice_entity.dart`：
這裡定義了發票要有：ID、日期、金額等等。
```dart
class InvoiceEntity {
  final String id;              // 唯一身分證 UID
  final String invoiceNumber;   // 發票號碼
  final DateTime? date;         // 發票日期
  final double? totalAmount;    // 總金額
  final String imageLocalPath;  // 存在手機裡的照片路徑

  InvoiceEntity({
    required this.id,
    required this.invoiceNumber,
    this.date,
    this.totalAmount,
    required this.imageLocalPath,
  });

  // 讓我們可以輕鬆複製並修改單一欄位 (Immutable 不可變設計的重要法則)
  InvoiceEntity copyWith({String? invoiceNumber, double? totalAmount}) {
    return InvoiceEntity(
      id: id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      date: date ?? this.date,
      totalAmount: totalAmount ?? this.totalAmount,
      imageLocalPath: imageLocalPath,
    );
  }

  // 將資料轉成 JSON 文字存進手機
  Map<String, dynamic> toJson() => {
    'id': id,
    'invoiceNumber': invoiceNumber,
    'date': date?.toIso8601String(),
    'imageLocalPath': imageLocalPath,
    'totalAmount': totalAmount,
  };

  // 從手機讀取 JSON 文字變回發票資料
  factory InvoiceEntity.fromJson(Map<String, dynamic> json) => InvoiceEntity(
    id: json['id'],
    invoiceNumber: json['invoiceNumber'] ?? '',
    date: json['date'] != null ? DateTime.parse(json['date']) : null,
    imageLocalPath: json['imageLocalPath'] ?? '',
    totalAmount: json['totalAmount'],
  );
}
```

### 2-2. 實作本地儲存庫 (`LocalStorageService`)
既然有了發票的結構，我們把它寫進手機硬碟裡。在 `lib` 下建立 `shared/services/local_storage_service.dart`：
```dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
// import 你的 InvoiceEntity...

class LocalStorageService {
  // 1. 取得手機隱密的手機沙盒資料夾，來存 JSON 檔
  Future<File> _getInvoicesFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/invoices';
    if (!await Directory(path).exists()) await Directory(path).create();
    return File('$path/invoices.json');
  }

  // 2. 這段超重要：相機拍的照片只是「暫存檔」，不趕快複製到安全的地方，手機重開機就會不見破圖！
  Future<String> copyImageToAppDirectory(String sourcePath, String id) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = sourcePath.split('.').last;
    final targetPath = '${dir.path}/invoices/images/img_$id.$ext';
    await File(sourcePath).copy(targetPath);
    return targetPath; // 回傳永久保存的安全路徑
  }
}
```

---

## 🧠 Step 3: 呼叫 Google AI 與字串解析 (OCR & Parser)

> 現在我們準備請 Google 的視覺 AI 來幫忙「看懂」照片上有什麼中文字。

### 3-1. 實作 OCR 掃描服務 (`OcrService`)
建立檔案 `lib/features/scanner/data/ocr_service.dart`：
```dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  // 指定我們要辨識「繁體中文」
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);

  Future<String> processImage(String imagePath) async {
    // 把照片位址包裝成 ML Kit 懂的格式
    final inputImage = InputImage.fromFilePath(imagePath);
    // 送給機器人去判讀，經過一秒鐘後，它會吐一大串未分類的純文字回來
    final recognizedText = await _textRecognizer.processImage(inputImage);
    return recognizedText.text;
  }
}
```

### 3-2. 實作發票文字解析器 (`InvoiceParser`)
雖然機器人看懂了中文字，但它不知道哪段是日期、哪段是金額。你必須寫出「篩選器」。
建立 `lib/features/scanner/data/invoice_parser.dart`：
```dart
class InvoiceParser {
  static ParsedResult parse(String ocrText) {
    String? invNum;
    
    // 像查字典一樣：尋找「連續 2 個英文 + 減號(可有可無) + 連續 8 個數字」的組合
    final numRegex = RegExp(r'[A-Za-z]{2}-?\d{8}');
    final match = numRegex.firstMatch(ocrText);
    if (match != null) {
      invNum = match.group(0);
    }
    
    // 你可以依樣畫葫蘆去寫找日期、找金額的邏輯
    return ParsedResult(invoiceNumber: invNum);
  }
}
```

---

## 🚦 Step 4: 把齒輪接起來 — Riverpod 狀態管理 (State Flow)

> 這是大腦。把 Step 3 (辨識功能) 跟 Step 2 (資料模型)，都在這裡面組裝起來跑流程。

建立檔案 `lib/features/scanner/presentation/scanner_provider.dart`：
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 建立用來管理「有沒有在轉圈圈 Loading？」、「照片抓到沒？」的 Notifier
class ScannerNotifier extends StateNotifier<ScannerState> {
  ScannerNotifier() : super(ScannerState(isLoading: false));

  // 請注意這段非同步流程：
  Future<void> processCapturedImage(String imagePath) async {
    // 1. 告訴畫面：「我要開始花了，請給我顯示轉圈圈(Loading)」
    state = state.copyWith(isLoading: true);
    
    // 2. 呼叫 Step 3 的 AI 把純文字抓回來
    final rawText = await OcrService().processImage(imagePath);
    
    // 3. 呼叫 Step 3 的 Parsing 去抓發票號碼
    final parsedData = InvoiceParser.parse(rawText);
    
    // 4. 把它組合成 Step 2 我們定義的「發票實體 InvoiceEntity」
    final entity = InvoiceEntity(
      id: "隨機亂碼...",
      invoiceNumber: parsedData.invoiceNumber,
      imageLocalPath: imagePath,
    );
    
    // 5. 告訴畫面：「我做完了！不准再轉圈圈了，而且給妳熱騰騰的發票結果！」
    state = state.copyWith(isLoading: false, result: entity);
  }
}
```

---

## 🎨 Step 5: 開始畫畫面！(UI & Routing)

> 千呼萬喚始出來！我們在前台放按鈕，來呼叫我們在幕後佈置好的種種大軍。

### 5-1. 設定 GoRouter 導覽列 (`main.dart`)
把你專案進入點 `main.dart` 改成這樣：
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

void main() {
  // ProviderScope 非常重要！有了它，我們剛才寫的 Riverpod 大腦才會生效
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      // 設定好你的 /scan 拍照頁面、和 /invoices 清單頁面
      routerConfig: GoRouter(...), 
    );
  }
}
```

### 5-2. 實作相機掃描頁 (`scanner_page.dart`)
在畫面上嵌入相機並呼叫 API：
```dart
// 這邊是示範按鈕觸發核心流程的概念
ElevatedButton(
  onPressed: () async {
    // 1. 強制相機把當前畫面截圖拍下來
    final rawImage = await _cameraController.takePicture();
    
    // 2. 呼叫你剛才在 Step 4 寫好的 Riverpod 大腦！
    ref.read(scannerProvider.notifier).processCapturedImage(rawImage.path);
    
    // 3. 等大腦跑完，畫面就準備切換到下一個預覽頁面囉！
  },
  child: Icon(Icons.camera),
)
```
⚠️ **死亡陷阱警告**：退出相機頁面時，一定要在 `dispose()` 裡面寫下 `_cameraController.dispose();`。如果不把相機還給系統，使用者的手機等一下就會嚴重發燙甚至閃退！

### 5-3. 實作修改明細頁 (`invoice_detail_page.dart`)
因為世界上沒有 100% 完美的 AI，就算掃描結果出來了，也一定會有錯字。
所以這個頁面要拿好幾個 `TextField` (文字輸入框)，把剛才 AI 算出來的發票號碼填進去，讓使用者可以自己點擊畫面來手動打字覆蓋它。

最後，右上角放一個打勾按鈕 `Icon(Icons.check)`，按下去時呼叫 Step 2 的 `LocalStorageService` 把心血結晶永遠存進 JSON 裡面。

> **🎉 大功告成！你憑藉一己之力完成了一個具備「硬體相機控制、本地持久化存取、機器視覺 AI 分析」的超強大商業級小 APP！**
