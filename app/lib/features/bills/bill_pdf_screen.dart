import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../core/providers.dart';
import '../../core/theme/design_tokens.dart';

class BillPdfScreen extends ConsumerStatefulWidget {
  final int billId;
  const BillPdfScreen({super.key, required this.billId});

  @override
  ConsumerState<BillPdfScreen> createState() => _BillPdfScreenState();
}

class _BillPdfScreenState extends ConsumerState<BillPdfScreen> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Uint8List> _load() async {
    final bytes = await ref
        .read(billRepoProvider)
        .fetchBillPdfBytes(widget.billId);
    return Uint8List.fromList(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 18),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text('Bill #${widget.billId}'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/bills/new'),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Bill'),
          ),
          const SizedBox(width: DT.s8),
        ],
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
            pdfFileName: 'bill-${widget.billId}.pdf',
          );
        },
      ),
    );
  }
}
