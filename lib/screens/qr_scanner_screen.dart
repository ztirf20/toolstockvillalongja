import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/stock_movement.dart';
import '../providers/inventory_provider.dart';
import '../qr_code_data.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/stock_movement_sheet.dart';
import 'product_detail_screen.dart';

Future<void> openQrScanner(BuildContext context) {
  return Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const QrScannerScreen()),
  );
}

enum _ScanAction { stockIn, stockOut, open }

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _busy = false;
  String? _notice;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Matches a ToolStock QR code (by item id) or a plain code (by SKU).
  Product? _find(InventoryProvider inv, String raw) {
    final id = itemIdFromPayload(raw);
    if (id != null) return inv.byId(id);
    final code = raw.trim().toLowerCase();
    for (final p in inv.products) {
      if (p.sku.isNotEmpty && p.sku.toLowerCase() == code) return p;
    }
    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    String? raw;
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) {
        raw = v;
        break;
      }
    }
    if (raw != null) _handle(raw);
  }

  Future<void> _handle(String raw) async {
    _busy = true;
    try {
      final inv = context.read<InventoryProvider>();
      final product = _find(inv, raw);

      if (product == null) {
        setState(() => _notice = 'No item found for this code');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _notice = null);
        return;
      }

      HapticFeedback.mediumImpact();
      final action = await showModalBottomSheet<_ScanAction>(
        context: context,
        showDragHandle: true,
        builder: (_) => _ResultSheet(product: product),
      );
      if (!mounted) return;

      switch (action) {
        case _ScanAction.stockIn:
          await showStockMovementSheet(context, product,
              initial: MovementType.incoming);
        case _ScanAction.stockOut:
          await showStockMovementSheet(context, product,
              initial: MovementType.outgoing);
        case _ScanAction.open:
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ProductDetailScreen(productId: product.id!)),
          );
        case null:
          break;
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR code'),
        actions: [
          IconButton(
            tooltip: 'Flashlight',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Switch camera',
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: IgnorePointer(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
          ),
          if (_notice != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _notice!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Point the camera at an item QR code',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultSheet extends StatelessWidget {
  final Product product;
  const _ResultSheet({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = product;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(
                  icon: categoryIcon(p.category),
                  color: theme.colorScheme.primary,
                  size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      p.sku.isEmpty ? p.category : '${p.category} • ${p.sku}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              StatusBadge(p),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${p.quantity}',
                  style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: statusColor(context, p))),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${p.unit} in stock'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StockBar(p),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _ScanAction.stockIn),
                  icon: const Icon(Icons.south_west),
                  label: const Text('Stock in'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: p.quantity == 0
                      ? null
                      : () => Navigator.pop(context, _ScanAction.stockOut),
                  icon: const Icon(Icons.north_east),
                  label: const Text('Stock out'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, _ScanAction.open),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open item details'),
          ),
        ],
      ),
    );
  }
}