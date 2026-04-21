import '../../core/api/api_client.dart';
import '../models/product.dart';

class ProductRepo {
  final ApiClient _api;
  ProductRepo(this._api);

  Future<List<ProductCategory>> listCategories() async {
    final data = await _api.request('GET', '/products/categories');
    return (data as List)
        .map((e) => ProductCategory.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Product>> listProducts({int page = 1, int perPage = 100}) async {
    final env = await _api.requestEnvelope('GET', '/products',
        query: {'page': page, 'per_page': perPage});
    return (env['data'] as List)
        .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<ProductVariant>> listVariants({
    int page = 1,
    int perPage = 200,
    String? q,
    bool? active,
    bool includeInactive = false,
  }) async {
    final env = await _api.requestEnvelope('GET', '/products/variants/list', query: {
      'page': page,
      'per_page': perPage,
      if (q != null && q.isNotEmpty) 'q': q,
      // Backend param is `include_inactive`. If caller explicitly asks for
      // active-only, we still pass include_inactive=false. If caller asks for
      // inactive too, pass include_inactive=true.
      'include_inactive': includeInactive || active == false,
    });
    return (env['data'] as List)
        .map((e) => ProductVariant.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ProductCategory> createCategory(String name) async {
    final data = await _api.request('POST', '/products/categories', data: {'name': name});
    return ProductCategory.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Product> createProduct(Map<String, dynamic> body) async {
    final data = await _api.request('POST', '/products', data: body);
    return Product.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<ProductVariant> createVariant(Map<String, dynamic> body) async {
    final data = await _api.request('POST', '/products/variants', data: body);
    return ProductVariant.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<ProductVariant> updateVariant(int id, Map<String, dynamic> body) async {
    final data = await _api.request('PUT', '/products/variants/$id', data: body);
    return ProductVariant.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> deleteVariant(int id) async {
    await _api.request('DELETE', '/products/variants/$id');
  }

  Future<ProductVariant> setVariantActive(int id, bool active) async {
    return updateVariant(id, {'is_active': active});
  }
}
