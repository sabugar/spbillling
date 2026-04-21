double _asDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

class Customer {
  final int id;
  final String customerCode;
  final String name;
  final String mobile;
  final String? altMobile;
  final String village;
  final String? city;
  final String? district;
  final String? state;
  final String? pincode;
  final String? fullAddress;
  final String customerType; // domestic | commercial
  final String status; // active | inactive
  final double balance;
  final int emptyPending;
  final String? notes;
  final bool isDeleted;

  Customer({
    required this.id,
    required this.customerCode,
    required this.name,
    required this.mobile,
    this.altMobile,
    required this.village,
    this.city,
    this.district,
    this.state,
    this.pincode,
    this.fullAddress,
    required this.customerType,
    required this.status,
    required this.balance,
    required this.emptyPending,
    this.notes,
    required this.isDeleted,
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as int,
        customerCode: j['customer_code'] as String? ?? '',
        name: j['name'] as String,
        mobile: j['mobile'] as String,
        altMobile: j['alt_mobile'] as String?,
        village: j['village'] as String,
        city: j['city'] as String?,
        district: j['district'] as String?,
        state: j['state'] as String?,
        pincode: j['pincode'] as String?,
        fullAddress: j['full_address'] as String?,
        customerType: j['customer_type'] as String? ?? 'domestic',
        status: j['status'] as String? ?? 'active',
        balance: _asDouble(j['balance']),
        emptyPending: _asInt(j['empty_pending']),
        notes: j['notes'] as String?,
        isDeleted: j['is_deleted'] as bool? ?? false,
      );

  Map<String, dynamic> toCreateJson() => {
        'name': name,
        'mobile': mobile,
        if (altMobile?.isNotEmpty == true) 'alt_mobile': altMobile,
        'village': village,
        if (city?.isNotEmpty == true) 'city': city,
        if (district?.isNotEmpty == true) 'district': district,
        if (state?.isNotEmpty == true) 'state': state,
        if (pincode?.isNotEmpty == true) 'pincode': pincode,
        if (fullAddress?.isNotEmpty == true) 'full_address': fullAddress,
        'customer_type': customerType,
        'status': status,
        if (notes?.isNotEmpty == true) 'notes': notes,
      };
}
