// Customers list screen with search, pagination, and inline actions.
//
// Features:
//   * debounced search (300 ms) by name / mobile / village;
//   * status filter (active / inactive / all);
//   * per-row Edit, Toggle active, Delete (admin only for toggle+delete);
//   * "+ New customer" button opens CustomerFormDialog;
//   * "Upload Excel" bulk import (admin), with row-level error report;
//   * registration-date range filter, sort newest-first;
//   * bulk-delete via per-row checkboxes.
import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format/inr.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/customer_repo.dart';
import '../auth/auth_controller.dart';
import 'customer_form_dialog.dart';

/// Route `/customers`.
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  int _page = 1;
  String _q = '';
  String _statusFilter = 'active';
  DateTime? _regFrom;
  DateTime? _regTo;
  Future<CustomerPage>? _future;
  final Set<int> _selected = <int>{};

  static final _dateFmt = DateFormat('dd MMM yy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Re-runs the customer list query with the current filter state.
  void _load() {
    _future = ref.read(customerRepoProvider).list(
          page: _page,
          perPage: 25,
          q: _q,
          status: _statusFilter,
          registeredFrom: _regFrom,
          registeredTo: _regTo,
          sort: 'registered_desc',
        );
    setState(() {});
  }

  Future<void> _pickRegDate({required bool from}) async {
    final initial = (from ? _regFrom : _regTo) ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) {
      setState(() {
        if (from) {
          _regFrom = d;
        } else {
          _regTo = d;
        }
      });
      _page = 1;
      _load();
    }
  }

  void _clearRegDates() {
    setState(() {
      _regFrom = null;
      _regTo = null;
    });
    _page = 1;
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Debounces keystrokes so we don't hit the backend on every character.
  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _q = v.trim();
      _page = 1;
      _load();
    });
  }

  /// Opens the customer form — `existing == null` creates, otherwise edits.
  /// Reloads the list if the dialog returned a saved customer.
  Future<void> _openForm({Customer? existing}) async {
    final saved = await showDialog<Customer?>(
      context: context,
      builder: (_) => CustomerFormDialog(existing: existing),
    );
    if (saved != null) _load();
  }

  /// Flips `active`/`inactive` and reloads. Errors surface as a snackbar.
  Future<void> _toggleActive(Customer c) async {
    try {
      await ref
          .read(customerRepoProvider)
          .setActive(c.id, c.status != 'active');
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  /// Confirms and soft-deletes the customer. Backend returns an error if
  /// the row still has active bills; that error bubbles up as a snackbar.
  Future<void> _delete(Customer c) async {
    // Run the DELETE call from inside the dialog button itself so that any
    // navigator/context oddity around `showDialog` cannot prevent the API
    // call from going out. Returns: 'ok' | 'err:<message>' | null (cancelled).
    final outcome = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogCtx) {
        bool busy = false;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('Delete customer?'),
            content: Text(
              'Are you sure you want to delete ${c.name}'
              '${c.village?.isNotEmpty == true ? ' — ${c.village}' : ''}?',
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogCtx, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: DT.err600),
                onPressed: busy
                    ? null
                    : () async {
                        setLocal(() => busy = true);
                        try {
                          await ref.read(customerRepoProvider).delete(c.id);
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx, 'ok');
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
                          valueColor: AlwaysStoppedAnimation(Colors.white),
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
    if (outcome == 'ok') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Deleted ${c.name}'),
        duration: const Duration(seconds: 3),
        backgroundColor: DT.ok700,
      ));
      _load();
    } else if (outcome.startsWith('err:')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(outcome.substring(4)),
        duration: const Duration(seconds: 6),
        backgroundColor: DT.err700,
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
      duration: const Duration(seconds: 30),
    ));
    try {
      final bytes = await picked.readAsBytes();
      final result = await ref.read(customerRepoProvider).importExcel(
            bytes: bytes,
            filename: picked.name,
          );
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      final imported = result['imported'] ?? 0;
      final skipped = result['skipped'] ?? 0;
      final errors = (result['errors'] as List?) ?? const [];
      messenger.showSnackBar(SnackBar(
        content: Text(
          'Imported $imported · skipped $skipped'
          '${errors.isNotEmpty ? ' · ${errors.length} errors' : ''}',
        ),
        duration: const Duration(seconds: 5),
        backgroundColor: errors.isEmpty ? DT.ok700 : DT.warn700,
      ));
      if (errors.isNotEmpty) {
        await _showImportErrors(errors);
      }
      _load();
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text('Import failed: ${e.toString()}'),
        duration: const Duration(seconds: 8),
        backgroundColor: DT.err700,
      ));
    }
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
            title: Text('Delete $n ${n == 1 ? 'customer' : 'customers'}?'),
            content: Text(
              'These customers will be marked deleted (soft-delete). '
              'You can ask the owner to restore from audit logs if needed.',
            ),
            actions: [
              TextButton(
                onPressed:
                    busy ? null : () => Navigator.pop(dialogCtx, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: DT.err600),
                onPressed: busy
                    ? null
                    : () async {
                        setLocal(() => busy = true);
                        try {
                          final res = await ref
                              .read(customerRepoProvider)
                              .bulkDelete(ids);
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
                          valueColor: AlwaysStoppedAnimation(Colors.white),
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
            Text('Deleted ${parts[1]} · skipped ${parts[2]}'),
        backgroundColor: DT.ok700,
        duration: const Duration(seconds: 3),
      ));
      setState(_selected.clear);
      _load();
    } else if (outcome.startsWith('err:')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(outcome.substring(4)),
        backgroundColor: DT.err700,
        duration: const Duration(seconds: 6),
      ));
    }
  }

  Future<void> _showImportErrors(List errors) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        title: Text('${errors.length} row${errors.length == 1 ? '' : 's'} skipped'),
        content: SizedBox(
          width: 480,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: errors.length,
            itemBuilder: (_, i) {
              final e = errors[i] as Map;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Row ${e['row']}: ${e['error']}',
                  style: const TextStyle(fontSize: DT.fsSm, color: DT.err700),
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

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authControllerProvider).role == 'admin';
    return Padding(
      padding: const EdgeInsets.all(DT.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: DT.inputHeight,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      hintText:
                          'Search by name, mobile, consumer # or city',
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DT.s12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'active', label: Text('Active')),
                  ButtonSegment(value: 'inactive', label: Text('Inactive')),
                ],
                selected: {_statusFilter},
                onSelectionChanged: (s) {
                  _statusFilter = s.first;
                  _page = 1;
                  _load();
                },
              ),
              const SizedBox(width: DT.s12),
              ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Customer'),
              ),
              const SizedBox(width: DT.s8),
              OutlinedButton.icon(
                onPressed: isAdmin ? _importExcel : null,
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text('Upload Excel'),
              ),
            ],
          ),
          const SizedBox(height: DT.s12),
          // Date filter + selection action bar
          Row(
            children: [
              _RegDateChip(
                label: 'Registered from',
                value: _regFrom,
                onTap: () => _pickRegDate(from: true),
                onClear: _regFrom == null
                    ? null
                    : () {
                        setState(() => _regFrom = null);
                        _page = 1;
                        _load();
                      },
              ),
              const SizedBox(width: DT.s8),
              _RegDateChip(
                label: 'to',
                value: _regTo,
                onTap: () => _pickRegDate(from: false),
                onClear: _regTo == null
                    ? null
                    : () {
                        setState(() => _regTo = null);
                        _page = 1;
                        _load();
                      },
              ),
              if (_regFrom != null || _regTo != null) ...[
                const SizedBox(width: DT.s8),
                TextButton.icon(
                  onPressed: _clearRegDates,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Clear dates'),
                  style: TextButton.styleFrom(foregroundColor: DT.text2),
                ),
              ],
              const Spacer(),
              if (_selected.isNotEmpty) ...[
                Text('${_selected.length} selected',
                    style: const TextStyle(
                        fontSize: DT.fsSm,
                        color: DT.brand700,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: DT.s8),
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: const Text('Clear'),
                ),
                const SizedBox(width: DT.s4),
                ElevatedButton.icon(
                  onPressed: isAdmin ? _bulkDelete : null,
                  icon: const Icon(Icons.delete_outline, size: 14),
                  label: Text('Delete selected (${_selected.length})'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: DT.err600),
                ),
              ],
            ],
          ),
          const SizedBox(height: DT.s12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: DT.surface,
                borderRadius: BorderRadius.circular(DT.rMd),
                border: Border.all(color: DT.border),
              ),
              child: FutureBuilder<CustomerPage>(
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
                      child: Text('No customers match these filters.',
                          style: TextStyle(color: DT.text2)),
                    );
                  }
                  // Selection helpers — only consider current page items.
                  final pageIds = page.items.map((c) => c.id).toSet();
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
                                        DT.s48),
                                child: DataTable(
                              headingRowHeight: 40,
                              dataRowMinHeight: DT.rowHeight,
                              dataRowMaxHeight: DT.rowHeight,
                              columns: [
                                DataColumn(
                                  label: _MiniCheckbox(
                                    value: allOnPageSelected
                                        ? true
                                        : (someOnPageSelected ? null : false),
                                    tristate: true,
                                    onChanged: isAdmin
                                        ? (v) {
                                            setState(() {
                                              if (v == true) {
                                                _selected.addAll(pageIds);
                                              } else {
                                                _selected.removeAll(pageIds);
                                              }
                                            });
                                          }
                                        : null,
                                  ),
                                ),
                                const DataColumn(label: Text('Name')),
                                const DataColumn(label: Text('Mobile')),
                                const DataColumn(label: Text('Registered')),
                                const DataColumn(label: Text('Consumer #')),
                                const DataColumn(label: Text('DO')),
                                const DataColumn(label: Text('Type')),
                                const DataColumn(
                                    label: Text('Balance'), numeric: true),
                                const DataColumn(
                                    label: Text('Empty'), numeric: true),
                                const DataColumn(label: Text('Status')),
                                const DataColumn(label: Text('')),
                              ],
                              rows: [
                                for (final c in page.items)
                                  DataRow(
                                    selected: _selected.contains(c.id),
                                    cells: [
                                    DataCell(_MiniCheckbox(
                                      value: _selected.contains(c.id),
                                      onChanged: isAdmin
                                          ? (v) {
                                              setState(() {
                                                if (v == true) {
                                                  _selected.add(c.id);
                                                } else {
                                                  _selected.remove(c.id);
                                                }
                                              });
                                            }
                                          : null,
                                    )),
                                    DataCell(Text(c.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500))),
                                    DataCell(Text(c.mobile,
                                        style: AppTheme.mono(size: 12))),
                                    DataCell(Text(
                                        c.registrationDate == null
                                            ? '—'
                                            : _dateFmt.format(
                                                c.registrationDate!),
                                        style: const TextStyle(
                                            fontSize: DT.fsSm,
                                            color: DT.text2))),
                                    DataCell(Text(c.consumerNumber ?? '',
                                        style: AppTheme.mono(size: 12))),
                                    DataCell(Text(
                                        c.distributorOutlet?.code ?? '',
                                        style: AppTheme.mono(size: 12))),
                                    DataCell(_typeChip(c.customerType)),
                                    DataCell(Text(fmtINR(c.balance),
                                        style: AppTheme.mono(size: 12))),
                                    DataCell(Text(c.emptyPending.toString(),
                                        style: AppTheme.mono(size: 12))),
                                    DataCell(_statusChip(c.status)),
                                    DataCell(Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit',
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 16),
                                          onPressed: () =>
                                              _openForm(existing: c),
                                        ),
                                        IconButton(
                                          tooltip: c.status == 'active'
                                              ? 'Deactivate'
                                              : 'Activate',
                                          icon: Icon(
                                            c.status == 'active'
                                                ? Icons.toggle_on
                                                : Icons.toggle_off,
                                            size: 18,
                                            color: c.status == 'active'
                                                ? DT.ok600
                                                : DT.text3,
                                          ),
                                          onPressed: isAdmin
                                              ? () => _toggleActive(c)
                                              : null,
                                        ),
                                        IconButton(
                                          tooltip: 'Delete',
                                          icon: const Icon(
                                              Icons.delete_outline,
                                              size: 16,
                                              color: DT.err600),
                                          onPressed:
                                              isAdmin ? () => _delete(c) : null,
                                        ),
                                      ],
                                    )),
                                  ]),
                              ],
                                ),
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
                            Text(
                                '${page.total} customers · page ${page.page} of ${page.lastPage}',
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

  Widget _typeChip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: DT.s8, vertical: 2),
        decoration: BoxDecoration(
          color: t == 'commercial' ? DT.warn50 : DT.brand50,
          borderRadius: BorderRadius.circular(DT.rXs),
        ),
        child: Text(
          t,
          style: TextStyle(
            color: t == 'commercial' ? DT.warn700 : DT.brand700,
            fontSize: DT.fsSm,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _statusChip(String s) {
    final active = s == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DT.s8, vertical: 2),
      decoration: BoxDecoration(
        color: active ? DT.ok50 : DT.surface3,
        borderRadius: BorderRadius.circular(DT.rXs),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(
          color: active ? DT.ok700 : DT.text2,
          fontSize: DT.fsSm,
          fontWeight: FontWeight.w600,
        ),
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

class _RegDateChip extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  static final _fmt = DateFormat('dd MMM yy');

  const _RegDateChip({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
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
            if (onClear != null) ...[
              const SizedBox(width: DT.s4),
              InkWell(
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 12, color: DT.text3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
