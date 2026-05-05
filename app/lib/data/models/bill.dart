// Models for bill drafts (in-progress bill being composed on screen) and
// confirmed bills fetched from the backend.
//
// The key rule implemented here: rate is GST-inclusive. The UI shows
// the total as `qty * rate`, and GST / base are derived by reverse math
// so the printed grand total always equals what the user typed.

/// Coerces dynamic JSON values (num, String, null) to a double.
double _d(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

/// Coerces dynamic JSON values (num, String, null) to an int.
int _i(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

/// One editable row in the New Bill screen before the bill is saved.
///
/// Holds a reference to the selected variant plus user-entered qty / rate /
/// empty-returned count. Use the getters for the GST-inclusive line math.
class BillItemDraft {
  int variantId;
  String variantLabel;
  int quantity;
  double rate;
  int emptyReturned;
  double gstRate;

  BillItemDraft({
    required this.variantId,
    required this.variantLabel,
    this.quantity = 1,
    this.rate = 0,
    this.emptyReturned = 0,
    this.gstRate = 0,
  });

  // Rate is GST-INCLUSIVE. Total is rate*qty; GST/base derived by reverse math.
  double get lineTotal => quantity * rate;
  double get lineGst => lineTotal * gstRate / (100.0 + gstRate);
  double get lineBase => lineTotal - lineGst;
  // Legacy alias — still means "excl. GST" (renamed conceptually to base).
  double get lineSubtotal => lineBase;

  Map<String, dynamic> toJson() => {
        'product_variant_id': variantId,
        'quantity': quantity,
        'rate': rate,
        'empty_returned': emptyReturned,
        'gst_rate': gstRate,
      };
}

/// Read-only bill as returned by the backend list/detail endpoints.
///
/// The backend flattens customer name/village into the JSON (either at the
/// top level or inside a nested `customer` object); [fromJson] tolerates
/// both shapes.
class Bill {
  final int id;
  final String billNumber;
  final DateTime billDate;
  final int customerId;
  final String? customerName;
  final String? customerMobile;
  final String? customerVillage;
  final double subtotal;
  final double gstAmount;
  final double discount;
  final double totalAmount;
  final double amountPaid;
  final double balanceDue;
  final String paymentMode;
  final String status;
  final String? notes;
  final List<Map<String, dynamic>> items;

  Bill({
    required this.id,
    required this.billNumber,
    required this.billDate,
    required this.customerId,
    this.customerName,
    this.customerMobile,
    this.customerVillage,
    required this.subtotal,
    required this.gstAmount,
    required this.discount,
    required this.totalAmount,
    required this.amountPaid,
    required this.balanceDue,
    required this.paymentMode,
    required this.status,
    this.notes,
    required this.items,
  });

  factory Bill.fromJson(Map<String, dynamic> j) {
    final cust = j['customer'];
    final Map<String, dynamic>? custMap =
        cust is Map ? Map<String, dynamic>.from(cust) : null;
    return Bill(
        id: _i(j['id']),
        billNumber: j['bill_number'] as String? ?? '',
        billDate: DateTime.tryParse(j['bill_date'] as String? ?? '') ??
            DateTime.now(),
        customerId: _i(j['customer_id']),
        customerName: custMap?['name'] as String? ?? j['customer_name'] as String?,
        customerMobile:
            custMap?['mobile'] as String? ?? j['customer_mobile'] as String?,
        customerVillage:
            custMap?['village'] as String? ?? j['customer_village'] as String?,
        subtotal: _d(j['subtotal']),
        gstAmount: _d(j['gst_amount']),
        discount: _d(j['discount']),
        totalAmount: _d(j['total_amount']),
        amountPaid: _d(j['amount_paid']),
        balanceDue: _d(j['balance_due']),
        paymentMode: j['payment_mode'] as String? ?? 'cash',
        status: j['status'] as String? ?? 'confirmed',
        notes: j['notes'] as String?,
        items: (j['items'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
  }
}
