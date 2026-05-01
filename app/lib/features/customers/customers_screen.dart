// Customers list screen with search, pagination, and inline actions.
//
// Features:
//   * debounced search (300 ms) by name / mobile / village;
//   * status filter (active / inactive / all);
//   * per-row Edit, Toggle active, Delete (admin only for toggle+delete);
//   * "+ New customer" button opens CustomerFormDialog.import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  Future<CustomerPage>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Re-runs the customer list query with the current filter state.
  void _load() {
    _future = ref.read(customerRepoProvider).list(
        page: _page, perPage: 25, q: _q, status: _statusFilter);
    setState(() {});
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
          const SizedBox(height: DT.s16),
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
                      child: Text('No customers yet.',
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
                                DataColumn(label: Text('Name')),
                                DataColumn(label: Text('Mobile')),
                                DataColumn(label: Text('Consumer #')),
                                DataColumn(label: Text('DO')),
                                DataColumn(label: Text('Type')),
                                DataColumn(
                                    label: Text('Balance'), numeric: true),
                                DataColumn(
                                    label: Text('Empty'), numeric: true),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('')),
                              ],
                              rows: [
                                for (final c in page.items)
                                  DataRow(cells: [
                                    DataCell(Text(c.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500))),
                                    DataCell(Text(c.mobile,
                                        style: AppTheme.mono(size: 12))),
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
