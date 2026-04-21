import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/customer.dart';
import '../../data/models/distributor_outlet.dart';

class CustomerFormDialog extends ConsumerStatefulWidget {
  final Customer? existing;
  final String? prefillName;
  final String? prefillMobile;

  const CustomerFormDialog({
    super.key,
    this.existing,
    this.prefillName,
    this.prefillMobile,
  });

  @override
  ConsumerState<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _consumerNumber;
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
  DistributorOutlet? _selectedDO;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _consumerNumber = TextEditingController(text: e?.consumerNumber ?? '');
    _name = TextEditingController(text: e?.name ?? widget.prefillName ?? '');
    _mobile =
        TextEditingController(text: e?.mobile ?? widget.prefillMobile ?? '');
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
    _selectedDO = e?.distributorOutlet;
  }

  @override
  void dispose() {
    for (final c in [
      _consumerNumber,
      _name,
      _mobile,
      _altMobile,
      _village,
      _city,
      _district,
      _state,
      _pincode,
      _address,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDO == null) {
      setState(() => _error = 'Please select a distributor outlet (DO)');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final village = _village.text.trim();
      final cityInput = _city.text.trim();
      final body = {
        'consumer_number': _consumerNumber.text.trim(),
        'do_id': _selectedDO!.id,
        'name': _name.text.trim(),
        'mobile': _mobile.text.trim(),
        if (_altMobile.text.trim().isNotEmpty)
          'alternate_mobile': _altMobile.text.trim(),
        'village': village,
        // Backend requires city NOT NULL — fall back to village.
        'city': cityInput.isEmpty ? village : cityInput,
        if (_district.text.trim().isNotEmpty)
          'district': _district.text.trim(),
        if (_state.text.trim().isNotEmpty) 'state': _state.text.trim(),
        if (_pincode.text.trim().isNotEmpty) 'pincode': _pincode.text.trim(),
        if (_address.text.trim().isNotEmpty)
          'full_address': _address.text.trim(),
        'customer_type': _type,
        'status': _status,
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      };
      final repo = ref.read(customerRepoProvider);
      final saved = widget.existing == null
          ? await repo.create(body)
          : await repo.update(widget.existing!.id, body);
      if (mounted) Navigator.of(context).pop(saved);
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
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(DT.s20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
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
                    _field(_consumerNumber, 'Consumer Number *',
                        validator: _required),
                  ]),
                  const SizedBox(height: DT.s8),
                  DOTypeahead(
                    initial: _selectedDO,
                    onChanged: (v) => setState(() => _selectedDO = v),
                  ),
                  const SizedBox(height: DT.s8),
                  _row([
                    _field(_village, 'Village *', validator: _required),
                    _field(_city, 'City'),
                  ]),
                  _row([
                    _field(_district, 'District'),
                    _field(_state, 'State'),
                  ]),
                  _row([
                    _field(_pincode, 'Pincode'),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _type,
                            decoration:
                                const InputDecoration(labelText: 'Type'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'domestic', child: Text('Domestic')),
                              DropdownMenuItem(
                                  value: 'commercial',
                                  child: Text('Commercial')),
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
                  ]),
                  _field(_address, 'Full address', maxLines: 2),
                  const SizedBox(height: DT.s8),
                  _field(_notes, 'Notes', maxLines: 2),
                  const SizedBox(height: DT.s20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
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

/// DO typeahead — debounced backend search + static preload fallback.
class DOTypeahead extends ConsumerStatefulWidget {
  final DistributorOutlet? initial;
  final ValueChanged<DistributorOutlet?> onChanged;
  final String label;

  const DOTypeahead({
    super.key,
    this.initial,
    required this.onChanged,
    this.label = 'Distributor Outlet (DO) *',
  });

  @override
  ConsumerState<DOTypeahead> createState() => _DOTypeaheadState();
}

class _DOTypeaheadState extends ConsumerState<DOTypeahead> {
  final TextEditingController _text = TextEditingController();
  Timer? _debounce;
  List<DistributorOutlet> _options = [];
  DistributorOutlet? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    if (_selected != null) _text.text = _selected!.display;
    // Preload some so empty-click shows options.
    Future.microtask(() async {
      try {
        final list = await ref.read(doRepoProvider).search('', limit: 20);
        if (mounted) setState(() => _options = list);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _onTyped(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final list = await ref.read(doRepoProvider).search(v, limit: 20);
        if (mounted) setState(() => _options = list);
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<DistributorOutlet>(
      initialValue: _selected == null
          ? const TextEditingValue()
          : TextEditingValue(text: _selected!.display),
      displayStringForOption: (o) => o.display,
      optionsBuilder: (val) {
        _onTyped(val.text);
        final q = val.text.trim().toLowerCase();
        if (q.isEmpty) return _options;
        return _options.where((o) =>
            o.code.toLowerCase().contains(q) ||
            o.ownerName.toLowerCase().contains(q) ||
            o.location.toLowerCase().contains(q));
      },
      onSelected: (o) {
        setState(() => _selected = o);
        widget.onChanged(o);
      },
      fieldViewBuilder: (ctx, ctrl, focus, _) {
        return TextFormField(
          controller: ctrl,
          focusNode: focus,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: 'Type code, owner, or location',
            suffixIcon: _selected == null
                ? const Icon(Icons.arrow_drop_down)
                : IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      ctrl.clear();
                      setState(() => _selected = null);
                      widget.onChanged(null);
                    },
                  ),
          ),
          validator: (_) => _selected == null ? 'Required' : null,
        );
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(DT.rMd),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 420),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (c, i) {
                  final o = options.elementAt(i);
                  return InkWell(
                    onTap: () => onSelected(o),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: DT.s12, vertical: DT.s8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: DT.brand50,
                              borderRadius: BorderRadius.circular(DT.rXs),
                            ),
                            child: Text(o.code,
                                style: const TextStyle(
                                    color: DT.brand800,
                                    fontSize: DT.fsSm,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: DT.s8),
                          Expanded(
                            child: Text(
                              '${o.ownerName} — ${o.location}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
