import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../models/customer.dart';

/// Paginated slice returned by [CustomerRepo.list].
class CustomerPage {
  final List<Customer> items;
  final int page;
  final int perPage;
  final int total;
  final int lastPage;
  CustomerPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });
}

/// Methods map 1-1 to backend customer endpoints. Any screen that touches
/// customer data should go through this class and not call [ApiClient]
/// directly.
class CustomerRepo {
  final ApiClient _api;
  CustomerRepo(this._api);

  /// Paginated list with optional search ([q]) and status filter.
  Future<CustomerPage> list({int page = 1, int perPage = 25, String? q, String? status}) async {
    final env = await _api.requestEnvelope('GET', '/customers', query: {
      'page': page,
      'per_page': perPage,
      if (q != null && q.isNotEmpty) 'q': q,
      if (status != null) 'status': status,
    });
    final items = (env['data'] as List)
        .map((e) => Customer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final meta = Map<String, dynamic>.from(env['meta'] as Map? ?? {});
    return CustomerPage(
      items: items,
      page: meta['page'] as int? ?? page,
      perPage: meta['per_page'] as int? ?? perPage,
      total: meta['total'] as int? ?? items.length,
      lastPage: meta['last_page'] as int? ?? 1,
    );
  }

  /// Typeahead search used by the New Bill customer picker.
  /// Empty query short-circuits to an empty list (no network call).
  Future<List<Customer>> search(String q) async {
    if (q.trim().isEmpty) return [];
    final data = await _api.request('GET', '/customers/search', query: {'q': q});
    return (data as List)
        .map((e) => Customer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Fetches a single customer by id.
  Future<Customer> get(int id) async {
    final data = await _api.request('GET', '/customers/$id');
    return Customer.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Creates a new customer. `body` typically comes from
  /// [Customer.toCreateJson].
  Future<Customer> create(Map<String, dynamic> body) async {
    final data = await _api.request('POST', '/customers', data: body);
    return Customer.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Updates an existing customer (full PUT).
  Future<Customer> update(int id, Map<String, dynamic> body) async {
    final data = await _api.request('PUT', '/customers/$id', data: body);
    return Customer.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Soft-deletes a customer on the backend (admin-only). The row is kept
  /// for history but excluded from lists.
  Future<void> delete(int id) async {
    await _api.request('DELETE', '/customers/$id');
  }

  /// Toggles `status` between active/inactive without deleting the record.
  Future<Customer> setActive(int id, bool active) async {
    final data = await _api.request('PATCH', '/customers/$id/active',
        query: {'active': active});
    return Customer.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Bulk import customers from an Excel/CSV file.
  /// Returns the import summary: { imported, skipped, errors: [...] }
  Future<Map<String, dynamic>> importExcel({
    required List<int> bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final data = await _api.request('POST', '/customers/import', data: form);
    return Map<String, dynamic>.from(data as Map);
  }
}
