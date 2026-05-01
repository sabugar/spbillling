// 9-up batch print preview — 9 bills per A4 page, used by admins to
// print a day's or a date-range's bills in one go.
//
// Fetches the PDF from `/api/bills/print/batch?from=&to=&format=9up`
// and displays it with the standard `printing` preview.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../core/providers.dart';
import '../../core/theme/design_tokens.dart';

/// Route `/bills/batch-print?from=&to=`.
class BillsBatchPdfScreen extends ConsumerStatefulWidget {
  final DateTime fromDate;
  final DateTime toDate;
  final String format; // '9up' or 'preprinted'
  final int? doId;
  final String? city;
  final String? billNumberFrom;
  final String? billNumberTo;

  const BillsBatchPdfScreen({
    super.key,
    required this.fromDate,
    required this.toDate,
    this.format = '9up',
    this.doId,
    this.city,
    this.billNumberFrom,
    this.billNumberTo,
  });

  @override
  ConsumerState<BillsBatchPdfScreen> createState() =>
      _BillsBatchPdfScreenState();
}

class _BillsBatchPdfScreenState extends ConsumerState<BillsBatchPdfScreen> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// Downloads the 9-up PDF for the selected date range.
  Future<Uint8List> _load() async {
    final bytes = await ref.read(billRepoProvider).fetchBatchPdfBytes(
          fromDate: widget.fromDate,
          toDate: widget.toDate,
          format: widget.format,
          doId: widget.doId,
          city: widget.city,
          billNumberFrom: widget.billNumberFrom,
          billNumberTo: widget.billNumberTo,
        );
    return Uint8List.fromList(bytes);
  }

  String get _label =>
      widget.format == 'preprinted' ? 'pre-printed 6-up' : '9-up';

  @override
  Widget build(BuildContext context) {
    final from = widget.fromDate.toIso8601String().split('T').first;
    final to = widget.toDate.toIso8601String().split('T').first;
    return Scaffold(
      backgroundColor: DT.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 18),
          onPressed: () => context.go('/bills'),
        ),
        title: Text('Bills $from → $to ($_label)'),
      ),
      body: FutureBuilder<Uint8List>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(snap.error.toString(),
                  style: const TextStyle(color: DT.err700)),
            );
          }
          final fnameSuffix =
              widget.format == 'preprinted' ? '-preprinted' : '';
          return PdfPreview(
            build: (_) async => snap.data!,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            pdfFileName: 'bills-$from-to-$to$fnameSuffix.pdf',
          );
        },
      ),
    );
  }
}
