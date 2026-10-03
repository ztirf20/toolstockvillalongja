import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/sample_tools.dart';
import '../db/database_helper.dart';
import '../models/app_user.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../services/notification_service.dart';

class InventoryProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Product> _products = [];
  List<StockMovement> _recent = [];
  String? _uid;
  String _actorName = 'Unknown';
  int _historyVersion = 0;
  bool _loading = true;
  bool _productsReady = false;
  bool _disposed = false;
  StreamSubscription<List<Product>>? _productSub;
  StreamSubscription<void>? _moveSub;

  List<Product> get products => _products;
  List<StockMovement> get recentActivity => _recent;
  bool get loading => _loading;

  /// Bumped whenever movements change so history/report screens reload.
  int get historyVersion => _historyVersion;

  List<Product> get lowStock => _products.where((p) => p.isLow).toList();
  int get totalUnits => _products.fold(0, (sum, p) => sum + p.quantity);
  double get totalValue =>
      _products.fold(0.0, (sum, p) => sum + p.quantity * p.price);

  Product? byId(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Called by the app whenever the logged-in user changes.
  /// Starts live data for a signed-in user and stops it on sign-out.
  void syncWith(AppUser? user) {
    if (user?.uid == _uid) {
      if (user != null) _actorName = user.name;
      return;
    }
    _stop();
    _uid = user?.uid;
    if (user != null) {
      _actorName = user.name;
      final uid = user.uid;
      Future.microtask(() => _start(uid));
    } else {
      Future.microtask(_safeNotify);
    }
  }

  void _stop() {
    _productSub?.cancel();
    _productSub = null;
    _moveSub?.cancel();
    _moveSub = null;
    _db.stopListening();
    _products = [];
    _recent = [];
    _loading = true;
    _productsReady = false;
  }

  Future<void> _start(String uid) async {
    try {
      final first = Completer<void>();
      _productSub = _db.watchProducts().listen(
        (list) {
          if (_uid != uid) return;
          _onProducts(list);
          if (!first.isCompleted) first.complete();
        },
        onError: (Object e) {
          debugPrint('Products stream error: $e');
          if (!first.isCompleted) first.complete();
        },
      );

      await _db.startListeningToMovements();
      if (_uid != uid || _disposed) return;
      _recent = _db.recentMovements(5);
      _historyVersion++;
      _moveSub = _db.movementsChanged.listen((_) {
        _recent = _db.recentMovements(5);
        _historyVersion++;
        _safeNotify();
      });

      await first.future.timeout(const Duration(seconds: 8), onTimeout: () {});
    } catch (e) {
      debugPrint('Inventory start failed: $e');
    }
    if (_uid == uid) {
      _loading = false;
      _safeNotify();
    }
  }

  void _onProducts(List<Product> list) {
    if (_productsReady) {
      final old = {for (final p in _products) p.id: p};
      for (final p in list) {
        final before = old[p.id];
        final becameLow = before == null
            ? p.isLow
            : (p.quantity < before.quantity && p.isLow) ||
                (!before.isLow && p.isLow);
        if (becameLow) NotificationService.instance.showLowStock(p);
      }
    }
    _products = list;
    _productsReady = true;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  /// Pull-to-refresh. Live streams already keep the data current.
  Future<void> refresh() async {
    try {
      _products = await _db.getProducts();
      _safeNotify();
    } catch (e) {
      debugPrint('Refresh failed: $e');
    }
  }

  Future<void> addProduct(Product p) => _db.insertProduct(p, _actorName);

  Future<void> updateProduct(Product p) => _db.updateProduct(p);

  Future<void> deleteProduct(String id) => _db.deleteProduct(id);

  /// Owner only. Adds the sample hardware catalog, skipping items that
  /// already exist (matched by name or SKU). Returns how many were added.
  Future<int> loadSampleTools() async {
    final names = _products.map((p) => p.name.toLowerCase()).toSet();
    final skus = _products
        .where((p) => p.sku.isNotEmpty)
        .map((p) => p.sku.toLowerCase())
        .toSet();
    final items = <Product>[];
    for (final s in kSampleTools) {
      if (names.contains(s.name.toLowerCase()) ||
          skus.contains(s.sku.toLowerCase())) {
        continue;
      }
      items.add(Product(
        name: s.name,
        category: s.category,
        price: s.price,
        quantity: s.quantity,
        minStock: s.minStock,
        updatedAt: DateTime.now(),
        sku: s.sku,
        unit: s.unit,
        supplier: s.supplier,
      ));
    }
    return _db.seedProducts(items, _actorName);
  }

  /// Throws [InsufficientStockException] if an outgoing amount exceeds stock.
  Future<void> recordMovement({
    required Product product,
    required MovementType type,
    required int amount,
    String note = '',
  }) async {
    await _db.applyMovement(
      productId: product.id!,
      type: type,
      amount: amount,
      note: note,
      staff: _actorName,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _productSub?.cancel();
    _moveSub?.cancel();
    _db.stopListening();
    super.dispose();
  }
}