import re
import sys

file_path = 'lib/features/billing/billing_home_screen.dart'
new_file_path = 'lib/features/billing/views/bill_lines_panel.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

start_marker = "  Map<String, TextEditingController> _lineEditControllers = {};"
end_marker = "  @override\n  Widget build(BuildContext context) {"

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx == -1 or end_idx == -1:
    print("Could not find markers")
    sys.exit(1)

extracted_logic = content[start_idx:end_idx]

# Remove the extracted logic from original file
content = content[:start_idx] + content[end_idx:]

# Remove enum from original file
enum_marker = "enum _DraftEditableField { quantity, price, amount }"
if enum_marker in content:
    content = content.replace(enum_marker, '')

# We need to adapt the extracted logic for the new BillLinesPanel class.
# Replace _billLines mutations with ref.read(billingControllerProvider.notifier) calls.

# 1. length checks
extracted_logic = extracted_logic.replace('_billLines.length', 'ref.read(billingControllerProvider).billLines.length')

# 2. index reads
extracted_logic = extracted_logic.replace('_billLines[index]', 'ref.read(billingControllerProvider).billLines[index]')
extracted_logic = extracted_logic.replace('_billLines[editingIndex]', 'ref.read(billingControllerProvider).billLines[editingIndex]')

# 3. indexWhere
extracted_logic = extracted_logic.replace('_billLines.indexWhere', 'ref.read(billingControllerProvider).billLines.indexWhere')

# 4. Mutations:
# In _commitInlineEdit:
old_commit = '''      setState(() {
        _billLines[editingIndex] = updatedLine;
        _clearInlineEditState();
      });
      ref.read(billingControllerProvider.notifier).syncLines(_billLines);'''

new_commit = '''      ref.read(billingControllerProvider.notifier).updateLine(editingIndex, updatedLine);
      setState(() {
        _clearInlineEditState();
      });'''
extracted_logic = extracted_logic.replace(old_commit, new_commit)

# In _deleteLineWithUndo:
old_remove = '''    setState(() {
      _billLines.removeAt(index);
      if (_editingLineKey != null) {
        if (_editingLineKey == removedKey) {
          _clearInlineEditState();
        }
      }
    });
    ref.read(billingControllerProvider.notifier).syncLines(_billLines);'''

new_remove = '''    ref.read(billingControllerProvider.notifier).removeLine(index);
    setState(() {
      if (_editingLineKey != null) {
        if (_editingLineKey == removedKey) {
          _clearInlineEditState();
        }
      }
    });'''
extracted_logic = extracted_logic.replace(old_remove, new_remove)

old_undo = '''            setState(() {
              final insertIndex = index.clamp(0, _billLines.length);
              _billLines.insert(insertIndex, removedLine);
            });
            ref.read(billingControllerProvider.notifier).syncLines(_billLines);'''

new_undo = '''            final currentLines = List<BillLineItem>.from(ref.read(billingControllerProvider).billLines);
            final insertIndex = index.clamp(0, currentLines.length);
            currentLines.insert(insertIndex, removedLine);
            ref.read(billingControllerProvider.notifier).syncLines(currentLines);'''
extracted_logic = extracted_logic.replace(old_undo, new_undo)

# 5. Fix _hasEnoughStockForDraft call:
extracted_logic = extracted_logic.replace('_hasEnoughStockForDraft', 'widget.checkStock')

# Create new file
new_file_content = f'''import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../models/bill_line_item.dart';
import '../controllers/billing_controller.dart';
import '../../../core/constants/app_strings.dart' as strings;

enum _DraftEditableField {{ quantity, price, amount }}

class BillLinesPanel extends ConsumerStatefulWidget {{
  final Future<bool> Function({{required int itemId, required double newQtyGrams, int? excludeLineIndex}}) checkStock;

  const BillLinesPanel({{
    super.key,
    required this.checkStock,
  }});

  @override
  ConsumerState<BillLinesPanel> createState() => _BillLinesPanelState();
}}

class _BillLinesPanelState extends ConsumerState<BillLinesPanel> {{
{extracted_logic}
  @override
  Widget build(BuildContext context) {{
    final billLines = ref.watch(billingControllerProvider).billLines;
    
    return ListView.builder(
      itemCount: billLines.length,
      itemBuilder: (ctx, i) {{
        final line = billLines[i];
        return _buildBillLineTile(line, i);
      }},
    );
  }}
}}
'''

with open(new_file_path, 'w', encoding='utf-8') as f:
    f.write(new_file_content)

# Now, update billing_home_screen.dart to use BillLinesPanel
content = content.replace("import 'views/bill_summary_panel.dart';", "import 'views/bill_summary_panel.dart';\nimport 'views/bill_lines_panel.dart';")

old_list_view = '''          Expanded(
            child: ListView.builder(
              itemCount: _billLines.length,
              itemBuilder: (ctx, i) {
                final line = _billLines[i];
                return _buildBillLineTile(line, i);
              },
            ),
          ),'''

new_list_view = '''          Expanded(
            child: BillLinesPanel(
              checkStock: _hasEnoughStockForDraft,
            ),
          ),'''
content = content.replace(old_list_view, new_list_view)

# Also remove _billLines from billing_home_screen since it's now fully in controller.
content = content.replace('final List<BillLineItem> _billLines = [];\n', '')
content = content.replace('_billLines.isEmpty', 'ref.read(billingControllerProvider).billLines.isEmpty')
content = content.replace('_billLines.add(', 'ref.read(billingControllerProvider.notifier).addLine(')
content = content.replace('_billLines.last.draftKey', 'ref.read(billingControllerProvider).billLines.last.draftKey')
content = content.replace('_billLines.clear();', '') # handled by clearBill()
content = content.replace('final linesSnapshot = List<BillLineItem>.from(_billLines);', 'final linesSnapshot = ref.read(billingControllerProvider).billLines;')

# We must keep _hasEnoughStockForDraft in billing_home_screen.dart.
# Let's ensure _hasEnoughStockForDraft accesses ref.read(billingControllerProvider).billLines
content = content.replace('double draftQty = _billLines\n', 'double draftQty = ref.read(billingControllerProvider).billLines\n')
content = content.replace('double draftQty = _billLines.', 'double draftQty = ref.read(billingControllerProvider).billLines.')


with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Extraction script complete.")
