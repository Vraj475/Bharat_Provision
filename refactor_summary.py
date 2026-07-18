import re
import sys

file_path = 'lib/features/billing/billing_home_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update _saveBillToDatabase
content = content.replace(
    'final discountSnapshot = _discount;',
    'final discountSnapshot = ref.read(billingControllerProvider).discount;'
)

# 2. Update _clearCurrentBillDraft
old_clear_draft = '''    setState(() {
      _billLines.clear();
      _discount = 0;
      _isEditingGrandTotal = false;
      _isGrandTotalAdjusted = false;
      _customerName = null;
      _customerId = null;
      _activeDropdown = _BillingDropdownType.none;
      _customerController.clear();
    });
    ref.read(billingTabsProvider.notifier).clearActive();'''

new_clear_draft = '''    setState(() {
      _billLines.clear();
      _customerName = null;
      _customerId = null;
      _activeDropdown = _BillingDropdownType.none;
      _customerController.clear();
    });
    ref.read(billingTabsProvider.notifier).clearActive();
    ref.read(billingControllerProvider.notifier).clearBill();
    ref.read(billingControllerProvider.notifier).syncLines([]);'''

content = content.replace(old_clear_draft, new_clear_draft)

# 3. Remove local state variables
content = content.replace('double _discount = 0;', '// double _discount = 0;')
content = content.replace('bool _isEditingGrandTotal = false;', '// bool _isEditingGrandTotal = false;')
content = content.replace('bool _isGrandTotalAdjusted = false;', '// bool _isGrandTotalAdjusted = false;')

# 4. Sync in _commitInlineEdit
old_commit_set_state = '''      setState(() {
        _billLines[editingIndex] = updatedLine;
        _clearInlineEditState();
      });
    } finally {'''

new_commit_set_state = '''      setState(() {
        _billLines[editingIndex] = updatedLine;
        _clearInlineEditState();
      });
      ref.read(billingControllerProvider.notifier).syncLines(_billLines);
    } finally {'''
content = content.replace(old_commit_set_state, new_commit_set_state)

# 5. Sync in _deleteLineWithUndo (both removal and undo)
old_remove = '''    setState(() {
      _billLines.removeAt(index);
      if (_editingLineKey != null) {
        if (_editingLineKey == removedKey) {
          _clearInlineEditState();
        }
      }
    });
    _disposeLineResources(removedKey);'''

new_remove = '''    setState(() {
      _billLines.removeAt(index);
      if (_editingLineKey != null) {
        if (_editingLineKey == removedKey) {
          _clearInlineEditState();
        }
      }
    });
    ref.read(billingControllerProvider.notifier).syncLines(_billLines);
    _disposeLineResources(removedKey);'''

content = content.replace(old_remove, new_remove)

old_undo = '''            setState(() {
              final insertIndex = index.clamp(0, _billLines.length);
              _billLines.insert(insertIndex, removedLine);
            });'''

new_undo = '''            setState(() {
              final insertIndex = index.clamp(0, _billLines.length);
              _billLines.insert(insertIndex, removedLine);
            });
            ref.read(billingControllerProvider.notifier).syncLines(_billLines);'''

content = content.replace(old_undo, new_undo)

# Write back
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Refactoring applied successfully.")
