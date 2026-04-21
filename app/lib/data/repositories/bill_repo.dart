import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../models/bill.dart';

class BillPage {
  final List<Bill> items;
  final int page;
  final int perPage;
  final int total;
  final int lastPage;
  BillPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });
}

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

  Future<BillPage> list({
    int page = 1,
    int perPage = 25,
    int? customerId,
    DateTime? fromDate,
    DateTime? toDate,
    String? billNumberFrom,
    String? billNumberTo,
    String? status,
  }) async {
    String? d(DateTime? v) => v?.toIso8601String().split('T').first;
    final env = await _api.requestEnvelope('GET', '/bills', query: {
      'page': page,
      'per_page': perPage,
      if (customerId != null) 'customer_id': customerId,
      if (fromDate != null) 'from': d(fromDate),
      if (toDate != null) 'to': d(toDate),
      if (billNumberFrom != null && billNumberFrom.isNotEmpty)
        'bill_number_from': billNumberFrom,
      if (billNumberTo != null && billNumberTo.isNotEmpty)
        'bill_number_to': billNumberTo,
      if (status != null && status.isNotEmpty) 'status': status,
    });
    final items = (env['data'] as List)
        .map((e) => Bill.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final meta = Map<String, dynamic>.from(env['meta'] as Map? ?? {});
    return BillPage(
      items: items,
      page: meta['page'] as int? ?? page,
      perPage: meta['per_page'] as int? ?? perPage,
      total: meta['total'] as int? ?? items.length,
      lastPage: meta['last_page'] as int? ?? 1,
    );
  }

  Future<List<int>> fetchBillPdfBytes(int id) async {
    final bytes = await _api.request(
      'GET',
      '/bills/$id/pdf',
      responseType: ResponseType.bytes,
    );
    return List<int>.from(bytes as List);
  }

  Future<List<int>> fetchBatchPdfBytes({
    required DateTime fromDate,
    required DateTime toDate,
    String format = '9up',
  }) async {
    String d(DateTime v) => v.toIso8601String().split('T').first;
    final bytes = await _api.request(
      'GET',
      '/bills/print/batch',
      query: {'from': d(fromDate), 'to': d(toDate), 'format': format},
      responseType: ResponseType.bytes,
    );
    return List<int>.from(bytes as List);
  }

  Future<String> nextBillNumber({DateTime? billDate}) async {
    final data = await _api.request(
      'GET',
      '/bills/next-number',
      query: {
        if (billDate != null)
          'bill_date': billDate.toIso8601String().split('T').first,
      },
    );
    if (data is Map && data['bill_number'] != null) {
      return data['bill_number'].toString();
    }
    return '';
  }

  Future<Map<String, dynamic>?> dashboard() async {
    final data = await _api.request('GET', '/reports/dashboard');
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }
}
