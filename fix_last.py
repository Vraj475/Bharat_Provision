import sys

file_path = 'lib/features/billing/billing_home_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    # 1. Dispose method
    if '_lineEditControllers' in line or '_lineEditFocusNodes' in line:
        continue
    # 3. _registerLineResources
    if '_registerLineResources' in line:
        continue
    # 2 & 4. _billLines remaining
    if '_billLines' in line:
        line = line.replace('_billLines', 'ref.read(billingControllerProvider).billLines')
        
    new_lines.append(line)

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("Fixed last issues.")
