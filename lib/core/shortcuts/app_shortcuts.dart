import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'app_intents.dart';

/// Central keyboard shortcut mapping table for Bharat Provision POS.
class AppShortcuts {
  AppShortcuts._();

  /// Map of keyboard shortcuts to Intents for billing operations.
  /// Per user requirement, all extra shortcuts are removed; only Ctrl + Enter is used for saving the bill.
  static final Map<ShortcutActivator, Intent> billingShortcuts = {
    // Focus Product Search via Ctrl + F
    const SingleActivator(LogicalKeyboardKey.keyF, control: true):
        const FocusProductSearchIntent(),

    // Save Bill via Ctrl + Enter / Ctrl + NumpadEnter
    const SingleActivator(LogicalKeyboardKey.enter, control: true):
        const SaveBillIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter, control: true):
        const SaveBillIntent(),
  };

  /// Global shortcuts for switching between app modules (Ctrl + F1 - F6)
  static final Map<ShortcutActivator, Intent> moduleShortcuts = {
    // Ctrl + F1: Billing
    const SingleActivator(LogicalKeyboardKey.f1, control: true):
        const NavigateToModuleIntent(0),

    // Ctrl + F2: Bill History
    const SingleActivator(LogicalKeyboardKey.f2, control: true):
        const NavigateToModuleIntent(1),

    // Ctrl + F3: Inventory
    const SingleActivator(LogicalKeyboardKey.f3, control: true):
        const NavigateToModuleIntent(2),

    // Ctrl + F4: Khata / Customers
    const SingleActivator(LogicalKeyboardKey.f4, control: true):
        const NavigateToModuleIntent(3),

    // Ctrl + F5: Reports
    const SingleActivator(LogicalKeyboardKey.f5, control: true):
        const NavigateToModuleIntent(4),

    // Ctrl + F6: Settings
    const SingleActivator(LogicalKeyboardKey.f6, control: true):
        const NavigateToModuleIntent(5),
  };
}
