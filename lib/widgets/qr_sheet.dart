import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/product.dart';
import '../qr_code_data.dart';

/// Shows the QR code for one item.
Future<void> showItemQr(BuildContext context, Product p) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _QrSheet(product: p),
  );
}

class _QrSheet extends StatelessWidget {
  final Product product;
  const _QrSheet({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = product;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            p.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            p.sku.isEmpty ? p.category : '${p.category} • ${p.sku}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: QrImageView(
              data: qrPayloadFor(p),
              size: 240,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Print this or take a screenshot and stick it on the shelf. '
            'Scan it with the Scan QR button to open this item.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}