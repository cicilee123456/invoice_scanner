# 🧾 發票智慧辨識系統 (Invoice Scanner App)

這是一個基於 **Flutter** 開發的智慧發票管理工具，結合 **Google ML Kit** 與 **後端 Python 影像處理技術**，能自動從發票照片中擷取關鍵資訊。

## 🎯 作業目標達成說明
本專案已完整實作以下核心功能：
- **OCR 辨識**：整合 `google_mlkit_text_recognition` 進行中文與數字辨識。
- **影像前處理**：實作灰階、降噪、自適應二值化處理。
- **自動擷取**：自動解析發票號碼、日期與消費金額。
- **資料儲存**：辨識結果可儲存於 App 內進行管理，並可產出紀錄。

## 🛠️ 技術實作與檔案對照

### 1. 影像前處理 (Image Pre-processing)
**對應檔案：** `binarize.py` (後端 Python)
為了符合技術要求，本專案將圖片傳送至後端進行優化，流程如下：
- **灰階轉換**：減少運算量。
- **自適應二值化 (Adaptive Thresholding)**：解決光線不均問題，提升辨識率。
- **形態學操作**：連接斷裂文字。

### 2. 欄位自動解析 (Invoice Parsing)
**對應檔案：** `lib/features/scanner/data/invoice_parser.dart`
使用 **Regular Expression (正規表達式)** 進行資料擷取：
- **關鍵字辨識**：自動匹配「總計」、「經計」、「金額」等欄位抓取消費數字。

## 📸 前處理效果展示 (對比截圖)

| 原始發票照片 | 前處理後影像 (二值化) | App 自動填入結果 |
| :---: | :---: | :---: |
| <img width="200" src="https://github.com/user-attachments/assets/03cd02d5-c7ff-4e55-b4b2-e84e7c392fea" /> | <img width="200" src="https://github.com/user-attachments/assets/2451580b-3618-43e0-b878-9b44bec0abe3" /> | <img width="200" src="https://github.com/user-attachments/assets/df68e26f-6d31-4a92-bf03-546273e37577" /> |


> **說明：** 透過前處理優化，可大幅提升特殊字體（如初代花山拉麵）與模糊發票的辨識正確率。

---

## 🏃 如何安裝與執行
1. **後端環境**：啟動 XAMPP Apache，確保 `project_api` 資料夾位於 `htdocs`。
2. **Python 套件**：需安裝 `opencv-python`。
3. **前端設定**：確認 `ocr_service.dart` 中的 IP 位址（模擬器請用 `10.0.2.2`）。
4. **執行**：在終端機輸入 `flutter run`。
