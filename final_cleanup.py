import sys

file_path = 'lib/features/billing/billing_home_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Dispose method
dispose_old = '''    for (final controller in _lineEditControllers.values) {
      controller.dispose();
    }
    _lineEditControllers.clear();
    for (final focusNode in _lineEditFocusNodes.values) {
      focusNode.dispose();
    }
    _lineEditFocusNodes.clear();'''
content = content.replace(dispose_old, '')

# 2. _clearCurrentBillDraft
clear_old = '''    _clearInlineEditState();
    for (final key in _lineEditControllers.keys.toList()) {
      _disposeLineResources(key);
    }'''
content = content.replace(clear_old, '')

content = content.replace('_billLines.clear();', '')

# 3. _hasEnoughStockForDraft
content = content.replace('double draftQty = _billLines', 'double draftQty = ref.read(billingControllerProvider).billLines')

# 4. _registerLineResources
content = content.replace('      _registerLineResources(line.draftKey);\n', '')
content = content.replace('        _registerLineResources(item.id.toString());\n', '')

# 5. _billLines.add in _addProductToBill
add_old = '''      setState(() {
        _billLines.add(
          BillLineItem(
            draftKey: item.id.toString(),
            item: item,
            qtyGrams: qtyGrams,
            amount: amount,
          ),
        );
      });
      ref.read(billingControllerProvider.notifier).addLine(ref.read(billingControllerProvider).billLines.last);'''
add_new = '''      ref.read(billingControllerProvider.notifier).addLine(
        BillLineItem(
          draftKey: item.id.toString(),
          item: item,
          qtyGrams: qtyGrams,
          amount: amount,
        ),
      );'''
content = content.replace(add_old, add_new)

# if the replacement didn't match (because of formatting), try to find _billLines.add and replace
if '_billLines.add' in content:
    content = content.replace('_billLines.add(', 'ref.read(billingControllerProvider.notifier).addLine(')
    content = content.replace('_billLines.last', 'ref.read(billingControllerProvider).billLines.last')

# 6. BillLinesPanel import
if "import 'views/bill_lines_panel.dart';" not in content:
    content = content.replace("import 'views/bill_summary_panel.dart';", "import 'views/bill_summary_panel.dart';\nimport 'views/bill_lines_panel.dart';")

# 7. Remove _commitInlineEdit inside onClearBill
on_clear_old = '''        BillSummaryPanel(
          onClearBill: () {
            _commitInlineEdit();
            _clearCurrentBillDraft();
          },
        ),'''
on_clear_new = '''        BillSummaryPanel(
          onClearBill: () {
            _clearCurrentBillDraft();
          },
        ),'''
content = content.replace(on_clear_old, on_clear_new)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Final cleanup done.")
