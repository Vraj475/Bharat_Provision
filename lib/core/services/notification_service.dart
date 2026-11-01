import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps flutter_local_notifications with platform guards.
/// Windows is not supported by the package — calls are silently skipped there.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _prefKeyNotifiedLowStock =
      'notified_low_stock_product_ids';
  static const String _prefKeyNotifiedOutOfStock =
      'notified_out_of_stock_product_ids';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;
  bool _alertsLoaded = false;
  Set<int> _notifiedLowStockIds = <int>{};
  Set<int> _notifiedOutOfStockIds = <int>{};

  bool get _supported =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isLinux;

  Future<void> _loadNotifiedCache() async {
    if (_alertsLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lowList = prefs.getStringList(_prefKeyNotifiedLowStock) ?? [];
      final outList = prefs.getStringList(_prefKeyNotifiedOutOfStock) ?? [];
      _notifiedLowStockIds = lowList
          .map((e) => int.tryParse(e))
          .whereType<int>()
          .toSet();
      _notifiedOutOfStockIds = outList
          .map((e) => int.tryParse(e))
          .whereType<int>()
          .toSet();
      _alertsLoaded = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to load stock notification cache: $e');
      }
    }
  }

  Future<void> _saveNotifiedCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefKeyNotifiedLowStock,
        _notifiedLowStockIds.map((id) => id.toString()).toList(),
      );
      await prefs.setStringList(
        _prefKeyNotifiedOutOfStock,
        _notifiedOutOfStockIds.map((id) => id.toString()).toList(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to save stock notification cache: $e');
      }
    }
  }

  Future<void> init() async {
    if (!_supported || _initialised) return;
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'open',
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );
    await _plugin.initialize(initSettings);

    // Request POST_NOTIFICATIONS permission on Android 13+
    if (Platform.isAndroid) {
      try {
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (androidPlugin != null) {
          await androidPlugin.requestNotificationsPermission();
        }
      } catch (e) {
        // Silently handle any errors in permission request
        if (kDebugMode) {
          debugPrint('Notification permission request failed: $e');
        }
      }
    }

    _initialised = true;
  }

  /// Shows a low stock alert notification.
  /// If [productId] is provided, this alert only appears once while the product
  /// is at or below minimum stock. Subsequent calls are skipped until the product
  /// is restocked above minimum stock via [onProductRestocked].
  /// Returns `true` if notification was triggered, `false` if skipped.
  Future<bool> showLowStockAlert({
    int? productId,
    required String productName,
    required double qty,
  }) async {
    await _loadNotifiedCache();

    if (productId != null) {
      if (_notifiedLowStockIds.contains(productId)) {
        return false;
      }
      _notifiedLowStockIds.add(productId);
      await _saveNotifiedCache();
    }

    if (!_supported) return true;
    if (!_initialised) await init();
    await _plugin.show(
      productName.hashCode,
      'સ્ટોક ઓછો છે!',
      '$productName — માત્ર ${qty.toStringAsFixed(1)} બાકી',
      _details(),
    );
    return true;
  }

  /// Shows an out of stock alert notification.
  /// If [productId] is provided, this alert only appears once until restocked > 0.
  /// Returns `true` if notification was triggered, `false` if skipped.
  Future<bool> showOutOfStockAlert({
    int? productId,
    required String productName,
  }) async {
    await _loadNotifiedCache();

    if (productId != null) {
      if (_notifiedOutOfStockIds.contains(productId)) {
        return false;
      }
      _notifiedOutOfStockIds.add(productId);
      await _saveNotifiedCache();
    }

    if (!_supported) return true;
    if (!_initialised) await init();
    await _plugin.show(
      productName.hashCode ^ 0xFFFF,
      'સ્ટોક ખતમ!',
      '$productName — સ્ટોક શૂન્ય છે',
      _details(),
    );
    return true;
  }

  /// Called whenever a product's stock is replenished or updated.
  /// If [newStockQty] > [minStockQty], the low-stock alert status is reset
  /// so that the user will be alerted once more if stock drops low again.
  /// If [newStockQty] > 0, the out-of-stock alert status is reset.
  Future<void> onProductRestocked({
    required int productId,
    required double newStockQty,
    required double minStockQty,
  }) async {
    await _loadNotifiedCache();
    bool changed = false;

    if (newStockQty > minStockQty) {
      if (_notifiedLowStockIds.remove(productId)) {
        changed = true;
      }
    }

    if (newStockQty > 0) {
      if (_notifiedOutOfStockIds.remove(productId)) {
        changed = true;
      }
    }

    if (changed) {
      await _saveNotifiedCache();
    }
  }

  /// Manually clears notification history for a product.
  Future<void> resetAlertStatusForProduct(int productId) async {
    await _loadNotifiedCache();
    final changedLow = _notifiedLowStockIds.remove(productId);
    final changedOut = _notifiedOutOfStockIds.remove(productId);
    if (changedLow || changedOut) {
      await _saveNotifiedCache();
    }
  }

  /// Clears all alert statuses (useful for test resets).
  @visibleForTesting
  Future<void> clearAllAlertStatuses() async {
    _notifiedLowStockIds.clear();
    _notifiedOutOfStockIds.clear();
    _alertsLoaded = true;
    await _saveNotifiedCache();
  }

  /// Checks if product has already received a low stock notification.
  Future<bool> isLowStockNotified(int productId) async {
    await _loadNotifiedCache();
    return _notifiedLowStockIds.contains(productId);
  }

  /// Checks if product has already received an out of stock notification.
  Future<bool> isOutOfStockNotified(int productId) async {
    await _loadNotifiedCache();
    return _notifiedOutOfStockIds.contains(productId);
  }

  NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      'stock_alerts',
      'સ્ટોક એલર્ટ',
      channelDescription: 'Low stock and out-of-stock alerts',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    const darwin = DarwinNotificationDetails();
    const linux = LinuxNotificationDetails();
    return const NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
      linux: linux,
    );
  }
}
