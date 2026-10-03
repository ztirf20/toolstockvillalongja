import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/inventory_provider.dart';
import '../utils.dart';

/// Owner only. Used for adding a new item and for editing one.
class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _supplier;
  late final TextEditingController _price;
  late final TextEditingController _qty;
  late final TextEditingController _min;
  late String _category;
  late String _unit;
  bool _saving = false;

  bool get _editing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _sku = TextEditingController(text: p?.sku ?? '');
    _supplier = TextEditingController(text: p?.supplier ?? '');
    _price = TextEditingController(text: p == null ? '' : p.price.toString());
    _qty = TextEditingController(text: p == null ? '' : p.quantity.toString());
    _min = TextEditingController(text: p?.minStock.toString() ?? '5');
    _category = p?.category ?? kCategories.first;
    _unit = p?.unit ?? kUnits.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _supplier.dispose();
    _price.dispose();
    _qty.dispose();
    _min.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final inv = context.read<InventoryProvider>();
    final product = Product(
      id: widget.product?.id,
      name: _name.text.trim(),
      category: _category,
      price: double.parse(_price.text),
      // Quantity of an existing item changes only via stock movements,
      // so every change is recorded in the history.
      quantity: _editing ? widget.product!.quantity : int.parse(_qty.text),
      minStock: int.parse(_min.text),
      updatedAt: DateTime.now(),
      sku: _sku.text.trim().toUpperCase(),
      unit: _unit,
      supplier: _supplier.text.trim(),
    );
    try {
      if (_editing) {
        await inv.updateProduct(product);
      } else {
        await inv.addProduct(product);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      ...kCategories,
      if (!kCategories.contains(_category)) _category,
    ];
    final units = [
      ...kUnits,
      if (!kUnits.contains(_unit)) _unit,
    ];
    final others = context
        .read<InventoryProvider>()
        .products
        .where((p) => p.id != widget.product?.id)
        .toList();
    final existingNames = others.map((p) => p.name.toLowerCase()).toSet();
    final existingSkus = others
        .where((p) => p.sku.isNotEmpty)
        .map((p) => p.sku.toLowerCase())
        .toSet();

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit item' : 'Add item')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Item name',
                prefixIcon: Icon(Icons.hardware_outlined),
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'Name is required';
                if (existingNames.contains(s.toLowerCase())) {
                  return 'An item with this name already exists';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sku,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'SKU / item code (optional)',
                prefixIcon: Icon(Icons.qr_code_2),
              ),
              validator: (v) {
                final s = v?.trim().toLowerCase() ?? '';
                if (s.isNotEmpty && existingSkus.contains(s)) {
                  return 'This SKU is already used by another item';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: [
                for (final c in categories)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Price each',
                      prefixText: '₱ ',
                    ),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null) return 'Enter a price';
                      if (n < 0) return 'Cannot be negative';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: [
                      for (final u in units)
                        DropdownMenuItem(value: u, child: Text(u)),
                    ],
                    onChanged: (v) => setState(() => _unit = v ?? _unit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _supplier,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Supplier (optional)',
                prefixIcon: Icon(Icons.local_shipping_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _qty,
              enabled: !_editing,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: _editing ? 'Current stock' : 'Starting stock',
                prefixIcon: const Icon(Icons.inventory_2_outlined),
                helperText: _editing
                    ? 'Use Stock in / Stock out to change it'
                    : null,
              ),
              validator: (v) =>
                  int.tryParse(v ?? '') == null ? 'Enter a whole number' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _min,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Low-stock alert level',
                prefixIcon: Icon(Icons.notifications_active_outlined),
                helperText: 'You are alerted when stock falls to this level',
              ),
              validator: (v) =>
                  int.tryParse(v ?? '') == null ? 'Enter a whole number' : null,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(_editing ? 'Save changes' : 'Add item'),
            ),
          ],
        ),
      ),
    );
  }
}