import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);

  Future<String> processImage(String imagePath) async {
    debugPrint("--- 開始處理圖片 ---");

    // 1. 先執行 OCR 辨識 (確保就算網路斷了也能拿到文字)
    String resultText = "";
    try {
      debugPrint("正在啟動本地 ML Kit 辨識...");
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      resultText = recognizedText.text;
      debugPrint("本地辨識完成，字數: ${resultText.length}");
    } catch (e) {
      debugPrint("本地 OCR 失敗: $e");
    }

    // 2. 嘗試背景上傳給 PHP (這部分失敗也沒關係，不影響辨識結果)
    try {
      // 請在此處確認你的 IP 是否正確，如果不確定，可以先註解掉這段
      var uri = Uri.parse("http://172.20.10.2/project_api/api.php"); 
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
      request.fields['type'] = '二值化';

      debugPrint("嘗試背景上傳伺服器...");
      // 把超時設短一點，才不會等太久
      await http.Response.fromStream(await request.send()).timeout(const Duration(seconds: 2));
      debugPrint("伺服器連線成功");
    } catch (e) {
      debugPrint("伺服器連線失敗 (這不影響辨識結果): $e");
    }

    return resultText;
  }

  void dispose() {
    _textRecognizer.close();
  }
}