import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import 'common.dart';

Future<void> showStockMovementSheet(
  BuildContext context,
  Product product, {
  MovementType initial = MovementType.incoming,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => StockMovementSheet(product: product, initial: initial),
  );
}

class StockMovementSheet extends StatefulWidget {
  final Product product;
  final MovementType initial;
  const StockMovementSheet({
    super.key,
    required this.product,
    this.initial = MovementType.incoming,
  });

  @override
  State<StockMovementSheet> createState() => _StockMovementSheetState();
}

class _StockMovementSheetState extends State<StockMovementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late MovementType _type = widget.initial;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<InventoryProvider>().recordMovement(
            product: widget.product,
            type: _type,
            amount: int.parse(_qtyCtrl.text),
            note: _noteCtrl.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } on InsufficientStockException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not save: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwner = context.read<AuthProvider>().isOwner;
    final types = isOwner
        ? MovementType.values
        : const [MovementType.incoming, MovementType.outgoing];
    // Use the live product so "current stock" is always accurate.
    final live =
        context.watch<InventoryProvider>().byId(widget.product.id!) ??
            widget.product;
    final isCorrection = _type == MovementType.correction;

    final n = int.tryParse(_qtyCtrl.text);
    int? after;
    if (n != null) {
      after = switch (_type) {
        MovementType.incoming => live.quantity + n,
        MovementType.outgoing => live.quantity - n,
        MovementType.correction => n,
      };
    }
    final bad = after != null && after < 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(live.name,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Current stock: ${live.quantity} ${live.unit}'),
                const Spacer(),
                StatusBadge(live),
              ],
            ),
            const SizedBox(height: 6),
            StockBar(live),
            const SizedBox(height: 16),
            SegmentedButton<MovementType>(
              showSelectedIcon: false,
              segments: [
                for (final t in types)
                  ButtonSegment(
                      value: t, label: Text(t.label), icon: Icon(t.icon)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                labelText:
                    isCorrection ? 'Actual counted quantity' : 'Quantity',
                suffixText: live.unit,
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null) return 'Enter a number';
                if (!isCorrection && n <= 0) return 'Must be at least 1';
                return null;
              },
            ),
            if (after != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: (bad ? theme.colorScheme.error : theme.colorScheme.primary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(bad ? Icons.error_outline : Icons.inventory_2_outlined,
                        size: 20,
                        color: bad
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        bad
                            ? 'Not enough stock for this removal'
                            : 'Stock after: $after ${live.unit}'
                                '${after <= live.minStock ? '  (low)' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: bad ? theme.colorScheme.error : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                hintText: switch (_type) {
                  MovementType.incoming => 'e.g. Delivery from supplier',
                  MovementType.outgoing => 'e.g. Sold to customer',
                  MovementType.correction => 'e.g. Shelf recount',
                },
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}