import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../models/bill.dart';

class BillRepo {
  final ApiClient _api;
  BillRepo(this._api);

  Future<Bill> create({
    required int customerId,
    required DateTime billDate,
    required List<BillItemDraft> items,
    required double discount,
    required double amountPaid,
    required String paymentMode,
    String? notes,
    Map<String, dynamic>? chequeDetails,
  }) async {
    final body = {
      'customer_id': customerId,
      'bill_date': billDate.toIso8601String().split('T').first,
      'discount': discount,
      'amount_paid': amountPaid,
      'payment_mode': paymentMode,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (chequeDetails != null) 'cheque_details': chequeDetails,
      'items': items.map((i) => i.toJson()).toList(),
    };
    final data = await _api.request('POST', '/bills', data: body);
    return Bill.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Bill> get(int id) async {
    final data = await _api.request('GET', '/bills/$id');
    return Bill.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<int>> fetchBillPdfBytes(int id) async {
    final bytes = await _api.request(
      'GET',
      '/bills/$id/pdf',
      responseType: ResponseType.bytes,
    );
    return List<int>.from(bytes as List);
  }

  Future<Map<String, dynamic>?> dashboard() async {
    final data = await _api.request('GET', '/reports/dashboard');
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }
}
