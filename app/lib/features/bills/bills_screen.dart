import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/inr.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/repositories/bill_repo.dart';
import '../auth/auth_controller.dart';

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  final _billNumFromCtrl = TextEditingController();
  final _billNumToCtrl = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  int _page = 1;
  Future<BillPage>? _future;

  @override
  void initState() {
    super.initState();
    // Default: this month
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = now;
    _load();
  }

  @override
  void dispose() {
    _billNumFromCtrl.dispose();
    _billNumToCtrl.dispose();
    super.dispose();
  }

  void _load() {
    _future = ref.read(billRepoProvider).list(
          page: _page,
          perPage: 25,
          fromDate: _fromDate,
          toDate: _toDate,
          billNumberFrom: _billNumFromCtrl.text.trim(),
          billNumberTo: _billNumToCtrl.text.trim(),
        );
    setState(() {});
  }

  Future<void> _pick({required bool from}) async {
    final initial = (from ? _fromDate : _toDate) ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) {
      setState(() {
        if (from) {
          _fromDate = d;
        } else {
          _toDate = d;
        }
      });
    }
  }

  void _printBatch() {
    if (_fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick from & to dates first')),
      );
      return;
    }
    final from = _fromDate!.toIso8601String().split('T').first;
    final to = _toDate!.toIso8601String().split('T').first;
    context.go('/bills/batch-print?from=$from&to=$to');
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authControllerProvider).role == 'admin';
    return Padding(
      padding: const EdgeInsets.all(DT.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _filters(isAdmin),
          const SizedBox(height: DT.s16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: DT.surface,
                borderRadius: BorderRadius.circular(DT.rMd),
                border: Border.all(color: DT.border),
              ),
              child: FutureBuilder<BillPage>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Text(
                        snap.error.toString(),
                        style: const TextStyle(color: DT.err700),
                      ),
                    );
                  }
                  final page = snap.data!;
                  if (page.items.isEmpty) {
                    return const Center(
                      child: Text('No bills in this range.',
                          style: TextStyle(color: DT.text2)),
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                                minWidth: MediaQuery.of(context).size.width -
                                    DT.sidebarWidth -
                                    DT.s48),
                            child: DataTable(
                              headingRowHeight: 40,
                              dataRowMinHeight: DT.rowHeight,
                              dataRowMaxHeight: DT.rowHeight,
                              columns: const [
                                DataColumn(label: Text('Bill #')),
                                DataColumn(label: Text('Date')),
                                DataColumn(label: Text('Customer')),
                                DataColumn(label: Text('Total'), numeric: true),
                                DataColumn(label: Text('Paid'), numeric: true),
                                DataColumn(label: Text('Due'), numeric: true),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('')),
                              ],
                              rows: [
                                for (final b in page.items)
                                  DataRow(cells: [
                                    DataCell(Text(b.billNumber,
                                        style: AppTheme.mono(size: 12))),
                                    DataCell(Text(b.billDate
                                        .toIso8601String()
                                        .split('T')
                                        .first)),
                                    DataCell(Text(
                                        '${b.customerName ?? ''}${b.customerVillage == null ? '' : ' — ${b.customerVillage}'}')),
                                    DataCell(Text(fmtINR(b.totalAmount),
                                        style: AppTheme.mono(size: 12))),
                                    DataCell(Text(fmtINR(b.amountPaid),
                                        style: AppTheme.mono(size: 12))),
                                    DataCell(Text(fmtINR(b.balanceDue),
                                        style: AppTheme.mono(
                                            size: 12,
                                            color: b.balanceDue > 0
                                                ? DT.err700
                                                : DT.text2))),
                                    DataCell(_statusChip(b.status)),
                                    DataCell(IconButton(
                                      tooltip: 'View PDF',
                                      icon: const Icon(
                                          Icons.picture_as_pdf_outlined,
                                          size: 16),
                                      onPressed: () =>
                                          context.go('/bills/${b.id}/pdf'),
                                    )),
                                  ]),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: DT.divider),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: DT.s16, vertical: DT.s8),
                        child: Row(
                          children: [
                            Text(
                                '${page.total} bills · page ${page.page} of ${page.lastPage}',
                                style: const TextStyle(
                                    color: DT.text2, fontSize: DT.fsSm)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.chevron_left, size: 18),
                              onPressed: page.page > 1
                                  ? () {
                                      _page--;
                                      _load();
                                    }
                                  : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, size: 18),
                              onPressed: page.page < page.lastPage
                                  ? () {
                                      _page++;
                                      _load();
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(bool isAdmin) => Container(
        padding: const EdgeInsets.all(DT.s12),
        decoration: BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.circular(DT.rMd),
          border: Border.all(color: DT.border),
        ),
        child: Wrap(
          spacing: DT.s12,
          runSpacing: DT.s8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _dateBtn('From',
                _fromDate?.toIso8601String().split('T').first, () => _pick(from: true)),
            _dateBtn('To',
                _toDate?.toIso8601String().split('T').first, () => _pick(from: false)),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _billNumFromCtrl,
                decoration: const InputDecoration(labelText: 'Bill # from'),
              ),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _billNumToCtrl,
                decoration: const InputDecoration(labelText: 'Bill # to'),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                _page = 1;
                _load();
              },
              icon: const Icon(Icons.check, size: 14),
              label: const Text('Apply'),
            ),
            if (isAdmin)
              OutlinedButton.icon(
                onPressed: _printBatch,
                icon: const Icon(Icons.print_outlined, size: 14),
                label: const Text('Print filtered (9-up)'),
              ),
          ],
        ),
      );

  Widget _dateBtn(String label, String? value, VoidCallback onTap) =>
      OutlinedButton.icon(
        icon: const Icon(Icons.calendar_today, size: 14),
        label: Text('$label: ${value ?? '—'}'),
        onPressed: onTap,
      );

  Widget _statusChip(String s) {
    Color bg, fg;
    switch (s) {
      case 'cancelled':
        bg = DT.err50;
        fg = DT.err700;
        break;
      case 'draft':
        bg = DT.surface3;
        fg = DT.text2;
        break;
      default:
        bg = DT.ok50;
        fg = DT.ok700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DT.s8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DT.rXs),
      ),
      child: Text(
        s,
        style: TextStyle(
            color: fg, fontSize: DT.fsSm, fontWeight: FontWeight.w600),
      ),
    );
  }
}
