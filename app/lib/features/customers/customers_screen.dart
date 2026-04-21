import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/inr.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/customer_repo.dart';

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
  Future<CustomerPage>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future =
        ref.read(customerRepoProvider).list(page: _page, perPage: 25, q: _q);
    setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _q = v.trim();
      _page = 1;
      _load();
    });
  }

  Future<void> _openForm({Customer? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CustomerFormDialog(existing: existing),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
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
                      hintText: 'Search by name, mobile, or village',
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DT.s12),
              ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Customer'),
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
                                DataColumn(label: Text('Village')),
                                DataColumn(label: Text('Mobile')),
                                DataColumn(label: Text('Type')),
                                DataColumn(
                                    label: Text('Balance'), numeric: true),
                                DataColumn(
                                    label: Text('Empty'), numeric: true),
                                DataColumn(label: Text('')),
                              ],
                              rows: [
                                for (final c in page.items)
                                  DataRow(cells: [
                                    DataCell(Text(c.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500))),
                                    DataCell(Text(c.village)),
                                    DataCell(Text(c.mobile,
                                        style: AppTheme.mono(size: 12))),
                                    DataCell(_typeChip(c.customerType)),
                                    DataCell(Text(fmtINR(c.balance),
                                        style: AppTheme.mono(size: 12))),
                                    DataCell(Text(c.emptyPending.toString(),
                                        style: AppTheme.mono(size: 12))),
                                    DataCell(IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 16),
                                      onPressed: () =>
                                          _openForm(existing: c),
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
        padding:
            const EdgeInsets.symmetric(horizontal: DT.s8, vertical: 2),
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
}

class _CustomerFormDialog extends ConsumerStatefulWidget {
  final Customer? existing;
  const _CustomerFormDialog({this.existing});

  @override
  ConsumerState<_CustomerFormDialog> createState() =>
      _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<_CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late final TextEditingController _altMobile;
  late final TextEditingController _village;
  late final TextEditingController _city;
  late final TextEditingController _district;
  late final TextEditingController _state;
  late final TextEditingController _pincode;
  late final TextEditingController _address;
  late final TextEditingController _notes;
  String _type = 'domestic';
  String _status = 'active';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _mobile = TextEditingController(text: e?.mobile ?? '');
    _altMobile = TextEditingController(text: e?.altMobile ?? '');
    _village = TextEditingController(text: e?.village ?? '');
    _city = TextEditingController(text: e?.city ?? '');
    _district = TextEditingController(text: e?.district ?? '');
    _state = TextEditingController(text: e?.state ?? 'Gujarat');
    _pincode = TextEditingController(text: e?.pincode ?? '');
    _address = TextEditingController(text: e?.fullAddress ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _type = e?.customerType ?? 'domestic';
    _status = e?.status ?? 'active';
  }

  @override
  void dispose() {
    for (final c in [
      _name, _mobile, _altMobile, _village, _city, _district,
      _state, _pincode, _address, _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final body = {
        'name': _name.text.trim(),
        'mobile': _mobile.text.trim(),
        if (_altMobile.text.trim().isNotEmpty)
          'alt_mobile': _altMobile.text.trim(),
        'village': _village.text.trim(),
        if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
        if (_district.text.trim().isNotEmpty)
          'district': _district.text.trim(),
        if (_state.text.trim().isNotEmpty) 'state': _state.text.trim(),
        if (_pincode.text.trim().isNotEmpty)
          'pincode': _pincode.text.trim(),
        if (_address.text.trim().isNotEmpty)
          'full_address': _address.text.trim(),
        'customer_type': _type,
        'status': _status,
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      };
      final repo = ref.read(customerRepoProvider);
      if (widget.existing == null) {
        await repo.create(body);
      } else {
        await repo.update(widget.existing!.id, body);
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
    final title = widget.existing == null ? 'Add customer' : 'Edit customer';
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
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
                _row([
                  _field(_name, 'Name *', validator: _required),
                  _field(_mobile, 'Mobile *',
                      validator: (v) =>
                          (v == null || v.length < 10) ? 'Invalid' : null),
                ]),
                _row([
                  _field(_altMobile, 'Alt mobile'),
                  _field(_village, 'Village *', validator: _required),
                ]),
                _row([
                  _field(_city, 'City'),
                  _field(_district, 'District'),
                ]),
                _row([
                  _field(_state, 'State'),
                  _field(_pincode, 'Pincode'),
                ]),
                _field(_address, 'Full address', maxLines: 2),
                const SizedBox(height: DT.s8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _type,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: const [
                          DropdownMenuItem(
                              value: 'domestic', child: Text('Domestic')),
                          DropdownMenuItem(
                              value: 'commercial', child: Text('Commercial')),
                        ],
                        onChanged: (v) =>
                            setState(() => _type = v ?? 'domestic'),
                      ),
                    ),
                    const SizedBox(width: DT.s12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration:
                            const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(
                              value: 'active', child: Text('Active')),
                          DropdownMenuItem(
                              value: 'inactive', child: Text('Inactive')),
                        ],
                        onChanged: (v) =>
                            setState(() => _status = v ?? 'active'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DT.s8),
                _field(_notes, 'Notes', maxLines: 2),
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

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Widget _row(List<Widget> cells) => Padding(
        padding: const EdgeInsets.only(bottom: DT.s8),
        child: Row(
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0) const SizedBox(width: DT.s12),
              Expanded(child: cells[i]),
            ],
          ],
        ),
      );

  Widget _field(TextEditingController c, String label,
          {String? Function(String?)? validator, int maxLines = 1}) =>
      TextFormField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: validator,
      );
}
