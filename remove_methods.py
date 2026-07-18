import sys

file_path = 'lib/features/billing/billing_home_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

def remove_method(start_str):
    global lines
    start_idx = -1
    for i, line in enumerate(lines):
        if start_str in line:
            start_idx = i
            break
    if start_idx == -1: return

    # find brace end
    brace_count = 0
    found_open = False
    end_idx = -1
    for j in range(start_idx, len(lines)):
        for char in lines[j]:
            if char == '{':
                brace_count += 1
                found_open = True
            elif char == '}':
                brace_count -= 1
        if found_open and brace_count == 0:
            end_idx = j
            break
    
    if end_idx != -1:
        lines = lines[:start_idx] + lines[end_idx+1:]

remove_method('void _registerLineResources(')
remove_method('void _disposeLineResources(')
remove_method('void _clearInlineEditState(')
remove_method('double _lineSellPricePerKg(')
remove_method('String _kgEditableText(')
remove_method('void _startInlineEdit(')
remove_method('Future<void> _commitInlineEdit(')
remove_method('Future<void> _deleteLineWithUndo(')
remove_method('Widget _buildEditableValueChip(')
remove_method('Widget _buildBillLineTile(')
remove_method('enum _DraftEditableField')

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace variables and list view
# Note: _billLines might be declared differently. Let's just remove the declaration
content = content.replace('  final List<BillLineItem> _billLines = [];\n', '')
content = content.replace('  final Map<String, TextEditingController> _lineEditControllers = {};\n', '')
content = content.replace('  final Map<String, FocusNode> _lineEditFocusNodes = {};\n', '')
content = content.replace('  String? _editingLineKey;\n', '')
content = content.replace('  _DraftEditableField? _editingField;\n', '')
content = content.replace('  bool _isCommittingInlineEdit = false;\n', '')

# Replace list view usage.
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

# Replace remaining _billLines usages with controller access
content = content.replace('_billLines.isEmpty', 'ref.read(billingControllerProvider).billLines.isEmpty')
content = content.replace('_billLines.add(', 'ref.read(billingControllerProvider.notifier).addLine(')
content = content.replace('_billLines.last.draftKey', 'ref.read(billingControllerProvider).billLines.last.draftKey')
content = content.replace('final linesSnapshot = List<BillLineItem>.from(_billLines);', 'final linesSnapshot = ref.read(billingControllerProvider).billLines;')
content = content.replace('double draftQty = _billLines\n', 'double draftQty = ref.read(billingControllerProvider).billLines\n')
content = content.replace('double draftQty = _billLines.', 'double draftQty = ref.read(billingControllerProvider).billLines.')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Removed methods and updated references.")
