import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/stock_movement.dart';
import '../providers/inventory_provider.dart';
import '../utils.dart';
import 'common.dart';
import 'stock_movement_sheet.dart';

/// Quick flow: choose an item from a searchable list, then record the movement.
Future<void> startStockFlow(BuildContext context, MovementType type) async {
  final picked = await showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PickerSheet(type: type),
  );
  if (picked != null && context.mounted) {
    await showStockMovementSheet(context, picked, initial: type);
  }
}

class _PickerSheet extends StatefulWidget {
  final MovementType type;
  const _PickerSheet({required this.type});

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final products = context.watch<InventoryProvider>().products;
    final isOut = widget.type == MovementType.outgoing;
    final list = products
        .where((p) =>
            _q.isEmpty ||
            p.name.toLowerCase().contains(_q) ||
            p.sku.toLowerCase().contains(_q))
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isOut ? 'Stock out: choose an item' : 'Stock in: choose an item',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search by name or SKU',
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('No items found'))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final p = list[i];
                        final disabled = isOut && p.quantity == 0;
                        return ListTile(
                          enabled: !disabled,
                          leading: IconTile(
                            icon: categoryIcon(p.category),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(p.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${p.quantity} ${p.unit} in stock'),
                          trailing: StatusBadge(p),
                          onTap: () => Navigator.pop(context, p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}