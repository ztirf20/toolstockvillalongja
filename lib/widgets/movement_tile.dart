import 'package:flutter/material.dart';

import '../models/stock_movement.dart';
import '../utils.dart';
import 'common.dart';

class MovementTile extends StatelessWidget {
  final StockMovement movement;
  final bool showProductName;

  const MovementTile({
    super.key,
    required this.movement,
    this.showProductName = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = movement;
    final Color color = switch (m.type) {
      MovementType.incoming => Colors.green.shade600,
      MovementType.outgoing => Colors.red.shade600,
      MovementType.correction => Colors.blueGrey,
    };
    final sign = m.change > 0 ? '+' : '';
    final details = [
      m.type.label,
      if (m.note.isNotEmpty) m.note,
    ].join(' • ');
    final who = '${m.staffName.isEmpty ? 'Unknown' : m.staffName} • '
        '${dateTimeFmt.format(m.timestamp)}';
    final muted =
        theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          IconTile(icon: m.type.icon, color: color, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(showProductName ? m.productName : details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (showProductName)
                  Text(details,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                Text(who,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$sign${m.change}',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w800, fontSize: 17)),
              Text('now ${m.stockAfter}', style: muted),
            ],
          ),
        ],
      ),
    );
  }
}