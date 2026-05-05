import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Wraps flutter_local_notifications with platform guards.
/// Windows is not supported by the package — calls are silently skipped there.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  bool get _supported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isLinux;

  Future<void> init() async {
    if (!_supported || _initialised) return;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxSettings =
        LinuxInitializationSettings(defaultActionName: 'open');
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
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.requestNotificationsPermission();
        }
      } catch (e) {
        // Silently handle any errors in permission request
        debugPrint('Notification permission request failed: $e');
      }
    }
    
    _initialised = true;
  }

  Future<void> showLowStockAlert({
    required String productName,
    required double qty,
  }) async {
    if (!_supported) return;
    if (!_initialised) await init();
    await _plugin.show(
      productName.hashCode,
      'સ્ટોક ઓછો છે!',
      '$productName — માત્ર ${qty.toStringAsFixed(1)} બાકી',
      _details(),
    );
  }

  Future<void> showOutOfStockAlert({required String productName}) async {
    if (!_supported) return;
    if (!_initialised) await init();
    await _plugin.show(
      productName.hashCode ^ 0xFFFF,
      'સ્ટોક ખતમ!',
      '$productName — સ્ટોક શૂન્ય છે',
      _details(),
    );
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
