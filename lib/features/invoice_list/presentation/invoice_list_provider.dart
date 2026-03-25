/// 發票清單資料狀態管理 (Invoice List Provider)
/// 
/// 管理所有已儲存發票的列表清單非同步狀態，包含初始化讀取、排序、刪除處理等邏輯。
/// 支援 AsyncValue 以便在 UI 層輕鬆處理 loading 與 error 狀態。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../scanner/domain/entities/invoice_entity.dart';
import '../../invoice_detail/presentation/invoice_detail_provider.dart';
import '../../../shared/services/local_storage_service.dart';

/// 全域提供的清單 Provider
final invoiceListProvider = StateNotifierProvider<InvoiceListNotifier, AsyncValue<List<InvoiceEntity>>>((ref) {
  // 從 shared provider 共用同一個 localStorageService
  final storage = ref.watch(localStorageServiceProvider);
  return InvoiceListNotifier(storage);
});

class InvoiceListNotifier extends StateNotifier<AsyncValue<List<InvoiceEntity>>> {
  final LocalStorageService _storage;

  InvoiceListNotifier(this._storage) : super(const AsyncValue.loading()) {
    // 建立元件時就立刻進行第一次向下的快取讀取
    loadInvoices();
  }

  /// 讀取本地端的所有發票紀錄
  Future<void> loadInvoices() async {
    try {
      // 設置為載入中狀態
      state = const AsyncValue.loading();
      
      final invoices = await _storage.readInvoices();
      
      // 按照發票開立的日期進行排序 (由新到舊)
      invoices.sort((a, b) => (b.date ?? DateTime.now()).compareTo(a.date ?? DateTime.now()));
      
      // 更新狀態為成功取得清單資料
      state = AsyncValue.data(invoices);
    } catch (e, st) {
      // 更新狀態為錯誤，供 UI 捕捉繪製
      state = AsyncValue.error(e, st);
    }
  }

  /// 刪除特定發票
  Future<void> deleteInvoice(String id) async {
    try {
      await _storage.deleteInvoice(id);
      await loadInvoices(); // 刪除完畢後再次觸發刷新清單
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
