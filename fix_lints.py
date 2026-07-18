import sys

file_path = 'lib/features/billing/views/bill_lines_panel.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('!mounted || _isDisposed', '!mounted')
content = content.replace('_billLines', 'ref.read(billingControllerProvider).billLines')
content = content.replace("import '../controllers/billing_controller.dart';", "import '../controllers/billing_controller.dart';\nimport '../../../core/utils/currency_format.dart';")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Fixed lints.')
