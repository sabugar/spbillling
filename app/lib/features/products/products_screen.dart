import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/inr.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/product.dart';
import '../auth/auth_controller.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  List<ProductCategory> _categories = [];
  List<Product> _products = [];
  List<ProductVariant> _variants = [];
  int? _selectedCategoryId;
  bool _loading = true;
  String? _error;
  bool _showActive = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(productRepoProvider);
      final cats = await repo.listCategories();
      final prods = await repo.listProducts();
      // Load all variants (active + inactive), filter client-side by toggle.
      final vars = await repo.listVariants(perPage: 200, includeInactive: true);
      setState(() {
        _categories = cats;
        _products = prods;
        _variants = vars;
        _selectedCategoryId ??= cats.isNotEmpty ? cats.first.id : null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addCategory() async {
    final name = await _promptText(context, 'New category');
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(productRepoProvider).createCategory(name.trim());
      _loadAll();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _openVariantForm({ProductVariant? existing}) async {
    if (_selectedCategoryId == null) {
      _snack('Pick a category first');
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _VariantFormDialog(
        categoryId: _selectedCategoryId!,
        products: _products
            .where((p) => p.categoryId == _selectedCategoryId)
            .toList(),
        existing: existing,
      ),
    );
    if (saved == true) _loadAll();
  }

  Future<void> _toggleActive(ProductVariant v) async {
    try {
      await ref
          .read(productRepoProvider)
          .setVariantActive(v.id, !v.isActive);
      _loadAll();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _delete(ProductVariant v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete variant?'),
        content: Text(
            'Delete "${v.name}"? This deactivates it (kept in history).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: DT.err600),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(productRepoProvider).deleteVariant(v.id);
      _loadAll();
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  List<ProductVariant> get _visibleVariants {
    Iterable<ProductVariant> rows = _variants;
    if (_selectedCategoryId != null) {
      final prodIds = _products
          .where((p) => p.categoryId == _selectedCategoryId)
          .map((p) => p.id)
          .toSet();
      rows = rows.where((v) => prodIds.contains(v.productId));
    }
    rows = rows.where((v) => v.isActive == _showActive);
    return rows.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DT.s24),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: DT.err700)))
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 240, child: _categoriesPane()),
                    const SizedBox(width: DT.s16),
                    Expanded(child: _variantsPane()),
                  ],
                ),
    );
  }

  Widget _categoriesPane() => Container(
        decoration: BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.circular(DT.rMd),
          border: Border.all(color: DT.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(DT.s12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Categories',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: DT.fsBody)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 16),
                    onPressed: _addCategory,
                    tooltip: 'Add category',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: DT.divider),
            Expanded(
              child: ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (_, i) {
                  final c = _categories[i];
                  final active = c.id == _selectedCategoryId;
                  return InkWell(
                    onTap: () => setState(() => _selectedCategoryId = c.id),
                    child: Container(
                      height: 40,
                      padding:
                          const EdgeInsets.symmetric(horizontal: DT.s12),
                      color: active ? DT.brand50 : null,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        c.name,
                        style: TextStyle(
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w500,
                          color: active ? DT.brand800 : DT.text,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );

  Widget _variantsPane() {
    final isAdmin = ref.watch(authControllerProvider).role == 'admin';
    return Container(
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(DT.s12),
            child: Row(
              children: [
                const Text('Variants',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: DT.fsBody)),
                const SizedBox(width: DT.s16),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Active')),
                    ButtonSegment(value: false, label: Text('Inactive')),
                  ],
                  selected: {_showActive},
                  onSelectionChanged: (s) =>
                      setState(() => _showActive = s.first),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _openVariantForm(),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add Variant'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: DT.divider),
          Expanded(
            child: _visibleVariants.isEmpty
                ? Center(
                    child: Text(
                        _showActive
                            ? 'No active variants.'
                            : 'No inactive variants.',
                        style: const TextStyle(color: DT.text2)))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 40,
                      dataRowMinHeight: DT.rowHeight,
                      dataRowMaxHeight: DT.rowHeight,
                      columns: const [
                        DataColumn(label: Text('Product')),
                        DataColumn(label: Text('Variant')),
                        DataColumn(label: Text('Price'), numeric: true),
                        DataColumn(label: Text('GST %'), numeric: true),
                        DataColumn(label: Text('HSN')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('')),
                      ],
                      rows: [
                        for (final v in _visibleVariants)
                          DataRow(cells: [
                            DataCell(Text(v.productName ?? '—')),
                            DataCell(Text(v.name)),
                            DataCell(Text(fmtINR(v.unitPrice),
                                style: AppTheme.mono(size: 12))),
                            DataCell(Text(v.gstRate.toStringAsFixed(1),
                                style: AppTheme.mono(size: 12))),
                            DataCell(Text(v.hsnCode ?? '—')),
                            DataCell(_statusChip(v.isActive)),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 16),
                                  onPressed: isAdmin
                                      ? () => _openVariantForm(existing: v)
                                      : null,
                                ),
                                IconButton(
                                  tooltip: v.isActive
                                      ? 'Deactivate'
                                      : 'Activate',
                                  icon: Icon(
                                    v.isActive
                                        ? Icons.toggle_on
                                        : Icons.toggle_off,
                                    size: 18,
                                    color: v.isActive
                                        ? DT.ok600
                                        : DT.text3,
                                  ),
                                  onPressed:
                                      isAdmin ? () => _toggleActive(v) : null,
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline,
                                      size: 16, color: DT.err600),
                                  onPressed:
                                      isAdmin ? () => _delete(v) : null,
                                ),
                              ],
                            )),
                          ]),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(bool active) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

Future<String?> _promptText(BuildContext context, String title) async {
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  return ok == true ? ctrl.text : null;
}

class _VariantFormDialog extends ConsumerStatefulWidget {
  final int categoryId;
  final List<Product> products;
  final ProductVariant? existing;
  const _VariantFormDialog({
    required this.categoryId,
    required this.products,
    this.existing,
  });

  @override
  ConsumerState<_VariantFormDialog> createState() => _VariantFormDialogState();
}

class _VariantFormDialogState extends ConsumerState<_VariantFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _productName = TextEditingController();
  late final TextEditingController _variantName;
  late final TextEditingController _price;
  late final TextEditingController _deposit;
  late final TextEditingController _gst;
  late final TextEditingController _hsn;
  late final TextEditingController _sku;
  int? _productId;
  bool _returnable = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _variantName = TextEditingController(text: e?.name ?? '');
    _price = TextEditingController(text: e?.unitPrice.toStringAsFixed(2) ?? '');
    _deposit = TextEditingController(
        text: e?.depositAmount.toStringAsFixed(2) ?? '0');
    _gst =
        TextEditingController(text: e?.gstRate.toStringAsFixed(2) ?? '5');
    _hsn = TextEditingController(text: e?.hsnCode ?? '');
    _sku = TextEditingController(text: e?.skuCode ?? '');
    if (e != null) {
      _productId = e.productId;
      _returnable = e.isReturnable ?? true;
    } else if (widget.products.isNotEmpty) {
      _productId = widget.products.first.id;
      _returnable = widget.products.first.isReturnable;
    }
  }

  @override
  void dispose() {
    for (final c in [_productName, _variantName, _price, _deposit, _gst, _hsn, _sku]) {
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
      final repo = ref.read(productRepoProvider);
      if (widget.existing != null) {
        await repo.updateVariant(widget.existing!.id, {
          'name': _variantName.text.trim(),
          if (_sku.text.trim().isNotEmpty) 'sku_code': _sku.text.trim(),
          'unit_price': double.tryParse(_price.text) ?? 0,
          'deposit_amount': double.tryParse(_deposit.text) ?? 0,
          'gst_rate': double.tryParse(_gst.text) ?? 0,
        });
      } else {
        int pid;
        if (_productId != null) {
          pid = _productId!;
        } else {
          final p = await repo.createProduct({
            'category_id': widget.categoryId,
            'name': _productName.text.trim(),
            'is_returnable': _returnable,
            if (_hsn.text.trim().isNotEmpty) 'hsn_code': _hsn.text.trim(),
          });
          pid = p.id;
        }
        await repo.createVariant({
          'product_id': pid,
          'name': _variantName.text.trim(),
          if (_sku.text.trim().isNotEmpty) 'sku_code': _sku.text.trim(),
          'unit_price': double.tryParse(_price.text) ?? 0,
          'deposit_amount': double.tryParse(_deposit.text) ?? 0,
          'gst_rate': double.tryParse(_gst.text) ?? 0,
          'is_active': true,
        });
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
    final isEdit = widget.existing != null;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(DT.s20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(isEdit ? 'Edit variant' : 'Add variant',
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
                  if (!isEdit)
                    DropdownButtonFormField<int?>(
                      initialValue: _productId,
                      decoration:
                          const InputDecoration(labelText: 'Product'),
                      items: [
                        for (final p in widget.products)
                          DropdownMenuItem<int?>(
                              value: p.id, child: Text(p.name)),
                        const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('+ Create new product')),
                      ],
                      onChanged: (v) => setState(() => _productId = v),
                    ),
                  if (!isEdit && _productId == null) ...[
                    const SizedBox(height: DT.s8),
                    TextFormField(
                      controller: _productName,
                      decoration: const InputDecoration(
                          labelText: 'New product name *'),
                      validator: (v) =>
                          _productId == null && (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                    ),
                    const SizedBox(height: DT.s8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _returnable,
                      onChanged: (v) => setState(() => _returnable = v),
                      title: const Text('Returnable (cylinder)'),
                    ),
                  ],
                  const SizedBox(height: DT.s8),
                  TextFormField(
                    controller: _variantName,
                    decoration:
                        const InputDecoration(labelText: 'Variant name *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: DT.s8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _price,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Price *'),
                          validator: (v) =>
                              (double.tryParse(v ?? '') == null)
                                  ? 'Invalid'
                                  : null,
                        ),
                      ),
                      const SizedBox(width: DT.s12),
                      Expanded(
                        child: TextFormField(
                          controller: _deposit,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Deposit'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DT.s8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _gst,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'GST %'),
                        ),
                      ),
                      const SizedBox(width: DT.s12),
                      Expanded(
                        child: TextFormField(
                          controller: _hsn,
                          decoration:
                              const InputDecoration(labelText: 'HSN'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DT.s8),
                  TextFormField(
                    controller: _sku,
                    decoration:
                        const InputDecoration(labelText: 'SKU code'),
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
                            : Text(isEdit ? 'Save' : 'Create'),
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
}
