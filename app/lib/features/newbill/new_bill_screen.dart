
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/inr.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/bill.dart';
import '../../data/models/customer.dart';
import '../../data/models/product.dart';
import '../customers/customer_form_dialog.dart';

/// Route `/bills/new`.
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
  final _searchFocus = FocusNode();
  DateTime _chequeDate = DateTime.now();

  Timer? _debounce;
  List<Customer> _results = [];
  bool _searchedOnce = false;
  String _lastSearchQuery = '';
  Customer? _selectedCustomer;
  DateTime _billDate = DateTime.now();
  String _paymentMode = 'cash';

  List<ProductVariant> _variants = [];
  bool _loadingVariants = true;
  int _lastCatalogVersion = 0;
  final List<BillItemDraft> _items = [];
  bool _saving = false;
  String? _error;
  String _nextBillNumber = '';

  @override
  void initState() {
    super.initState();
    _loadVariants();
    _refreshNextBillNumber();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
  }

  /// Global Enter-key handler registered on [HardwareKeyboard].
  ///
  /// Returning `true` consumes the event so focused `TextField`s don't
  /// also see it. Disabled while a save is already in flight.
  bool _handleGlobalKey(KeyEvent event) {
    if (!mounted) return false;
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return false;
    }
    if (_saving) return true;
    _save();
    return true; // consume so TextFields don't also process it
  }

  /// Peeks the next bill number for display at the top of the form.
  /// Silently swallows errors — it's a cosmetic hint, not critical.
  Future<void> _refreshNextBillNumber() async {
    try {
      final n = await ref.read(billRepoProvider).nextBillNumber(billDate: _billDate);
      if (mounted) setState(() => _nextBillNumber = n);
    } catch (_) {}
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    _debounce?.cancel();
    _searchCtrl.dispose();
    _discountCtrl.dispose();
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    _chequeNum.dispose();
    _chequeBank.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Loads the sellable variants for the items dropdown. After load,
  /// seeds the default "15 kg × 1 @ 2950" row if the items list is empty.
  Future<void> _loadVariants() async {
    try {
      final list = await ref
          .read(productRepoProvider)
          .listVariants(perPage: 100, active: true);
      setState(() {
        _variants = list;
        _loadingVariants = false;
        // If the user already has rows queued, refresh their rate/gst/label
        // from the latest variant data so price edits in /products show up.
        for (final item in _items) {
          final fresh = list.where((v) => v.id == item.variantId);
          if (fresh.isNotEmpty) {
            final v = fresh.first;
            item.rate = v.unitPrice;
            item.gstRate = v.gstRate;
            item.variantLabel = v.displayName;
          }
        }
      });
      _seedDefaultRowIfEmpty();
    } catch (e) {
      setState(() {
        _loadingVariants = false;
        _error = e.toString();
      });
    }
  }

  /// Picks the best match for the default first-row variant.
  /// Priority: (1) name contains "15" + "kg"/"cylinder", (2) first
  /// variant with "cylinder" in the label, (3) first variant overall.
  ProductVariant? _defaultFirstRowVariant() {
    if (_variants.isEmpty) return null;
    // Prefer any cylinder variant whose name mentions "15".
    ProductVariant? match;
    for (final v in _variants) {
      final label = v.displayName.toLowerCase();
      if (label.contains('15') &&
          (label.contains('kg') || label.contains('cylinder'))) {
        match = v;
        break;
      }
    }
    // Fallback: first variant with "cylinder" in label; else first variant.
    match ??= _variants.firstWhere(
      (v) => v.displayName.toLowerCase().contains('cylinder'),
      orElse: () => _variants.first,
    );
    return match;
  }

  /// Inserts one pre-filled item row (15 kg cylinder × 1 @ 2950) if the
  /// items list is empty. Owner-requested shortcut for the common case.
  void _seedDefaultRowIfEmpty() {
    if (_items.isNotEmpty) return;
    final v = _defaultFirstRowVariant();
    if (v == null) return;
    setState(() {
      _items.add(BillItemDraft(
        variantId: v.id,
        variantLabel: v.displayName,
        quantity: 1,
        rate: v.unitPrice,   // pull live price from the variant
        gstRate: v.gstRate,
      ));
    });
  }

  /// Debounced customer typeahead. Only active customers are shown in
  /// the dropdown; inactive ones must be re-activated first.
  void _search(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final q = v.trim();
      if (q.isEmpty) {
        setState(() {
          _results = [];
          _searchedOnce = false;
          _lastSearchQuery = '';
        });
        return;
      }
      try {
        final r = await ref.read(customerRepoProvider).search(q);
        if (mounted) {
          setState(() {
            _results = r.where((c) => c.status == 'active').toList();
            _searchedOnce = true;
            _lastSearchQuery = q;
          });
        }
      } catch (_) {}
    });
  }

  /// Opens the customer-add dialog with the current query pre-filled.
  /// If the query looks like a mobile (10+ digits), it's used as mobile;
  /// otherwise it's treated as the name.
  Future<void> _addNewCustomerInline() async {
    final query = _lastSearchQuery;
    final digits = query.replaceAll(RegExp(r'\D'), '');
    final prefillMobile = digits.length >= 10 ? digits.substring(0, 10) : null;
    final prefillName = (prefillMobile == null && query.isNotEmpty) ? query : null;
    final saved = await showDialog<Customer?>(
      context: context,
      builder: (_) => CustomerFormDialog(
        prefillName: prefillName,
        prefillMobile: prefillMobile,
      ),
    );
    if (saved != null) {
      setState(() {
        _selectedCustomer = saved;
        _results = [];
        _searchedOnce = false;
        _searchCtrl.text =
            '${saved.name}${saved.village?.isNotEmpty == true ? ' — ${saved.village}' : ''}';
      });
    }
  }

  /// Appends a blank item row using the first available variant's
  /// default price / GST.
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

  /// Updates an existing row when the user picks a different variant —
  /// also refreshes the price and GST to the new variant's defaults.
  void _changeVariant(BillItemDraft draft, int newId) {
    final v = _variants.firstWhere((x) => x.id == newId);
    setState(() {
      draft.variantId = v.id;
      draft.variantLabel = v.displayName;
      draft.rate = v.unitPrice;
      draft.gstRate = v.gstRate;
    });
  }

  // GST is price-inclusive. Subtotal = sum(lineBase), GST = sum(lineGst).
  // Grand = Subtotal + GST − discount  (= sum(lineTotal) − discount).
  double get _subtotal => _items.fold(0, (s, it) => s + it.lineBase);
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

  /// Lets the user back-date a bill (max: tomorrow). Refreshes the
  /// "next bill number" hint because numbering is per fiscal year.
  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) {
      setState(() => _billDate = d);
      _refreshNextBillNumber();
    }
  }

  /// Called after a successful save — clears the customer + search box
  /// but keeps items/payment so serial bills with similar items stay
  /// fast. Focus snaps back to the customer search field.
  void _resetForNextBill() {
    // Keep items, payment values, notes — only clear the customer.
    setState(() {
      _selectedCustomer = null;
      _results = [];
      _searchedOnce = false;
      _lastSearchQuery = '';
      _searchCtrl.clear();
      _error = null;
    });
    _refreshNextBillNumber();
    _searchFocus.requestFocus();
  }

  /// Validates and POSTs the bill. On success shows a snackbar with the
  /// generated bill number and calls [_resetForNextBill].
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
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
            chequeDetails: cheque,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bill ${bill.billNumber} saved'),
          backgroundColor: DT.ok600,
          duration: const Duration(seconds: 3),
        ),
      );
      _saving = false;
      _resetForNextBill();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reload variants whenever Products screen bumps the catalog version,
    // so price/name edits show up here without a navigation reload.
    final version = ref.watch(productCatalogVersionProvider);
    if (version != _lastCatalogVersion) {
      _lastCatalogVersion = version;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadVariants();
      });
    }
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
            focusNode: _searchFocus,
            onChanged: _search,
            decoration: const InputDecoration(
              hintText: 'Search by mobile, consumer #, or name',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
          if (_selectedCustomer == null &&
              _searchedOnce &&
              _lastSearchQuery.isNotEmpty) ...[
            const SizedBox(height: DT.s8),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                border: Border.all(color: DT.border),
                borderRadius: BorderRadius.circular(DT.rSm),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_results.isNotEmpty)
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _results.length,
                        itemBuilder: (_, i) {
                          final c = _results[i];
                          final doCode = c.distributorOutlet?.code ?? '';
                          final village = c.village;
                          final cn = c.consumerNumber;
                          final villageSuffix = village?.isNotEmpty == true
                              ? ' — $village'
                              : '';
                          return ListTile(
                            dense: true,
                            title: Text(
                                '${c.name}$villageSuffix${doCode.isEmpty ? '' : '  ·  DO $doCode'}'),
                            subtitle: Text(
                              '${c.mobile}${cn?.isNotEmpty == true ? '  ·  $cn' : ''}',
                              style:
                                  AppTheme.mono(size: 11, color: DT.text2),
                            ),
                            onTap: () => setState(() {
                              _selectedCustomer = c;
                              _results = [];
                              _searchedOnce = false;
                              _searchCtrl.text = '${c.name}$villageSuffix';
                            }),
                          );
                        },
                      ),
                    ),
                  if (_results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(DT.s12),
                      child: Text('No customers match.',
                          style: TextStyle(color: DT.text2)),
                    ),
                  const Divider(height: 1, color: DT.divider),
                  InkWell(
                    onTap: _addNewCustomerInline,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: DT.s12, vertical: DT.s12),
                      color: DT.brand50,
                      child: Row(
                        children: [
                          const Icon(Icons.add_circle,
                              size: 16, color: DT.brand700),
                          const SizedBox(width: DT.s8),
                          Expanded(
                            child: Text(
                              'Add new customer "$_lastSearchQuery"',
                              style: const TextStyle(
                                  color: DT.brand800,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(Icons.arrow_forward,
                              size: 14, color: DT.brand700),
                        ],
                      ),
                    ),
                  ),
                ],
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
                            '${_selectedCustomer!.name}${_selectedCustomer!.village?.isNotEmpty == true ? ' — ${_selectedCustomer!.village}' : ''}',
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
                  Text(
                    '${_selectedCustomer!.mobile}${_selectedCustomer!.consumerNumber?.isNotEmpty == true ? '  ·  ${_selectedCustomer!.consumerNumber}' : ''}${_selectedCustomer!.distributorOutlet == null ? '' : '  ·  DO ${_selectedCustomer!.distributorOutlet!.code}'}',
                    style: AppTheme.mono(size: 11, color: DT.text2),
                  ),
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
                width: 110,
                child: TextFormField(
                  initialValue: d.rate.toStringAsFixed(2),
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Rate (incl GST)'),
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
                style: AppTheme.mono(size: 12, weight: FontWeight.w600)),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Summary',
                    style: Theme.of(context).textTheme.headlineMedium),
                const Spacer(),
                if (_nextBillNumber.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: DT.s8, vertical: 2),
                    decoration: BoxDecoration(
                      color: DT.brand50,
                      borderRadius: BorderRadius.circular(DT.rXs),
                    ),
                    child: Text(
                      // Show only the trailing serial (e.g. "0015") — the
                      // FY prefix BILL/26-27/ is implicit and noisy here.
                      '# ${_nextBillNumber.contains('/') ? _nextBillNumber.split('/').last : _nextBillNumber}',
                      style: AppTheme.mono(
                          size: 11,
                          weight: FontWeight.w700,
                          color: DT.brand800),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: DT.s12),
            _sumRow('Subtotal (excl GST)', fmtINR(_subtotal)),
            _sumRow('GST', fmtINR(_gst)),
            TextField(
              controller: _discountCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Discount'),
            ),
            const SizedBox(height: DT.s8),
            _sumRow('Grand Total', fmtINR(_total),
                bold: true, size: 16, color: DT.text),
            const Divider(height: DT.s24, color: DT.divider),
            DropdownButtonFormField<String>(
              initialValue: _paymentMode,
              decoration: const InputDecoration(labelText: 'Payment mode'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                DropdownMenuItem(value: 'upi', child: Text('UPI')),
                DropdownMenuItem(value: 'card', child: Text('Card')),
                DropdownMenuItem(value: 'credit', child: Text('Credit')),
              ],
              onChanged: (v) => setState(() => _paymentMode = v ?? 'cash'),
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
                decoration: const InputDecoration(labelText: 'Bank name'),
              ),
              const SizedBox(height: DT.s8),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 14),
                label: Text(
                    'Cheque date: ${_chequeDate.toIso8601String().split('T').first}'),
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
                label: const Text('Save'),
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
