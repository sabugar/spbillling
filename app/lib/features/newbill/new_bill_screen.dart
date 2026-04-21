import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/inr.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/bill.dart';
import '../../data/models/customer.dart';
import '../../data/models/product.dart';

class NewBillScreen extends ConsumerStatefulWidget {
  const NewBillScreen({super.key});

  @override
  ConsumerState<NewBillScreen> createState() => _NewBillScreenState();
}

class _NewBillScreenState extends ConsumerState<NewBillScreen> {
  final _searchCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final _paidCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  final _chequeNum = TextEditingController();
  final _chequeBank = TextEditingController();
  DateTime _chequeDate = DateTime.now();

  Timer? _debounce;
  List<Customer> _results = [];
  Customer? _selectedCustomer;
  DateTime _billDate = DateTime.now();
  String _paymentMode = 'cash';

  List<ProductVariant> _variants = [];
  bool _loadingVariants = true;
  final List<BillItemDraft> _items = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVariants();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _discountCtrl.dispose();
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    _chequeNum.dispose();
    _chequeBank.dispose();
    super.dispose();
  }

  Future<void> _loadVariants() async {
    try {
      final list = await ref
          .read(productRepoProvider)
          .listVariants(perPage: 100, active: true);
      setState(() {
        _variants = list;
        _loadingVariants = false;
      });
    } catch (e) {
      setState(() {
        _loadingVariants = false;
        _error = e.toString();
      });
    }
  }

  void _search(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (v.trim().isEmpty) {
        setState(() => _results = []);
        return;
      }
      try {
        final r = await ref.read(customerRepoProvider).search(v.trim());
        if (mounted) setState(() => _results = r);
      } catch (_) {}
    });
  }

  void _addRow() {
    if (_variants.isEmpty) return;
    final v = _variants.first;
    setState(() {
      _items.add(BillItemDraft(
        variantId: v.id,
        variantLabel: v.displayName,
        quantity: 1,
        rate: v.unitPrice,
        gstRate: v.gstRate,
      ));
    });
  }

  void _changeVariant(BillItemDraft draft, int newId) {
    final v = _variants.firstWhere((x) => x.id == newId);
    setState(() {
      draft.variantId = v.id;
      draft.variantLabel = v.displayName;
      draft.rate = v.unitPrice;
      draft.gstRate = v.gstRate;
    });
  }

  double get _subtotal =>
      _items.fold(0, (s, it) => s + it.lineSubtotal);
  double get _gst => _items.fold(0, (s, it) => s + it.lineGst);
  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _total => _subtotal + _gst - _discount;
  double get _paid => double.tryParse(_paidCtrl.text) ?? 0;
  double get _balance => _total - _paid;

  bool _variantReturnable(int variantId) {
    final v = _variants.firstWhere(
      (x) => x.id == variantId,
      orElse: () => _variants.first,
    );
    return v.isReturnable ?? false;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _billDate = d);
  }

  Future<void> _save() async {
    if (_selectedCustomer == null) {
      setState(() => _error = 'Pick a customer first');
      return;
    }
    if (_items.isEmpty) {
      setState(() => _error = 'Add at least one item');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      Map<String, dynamic>? cheque;
      if (_paymentMode == 'cheque') {
        cheque = {
          'cheque_number': _chequeNum.text.trim(),
          'bank_name': _chequeBank.text.trim(),
          'cheque_date': _chequeDate.toIso8601String().split('T').first,
        };
      }
      final bill = await ref.read(billRepoProvider).create(
            customerId: _selectedCustomer!.id,
            billDate: _billDate,
            items: _items,
            discount: _discount,
            amountPaid: _paid,
            paymentMode: _paymentMode,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            chequeDetails: cheque,
          );
      if (mounted) context.go('/bills/${bill.id}/pdf');
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingVariants) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.all(DT.s24),
      child: LayoutBuilder(
        builder: (ctx, cs) {
          final wide = cs.maxWidth > 900;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: SingleChildScrollView(child: _leftCol())),
                const SizedBox(width: DT.s20),
                SizedBox(
                    width: 320,
                    child: SingleChildScrollView(child: _summary())),
              ],
            );
          }
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _leftCol(),
                const SizedBox(height: DT.s16),
                _summary(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _leftCol() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _card('Customer', _customerSection()),
          const SizedBox(height: DT.s16),
          _card('Items', _itemsSection()),
        ],
      );

  Widget _card(String title, Widget body) => Container(
        padding: const EdgeInsets.all(DT.s16),
        decoration: BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.circular(DT.rMd),
          border: Border.all(color: DT.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: DT.s12),
            body,
          ],
        ),
      );

  Widget _customerSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: _search,
            decoration: const InputDecoration(
              hintText: 'Search by mobile or name',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
          if (_selectedCustomer == null && _results.isNotEmpty) ...[
            const SizedBox(height: DT.s8),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                border: Border.all(color: DT.border),
                borderRadius: BorderRadius.circular(DT.rSm),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final c = _results[i];
                  return ListTile(
                    dense: true,
                    title: Text('${c.name} — ${c.village}'),
                    subtitle: Text(c.mobile,
                        style: AppTheme.mono(size: 11, color: DT.text2)),
                    onTap: () => setState(() {
                      _selectedCustomer = c;
                      _results = [];
                      _searchCtrl.text = '${c.name} — ${c.village}';
                    }),
                  );
                },
              ),
            ),
          ],
          if (_selectedCustomer != null) ...[
            const SizedBox(height: DT.s12),
            Container(
              padding: const EdgeInsets.all(DT.s12),
              decoration: BoxDecoration(
                color: DT.brand50,
                borderRadius: BorderRadius.circular(DT.rSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            '${_selectedCustomer!.name} — ${_selectedCustomer!.village}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() {
                          _selectedCustomer = null;
                          _searchCtrl.clear();
                        }),
                      ),
                    ],
                  ),
                  Text(_selectedCustomer!.mobile,
                      style: AppTheme.mono(size: 11, color: DT.text2)),
                  const SizedBox(height: DT.s8),
                  Wrap(
                    spacing: DT.s8,
                    runSpacing: DT.s4,
                    children: [
                      _pill('Balance ${fmtINR(_selectedCustomer!.balance)}',
                          DT.warn50, DT.warn700),
                      _pill('Empty ${_selectedCustomer!.emptyPending}',
                          DT.info500.withValues(alpha: .1), DT.info600),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: DT.s12),
          Wrap(
            spacing: DT.s8,
            runSpacing: DT.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Bill date:', style: TextStyle(color: DT.text2)),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 14),
                label: Text(_billDate.toIso8601String().split('T').first),
                onPressed: _pickDate,
              ),
            ],
          ),
        ],
      );

  Widget _pill(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: DT.s8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(DT.rXs),
        ),
        child: Text(text,
            style: TextStyle(
                color: fg, fontSize: DT.fsSm, fontWeight: FontWeight.w600)),
      );

  Widget _itemsSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: DT.s16),
              child: Text('No items yet.',
                  style: TextStyle(color: DT.text2)),
            ),
          for (var i = 0; i < _items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: DT.s8),
              child: _itemRow(_items[i], i),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _variants.isEmpty ? null : _addRow,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add item'),
            ),
          ),
          if (_variants.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: DT.s8),
              child: Text(
                  'No active variants. Add products first in Products screen.',
                  style: TextStyle(color: DT.warn700, fontSize: DT.fsSm)),
            ),
        ],
      );

  Widget _itemRow(BillItemDraft d, int idx) {
    final returnable = _variantReturnable(d.variantId);
    return Container(
      padding: const EdgeInsets.all(DT.s8),
      decoration: BoxDecoration(
        color: DT.surface2,
        borderRadius: BorderRadius.circular(DT.rSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: d.variantId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Variant'),
                  items: [
                    for (final v in _variants)
                      DropdownMenuItem(
                          value: v.id,
                          child: Text(v.displayName,
                              overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => v == null ? null : _changeVariant(d, v),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: DT.err600),
                onPressed: () => setState(() => _items.removeAt(idx)),
              ),
            ],
          ),
          const SizedBox(height: DT.s8),
          Wrap(
            spacing: DT.s8,
            runSpacing: DT.s8,
            children: [
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: d.quantity.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Qty'),
                  onChanged: (v) =>
                      setState(() => d.quantity = int.tryParse(v) ?? 0),
                ),
              ),
              SizedBox(
                width: 100,
                child: TextFormField(
                  initialValue: d.rate.toStringAsFixed(2),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Rate'),
                  onChanged: (v) =>
                      setState(() => d.rate = double.tryParse(v) ?? 0),
                ),
              ),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: d.gstRate.toStringAsFixed(1),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'GST %'),
                  onChanged: (v) =>
                      setState(() => d.gstRate = double.tryParse(v) ?? 0),
                ),
              ),
              if (returnable)
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    initialValue: d.emptyReturned.toString(),
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Empty ret.'),
                    onChanged: (v) => setState(
                        () => d.emptyReturned = int.tryParse(v) ?? 0),
                  ),
                ),
            ],
          ),
          const SizedBox(height: DT.s4),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Line total: ${fmtINR(d.lineTotal)}',
                style:
                    AppTheme.mono(size: 12, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _summary() => Container(
        padding: const EdgeInsets.all(DT.s16),
        decoration: BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.circular(DT.rMd),
          border: Border.all(color: DT.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Summary',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: DT.s12),
            _sumRow('Subtotal', fmtINR(_subtotal)),
            _sumRow('GST', fmtINR(_gst)),
            TextField(
              controller: _discountCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Discount'),
            ),
            const SizedBox(height: DT.s8),
            _sumRow('Total', fmtINR(_total),
                bold: true, size: 16, color: DT.text),
            const Divider(height: DT.s24, color: DT.divider),
            DropdownButtonFormField<String>(
              initialValue: _paymentMode,
              decoration:
                  const InputDecoration(labelText: 'Payment mode'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                DropdownMenuItem(value: 'upi', child: Text('UPI')),
                DropdownMenuItem(value: 'card', child: Text('Card')),
                DropdownMenuItem(value: 'credit', child: Text('Credit')),
              ],
              onChanged: (v) =>
                  setState(() => _paymentMode = v ?? 'cash'),
            ),
            const SizedBox(height: DT.s8),
            TextField(
              controller: _paidCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Amount paid'),
            ),
            if (_paymentMode == 'cheque') ...[
              const SizedBox(height: DT.s8),
              TextField(
                controller: _chequeNum,
                decoration:
                    const InputDecoration(labelText: 'Cheque number'),
              ),
              const SizedBox(height: DT.s8),
              TextField(
                controller: _chequeBank,
                decoration:
                    const InputDecoration(labelText: 'Bank name'),
              ),
              const SizedBox(height: DT.s8),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 14),
                label:
                    Text('Cheque date: ${_chequeDate.toIso8601String().split('T').first}'),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _chequeDate,
                    firstDate: DateTime(2020),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setState(() => _chequeDate = d);
                },
              ),
            ],
            const SizedBox(height: DT.s8),
            _sumRow('Balance due', fmtINR(_balance),
                color: _balance > 0 ? DT.err700 : DT.ok700),
            const SizedBox(height: DT.s12),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
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
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check, size: 16),
                label: const Text('Save & Print'),
              ),
            ),
          ],
        ),
      );

  Widget _sumRow(String label, String value,
      {bool bold = false, double size = 13, Color color = DT.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: bold ? color : DT.text2,
                  fontSize: size,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          const Spacer(),
          Text(value,
              style: AppTheme.mono(
                  size: size,
                  weight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }
}
