import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/format/inr.dart';
import '../../core/io/web_download.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/repositories/report_repo.dart';

class DailyRegisterScreen extends ConsumerStatefulWidget {
  const DailyRegisterScreen({super.key});

  @override
  ConsumerState<DailyRegisterScreen> createState() =>
      _DailyRegisterScreenState();
}

class _DailyRegisterScreenState
    extends ConsumerState<DailyRegisterScreen> {
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();
  Future<List<DailyRegisterRow>>? _future;

  static final _dateFmt = DateFormat('dd MMM yy');
  static final _monthFmt = DateFormat('MMMM yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ref.read(reportRepoProvider).dailyRegister(
          fromDate: _fromDate,
          toDate: _toDate,
        );
    setState(() {});
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Pick any day in the month',
    );
    if (picked == null) return;
    setState(() {
      _fromDate = DateTime(picked.year, picked.month, 1);
      // last day of the picked month
      final next = DateTime(picked.year, picked.month + 1, 1);
      _toDate = next.subtract(const Duration(days: 1));
    });
    _load();
  }

  void _printBills() {
    final from = DateFormat('yyyy-MM-dd').format(_fromDate);
    final to = DateFormat('yyyy-MM-dd').format(_toDate);
    // Reuses /bills/batch-print which is already sorted asc by (date, bill #).
    context.go(
      '/bills/batch-print?from=$from&to=$to&format=preprinted',
    );
  }

  Future<void> _export(String format) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: Text('Generating ${format.toUpperCase()}…'),
      duration: const Duration(seconds: 30),
    ));
    try {
      final bytes = await ref.read(reportRepoProvider).dailyRegisterExportBytes(
            fromDate: _fromDate,
            toDate: _toDate,
            format: format,
          );
      final from = DateFormat('yyyy-MM-dd').format(_fromDate);
      final to = DateFormat('yyyy-MM-dd').format(_toDate);
      final ext = format == 'excel' ? 'xlsx' : 'pdf';
      final mime = format == 'excel'
          ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          : 'application/pdf';
      await downloadBytes(
        Uint8List.fromList(bytes),
        'daily-register-$from-to-$to.$ext',
        mime,
      );
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text('Downloaded daily-register.$ext'),
        backgroundColor: DT.ok700,
        duration: const Duration(seconds: 3),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text('Export failed: $e'),
        backgroundColor: DT.err700,
        duration: const Duration(seconds: 6),
      ));
    }
  }

  Future<void> _pickRange({required bool from}) async {
    final initial = from ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DT.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: DT.s16),
          _filterCard(),
          const SizedBox(height: DT.s16),
          Expanded(child: _tableCard()),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Daily Register',
                style: TextStyle(
                    fontSize: DT.fsH1,
                    fontWeight: FontWeight.w700,
                    color: DT.text,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 2),
              Text(
                _monthFmt.format(_fromDate),
                style: const TextStyle(
                    fontSize: DT.fsSm, color: DT.text2),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _pickMonth,
          icon: const Icon(Icons.calendar_month_outlined, size: 14),
          label: const Text('Pick month'),
        ),
        const SizedBox(width: DT.s8),
        OutlinedButton.icon(
          onPressed: _printBills,
          icon: const Icon(Icons.print_outlined, size: 14),
          label: const Text('Print bills (6-up)'),
        ),
        const SizedBox(width: DT.s8),
        PopupMenuButton<String>(
          tooltip: 'Export',
          onSelected: _export,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'excel',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.grid_on_outlined, size: 18),
                title: Text('Excel (.xlsx)'),
              ),
            ),
            PopupMenuItem(
              value: 'pdf',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.picture_as_pdf_outlined, size: 18),
                title: Text('PDF'),
              ),
            ),
          ],
          child: Container(
            height: DT.btnHeight,
            padding: const EdgeInsets.symmetric(horizontal: DT.s12),
            decoration: BoxDecoration(
              color: DT.brand600,
              borderRadius: BorderRadius.circular(DT.rSm),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download_rounded, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text('Export',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: DT.fsBody,
                        fontWeight: FontWeight.w600)),
                Icon(Icons.arrow_drop_down, size: 16, color: Colors.white),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterCard() {
    return Container(
      padding: const EdgeInsets.all(DT.s12),
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.border),
      ),
      child: Row(
        children: [
          _DateChip(
              label: 'From',
              value: _fromDate,
              onTap: () => _pickRange(from: true)),
          const SizedBox(width: DT.s8),
          _DateChip(
              label: 'To',
              value: _toDate,
              onTap: () => _pickRange(from: false)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('Reload'),
          ),
        ],
      ),
    );
  }

  Widget _tableCard() {
    return Container(
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<List<DailyRegisterRow>>(
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
          final rows = snap.data ?? const <DailyRegisterRow>[];
          if (rows.isEmpty) {
            return const Center(
              child: Text('No bills in this range.',
                  style: TextStyle(color: DT.text2)),
            );
          }
          final totalQty = rows.fold<int>(0, (s, r) => s + r.qty);
          final totalAmt = rows.fold<double>(0, (s, r) => s + r.total);
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width -
                            DT.sidebarWidth -
                            DT.s48,
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
                        dataRowMinHeight: 44,
                        dataRowMaxHeight: 44,
                        columnSpacing: DT.s24,
                        horizontalMargin: DT.s16,
                        columns: const [
                          DataColumn(label: Text('DATE')),
                          DataColumn(label: Text('BILL # FROM')),
                          DataColumn(label: Text('BILL # TO')),
                          DataColumn(label: Text('QTY'), numeric: true),
                          DataColumn(label: Text('TOTAL'), numeric: true),
                        ],
                        rows: [
                          for (final r in rows)
                            DataRow(cells: [
                              DataCell(Text(
                                _dateFmt.format(r.date),
                                style: const TextStyle(
                                    fontSize: DT.fsBody,
                                    color: DT.text,
                                    fontWeight: FontWeight.w500),
                              )),
                              DataCell(Text(r.billFrom,
                                  style: AppTheme.mono(size: 12))),
                              DataCell(Text(r.billTo,
                                  style: AppTheme.mono(size: 12))),
                              DataCell(Text('${r.qty}',
                                  style: AppTheme.mono(size: 12))),
                              DataCell(Text(fmtINR(r.total),
                                  style: AppTheme.mono(size: 12).copyWith(
                                      fontWeight: FontWeight.w600))),
                            ]),
                        ],
                      ),
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
                    Text('${rows.length} days',
                        style: const TextStyle(
                            color: DT.text2, fontSize: DT.fsSm)),
                    const Spacer(),
                    Text('Qty $totalQty',
                        style: AppTheme.mono(size: 12).copyWith(
                            color: DT.text2, fontWeight: FontWeight.w600)),
                    const SizedBox(width: DT.s16),
                    Text('Total ${fmtINR(totalAmt)}',
                        style: AppTheme.mono(size: 12).copyWith(
                            color: DT.brand700, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final DateTime value;
  final VoidCallback onTap;
  static final _fmt = DateFormat('dd MMM yy');

  const _DateChip({
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
            Text(_fmt.format(value),
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
