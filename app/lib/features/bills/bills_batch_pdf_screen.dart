import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../core/providers.dart';
import '../../core/theme/design_tokens.dart';

class BillsBatchPdfScreen extends ConsumerStatefulWidget {
  final DateTime fromDate;
  final DateTime toDate;
  const BillsBatchPdfScreen({
    super.key,
    required this.fromDate,
    required this.toDate,
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

  Future<Uint8List> _load() async {
    final bytes = await ref.read(billRepoProvider).fetchBatchPdfBytes(
          fromDate: widget.fromDate,
          toDate: widget.toDate,
          format: '9up',
        );
    return Uint8List.fromList(bytes);
  }

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
        title: Text('Bills $from → $to (9-up)'),
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
          return PdfPreview(
            build: (_) async => snap.data!,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            pdfFileName: 'bills-$from-to-$to.pdf',
          );
        },
      ),
    );
  }
}
