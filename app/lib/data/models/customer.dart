import 'distributor_outlet.dart';

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
  final String? consumerNumber;
  final int doId;
  final DistributorOutlet? distributorOutlet;
  final String name;
  final String mobile;
  final String? altMobile;
  final String? village;
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
    this.consumerNumber,
    required this.doId,
    this.distributorOutlet,
    required this.name,
    required this.mobile,
    this.altMobile,
    this.village,
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
        consumerNumber: j['consumer_number'] as String?,
        doId: _asInt(j['do_id']),
        distributorOutlet: j['distributor_outlet'] != null
            ? DistributorOutlet.fromJson(
                Map<String, dynamic>.from(j['distributor_outlet'] as Map))
            : null,
        name: j['name'] as String,
        mobile: j['mobile'] as String,
        altMobile:
            (j['alternate_mobile'] ?? j['alt_mobile']) as String?,
        village: j['village'] as String?,
        city: j['city'] as String?,
        district: j['district'] as String?,
        state: j['state'] as String?,
        pincode: j['pincode'] as String?,
        fullAddress: j['full_address'] as String?,
        customerType: j['customer_type'] as String? ?? 'domestic',
        status: j['status'] as String? ?? 'active',
        balance: _asDouble(j['current_balance'] ?? j['balance']),
        emptyPending:
            _asInt(j['current_empty_bottles'] ?? j['empty_pending']),
        notes: j['notes'] as String?,
        isDeleted: j['is_deleted'] as bool? ?? false,
      );

  Map<String, dynamic> toCreateJson() => {
        if (consumerNumber?.isNotEmpty == true) 'consumer_number': consumerNumber,
        'do_id': doId,
        'name': name,
        'mobile': mobile,
        if (altMobile?.isNotEmpty == true) 'alternate_mobile': altMobile,
        if (village?.isNotEmpty == true) 'village': village,
        // Backend requires city (NOT NULL). Fall back to village or '-'.
        'city': (city?.isNotEmpty == true)
            ? city
            : (village?.isNotEmpty == true ? village : '-'),
        if (district?.isNotEmpty == true) 'district': district,
        if (state?.isNotEmpty == true) 'state': state,
        if (pincode?.isNotEmpty == true) 'pincode': pincode,
        if (fullAddress?.isNotEmpty == true) 'full_address': fullAddress,
        'customer_type': customerType,
        'status': status,
        if (notes?.isNotEmpty == true) 'notes': notes,
      };

  Map<String, dynamic> toUpdateJson() => {
        'consumer_number': consumerNumber,
        'do_id': doId,
        'name': name,
        'mobile': mobile,
        'alternate_mobile': altMobile,
        'village': village,
        'city': city,
        'district': district,
        'state': state,
        'pincode': pincode,
        'full_address': fullAddress,
        'customer_type': customerType,
        'status': status,
        'notes': notes,
      };
}
