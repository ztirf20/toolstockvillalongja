import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/stock_movement.dart';

class InsufficientStockException implements Exception {
  final String message;
  InsufficientStockException(this.message);
  @override
  String toString() => message;
}

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _cacheLimit = 1000;
  static const _writeTimeout = Duration(seconds: 4);

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _products =>
      _fs.collection('products');
  CollectionReference<Map<String, dynamic>> get _moves =>
      _fs.collection('stock_movements');

  // Live, in-memory copy of the latest movements. History, product activity
  // and reports all read from this, so they need no Firestore indexes.
  List<StockMovement> _cache = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _moveSub;
  final StreamController<void> _changed = StreamController<void>.broadcast();

  Stream<void> get movementsChanged => _changed.stream;

  /// Waits for a write to be acknowledged. If the phone is offline the write
  /// stays queued by Firestore and syncs later, so we stop waiting after a
  /// few seconds instead of freezing the UI.
  Future<void> _settle(Future<void> write) async {
    try {
      await write.timeout(_writeTimeout);
    } on TimeoutException {
      debugPrint('Offline: write queued, will sync when back online.');
    }
  }

  // ---------------------------------------------------------------- products

  Stream<List<Product>> watchProducts() => _products.snapshots().map((s) {
        final list = s.docs.map(Product.fromDoc).toList();
        list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });

  Future<List<Product>> getProducts() async {
    final s = await _products.get();
    final list = s.docs.map(Product.fromDoc).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Map<String, Object?> _movementData({
    required String productId,
    required String productName,
    required MovementType type,
    required int change,
    required int stockAfter,
    required String note,
    required String staff,
  }) =>
      {
        'productId': productId,
        'productName': productName,
        'type': type.name,
        'change': change,
        'stockAfter': stockAfter,
        'note': note,
        'staffName': staff,
        'timestamp': Timestamp.fromDate(DateTime.now()),
      };

  Future<String> insertProduct(Product p, String staff) async {
    final ref = _products.doc();
    final batch = _fs.batch();
    batch.set(ref, p.toMap());
    if (p.quantity > 0) {
      batch.set(
        _moves.doc(),
        _movementData(
          productId: ref.id,
          productName: p.name,
          type: MovementType.incoming,
          change: p.quantity,
          stockAfter: p.quantity,
          note: 'Initial stock',
          staff: staff,
        ),
      );
    }
    await _settle(batch.commit());
    return ref.id;
  }

  /// Updates details only. Quantity is deliberately left out so an edit can
  /// never overwrite a stock change made on another device.
  Future<void> updateProduct(Product p) async {
    await _settle(_products.doc(p.id).update({
      'name': p.name,
      'category': p.category,
      'price': p.price,
      'minStock': p.minStock,
      'sku': p.sku,
      'unit': p.unit,
      'supplier': p.supplier,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }));
  }

  Future<void> deleteProduct(String id) async {
    await _settle(_products.doc(id).delete());
  }

  /// Adds many products at once (used for the sample catalog).
  /// Written in small batches to stay within Firestore rule limits.
  Future<int> seedProducts(List<Product> items, String staff) async {
    if (items.isEmpty) return 0;
    const chunkSize = 4;
    final commits = <Future<void>>[];
    for (var i = 0; i < items.length; i += chunkSize) {
      final batch = _fs.batch();
      final end = (i + chunkSize) > items.length ? items.length : i + chunkSize;
      for (final p in items.sublist(i, end)) {
        final ref = _products.doc();
        batch.set(ref, p.toMap());
        if (p.quantity > 0) {
          batch.set(
            _moves.doc(),
            _movementData(
              productId: ref.id,
              productName: p.name,
              type: MovementType.incoming,
              change: p.quantity,
              stockAfter: p.quantity,
              note: 'Initial stock',
              staff: staff,
            ),
          );
        }
      }
      commits.add(batch.commit());
    }
    await _settle(Future.wait(commits).then((_) {}));
    return items.length;
  }

  // --------------------------------------------------------------- movements

  Future<void> startListeningToMovements() async {
    await _moveSub?.cancel();
    _cache = [];
    final ready = Completer<void>();
    _moveSub = _moves
        .orderBy('timestamp', descending: true)
        .limit(_cacheLimit)
        .snapshots()
        .listen(
      (snap) {
        _cache = snap.docs.map(StockMovement.fromDoc).toList();
        _changed.add(null);
        if (!ready.isCompleted) ready.complete();
      },
      onError: (Object e) {
        debugPrint('Movements stream error: $e');
        if (!ready.isCompleted) ready.complete();
      },
    );
    await ready.future.timeout(const Duration(seconds: 8), onTimeout: () {});
  }

  Future<void> stopListening() async {
    final sub = _moveSub;
    _moveSub = null;
    _cache = [];
    await sub?.cancel();
  }

  List<StockMovement> recentMovements(int n) => _cache.take(n).toList();

  /// Records a stock movement. Quantity changes use FieldValue.increment, so
  /// two staff members updating the same item at the same time both count.
  Future<Product> applyMovement({
    required String productId,
    required MovementType type,
    required int amount,
    required String note,
    required String staff,
  }) async {
    final ref = _products.doc(productId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Product no longer exists.');
    final product = Product.fromDoc(snap);

    late int newQty;
    late int change;
    switch (type) {
      case MovementType.incoming:
        change = amount;
        newQty = product.quantity + amount;
      case MovementType.outgoing:
        if (amount > product.quantity) {
          throw InsufficientStockException(
              'Only ${product.quantity} in stock. Cannot remove $amount.');
        }
        change = -amount;
        newQty = product.quantity - amount;
      case MovementType.correction:
        newQty = amount;
        change = amount - product.quantity;
    }

    final now = DateTime.now();
    final batch = _fs.batch();
    batch.update(ref, {
      'quantity': type == MovementType.correction
          ? newQty
          : FieldValue.increment(change),
      'updatedAt': Timestamp.fromDate(now),
    });
    batch.set(
      _moves.doc(),
      _movementData(
        productId: productId,
        productName: product.name,
        type: type,
        change: change,
        stockAfter: newQty,
        note: note,
        staff: staff,
      ),
    );
    await _settle(batch.commit());
    return product.copyWith(quantity: newQty, updatedAt: now);
  }

  Future<List<StockMovement>> getMovements({
    String? productId,
    MovementType? type,
    DateTime? from,
    DateTime? to,
    String? search,
    int limit = 30,
    int offset = 0,
  }) async {
    final s = search?.trim().toLowerCase() ?? '';
    final matches = _cache.where((m) {
      if (productId != null && m.productId != productId) return false;
      if (type != null && m.type != type) return false;
      if (from != null && m.timestamp.isBefore(from)) return false;
      if (to != null && m.timestamp.isAfter(to)) return false;
      if (s.isNotEmpty &&
          !m.productName.toLowerCase().contains(s) &&
          !m.staffName.toLowerCase().contains(s)) {
        return false;
      }
      return true;
    });
    return matches.skip(offset).take(limit).toList();
  }

  Future<({int totalIn, int totalOut})> getTotals(DateTime from) async {
    var totalIn = 0;
    var totalOut = 0;
    for (final m in _cache) {
      if (m.timestamp.isBefore(from)) continue;
      if (m.type == MovementType.incoming) totalIn += m.change;
      if (m.type == MovementType.outgoing) totalOut += -m.change;
    }
    return (totalIn: totalIn, totalOut: totalOut);
  }

  Future<List<({String name, int total})>> getTopOutgoing(DateTime from) async {
    final sums = <String, int>{};
    for (final m in _cache) {
      if (m.type != MovementType.outgoing || m.timestamp.isBefore(from)) {
        continue;
      }
      sums[m.productName] = (sums[m.productName] ?? 0) + (-m.change);
    }
    final list = sums.entries.map((e) => (name: e.key, total: e.value)).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list.take(5).toList();
  }
}