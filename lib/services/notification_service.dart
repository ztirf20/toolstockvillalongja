import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/product.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(const InitializationSettings(android: android));
      // Android 13+ requires a runtime permission for notifications.
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  Future<void> showLowStock(Product p) async {
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'low_stock_channel',
          'Low Stock Alerts',
          channelDescription: 'Alerts when a tool falls below its minimum stock',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      final title = p.isOut ? 'Out of stock: ${p.name}' : 'Low stock: ${p.name}';
      final body = p.isOut
          ? 'No units left. Reorder now.'
          : 'Only ${p.quantity} left (minimum ${p.minStock}).';
      await _plugin.show(
          (p.id ?? '').hashCode & 0x7fffffff, title, body, details);
    } catch (e) {
      debugPrint('Notification failed: $e');
    }
  }
}