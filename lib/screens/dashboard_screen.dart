import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'qr_scanner_screen.dart';
import '../models/app_user.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/movement_tile.dart';
import '../widgets/product_picker.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _open(BuildContext context, Product p) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p.id!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryProvider>();
    final user = context.watch<AuthProvider>().user;
    final scheme = Theme.of(context).colorScheme;
    final isOwner = user?.isOwner ?? false;

    final low = inv.lowStock..sort((a, b) => a.quantity.compareTo(b.quantity));
    final outCount = inv.products.where((p) => p.isOut).length;
    final lowOnly = low.length - outCount;
    final okCount = inv.products.length - low.length;

    return Scaffold(
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductFormScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('New item'),
            )
          : null,
      body: SafeArea(
        child: inv.loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: inv.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    if (user != null)
                      _Header(
                        name: user.name,
                        role: user.role,
                        lowCount: low.length,
                      ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () =>
                                startStockFlow(context, MovementType.incoming),
                            icon: const Icon(Icons.south_west),
                            label: const Text('Stock in'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () =>
                                startStockFlow(context, MovementType.outgoing),
                            icon: const Icon(Icons.north_east),
                            label: const Text('Stock out'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12), // NEW
                    OutlinedButton.icon( // NEW
                      onPressed: () => openQrScanner(context), // NEW
                      icon: const Icon(Icons.qr_code_scanner), // NEW
                      label: const Text('Scan QR code'), // NEW
                    ), // NEW
                    const SizedBox(height: 14),
                    Column(
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _StatTile(
                                    icon: Icons.inventory_2_outlined,
                                    color: scheme.primary,
                                    value: '${inv.products.length}',
                                    label: 'Items'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatTile(
                                    icon: Icons.layers_outlined,
                                    color: Colors.blue.shade600,
                                    value: '${inv.totalUnits}',
                                    label: 'Units in stock'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _StatTile(
                                    icon: Icons.warning_amber_rounded,
                                    color: low.isEmpty
                                        ? Colors.green.shade600
                                        : scheme.error,
                                    value: '${low.length}',
                                    label: 'Need restock'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: isOwner
                                    ? _StatTile(
                                        icon: Icons.payments_outlined,
                                        color: Colors.teal.shade600,
                                        value: money.format(inv.totalValue),
                                        label: 'Stock value')
                                    : _StatTile(
                                        icon: Icons.category_outlined,
                                        color: Colors.purple.shade400,
                                        value:
                                            '${inv.products.map((p) => p.category).toSet().length}',
                                        label: 'Categories'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const SectionTitle('Stock health'),
                    _HealthCard(ok: okCount, low: lowOnly, out: outCount),
                    const SizedBox(height: 24),
                    SectionTitle(
                      'Low-stock alerts',
                      trailing: low.isEmpty
                          ? null
                          : Text('${low.length} items',
                              style: Theme.of(context).textTheme.bodySmall),
                    ),
                    if (low.isEmpty)
                      AppCard(
                        child: Row(
                          children: [
                            IconTile(
                                icon: Icons.check_circle_outline,
                                color: Colors.green.shade600),
                            const SizedBox(width: 12),
                            const Expanded(
                                child: Text('All items are sufficiently stocked')),
                          ],
                        ),
                      )
                    else
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < low.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              _LowRow(
                                  product: low[i],
                                  onTap: () => _open(context, low[i])),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    const SectionTitle('Recent stock movements'),
                    if (inv.recentActivity.isEmpty)
                      AppCard(
                        child: Row(
                          children: [
                            IconTile(
                                icon: Icons.info_outline, color: scheme.primary),
                            const SizedBox(width: 12),
                            const Expanded(child: Text('No movements yet')),
                          ],
                        ),
                      )
                    else
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < inv.recentActivity.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              MovementTile(movement: inv.recentActivity[i]),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  final UserRole role;
  final int lowCount;
  const _Header({
    required this.name,
    required this.role,
    required this.lowCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: kBrandGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.22),
            child: Text(initials(name),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${greeting()},',
                    style: const TextStyle(color: Colors.white70)),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    RoleBadge(role, onDark: true),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        lowCount == 0
                            ? 'All stocked'
                            : '$lowCount need restocking',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconTile(icon: icon, color: color, size: 36),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  final int ok;
  final int low;
  final int out;
  const _HealthCard({required this.ok, required this.low, required this.out});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = ok + low + out;
    final green = Colors.green.shade600;
    final orange = Colors.orange.shade700;
    final red = theme.colorScheme.error;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$total items tracked',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: total == 0
                  ? ColoredBox(color: theme.colorScheme.outlineVariant)
                  : Row(
                      children: [
                        if (ok > 0)
                          Expanded(
                              flex: ok, child: ColoredBox(color: green)),
                        if (low > 0)
                          Expanded(
                              flex: low, child: ColoredBox(color: orange)),
                        if (out > 0)
                          Expanded(flex: out, child: ColoredBox(color: red)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _Legend(color: green, text: 'In stock $ok'),
              _Legend(color: orange, text: 'Low $low'),
              _Legend(color: red, text: 'Out $out'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _LowRow extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const _LowRow({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = product;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            IconTile(
                icon: Icons.warning_amber_rounded,
                color: scheme.error,
                size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  StockBar(p, height: 6),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(p.isOut ? 'OUT' : '${p.quantity} ${p.unit}',
                    style: TextStyle(
                        color: scheme.error, fontWeight: FontWeight.w800)),
                Text('order ${p.suggestedReorder}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}