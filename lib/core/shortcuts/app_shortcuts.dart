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

    // Toggle Payment Mode (Cash / Credit) via Alt + C
    const SingleActivator(LogicalKeyboardKey.keyC, alt: true):
        const TogglePaymentModeIntent(),
  };

  /// Global shortcuts for switching between app modules (Alt + 1 - 7)
  static final Map<ShortcutActivator, Intent> moduleShortcuts = {
    // Alt + 1: Billing
    const SingleActivator(LogicalKeyboardKey.digit1, alt: true):
        const NavigateToModuleIntent(0),
    const SingleActivator(LogicalKeyboardKey.numpad1, alt: true):
        const NavigateToModuleIntent(0),

    // Alt + 2: Bill History / Next module
    const SingleActivator(LogicalKeyboardKey.digit2, alt: true):
        const NavigateToModuleIntent(1),
    const SingleActivator(LogicalKeyboardKey.numpad2, alt: true):
        const NavigateToModuleIntent(1),

    // Alt + 3: Expenses & Purchases
    const SingleActivator(LogicalKeyboardKey.digit3, alt: true):
        const NavigateToModuleIntent(2),
    const SingleActivator(LogicalKeyboardKey.numpad3, alt: true):
        const NavigateToModuleIntent(2),

    // Alt + 4: Inventory
    const SingleActivator(LogicalKeyboardKey.digit4, alt: true):
        const NavigateToModuleIntent(3),
    const SingleActivator(LogicalKeyboardKey.numpad4, alt: true):
        const NavigateToModuleIntent(3),

    // Alt + 5: Khata / Customers
    const SingleActivator(LogicalKeyboardKey.digit5, alt: true):
        const NavigateToModuleIntent(4),
    const SingleActivator(LogicalKeyboardKey.numpad5, alt: true):
        const NavigateToModuleIntent(4),

    // Alt + 6: Reports
    const SingleActivator(LogicalKeyboardKey.digit6, alt: true):
        const NavigateToModuleIntent(5),
    const SingleActivator(LogicalKeyboardKey.numpad6, alt: true):
        const NavigateToModuleIntent(5),

    // Alt + 7: Settings
    const SingleActivator(LogicalKeyboardKey.digit7, alt: true):
        const NavigateToModuleIntent(6),
    const SingleActivator(LogicalKeyboardKey.numpad7, alt: true):
        const NavigateToModuleIntent(6),
  };
}
