import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/qr_sheet.dart';
import '../db/database_helper.dart';
import '../models/stock_movement.dart';
import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/movement_tile.dart';
import '../widgets/stock_movement_sheet.dart';
import 'product_form_screen.dart';

class ProductDetailScreen extends StatelessWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  Future<void> _delete(BuildContext context, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('"$name" will be removed from your stock. '
            'Its history records are kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final inv = context.read<InventoryProvider>();
      Navigator.pop(context);
      await inv.deleteProduct(productId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryProvider>();
    final isOwner = context.select<AuthProvider, bool>((a) => a.isOwner);
    final p = inv.byId(productId);
    final theme = Theme.of(context);

    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This item no longer exists.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (isOwner) ...[
                         IconButton(
               tooltip: 'QR code',
               icon: const Icon(Icons.qr_code_2),
               onPressed: () => showItemQr(context, p),
             ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProductFormScreen(product: p)),
              ),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, p.name),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: kBrandGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(categoryIcon(p.category), color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(p.category,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(statusLabel(p),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${p.quantity}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 56,
                            fontWeight: FontWeight.w800,
                            height: 1)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('${p.unit} in stock',
                          style: const TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: p.levelRatio,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
                const SizedBox(height: 6),
                Text('Alert level: ${p.minStock} ${p.unit}',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          if (p.isLow) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Row(
                children: [
                  IconTile(
                      icon: Icons.local_shipping_outlined,
                      color: statusColor(context, p)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reorder ${p.suggestedReorder} ${p.unit}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          p.supplier.isEmpty
                              ? 'Suggested to bring stock back above the alert level.'
                              : 'Suggested order from ${p.supplier}.',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MiniStat('Price each', money.format(p.price))),
              if (isOwner) ...[
                const SizedBox(width: 10),
                Expanded(child: _MiniStat('Stock value', money.format(p.stockValue))),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => showStockMovementSheet(context, p,
                      initial: MovementType.incoming),
                  icon: const Icon(Icons.south_west),
                  label: const Text('Stock in'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: p.quantity == 0
                      ? null
                      : () => showStockMovementSheet(context, p,
                          initial: MovementType.outgoing),
                  icon: const Icon(Icons.north_east),
                  label: const Text('Stock out'),
                ),
              ),
            ],
          ),
          if (isOwner)
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () => showStockMovementSheet(context, p,
                    initial: MovementType.correction),
                icon: const Icon(Icons.tune),
                label: const Text('Correct count (stock take)'),
              ),
            ),
          const SizedBox(height: 16),
          const SectionTitle('Item details'),
          AppCard(
            child: Column(
              children: [
                _InfoRow('SKU', p.sku.isEmpty ? 'Not set' : p.sku),
                _InfoRow('Category', p.category),
                _InfoRow('Unit', p.unit),
                _InfoRow('Supplier', p.supplier.isEmpty ? 'Not set' : p.supplier),
                _InfoRow('Last updated', dateTimeFmt.format(p.updatedAt)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Stock movements for this item'),
          FutureBuilder<List<StockMovement>>(
            // Re-created on every provider change, so it stays fresh.
            future: DatabaseHelper.instance
                .getMovements(productId: productId, limit: 20),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final list = snap.data!;
              if (list.isEmpty) {
                return const AppCard(child: Text('No movements recorded yet'));
              }
              return AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      MovementTile(movement: list[i], showProductName: false),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}