// Distributor Outlet (DO) master screen.
//
// Admin-only CRUD for outlets — the retail sub-agencies each customer
// is linked to. Includes debounced search, pagination, and inline
// Edit / Toggle-active / Delete actions.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/distributor_outlet.dart';
import '../../data/repositories/do_repo.dart';
import '../auth/auth_controller.dart';

/// Route `/outlets`.
class OutletsScreen extends ConsumerStatefulWidget {
  const OutletsScreen({super.key});

  @override
  ConsumerState<OutletsScreen> createState() => _OutletsScreenState();
}

class _OutletsScreenState extends ConsumerState<OutletsScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  int _page = 1;
  String _q = '';
  Future<DOPage>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Re-runs the DO list query with the current filter / page state.
  void _load() {
    _future = ref.read(doRepoProvider).list(page: _page, perPage: 25, q: _q);
    setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Debounces search input to avoid flooding the backend.
  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _q = v.trim();
      _page = 1;
      _load();
    });
  }

  /// Opens the add/edit dialog. Reloads the list on successful save.
  Future<void> _openForm({DistributorOutlet? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _OutletFormDialog(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _toggleActive(DistributorOutlet o) async {
    try {
      await ref.read(doRepoProvider).setActive(o.id, !o.isActive);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _delete(DistributorOutlet o) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete outlet?'),
        content: Text('Delete DO ${o.code} — ${o.ownerName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: DT.err600),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(doRepoProvider).delete(o.id);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Deleted outlet ${o.code}'),
        duration: const Duration(seconds: 3),
        backgroundColor: DT.ok700,
      ));
      _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(e.toString()),
        duration: const Duration(seconds: 6),
        backgroundColor: DT.err700,
      ));
    }
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
                      hintText: 'Search by code, owner, or location',
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DT.s12),
              if (isAdmin)
                ElevatedButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Outlet'),
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
              child: FutureBuilder<DOPage>(
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
                      child: Text('No distributor outlets yet.',
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
                                DataColumn(label: Text('Code')),
                                DataColumn(label: Text('Owner Name')),
                                DataColumn(label: Text('Location')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('')),
                              ],
                              rows: [
                                for (final o in page.items)
                                  DataRow(cells: [
                                    DataCell(Text(o.code,
                                        style: AppTheme.mono(size: 12))),
                                    DataCell(Text(o.ownerName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500))),
                                    DataCell(Text(o.location)),
                                    DataCell(_statusChip(o.isActive)),
                                    DataCell(Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit',
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 16),
                                          onPressed: isAdmin
                                              ? () =>
                                                  _openForm(existing: o)
                                              : null,
                                        ),
                                        IconButton(
                                          tooltip: o.isActive
                                              ? 'Deactivate'
                                              : 'Activate',
                                          icon: Icon(
                                            o.isActive
                                                ? Icons.toggle_on
                                                : Icons.toggle_off,
                                            size: 18,
                                            color: o.isActive
                                                ? DT.ok600
                                                : DT.text3,
                                          ),
                                          onPressed: isAdmin
                                              ? () => _toggleActive(o)
                                              : null,
                                        ),
                                        IconButton(
                                          tooltip: 'Delete',
                                          icon: const Icon(
                                              Icons.delete_outline,
                                              size: 16,
                                              color: DT.err600),
                                          onPressed:
                                              isAdmin ? () => _delete(o) : null,
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
                                '${page.total} outlets · page ${page.page} of ${page.lastPage}',
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

  Widget _statusChip(bool active) => Container(
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

class _OutletFormDialog extends ConsumerStatefulWidget {
  final DistributorOutlet? existing;
  const _OutletFormDialog({this.existing});

  @override
  ConsumerState<_OutletFormDialog> createState() => _OutletFormDialogState();
}

class _OutletFormDialogState extends ConsumerState<_OutletFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _owner;
  late final TextEditingController _location;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _code = TextEditingController(text: e?.code ?? '');
    _owner = TextEditingController(text: e?.ownerName ?? '');
    _location = TextEditingController(text: e?.location ?? '');
  }

  @override
  void dispose() {
    _code.dispose();
    _owner.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final outlet = DistributorOutlet(
        id: widget.existing?.id ?? 0,
        code: _code.text.trim().toUpperCase(),
        ownerName: _owner.text.trim(),
        location: _location.text.trim(),
        isActive: widget.existing?.isActive ?? true,
      );
      final repo = ref.read(doRepoProvider);
      if (widget.existing == null) {
        await repo.create(outlet);
      } else {
        await repo.update(widget.existing!.id, outlet);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.existing == null ? 'Add distributor outlet' : 'Edit outlet';
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(DT.s20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: DT.s16),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(DT.s8),
                    color: DT.err50,
                    child: Text(_error!,
                        style: const TextStyle(
                            color: DT.err700, fontSize: DT.fsSm)),
                  ),
                  const SizedBox(height: DT.s12),
                ],
                TextFormField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Code * (e.g., AA)',
                    helperText: 'Short unique code, uppercased',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: DT.s12),
                TextFormField(
                  controller: _owner,
                  decoration:
                      const InputDecoration(labelText: 'Owner name *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: DT.s12),
                TextFormField(
                  controller: _location,
                  decoration: const InputDecoration(labelText: 'Location *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: DT.s20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: DT.s8),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
