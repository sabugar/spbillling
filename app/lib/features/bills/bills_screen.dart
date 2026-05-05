import 'package:file_selector/file_selector.dart';
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
  final Set<int> _selected = <int>{};

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

  /// Pull only the trailing digits — backend treats this as a serial-number
  /// match (FY-independent), so "5..30" matches across any month/year.
  String _serialOnly(String raw) {
    final m = RegExp(r'(\d+)\s*$').firstMatch(raw.trim());
    return m == null ? '' : m.group(1)!;
  }

  void _load() {
    final bnFrom = _serialOnly(_billNumFromCtrl.text);
    final bnTo = _serialOnly(_billNumToCtrl.text);
    // Bill # is a unique identifier — when the user types one, date range is
    // irrelevant. Drop the date filter so they always find the bill.
    final billNumActive = bnFrom.isNotEmpty || bnTo.isNotEmpty;
    _future = ref.read(billRepoProvider).list(
          page: _page,
          perPage: 10,
          fromDate: billNumActive ? null : _fromDate,
          toDate: billNumActive ? null : _toDate,
          billNumberFrom: bnFrom,
          billNumberTo: bnTo,
          doId: _selectedDO?.id,
          city: _cityCtrl.text.trim(),
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

  void _printBatch({String format = 'preprinted'}) {
    final bnFrom = _serialOnly(_billNumFromCtrl.text);
    final bnTo = _serialOnly(_billNumToCtrl.text);
    final billNumActive = bnFrom.isNotEmpty || bnTo.isNotEmpty;
    if (!billNumActive && (_fromDate == null || _toDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick from & to dates first')),
      );
      return;
    }
    // Backend requires `from` and `to`; when only bill# is in play, use a
    // wide window so the date filter is a no-op.
    final fromIso = billNumActive
        ? '2020-01-01'
        : _fromDate!.toIso8601String().split('T').first;
    final toIso = billNumActive
        ? DateTime.now().add(const Duration(days: 1))
            .toIso8601String()
            .split('T')
            .first
        : _toDate!.toIso8601String().split('T').first;
    final params = <String, String>{
      'from': fromIso,
      'to': toIso,
      'format': format,
    };
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

  Future<void> _bulkDelete() async {
    if (_selected.isEmpty) return;
    final ids = _selected.toList();
    final n = ids.length;
    final outcome = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogCtx) {
        bool busy = false;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text('Delete $n ${n == 1 ? 'bill' : 'bills'}?'),
            content: Text(
              'These bills will be permanently removed. Customer balances, '
              'empty-bottle ledgers, and stock will be reversed. The bill '
              'numbers will be free for new bills (numbering picks up from '
              'the highest remaining bill).',
              style: const TextStyle(fontSize: DT.fsSm),
            ),
            actions: [
              TextButton(
                onPressed:
                    busy ? null : () => Navigator.pop(dialogCtx, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: DT.err600),
                onPressed: busy
                    ? null
                    : () async {
                        setLocal(() => busy = true);
                        try {
                          final res =
                              await ref.read(billRepoProvider).bulkDelete(ids);
                          if (dialogCtx.mounted) {
                            Navigator.pop(
                              dialogCtx,
                              'ok:${res['deleted']}:${res['skipped']}',
                            );
                          }
                        } catch (e) {
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx, 'err:${e.toString()}');
                          }
                        }
                      },
                child: busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text('Delete $n'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || outcome == null) return;
    if (outcome.startsWith('ok:')) {
      final parts = outcome.split(':');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Deleted ${parts[1]} bills · skipped ${parts[2]}'),
        backgroundColor: DT.ok700,
        duration: const Duration(seconds: 4),
      ));
      setState(_selected.clear);
      _page = 1;
      _load();
    } else if (outcome.startsWith('err:')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(outcome.substring(4)),
        backgroundColor: DT.err700,
        duration: const Duration(seconds: 6),
      ));
    }
  }

  Future<void> _deleteBill(Bill b) async {
    final shortNo = _shortBillNo(b.billNumber);
    // API call runs inside the dialog button so navigator/context quirks
    // never block the request — same pattern as customer delete.
    final outcome = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogCtx) {
        bool busy = false;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text('Delete bill #$shortNo?'),
            content: Text(
              'Bill #$shortNo (${b.customerName ?? "—"}) will be permanently '
              'removed. Customer balance and empty-bottle ledger will be '
              'reversed, and bill # $shortNo will be free for the next bill.',
              style: const TextStyle(fontSize: DT.fsSm),
            ),
            actions: [
              TextButton(
                onPressed:
                    busy ? null : () => Navigator.pop(dialogCtx, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: DT.err600),
                onPressed: busy
                    ? null
                    : () async {
                        setLocal(() => busy = true);
                        try {
                          await ref.read(billRepoProvider).delete(b.id);
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx, 'ok:$shortNo');
                          }
                        } catch (e) {
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx, 'err:${e.toString()}');
                          }
                        }
                      },
                child: busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text('Delete'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || outcome == null) return;
    if (outcome.startsWith('ok:')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Deleted #${outcome.substring(3)} — '
            'this number is free for the next bill'),
        backgroundColor: DT.ok700,
        duration: const Duration(seconds: 4),
      ));
      _load();
    } else if (outcome.startsWith('err:')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(outcome.substring(4)),
        backgroundColor: DT.err700,
        duration: const Duration(seconds: 6),
      ));
    }
  }

  Future<void> _importExcel() async {
    final XFile? picked = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Excel/CSV', extensions: ['xlsx', 'xls', 'csv']),
      ],
    );
    if (picked == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: Text('Importing ${picked.name}…'),
      duration: const Duration(seconds: 60),
    ));
    try {
      final bytes = await picked.readAsBytes();
      final result = await ref.read(billRepoProvider).importExcel(
            bytes: bytes,
            filename: picked.name,
          );
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      final imported = result['imported'] ?? 0;
      final errors = (result['errors'] as List?) ?? const [];
      messenger.showSnackBar(SnackBar(
        content: Text(
          'Imported $imported bills'
          '${errors.isNotEmpty ? ' · ${errors.length} errors' : ''}',
        ),
        duration: const Duration(seconds: 5),
        backgroundColor: errors.isEmpty ? DT.ok700 : DT.warn700,
      ));
      if (errors.isNotEmpty) await _showImportErrors(errors);
      _page = 1;
      _load();
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text('Import failed: ${e.toString()}'),
        backgroundColor: DT.err700,
        duration: const Duration(seconds: 8),
      ));
    }
  }

  Future<void> _showImportErrors(List errors) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
            '${errors.length} row${errors.length == 1 ? '' : 's'} skipped'),
        content: SizedBox(
          width: 520,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: errors.length,
            itemBuilder: (_, i) {
              final e = errors[i] as Map;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Row ${e['row']}: ${e['error']}',
                  style: const TextStyle(
                      fontSize: DT.fsSm, color: DT.err700),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _selectionBar(bool isAdmin) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: DT.s16, vertical: DT.s8),
      decoration: BoxDecoration(
        color: DT.brand50,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.brand200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: DT.brand700),
          const SizedBox(width: DT.s8),
          Text('${_selected.length} selected',
              style: const TextStyle(
                  color: DT.brand800,
                  fontWeight: FontWeight.w600,
                  fontSize: DT.fsBody)),
          const SizedBox(width: DT.s8),
          TextButton(
            onPressed: () => setState(_selected.clear),
            child: const Text('Clear'),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: isAdmin ? _bulkDelete : null,
            icon: const Icon(Icons.delete_sweep_outlined, size: 14),
            label: Text('Delete selected (${_selected.length})'),
            style: ElevatedButton.styleFrom(backgroundColor: DT.err600),
          ),
        ],
      ),
    );
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
            onUpload: isAdmin ? _importExcel : null,
          ),
          const SizedBox(height: DT.s16),
          if (_selected.isNotEmpty) ...[
            _selectionBar(isAdmin),
            const SizedBox(height: DT.s12),
          ],
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
          final pageIds = page.items.map((b) => b.id).toSet();
          final allOnPageSelected = pageIds.isNotEmpty &&
              pageIds.every(_selected.contains);
          final someOnPageSelected =
              pageIds.any(_selected.contains) && !allOnPageSelected;
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
                          columns: [
                            DataColumn(
                              label: _MiniCheckbox(
                                value: allOnPageSelected
                                    ? true
                                    : (someOnPageSelected ? null : false),
                                tristate: true,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selected.addAll(pageIds);
                                    } else {
                                      _selected.removeAll(pageIds);
                                    }
                                  });
                                },
                              ),
                            ),
                            const DataColumn(label: Text('BILL #')),
                            const DataColumn(label: Text('DATE')),
                            const DataColumn(label: Text('CUSTOMER')),
                            const DataColumn(label: Text('MOBILE')),
                            const DataColumn(
                                label: Text('TOTAL'), numeric: true),
                            const DataColumn(label: Text('')),
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
    return DataRow(
      selected: _selected.contains(b.id),
      cells: [
      DataCell(_MiniCheckbox(
        value: _selected.contains(b.id),
        onChanged: (v) {
          setState(() {
            if (v == true) {
              _selected.add(b.id);
            } else {
              _selected.remove(b.id);
            }
          });
        },
      )),
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
      DataCell(Text(
        b.customerMobile ?? '—',
        style: AppTheme.mono(size: 12).copyWith(color: DT.text2),
      )),
      DataCell(Text(fmtINR(b.totalAmount),
          style: AppTheme.mono(size: 12).copyWith(
              fontWeight: FontWeight.w600,
              color: isCancelled ? DT.text3 : DT.text))),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'View / Print PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined,
                size: 16, color: DT.brand700),
            onPressed: () => context.go('/bills/${b.id}/pdf'),
          ),
          IconButton(
            tooltip: 'Delete bill',
            icon: const Icon(Icons.delete_outline,
                size: 16, color: DT.err600),
            onPressed: () => _deleteBill(b),
          ),
        ],
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
  final VoidCallback? onUpload;
  const _PageHeader({
    required this.future,
    this.onPrint,
    this.onUpload,
  });

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
        if (onUpload != null) ...[
          OutlinedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_file, size: 14),
            label: const Text('Upload bills'),
          ),
          const SizedBox(width: DT.s8),
        ],
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

class _MiniCheckbox extends StatelessWidget {
  final bool? value;
  final bool tristate;
  final ValueChanged<bool?>? onChanged;
  const _MiniCheckbox({
    required this.value,
    this.tristate = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.85,
      child: Theme(
        data: Theme.of(context).copyWith(
          checkboxTheme: CheckboxThemeData(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: const BorderSide(color: DT.text3, width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DT.rXs),
            ),
          ),
        ),
        child: Checkbox(
          value: value,
          tristate: tristate,
          onChanged: onChanged,
          activeColor: DT.brand600,
          checkColor: Colors.white,
        ),
      ),
    );
  }
}
