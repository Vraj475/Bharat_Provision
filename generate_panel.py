import os

file_path = 'lib/features/billing/billing_home_screen.dart'
new_file_path = 'lib/features/billing/views/bill_lines_panel.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

def get_method_lines(start_str):
    for i, line in enumerate(lines):
        if start_str in line:
            start = i
            brace_count = 0
            found_open = False
            for j in range(i, len(lines)):
                for char in lines[j]:
                    if char == '{':
                        brace_count += 1
                        found_open = True
                    elif char == '}':
                        brace_count -= 1
                if found_open and brace_count == 0:
                    return ''.join(lines[start:j+1])
    return ''

m_register = get_method_lines('void _registerLineResources(')
m_dispose = get_method_lines('void _disposeLineResources(')
m_clear = get_method_lines('void _clearInlineEditState(')
m_price = get_method_lines('double _lineSellPricePerKg(')
m_text = get_method_lines('String _kgEditableText(')
m_start = get_method_lines('void _startInlineEdit(')
m_commit = get_method_lines('Future<void> _commitInlineEdit(')
m_delete = get_method_lines('Future<void> _deleteLineWithUndo(')
m_chip = get_method_lines('Widget _buildEditableValueChip(')
m_tile = get_method_lines('Widget _buildBillLineTile(')

# Adapt mutations in methods for BillLinesPanel
def adapt(m):
    # Length & index
    m = m.replace('_billLines.length', 'ref.read(billingControllerProvider).billLines.length')
    m = m.replace('_billLines[index]', 'ref.read(billingControllerProvider).billLines[index]')
    m = m.replace('_billLines[editingIndex]', 'ref.read(billingControllerProvider).billLines[editingIndex]')
    m = m.replace('_billLines.indexWhere', 'ref.read(billingControllerProvider).billLines.indexWhere')
    m = m.replace('_hasEnoughStockForDraft(', 'widget.checkStock(')
    
    # commits
    old_commit = '''      setState(() {
        _billLines[editingIndex] = updatedLine;
        _clearInlineEditState();
      });
      ref.read(billingControllerProvider.notifier).syncLines(_billLines);'''
    new_commit = '''      ref.read(billingControllerProvider.notifier).updateLine(editingIndex, updatedLine);
      setState(() {
        _clearInlineEditState();
      });'''
    m = m.replace(old_commit, new_commit)

    # remove
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
    m = m.replace(old_remove, new_remove)

    # undo
    old_undo = '''            setState(() {
              final insertIndex = index.clamp(0, _billLines.length);
              _billLines.insert(insertIndex, removedLine);
            });
            ref.read(billingControllerProvider.notifier).syncLines(_billLines);'''
    new_undo = '''            final currentLines = List<BillLineItem>.from(ref.read(billingControllerProvider).billLines);
            final insertIndex = index.clamp(0, currentLines.length);
            currentLines.insert(insertIndex, removedLine);
            ref.read(billingControllerProvider.notifier).syncLines(currentLines);'''
    m = m.replace(old_undo, new_undo)

    # In _startInlineEdit
    m = m.replace('''    if (_isEditingGrandTotal) {
      _commitGrandTotalEdit();
    }''', '')

    return m

m_start = adapt(m_start)
m_commit = adapt(m_commit)
m_delete = adapt(m_delete)
m_tile = adapt(m_tile)
m_chip = adapt(m_chip)
m_price = adapt(m_price)
m_text = adapt(m_text)
m_clear = adapt(m_clear)
m_register = adapt(m_register)
m_dispose = adapt(m_dispose)

new_content = f'''import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../models/bill_line_item.dart';
import '../controllers/billing_controller.dart';

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
  final Map<String, TextEditingController> _lineEditControllers = {{}};
  final Map<String, FocusNode> _lineEditFocusNodes = {{}};
  String? _editingLineKey;
  _DraftEditableField? _editingField;
  bool _isCommittingInlineEdit = false;

  @override
  void dispose() {{
    for (final controller in _lineEditControllers.values) {{
      controller.dispose();
    }}
    for (final focusNode in _lineEditFocusNodes.values) {{
      focusNode.dispose();
    }}
    super.dispose();
  }}

{m_register}
{m_dispose}
{m_clear}
{m_price}
{m_text}
{m_start}
{m_commit}
{m_delete}
{m_chip}
{m_tile}

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
    f.write(new_content)

print("Generated BillLinesPanel!")
