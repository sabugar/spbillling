import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';

class DailyRegisterRow {
  final DateTime date;
  final String billFrom;
  final String billTo;
  final int qty;
  final double total;

  DailyRegisterRow({
    required this.date,
    required this.billFrom,
    required this.billTo,
    required this.qty,
    required this.total,
  });

  factory DailyRegisterRow.fromJson(Map<String, dynamic> j) =>
      DailyRegisterRow(
        date: DateTime.parse(j['date'] as String),
        billFrom: (j['bill_from'] ?? '') as String,
        billTo: (j['bill_to'] ?? '') as String,
        qty: (j['qty'] as num?)?.toInt() ?? 0,
        total: double.tryParse('${j['total'] ?? 0}') ?? 0.0,
      );
}

class DoRegisterRow {
  final int doId;
  final String doCode;
  final String doName;
  final String? doLocation;
  final DateTime date;
  final String billFrom;
  final String billTo;
  final int qty;
  final double total;

  DoRegisterRow({
    required this.doId,
    required this.doCode,
    required this.doName,
    this.doLocation,
    required this.date,
    required this.billFrom,
    required this.billTo,
    required this.qty,
    required this.total,
  });

  factory DoRegisterRow.fromJson(Map<String, dynamic> j) => DoRegisterRow(
        doId: (j['do_id'] as num).toInt(),
        doCode: j['do_code'] as String? ?? '',
        doName: j['do_name'] as String? ?? '',
        doLocation: j['do_location'] as String?,
        date: DateTime.parse(j['date'] as String),
        billFrom: (j['bill_from'] ?? '') as String,
        billTo: (j['bill_to'] ?? '') as String,
        qty: (j['qty'] as num?)?.toInt() ?? 0,
        total: double.tryParse('${j['total'] ?? 0}') ?? 0.0,
      );
}

class ReportRepo {
  final ApiClient _api;
  ReportRepo(this._api);

  String _d(DateTime v) => v.toIso8601String().split('T').first;

  /// One row per day in the range (date, bill# from, bill# to, qty, total).
  Future<List<DailyRegisterRow>> dailyRegister({
    required DateTime fromDate,
    required DateTime toDate,
    int? doId,
  }) async {
    final data = await _api.request(
      'GET',
      '/reports/register/daily',
      query: {
        'from': _d(fromDate),
        'to': _d(toDate),
        if (doId != null) 'do_id': doId,
      },
    );
    return (data as List)
        .map((e) => DailyRegisterRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// One row per (DO, day). Pass `doId` to scope to one outlet.
  Future<List<DoRegisterRow>> doRegister({
    required DateTime fromDate,
    required DateTime toDate,
    int? doId,
  }) async {
    final data = await _api.request(
      'GET',
      '/reports/register/do',
      query: {
        'from': _d(fromDate),
        'to': _d(toDate),
        if (doId != null) 'do_id': doId,
      },
    );
    return (data as List)
        .map((e) => DoRegisterRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Daily Register exported as Excel or PDF. `format` is `'excel'` or `'pdf'`.
  Future<List<int>> dailyRegisterExportBytes({
    required DateTime fromDate,
    required DateTime toDate,
    required String format,
    int? doId,
  }) async {
    final bytes = await _api.request(
      'GET',
      '/reports/register/daily/export',
      query: {
        'from': _d(fromDate),
        'to': _d(toDate),
        'fmt': format,
        if (doId != null) 'do_id': doId,
      },
      responseType: ResponseType.bytes,
    );
    return List<int>.from(bytes as List);
  }

  /// DO Register exported as Excel or PDF.
  Future<List<int>> doRegisterExportBytes({
    required DateTime fromDate,
    required DateTime toDate,
    required String format,
    int? doId,
  }) async {
    final bytes = await _api.request(
      'GET',
      '/reports/register/do/export',
      query: {
        'from': _d(fromDate),
        'to': _d(toDate),
        'fmt': format,
        if (doId != null) 'do_id': doId,
      },
      responseType: ResponseType.bytes,
    );
    return List<int>.from(bytes as List);
  }
}
