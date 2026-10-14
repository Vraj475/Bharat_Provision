import 'package:flutter/widgets.dart';

/// Intent to focus the product search input in billing (Ctrl + F)
class FocusProductSearchIntent extends Intent {
  const FocusProductSearchIntent();
}

/// Intent to focus and edit the weight/quantity of the first product in billing (Ctrl + R)
class FocusFirstItemWeightIntent extends Intent {
  const FocusFirstItemWeightIntent();
}

/// Intent to edit discount amount in billing (Ctrl + D)
class EditDiscountIntent extends Intent {
  const EditDiscountIntent();
}

/// Intent to edit final total in billing (Ctrl + G)
class EditGrandTotalIntent extends Intent {
  const EditGrandTotalIntent();
}

/// Intent to clear the current bill (Ctrl + C)
class ClearBillIntent extends Intent {
  const ClearBillIntent();
}

/// Intent to focus customer name input in billing (Ctrl + X)
class FocusCustomerSearchIntent extends Intent {
  const FocusCustomerSearchIntent();
}

/// Intent to save the bill (Ctrl + S)
class SaveBillIntent extends Intent {
  const SaveBillIntent();
}

/// Intent to print the bill (Ctrl + P)
class PrintBillIntent extends Intent {
  const PrintBillIntent();
}

/// Intent to save and print the bill (Ctrl + Enter)
class SaveAndPrintBillIntent extends Intent {
  const SaveAndPrintBillIntent();
}

/// Intent to delete the currently selected product row (Ctrl + Delete)
class DeleteSelectedProductIntent extends Intent {
  const DeleteSelectedProductIntent();
}

/// Intent to increment product quantity (+)
class IncrementProductQtyIntent extends Intent {
  const IncrementProductQtyIntent();
}

/// Intent to decrement product quantity (-)
class DecrementProductQtyIntent extends Intent {
  const DecrementProductQtyIntent();
}

/// Intent to switch/set Udhaar (credit/khata) payment mode (Alt + 1)
class SetUdhaarModeIntent extends Intent {
  const SetUdhaarModeIntent();
}

/// Intent to switch/set Cash payment mode (Alt + 2)
class SetCashModeIntent extends Intent {
  const SetCashModeIntent();
}

/// Intent for Escape key (close dropdowns, deselect, dismiss)
class EscapeIntent extends Intent {
  const EscapeIntent();
}

/// Intent to navigate between app modules (F1 - F6 / Ctrl + F1 - Ctrl + F6)
class NavigateToModuleIntent extends Intent {
  final int moduleIndex;
  const NavigateToModuleIntent(this.moduleIndex);
}
