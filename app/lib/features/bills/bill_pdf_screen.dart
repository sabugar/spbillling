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
  String _billNumber = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  static String _shortBillNo(String full) =>
      full.contains('/') ? full.split('/').last : full;

  Future<Uint8List> _load() async {
    final repo = ref.read(billRepoProvider);
    // Fetch bill metadata + PDF in parallel; one quick API call gives us the
    // human bill number for the page title (not the internal db id).
    final results = await Future.wait([
      repo.get(widget.billId),
      repo.fetchBillPdfBytes(widget.billId),
    ]);
    final bill = results[0] as dynamic;
    final bytes = results[1] as List<int>;
    if (mounted) {
      setState(() => _billNumber = _shortBillNo(bill.billNumber as String));
    }
    return Uint8List.fromList(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final title = _billNumber.isEmpty ? 'Bill' : 'Bill #$_billNumber';
    return Scaffold(
      backgroundColor: DT.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 18),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text(title),
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
          final fname = _billNumber.isEmpty
              ? 'bill-${widget.billId}.pdf'
              : 'bill-$_billNumber.pdf';
          return PdfPreview(
            build: (_) async => snap.data!,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            pdfFileName: fname,
          );
        },
      ),
    );
  }
}
