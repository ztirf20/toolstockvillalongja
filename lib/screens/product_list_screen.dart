import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'qr_scanner_screen.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/stock_movement_sheet.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

enum _Level { ok, low, out }

enum _Sort { name, lowest, highest }

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  String _query = '';
  String _category = 'All';
  _Level? _level;
  _Sort _sort = _Sort.name;

  bool _matchesLevel(Product p) => switch (_level) {
        null => true,
        _Level.ok => !p.isLow,
        _Level.low => p.isLow && !p.isOut,
        _Level.out => p.isOut,
      };

  Future<bool> _confirmDelete(BuildContext context, String name) async {
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
    return ok ?? false;
  }

  Future<void> _loadSamples(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load sample tools?'),
        content: const Text(
            'This adds about 40 common hardware items with starting stock. '
            'Items you already have are skipped.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Load')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final added = await context.read<InventoryProvider>().loadSampleTools();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(added == 0
              ? 'All sample tools are already in your stock'
              : '$added tools added')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not load: $e')));
    }
  }

  void _copyReorder(BuildContext context, List<Product> all) {
    final items = all.where((p) => p.isLow).toList()
      ..sort((a, b) => a.quantity.compareTo(b.quantity));
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to reorder. All stocked!')));
      return;
    }
    final b = StringBuffer(
        'REORDER LIST (${dateTimeFmt.format(DateTime.now())})\n');
    for (final p in items) {
      final sku = p.sku.isEmpty ? '' : ' [${p.sku}]';
      final sup = p.supplier.isEmpty ? '' : ' - ${p.supplier}';
      b.writeln('- ${p.name}$sku: have ${p.quantity} ${p.unit}, '
          'order ${p.suggestedReorder} ${p.unit}$sup');
    }
    Clipboard.setData(ClipboardData(text: b.toString()));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Reorder list copied (${items.length} items)')));
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryProvider>();
    final isOwner = context.select<AuthProvider, bool>((a) => a.isOwner);
    final scheme = Theme.of(context).colorScheme;
    final all = inv.products;

    final okCount = all.where((p) => !p.isLow).length;
    final outCount = all.where((p) => p.isOut).length;
    final lowCount = all.where((p) => p.isLow && !p.isOut).length;
    final categories = <String>{'All', ...all.map((p) => p.category)};

    final items = all.where((p) {
      if (_category != 'All' && p.category != _category) return false;
      if (!_matchesLevel(p)) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        if (!p.name.toLowerCase().contains(q) &&
            !p.sku.toLowerCase().contains(q) &&
            !p.supplier.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) => switch (_sort) {
            _Sort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            _Sort.lowest => a.quantity.compareTo(b.quantity),
            _Sort.highest => b.quantity.compareTo(a.quantity),
          });

    return Scaffold(
      appBar: AppBar(
        title: Text('Stock (${all.length})'),
        actions: [
                       IconButton(
               tooltip: 'Scan QR code',
               icon: const Icon(Icons.qr_code_scanner),
               onPressed: () => openQrScanner(context),
             ),
          PopupMenuButton<_Sort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Sort.name, child: Text('Name (A to Z)')),
              PopupMenuItem(
                  value: _Sort.lowest, child: Text('Lowest stock first')),
              PopupMenuItem(
                  value: _Sort.highest, child: Text('Highest stock first')),
            ],
          ),
          if (isOwner)
            IconButton(
              tooltip: 'Load sample tools',
              icon: const Icon(Icons.library_add_outlined),
              onPressed: () => _loadSamples(context),
            ),
          if (isOwner)
            IconButton(
              tooltip: 'Copy reorder list',
              icon: const Icon(Icons.checklist),
              onPressed: () => _copyReorder(context, all),
            ),
        ],
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductFormScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: _LevelTile(
                    label: 'In stock',
                    count: okCount,
                    color: Colors.green.shade600,
                    selected: _level == _Level.ok,
                    onTap: () => setState(
                        () => _level = _level == _Level.ok ? null : _Level.ok),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LevelTile(
                    label: 'Low',
                    count: lowCount,
                    color: Colors.orange.shade700,
                    selected: _level == _Level.low,
                    onTap: () => setState(() =>
                        _level = _level == _Level.low ? null : _Level.low),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LevelTile(
                    label: 'Out',
                    count: outCount,
                    color: scheme.error,
                    selected: _level == _Level.out,
                    onTap: () => setState(() =>
                        _level = _level == _Level.out ? null : _Level.out),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search name, SKU or supplier',
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      all.isEmpty
                          ? (isOwner
                              ? 'No items yet.\nTap "Add item" or the library icon\nto load sample tools.'
                              : 'No items yet.\nAsk the owner to add some.')
                          : 'No items match your filters.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 100),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final p = items[i];
                      final card = _StockCard(
                        product: p,
                        onOpen: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ProductDetailScreen(productId: p.id!)),
                        ),
                      );
                      if (!isOwner) return card;
                      return Dismissible(
                        key: ValueKey('product_${p.id}'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) => _confirmDelete(context, p.name),
                        onDismissed: (_) => context
                            .read<InventoryProvider>()
                            .deleteProduct(p.id!),
                        background: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 5),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          child:
                              Icon(Icons.delete, color: scheme.onErrorContainer),
                        ),
                        child: card,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _LevelTile({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? color : Colors.transparent, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$count',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800, color: color)),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  final Product product;
  final VoidCallback onOpen;
  const _StockCard({required this.product, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = product;
    final color = statusColor(context, p);
    final compact = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    );

    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      onTap: onOpen,
      child: Column(
        children: [
          Row(
            children: [
              IconTile(
                  icon: categoryIcon(p.category),
                  color: theme.colorScheme.primary,
                  size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      p.sku.isEmpty ? p.category : '${p.category} • ${p.sku}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    StockBar(p),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${p.quantity}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800, color: color)),
                  Text(p.unit, style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: compact,
                  onPressed: () => showStockMovementSheet(context, p,
                      initial: MovementType.incoming),
                  icon: const Icon(Icons.south_west, size: 18),
                  label: const Text('Stock in'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: compact,
                  onPressed: p.quantity == 0
                      ? null
                      : () => showStockMovementSheet(context, p,
                          initial: MovementType.outgoing),
                  icon: const Icon(Icons.north_east, size: 18),
                  label: const Text('Stock out'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}