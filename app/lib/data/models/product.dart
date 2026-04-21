double _d(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

int _i(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

class ProductCategory {
  final int id;
  final String name;
  final bool isActive;
  ProductCategory({required this.id, required this.name, required this.isActive});
  factory ProductCategory.fromJson(Map<String, dynamic> j) => ProductCategory(
        id: j['id'] as int,
        name: j['name'] as String,
        isActive: j['is_active'] as bool? ?? true,
      );
}

class ProductVariant {
  final int id;
  final int productId;
  final String name;
  final String? skuCode;
  final double unitPrice;
  final double depositAmount;
  final double gstRate;
  final int stockQuantity;
  final bool isActive;
  final String? productName;
  final String? categoryName;
  final bool? isReturnable;
  final String? hsnCode;

  ProductVariant({
    required this.id,
    required this.productId,
    required this.name,
    this.skuCode,
    required this.unitPrice,
    required this.depositAmount,
    required this.gstRate,
    required this.stockQuantity,
    required this.isActive,
    this.productName,
    this.categoryName,
    this.isReturnable,
    this.hsnCode,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> j) => ProductVariant(
        id: j['id'] as int,
        productId: _i(j['product_id']),
        name: j['name'] as String,
        skuCode: j['sku_code'] as String?,
        unitPrice: _d(j['unit_price']),
        depositAmount: _d(j['deposit_amount']),
        gstRate: _d(j['gst_rate']),
        stockQuantity: _i(j['stock_quantity']),
        isActive: j['is_active'] as bool? ?? true,
        productName: j['product_name'] as String?,
        categoryName: j['category_name'] as String?,
        isReturnable: j['is_returnable'] as bool?,
        hsnCode: j['hsn_code'] as String?,
      );

  String get displayName {
    final p = productName ?? '';
    return p.isEmpty ? name : '$p — $name';
  }
}

class Product {
  final int id;
  final int categoryId;
  final String name;
  final bool isReturnable;
  final String? hsnCode;
  final String? unitOfMeasure;
  final bool isActive;
  final List<ProductVariant> variants;

  Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.isReturnable,
    this.hsnCode,
    this.unitOfMeasure,
    required this.isActive,
    required this.variants,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as int,
        categoryId: _i(j['category_id']),
        name: j['name'] as String,
        isReturnable: j['is_returnable'] as bool? ?? false,
        hsnCode: j['hsn_code'] as String?,
        unitOfMeasure: j['unit_of_measure'] as String?,
        isActive: j['is_active'] as bool? ?? true,
        variants: (j['variants'] as List? ?? [])
            .map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
            .toList(),
      );
}
