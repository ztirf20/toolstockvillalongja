import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String? id;
  final String name;
  final String category;
  final double price;
  final int quantity;
  final int minStock;
  final DateTime updatedAt;
  final String sku;
  final String unit;
  final String supplier;

  const Product({
    this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.quantity,
    required this.minStock,
    required this.updatedAt,
    this.sku = '',
    this.unit = 'pcs',
    this.supplier = '',
  });

  bool get isLow => quantity <= minStock;
  bool get isOut => quantity == 0;
  double get stockValue => quantity * price;

  /// Fraction shown by the stock bar (the alert level sits at one third).
  double get levelRatio {
    final full = minStock <= 0 ? 10 : minStock * 3;
    return (quantity / full).clamp(0.0, 1.0).toDouble();
  }

  /// Units to order to bring stock back to double the alert level.
  int get suggestedReorder {
    final target = minStock * 2 > minStock + 1 ? minStock * 2 : minStock + 1;
    final need = target - quantity;
    return need < 0 ? 0 : need;
  }

  Product copyWith({
    String? name,
    String? category,
    double? price,
    int? quantity,
    int? minStock,
    DateTime? updatedAt,
    String? sku,
    String? unit,
    String? supplier,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      minStock: minStock ?? this.minStock,
      updatedAt: updatedAt ?? this.updatedAt,
      sku: sku ?? this.sku,
      unit: unit ?? this.unit,
      supplier: supplier ?? this.supplier,
    );
  }

  Map<String, Object?> toMap() => {
        'name': name,
        'category': category,
        'price': price,
        'quantity': quantity,
        'minStock': minStock,
        'sku': sku,
        'unit': unit,
        'supplier': supplier,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Product(
      id: d.id,
      name: m['name'] as String,
      category: m['category'] as String,
      price: (m['price'] as num).toDouble(),
      quantity: (m['quantity'] as num).toInt(),
      minStock: (m['minStock'] as num).toInt(),
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sku: (m['sku'] as String?) ?? '',
      unit: (m['unit'] as String?) ?? 'pcs',
      supplier: (m['supplier'] as String?) ?? '',
    );
  }
}