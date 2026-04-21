import '../../core/api/api_client.dart';
import '../models/distributor_outlet.dart';

class DOPage {
  final List<DistributorOutlet> items;
  final int page;
  final int perPage;
  final int total;
  final int lastPage;
  DOPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });
}

class DORepo {
  final ApiClient _api;
  DORepo(this._api);

  Future<DOPage> list({
    int page = 1,
    int perPage = 25,
    String? q,
    bool? active,
  }) async {
    final env = await _api.requestEnvelope('GET', '/distributor-outlets', query: {
      'page': page,
      'per_page': perPage,
      if (q != null && q.isNotEmpty) 'q': q,
      if (active != null) 'active': active,
    });
    final items = (env['data'] as List)
        .map((e) => DistributorOutlet.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final meta = Map<String, dynamic>.from(env['meta'] as Map? ?? {});
    return DOPage(
      items: items,
      page: meta['page'] as int? ?? page,
      perPage: meta['per_page'] as int? ?? perPage,
      total: meta['total'] as int? ?? items.length,
      lastPage: meta['last_page'] as int? ?? 1,
    );
  }

  Future<List<DistributorOutlet>> search(String q, {int limit = 20}) async {
    if (q.trim().isEmpty) return [];
    final data = await _api.request('GET', '/distributor-outlets/search',
        query: {'q': q, 'limit': limit});
    return (data as List)
        .map((e) => DistributorOutlet.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<DistributorOutlet> get(int id) async {
    final data = await _api.request('GET', '/distributor-outlets/$id');
    return DistributorOutlet.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<DistributorOutlet> create(DistributorOutlet outlet) async {
    final data = await _api.request('POST', '/distributor-outlets',
        data: outlet.toCreateJson());
    return DistributorOutlet.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<DistributorOutlet> update(int id, DistributorOutlet outlet) async {
    final data = await _api.request('PUT', '/distributor-outlets/$id',
        data: outlet.toUpdateJson());
    return DistributorOutlet.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<DistributorOutlet> setActive(int id, bool active) async {
    final data = await _api.request('PATCH', '/distributor-outlets/$id/active',
        query: {'active': active});
    return DistributorOutlet.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> delete(int id) async {
    await _api.request('DELETE', '/distributor-outlets/$id');
  }
}
