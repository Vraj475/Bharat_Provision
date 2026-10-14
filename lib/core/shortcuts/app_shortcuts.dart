import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'app_intents.dart';

/// Central keyboard shortcut mapping table for Bharat Provision POS.
class AppShortcuts {
  AppShortcuts._();

  /// Map of keyboard shortcuts to Intents for billing operations.
  static final Map<ShortcutActivator, Intent> billingShortcuts = {
    // 1. Ctrl + F: Focus on finding products in billing page
    const SingleActivator(LogicalKeyboardKey.keyF, control: true):
        const FocusProductSearchIntent(),

    // 2. Ctrl + R: Focus on editing the weight of first product
    const SingleActivator(LogicalKeyboardKey.keyR, control: true):
        const FocusFirstItemWeightIntent(),

    // 3. Ctrl + D: Edit discount amount in billing
    const SingleActivator(LogicalKeyboardKey.keyD, control: true):
        const EditDiscountIntent(),

    // 4. Ctrl + G: Edit final total in bill
    const SingleActivator(LogicalKeyboardKey.keyG, control: true):
        const EditGrandTotalIntent(),

    // 5. Ctrl + C: Clear the bill
    const SingleActivator(LogicalKeyboardKey.keyC, control: true):
        const ClearBillIntent(),

    // 6. Ctrl + X: Focus customer name textbox
    const SingleActivator(LogicalKeyboardKey.keyX, control: true):
        const FocusCustomerSearchIntent(),

    // 7. Ctrl + S: Save the bill
    const SingleActivator(LogicalKeyboardKey.keyS, control: true):
        const SaveBillIntent(),

    // 8. Ctrl + P: Print the bill
    const SingleActivator(LogicalKeyboardKey.keyP, control: true):
        const PrintBillIntent(),

    // 9. Ctrl + Enter / Ctrl + NumpadEnter: Save & Print the bill
    const SingleActivator(LogicalKeyboardKey.enter, control: true):
        const SaveAndPrintBillIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter, control: true):
        const SaveAndPrintBillIntent(),

    // 10. Ctrl + Delete: Delete selected product row
    const SingleActivator(LogicalKeyboardKey.delete, control: true):
        const DeleteSelectedProductIntent(),

    // 11. Alt + 1: Udhaar (Khata) Mode (customer name required)
    const SingleActivator(LogicalKeyboardKey.digit1, alt: true):
        const SetUdhaarModeIntent(),
    const SingleActivator(LogicalKeyboardKey.numpad1, alt: true):
        const SetUdhaarModeIntent(),

    // 12. Alt + 2: Cash Mode
    const SingleActivator(LogicalKeyboardKey.digit2, alt: true):
        const SetCashModeIntent(),
    const SingleActivator(LogicalKeyboardKey.numpad2, alt: true):
        const SetCashModeIntent(),

    // 13. Escape: Close suggestions / deselect / cancel
    const SingleActivator(LogicalKeyboardKey.escape):
        const EscapeIntent(),

    // 14. Plus & Minus: Adjust quantity of selected product
    const SingleActivator(LogicalKeyboardKey.add):
        const IncrementProductQtyIntent(),
    const SingleActivator(LogicalKeyboardKey.equal):
        const IncrementProductQtyIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadAdd):
        const IncrementProductQtyIntent(),
    const SingleActivator(LogicalKeyboardKey.minus):
        const DecrementProductQtyIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadSubtract):
        const DecrementProductQtyIntent(),
  };

  /// Global shortcuts for switching between app modules (F1 - F6 / Ctrl + F1 - F6)
  static final Map<ShortcutActivator, Intent> moduleShortcuts = {
    // F1 / Ctrl + F1: Billing
    const SingleActivator(LogicalKeyboardKey.f1):
        const NavigateToModuleIntent(0),
    const SingleActivator(LogicalKeyboardKey.f1, control: true):
        const NavigateToModuleIntent(0),

    // F2 / Ctrl + F2: Bill History
    const SingleActivator(LogicalKeyboardKey.f2):
        const NavigateToModuleIntent(1),
    const SingleActivator(LogicalKeyboardKey.f2, control: true):
        const NavigateToModuleIntent(1),

    // F3 / Ctrl + F3: Inventory
    const SingleActivator(LogicalKeyboardKey.f3):
        const NavigateToModuleIntent(2),
    const SingleActivator(LogicalKeyboardKey.f3, control: true):
        const NavigateToModuleIntent(2),

    // F4 / Ctrl + F4: Khata / Customers
    const SingleActivator(LogicalKeyboardKey.f4):
        const NavigateToModuleIntent(3),
    const SingleActivator(LogicalKeyboardKey.f4, control: true):
        const NavigateToModuleIntent(3),

    // F5 / Ctrl + F5: Reports
    const SingleActivator(LogicalKeyboardKey.f5):
        const NavigateToModuleIntent(4),
    const SingleActivator(LogicalKeyboardKey.f5, control: true):
        const NavigateToModuleIntent(4),

    // F6 / Ctrl + F6: Settings
    const SingleActivator(LogicalKeyboardKey.f6):
        const NavigateToModuleIntent(5),
    const SingleActivator(LogicalKeyboardKey.f6, control: true):
        const NavigateToModuleIntent(5),
  };
}
