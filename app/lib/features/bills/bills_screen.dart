// Bills list screen — the admin's gateway to old invoices.
//
// Supports:
//   * date-range filter (default: current month);
//   * bill-number range filter (accepts partial inputs like "1" or
//     "0005" and expands them to the full fiscal-year-prefixed form
//     before hitting the backend — see _normalizeBillNumber);
//   * pagination;
//   * per-row "View PDF" action;
//   * admin-only "Print filtered (9-up)" button that opens the
//     batch PDF preview.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/format/inr.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/bill.dart';
import '../../data/models/distributor_outlet.dart';
import '../../data/repositories/bill_repo.dart';
import '../auth/auth_controller.dart';
import '../customers/customer_form_dialog.dart' show DOTypeahead;

/// Route `/bills`. Lives inside the shell.
class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  final _billNumFromCtrl = TextEditingController();
  final _billNumToCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  DistributorOutlet? _selectedDO;
  int _page = 1;
  Future<BillPage>? _future;

  static final _dateFmt = DateFormat('dd MMM yy');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = now;
    _load();
  }

  @override
  void dispose() {
    _billNumFromCtrl.dispose();
    _billNumToCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  static String _shortBillNo(String full) {
    if (!full.contains('/')) return full;
    return full.split('/').last;
  }

  static String _fyPrefix(DateTime d) {
    final start = d.month >= 4 ? d.year % 100 : (d.year - 1) % 100;
    final end = d.month >= 4 ? (d.year + 1) % 100 : d.year % 100;
    return '${start.toString().padLeft(2, '0')}-${end.toString().padLeft(2, '0')}';
  }

  /// Expands a user-typed partial bill number into the canonical form the
  /// backend can compare lexicographically.
  ///
  ///   "1"        → "BILL/26-27/0001"
  ///   "0005"     → "BILL/26-27/0005"
  ///   "BILL/26-27/7" → "BILL/26-27/0007"
  ///
  /// Falls back to the raw (uppercased) input for unknown formats so
  /// power users can still paste exact numbers.
  String _normalizeBillNumber(String raw, DateTime refDate) {
    final v = raw.trim().toUpperCase();
    if (v.isEmpty) return '';
    final fy = _fyPrefix(refDate);
    if (RegExp(r'^\d+$').hasMatch(v)) {
      return 'BILL/$fy/${v.padLeft(4, '0')}';
    }
    final parts = v.split('/');
    if (parts.length == 3 && RegExp(r'^\d+$').hasMatch(parts[2])) {
      return '${parts[0]}/${parts[1]}/${parts[2].padLeft(4, '0')}';
    }
    return v;
  }

  /// Fires the backend query based on the current filter state.
  void _load() {
    final fromRef = _fromDate ?? DateTime.now();
    final toRef = _toDate ?? DateTime.now();
    _future = ref.read(billRepoProvider).list(
          page: _page,
          perPage: 10,
          fromDate: _fromDate,
          toDate: _toDate,
          billNumberFrom: _normalizeBillNumber(_billNumFromCtrl.text, fromRef),
          billNumberTo: _normalizeBillNumber(_billNumToCtrl.text, toRef),
          doId: _selectedDO?.id,
          city: _cityCtrl.text.trim(),
        );
    setState(() {});
  }

  /// Shows the date picker and updates either the `from` or `to` bound.
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

  void _printBatch({String format = 'preprinted'}) {
    if (_fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick from & to dates first')),
      );
      return;
    }
    final fromRef = _fromDate ?? DateTime.now();
    final toRef = _toDate ?? DateTime.now();
    final params = <String, String>{
      'from': _fromDate!.toIso8601String().split('T').first,
      'to': _toDate!.toIso8601String().split('T').first,
      'format': format,
    };
    final bnFrom = _normalizeBillNumber(_billNumFromCtrl.text, fromRef);
    final bnTo = _normalizeBillNumber(_billNumToCtrl.text, toRef);
    if (bnFrom.isNotEmpty) params['bill_number_from'] = bnFrom;
    if (bnTo.isNotEmpty) params['bill_number_to'] = bnTo;
    if (_selectedDO != null) params['do_id'] = _selectedDO!.id.toString();
    final cityVal = _cityCtrl.text.trim();
    if (cityVal.isNotEmpty) params['city'] = cityVal;
    final qs = params.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    context.go('/bills/batch-print?$qs');
  }

  void _clearFilters() {
    setState(() {
      _billNumFromCtrl.clear();
      _billNumToCtrl.clear();
      _cityCtrl.clear();
      _selectedDO = null;
    });
    _page = 1;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authControllerProvider).role == 'admin';
    return Padding(
      padding: const EdgeInsets.all(DT.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHeader(
            future: _future,
            onPrint: isAdmin ? () => _printBatch(format: 'preprinted') : null,
          ),
          const SizedBox(height: DT.s16),
          _filtersCard(),
          const SizedBox(height: DT.s16),
          Expanded(child: _tableCard()),
        ],
      ),
    );
  }

  // ---------------- filters card ----------------
  Widget _filtersCard() {
    return Container(
      padding: const EdgeInsets.all(DT.s12),
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1 — date range + bill # range
          Wrap(
            spacing: DT.s12,
            runSpacing: DT.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _DateRangeButton(
                label: 'From',
                value: _fromDate,
                onTap: () => _pick(from: true),
              ),
              _DateRangeButton(
                label: 'To',
                value: _toDate,
                onTap: () => _pick(from: false),
              ),
              SizedBox(
                width: 130,
                child: TextField(
                  controller: _billNumFromCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Bill # from',
                    hintText: '1',
                  ),
                  onSubmitted: (_) {
                    _page = 1;
                    _load();
                  },
                ),
              ),
              SizedBox(
                width: 130,
                child: TextField(
                  controller: _billNumToCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Bill # to',
                    hintText: '50',
                  ),
                  onSubmitted: (_) {
                    _page = 1;
                    _load();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: DT.s12),
          // Row 2 — DO + City + actions (DO expands to fill the row)
          Row(
            children: [
              Expanded(
                child: DOTypeahead(
                  key: ValueKey('bills-do-${_selectedDO?.id ?? 'none'}'),
                  initial: _selectedDO,
                  label: 'Distributor Outlet',
                  onChanged: (v) => setState(() => _selectedDO = v),
                ),
              ),
              const SizedBox(width: DT.s12),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _cityCtrl,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    hintText: 'e.g. Ahmedabad',
                  ),
                  onSubmitted: (_) {
                    _page = 1;
                    _load();
                  },
                ),
              ),
              const SizedBox(width: DT.s12),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.close, size: 14),
                label: const Text('Clear'),
                style: TextButton.styleFrom(foregroundColor: DT.text2),
              ),
              const SizedBox(width: DT.s4),
              ElevatedButton.icon(
                onPressed: () {
                  _page = 1;
                  _load();
                },
                icon: const Icon(Icons.search, size: 14),
                label: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- table card ----------------
  Widget _tableCard() {
    return Container(
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<BillPage>(
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
          final page = snap.data!;
          if (page.items.isEmpty) {
            return _EmptyState(onClear: _clearFilters);
          }
          return Column(
            children: [
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: MediaQuery.of(context).size.width -
                              DT.sidebarWidth -
                              DT.s48 -
                              2,
                        ),
                        child: DataTable(
                          headingRowHeight: 40,
                          headingRowColor:
                              WidgetStateProperty.all(DT.surface2),
                          headingTextStyle: const TextStyle(
                            fontSize: DT.fsSm,
                            fontWeight: FontWeight.w600,
                            color: DT.text2,
                            letterSpacing: 0.3,
                          ),
                          dataRowMinHeight: 48,
                          dataRowMaxHeight: 56,
                          horizontalMargin: DT.s16,
                          columnSpacing: DT.s24,
                          dividerThickness: 0.5,
                          columns: const [
                            DataColumn(label: Text('BILL #')),
                            DataColumn(label: Text('DATE')),
                            DataColumn(label: Text('CUSTOMER')),
                            DataColumn(label: Text('MODE')),
                            DataColumn(label: Text('TOTAL'), numeric: true),
                            DataColumn(label: Text('PAID'), numeric: true),
                            DataColumn(
                                label: Text('BALANCE'), numeric: true),
                            DataColumn(label: Text('STATUS')),
                            DataColumn(label: Text('')),
                          ],
                          rows: [
                            for (final b in page.items) _row(b),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: DT.divider),
              _footer(page),
            ],
          );
        },
      ),
    );
  }

  DataRow _row(Bill b) {
    final isCancelled = b.status == 'cancelled';
    return DataRow(cells: [
      DataCell(Text(
        '#${_shortBillNo(b.billNumber)}',
        style: AppTheme.mono(size: 12).copyWith(
          fontWeight: FontWeight.w600,
          color: isCancelled ? DT.text3 : DT.text,
        ),
      )),
      DataCell(Text(
        _dateFmt.format(b.billDate),
        style: const TextStyle(
            fontSize: DT.fsSm, color: DT.text2, fontFeatures: [
          FontFeature.tabularFigures(),
        ]),
      )),
      DataCell(_customerCell(b)),
      DataCell(_modeBadge(b.paymentMode)),
      DataCell(Text(fmtINR(b.totalAmount),
          style: AppTheme.mono(size: 12).copyWith(
              fontWeight: FontWeight.w600,
              color: isCancelled ? DT.text3 : DT.text))),
      DataCell(Text(fmtINR(b.amountPaid),
          style: AppTheme.mono(size: 12).copyWith(color: DT.text2))),
      DataCell(b.balanceDue > 0
          ? Text(fmtINR(b.balanceDue),
              style: AppTheme.mono(size: 12).copyWith(
                  fontWeight: FontWeight.w600,
                  color: isCancelled ? DT.text3 : DT.err700))
          : const Text('—',
              style: TextStyle(color: DT.text3, fontSize: DT.fsSm))),
      DataCell(_statusBadge(b)),
      DataCell(IconButton(
        tooltip: 'View / Print PDF',
        icon: const Icon(Icons.picture_as_pdf_outlined,
            size: 16, color: DT.brand700),
        onPressed: () => context.go('/bills/${b.id}/pdf'),
      )),
    ]);
  }

  Widget _customerCell(Bill b) {
    final name = (b.customerName ?? '').trim().isEmpty
        ? '—'
        : b.customerName!;
    final village = b.customerVillage;
    final hasVillage = village != null && village.isNotEmpty;
    return SizedBox(
      width: 220,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: DT.fsBody,
                  fontWeight: FontWeight.w600,
                  color: DT.text,
                  height: 1.2)),
          if (hasVillage)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(village,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: DT.fsSm, color: DT.text2, height: 1.2)),
            ),
        ],
      ),
    );
  }

  Widget _modeBadge(String mode) {
    Color bg, fg;
    switch (mode) {
      case 'cash':
        bg = DT.surface3;
        fg = DT.text2;
        break;
      case 'cheque':
        bg = DT.warn50;
        fg = DT.warn700;
        break;
      case 'upi':
        bg = DT.brand50;
        fg = DT.brand700;
        break;
      case 'card':
        bg = DT.brand50;
        fg = DT.brand700;
        break;
      case 'credit':
        bg = DT.err50;
        fg = DT.err700;
        break;
      default:
        bg = DT.surface3;
        fg = DT.text2;
    }
    return _Pill(label: mode, bg: bg, fg: fg);
  }

  Widget _statusBadge(Bill b) {
    if (b.status == 'cancelled') {
      return _Pill(label: 'cancelled', bg: DT.err50, fg: DT.err700);
    }
    if (b.status == 'draft') {
      return _Pill(label: 'draft', bg: DT.surface3, fg: DT.text2);
    }
    if (b.balanceDue <= 0) {
      return _Pill(label: 'paid', bg: DT.ok50, fg: DT.ok700);
    }
    if (b.amountPaid > 0) {
      return _Pill(label: 'partial', bg: DT.warn50, fg: DT.warn700);
    }
    return _Pill(label: 'unpaid', bg: DT.err50, fg: DT.err700);
  }

  Widget _footer(BillPage page) {
    final pageOutstanding =
        page.items.fold<double>(0, (s, b) => s + b.balanceDue);
    final pageTotal =
        page.items.fold<double>(0, (s, b) => s + b.totalAmount);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: DT.s16, vertical: DT.s8),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: DT.s12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Page ${page.page} of ${page.lastPage}',
                    style: const TextStyle(
                        color: DT.text2, fontSize: DT.fsSm)),
                Text('${page.items.length} on this page',
                    style: const TextStyle(
                        color: DT.text3, fontSize: DT.fsSm)),
                Text('Total ${fmtINR(pageTotal)}',
                    style:
                        AppTheme.mono(size: 12).copyWith(color: DT.text2)),
                Text(
                  pageOutstanding > 0
                      ? 'Outstanding ${fmtINR(pageOutstanding)}'
                      : 'All paid',
                  style: AppTheme.mono(size: 12).copyWith(
                      color:
                          pageOutstanding > 0 ? DT.err700 : DT.ok700,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 18),
            tooltip: 'Previous page',
            onPressed: page.page > 1
                ? () {
                    _page--;
                    _load();
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 18),
            tooltip: 'Next page',
            onPressed: page.page < page.lastPage
                ? () {
                    _page++;
                    _load();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

// ---------------- subcomponents ----------------

class _PageHeader extends StatelessWidget {
  final Future<BillPage>? future;
  final VoidCallback? onPrint;
  const _PageHeader({required this.future, this.onPrint});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bills',
                style: TextStyle(
                    fontSize: DT.fsH1,
                    fontWeight: FontWeight.w700,
                    color: DT.text,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 2),
              FutureBuilder<BillPage>(
                future: future,
                builder: (context, snap) {
                  String text;
                  if (snap.connectionState == ConnectionState.waiting ||
                      snap.data == null) {
                    text = 'Loading…';
                  } else {
                    final p = snap.data!;
                    text = '${p.total} ${p.total == 1 ? 'bill' : 'bills'} matched';
                  }
                  return Text(text,
                      style: const TextStyle(
                          fontSize: DT.fsSm, color: DT.text2));
                },
              ),
            ],
          ),
        ),
        if (onPrint != null)
          OutlinedButton.icon(
            onPressed: onPrint,
            icon: const Icon(Icons.print_outlined, size: 14),
            label: const Text('Print filtered (6-up)'),
          ),
      ],
    );
  }
}

class _DateRangeButton extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  static final _fmt = DateFormat('dd MMM yy');

  const _DateRangeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DT.rSm),
      child: Container(
        height: DT.inputHeight,
        padding: const EdgeInsets.symmetric(horizontal: DT.s12),
        decoration: BoxDecoration(
          color: DT.surface,
          border: Border.all(color: DT.border),
          borderRadius: BorderRadius.circular(DT.rSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 14, color: DT.text2),
            const SizedBox(width: DT.s8),
            Text('$label:',
                style: const TextStyle(
                    fontSize: DT.fsSm,
                    color: DT.text3,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: DT.s4),
            Text(value == null ? '—' : _fmt.format(value!),
                style: const TextStyle(
                    fontSize: DT.fsBody,
                    color: DT.text,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Pill({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DT.s8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: DT.fsSm,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onClear;
  const _EmptyState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: DT.surface2,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 28, color: DT.text3),
          ),
          const SizedBox(height: DT.s12),
          const Text('No bills match these filters',
              style: TextStyle(
                  fontSize: DT.fsBody,
                  color: DT.text,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: DT.s4),
          const Text('Try widening the date range or clearing filters.',
              style: TextStyle(fontSize: DT.fsSm, color: DT.text2)),
          const SizedBox(height: DT.s16),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }
}
