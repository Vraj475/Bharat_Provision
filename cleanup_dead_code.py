import sys

file_path = 'lib/features/billing/billing_home_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

def remove_method(method_sig):
    global lines
    start_idx = -1
    for i, line in enumerate(lines):
        if method_sig in line:
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

remove_method('void _startGrandTotalEdit()')
remove_method('void _commitGrandTotalEdit()')
remove_method('void _setDiscount()')

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove subtotal and total getters
content = content.replace('  double get _subtotal => ref.read(billingControllerProvider).billLines.fold(0, (sum, line) => sum + line.amount);\n', '')
content = content.replace('  double get _total => _subtotal - _discount;\n', '')
content = content.replace('  double get _subtotal => _billLines.fold(0, (sum, line) => sum + line.amount);\n', '')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

# Fix print service
print_path = 'lib/features/billing/services/billing_print_service.dart'
with open(print_path, 'r', encoding='utf-8') as f:
    pcontent = f.read()
pcontent = pcontent.replace('''      if (billRepo == null) {
        throw StateError('PRINT_001');
      }''', '')
with open(print_path, 'w', encoding='utf-8') as f:
    f.write(pcontent)

print("Cleanup done.")
