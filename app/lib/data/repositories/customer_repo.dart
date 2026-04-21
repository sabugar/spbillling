import '../../core/api/api_client.dart';
import '../models/customer.dart';

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

class CustomerRepo {
  final ApiClient _api;
  CustomerRepo(this._api);

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

  Future<List<Customer>> search(String q) async {
    if (q.trim().isEmpty) return [];
    final data = await _api.request('GET', '/customers/search', query: {'q': q});
    return (data as List)
        .map((e) => Customer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Customer> get(int id) async {
    final data = await _api.request('GET', '/customers/$id');
    return Customer.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Customer> create(Map<String, dynamic> body) async {
    final data = await _api.request('POST', '/customers', data: body);
    return Customer.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Customer> update(int id, Map<String, dynamic> body) async {
    final data = await _api.request('PUT', '/customers/$id', data: body);
    return Customer.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> delete(int id) async {
    await _api.request('DELETE', '/customers/$id');
  }

  Future<Customer> setActive(int id, bool active) async {
    final data = await _api.request('PATCH', '/customers/$id/active',
        query: {'active': active});
    return Customer.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
