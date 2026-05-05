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
import '../../data/models/distributor_outlet.dart';
import '../../data/repositories/report_repo.dart';
import '../customers/customer_form_dialog.dart' show DOTypeahead;

class DoRegisterScreen extends ConsumerStatefulWidget {
  const DoRegisterScreen({super.key});

  @override
  ConsumerState<DoRegisterScreen> createState() => _DoRegisterScreenState();
}

class _DoRegisterScreenState extends ConsumerState<DoRegisterScreen> {
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();
  DistributorOutlet? _selectedDO;
  Future<List<DoRegisterRow>>? _future;

  static final _dateFmt = DateFormat('dd MMM yy');
  static final _monthFmt = DateFormat('MMMM yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ref.read(reportRepoProvider).doRegister(
          fromDate: _fromDate,
          toDate: _toDate,
          doId: _selectedDO?.id,
        );
    setState(() {});
  }

  void _printBills() {
    final from = DateFormat('yyyy-MM-dd').format(_fromDate);
    final to = DateFormat('yyyy-MM-dd').format(_toDate);
    final doParam =
        _selectedDO == null ? '' : '&do_id=${_selectedDO!.id}';
    // Reuses /bills/batch-print — bills already come back sorted ascending
    // by (bill_date, bill_number).
    context.go(
      '/bills/batch-print?from=$from&to=$to&format=preprinted$doParam',
    );
  }

  Future<void> _export(String format) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: Text('Generating ${format.toUpperCase()}…'),
      duration: const Duration(seconds: 30),
    ));
    try {
      final bytes = await ref.read(reportRepoProvider).doRegisterExportBytes(
            fromDate: _fromDate,
            toDate: _toDate,
            format: format,
            doId: _selectedDO?.id,
          );
      final from = DateFormat('yyyy-MM-dd').format(_fromDate);
      final to = DateFormat('yyyy-MM-dd').format(_toDate);
      final ext = format == 'excel' ? 'xlsx' : 'pdf';
      final mime = format == 'excel'
          ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          : 'application/pdf';
      final suffix = _selectedDO == null ? '' : '-${_selectedDO!.code}';
      await downloadBytes(
        Uint8List.fromList(bytes),
        'do-register$suffix-$from-to-$to.$ext',
        mime,
      );
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text('Downloaded do-register.$ext'),
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
      final next = DateTime(picked.year, picked.month + 1, 1);
      _toDate = next.subtract(const Duration(days: 1));
    });
    _load();
  }

  Future<void> _pickRange({required bool from}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _fromDate : _toDate,
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
                'DO Register',
                style: TextStyle(
                    fontSize: DT.fsH1,
                    fontWeight: FontWeight.w700,
                    color: DT.text,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 2),
              Text(_monthFmt.format(_fromDate),
                  style: const TextStyle(
                      fontSize: DT.fsSm, color: DT.text2)),
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
          const SizedBox(width: DT.s12),
          Expanded(
            child: DOTypeahead(
              key: ValueKey('do-reg-${_selectedDO?.id ?? 'all'}'),
              initial: _selectedDO,
              label: 'Distributor Outlet (leave blank = all)',
              onChanged: (v) {
                setState(() => _selectedDO = v);
                _load();
              },
            ),
          ),
          const SizedBox(width: DT.s12),
          if (_selectedDO != null)
            TextButton.icon(
              onPressed: () {
                setState(() => _selectedDO = null);
                _load();
              },
              icon: const Icon(Icons.close, size: 14),
              label: const Text('Show all DOs'),
              style: TextButton.styleFrom(foregroundColor: DT.text2),
            ),
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
      child: FutureBuilder<List<DoRegisterRow>>(
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
          final rows = snap.data ?? const <DoRegisterRow>[];
          if (rows.isEmpty) {
            return const Center(
              child: Text('No bills in this range.',
                  style: TextStyle(color: DT.text2)),
            );
          }

          // Group by DO so the user sees one block per outlet.
          final byDo = <String, List<DoRegisterRow>>{};
          for (final r in rows) {
            byDo.putIfAbsent(r.doCode, () => []).add(r);
          }

          final totalQty = rows.fold<int>(0, (s, r) => s + r.qty);
          final totalAmt = rows.fold<double>(0, (s, r) => s + r.total);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final entry in byDo.entries)
                        _DoBlock(code: entry.key, rows: entry.value),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: DT.divider),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: DT.s16, vertical: DT.s8),
                child: Row(
                  children: [
                    Text('${byDo.length} DOs · ${rows.length} day-rows',
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

class _DoBlock extends StatelessWidget {
  final String code;
  final List<DoRegisterRow> rows;
  const _DoBlock({required this.code, required this.rows});

  static final _dateFmt = DateFormat('dd MMM yy');

  @override
  Widget build(BuildContext context) {
    final first = rows.first;
    final blockQty = rows.fold<int>(0, (s, r) => s + r.qty);
    final blockTotal = rows.fold<double>(0, (s, r) => s + r.total);
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DT.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // DO header strip
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: DT.s16, vertical: DT.s12),
            color: DT.surface2,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: DT.brand50,
                    borderRadius: BorderRadius.circular(DT.rXs),
                  ),
                  child: Text(code,
                      style: const TextStyle(
                          color: DT.brand800,
                          fontWeight: FontWeight.w700,
                          fontSize: DT.fsBody)),
                ),
                const SizedBox(width: DT.s8),
                Text(first.doName,
                    style: const TextStyle(
                        fontSize: DT.fsBody,
                        fontWeight: FontWeight.w600,
                        color: DT.text)),
                if ((first.doLocation ?? '').isNotEmpty) ...[
                  const Text(' · ',
                      style: TextStyle(color: DT.text3)),
                  Text(first.doLocation!,
                      style: const TextStyle(
                          fontSize: DT.fsSm, color: DT.text2)),
                ],
                const Spacer(),
                Text('Qty $blockQty',
                    style: AppTheme.mono(size: 12).copyWith(
                        color: DT.text2, fontWeight: FontWeight.w600)),
                const SizedBox(width: DT.s16),
                Text(fmtINR(blockTotal),
                    style: AppTheme.mono(size: 12).copyWith(
                        color: DT.brand700, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          // Rows for this DO
          for (final r in rows)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: DT.s16, vertical: DT.s8),
              decoration: const BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: DT.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(_dateFmt.format(r.date),
                        style: const TextStyle(
                            fontSize: DT.fsBody,
                            color: DT.text,
                            fontWeight: FontWeight.w500)),
                  ),
                  SizedBox(
                    width: 220,
                    child: Text('${r.billFrom} → ${r.billTo}',
                        style: AppTheme.mono(size: 12)
                            .copyWith(color: DT.text2)),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text('${r.qty}',
                        style: AppTheme.mono(size: 12)
                            .copyWith(fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: Text(fmtINR(r.total),
                        textAlign: TextAlign.right,
                        style: AppTheme.mono(size: 12).copyWith(
                            fontWeight: FontWeight.w600, color: DT.text)),
                  ),
                ],
              ),
            ),
        ],
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
