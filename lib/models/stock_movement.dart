import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum MovementType { incoming, outgoing, correction }

extension MovementTypeX on MovementType {
  String get label => switch (this) {
        MovementType.incoming => 'Stock In',
        MovementType.outgoing => 'Stock Out',
        MovementType.correction => 'Correction',
      };

  IconData get icon => switch (this) {
        MovementType.incoming => Icons.south_west,
        MovementType.outgoing => Icons.north_east,
        MovementType.correction => Icons.tune,
      };
}

class StockMovement {
  final String? id;
  final String productId;
  final String productName;
  final MovementType type;
  final int change;
  final int stockAfter;
  final String note;
  final String staffName;
  final DateTime timestamp;

  const StockMovement({
    this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.change,
    required this.stockAfter,
    required this.note,
    required this.staffName,
    required this.timestamp,
  });

  factory StockMovement.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return StockMovement(
      id: d.id,
      productId: m['productId'] as String,
      productName: m['productName'] as String,
      type: MovementType.values.byName(m['type'] as String),
      change: (m['change'] as num).toInt(),
      stockAfter: (m['stockAfter'] as num).toInt(),
      note: (m['note'] as String?) ?? '',
      staffName: (m['staffName'] as String?) ?? '',
      timestamp: (m['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}