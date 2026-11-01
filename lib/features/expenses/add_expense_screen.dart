import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/models/expense_account_model.dart';
import '../../shared/models/expense_model.dart';
import 'expense_repository_provider.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key, this.expense});

  final Expense? expense;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedAccountId;
  ExpenseAccount? _selectedAccount;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _paymentMode = 'cash';
  bool _amountEdited = false;
  bool _isSaving = false;

  final List<double> _quickAmounts = [50, 100, 200, 500, 1000, 2000, 5000];
  final List<String> _quickNotes = [
    'ચા-નાસ્તો',
    'વીજળી બિલ',
    'દુકાન ભાડું',
    'પગાર',
    'ટેમ્પો ભાડું',
    'પેકિંગ / થેલી',
    'સફાઈ ખર્ચ',
    'સ્ટેશનરી',
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.expense;
    if (initial != null) {
      _amountController.text = initial.amount.toStringAsFixed(2);
      _descriptionController.text = initial.description ?? '';
      _selectedDate = DateTime.tryParse(initial.expenseDate) ?? DateTime.now();
      _selectedAccountId = initial.expenseAccountId;
      _amountEdited = true;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('કૃપા કરીને ખર્ચ ખાતું પસંદ કરો.'),
          backgroundColor: AppColors.alert,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('કૃપા કરીને માન્ય રકમ દાખલ કરો.'),
          backgroundColor: AppColors.alert,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final expense = Expense(
        id: widget.expense?.id,
        expenseAccountId: _selectedAccountId,
        accountNameSnapshot: _selectedAccount?.accountNameGujarati ??
            widget.expense?.accountNameSnapshot ??
            'ખર્ચ',
        amount: amount,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        expenseDate: _selectedDate.toIso8601String(),
        createdAt: widget.expense?.createdAt ?? DateTime.now().toIso8601String(),
      );

      final repo = ref.read(expenseRepositoryProvider);
      if (widget.expense == null) {
        await repo.addExpense(expense, paymentMode: _paymentMode);
      } else {
        await repo.updateExpense(expense, paymentMode: _paymentMode);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.expense == null
                  ? 'ખર્ચ સફળતાપૂર્વક સાચવવામાં આવ્યો!'
                  : 'ખર્ચ સફળતાપૂર્વક અપડેટ થયો!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ભૂલ: $e'),
            backgroundColor: AppColors.alert,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.expense != null;
    final dateStr =
        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(isEditing ? 'ખર્ચ બદલો (Edit Expense)' : 'નવો ખર્ચ ઉમેરો (Add Expense)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.money_off_csred_outlined,
                              color: AppColors.alert,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing ? 'ખર્ચ વિગતમાં ફેરફાર કરો' : 'દુકાન ખર્ચ નોંધણી',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Text(
                                'રોજબરોજના ખર્ચાઓ પ્રોફિટ ગણતરી માટે નોંધો',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 20),

                      // 1. Expense Account Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ખર્ચ ખાતું (Expense Account) *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                            ),
                            onPressed: _showQuickAddAccountDialog,
                            icon: const Icon(Icons.add_circle_outline, size: 16),
                            label: const Text('+ નવું ખાતું'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildAccountDropdown(),
                      const SizedBox(height: 18),

                      // 2. Amount Input Field
                      const Text(
                        'ખર્ચ રકમ (Amount) *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              '₹',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                          hintText: '0.00',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'કૃપા કરીને રકમ દાખલ કરો';
                          }
                          final parsed = double.tryParse(value.trim());
                          if (parsed == null || parsed <= 0) {
                            return 'માન્ય રકમ દાખલ કરો';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      // Quick Amount Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _quickAmounts.map((amt) {
                          return ActionChip(
                            label: Text('+ ₹${amt.toInt()}'),
                            backgroundColor: const Color(0xFFF1F5F9),
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                            onPressed: () {
                              final current = double.tryParse(_amountController.text.trim()) ?? 0;
                              if (current == 0) {
                                _amountController.text = amt.toStringAsFixed(0);
                              } else {
                                _amountController.text = (current + amt).toStringAsFixed(0);
                              }
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),

                      // 3. Payment Mode & Date Row
                      Row(
                        children: [
                          // Payment mode
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ચુકવણી પદ્ધતિ (Mode)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: _paymentMode,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.payment, size: 20),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'cash', child: Text('રોકડ (Cash)')),
                                    DropdownMenuItem(value: 'bank', child: Text('UPI / બેંક (Online)')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _paymentMode = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Date picker
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ખર્ચ તારીખ (Date)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: _pickDate,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(10),
                                      color: Colors.white,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
                                        const SizedBox(width: 8),
                                        Text(
                                          dateStr,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 4. Description Field
                      const Text(
                        'વિગત / નોંધ (Description / Notes)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'દા.ત. દુકાન માટે ચા-પાણી, વીજળી બિલ, વગેરે...',
                          prefixIcon: const Icon(Icons.edit_note, size: 22),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Quick Notes Chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _quickNotes.map((note) {
                          return ActionChip(
                            label: Text(note),
                            backgroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey.shade300),
                            labelStyle: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                            onPressed: () {
                              _descriptionController.text = note;
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 28),

                      // 5. Submit Button
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveExpense,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 1,
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            _isSaving
                                ? 'સાચવી રહ્યા છે...'
                                : (isEditing ? 'ખર્ચ અપડેટ કરો' : 'ખર્ચ સાચવો (Save Expense)'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountDropdown() {
    final accountsAsync = ref.watch(activeExpenseAccountsProvider);

    return accountsAsync.when(
      data: (accounts) {
        if (_selectedAccountId == null &&
            widget.expense?.expenseAccountId != null) {
          _selectedAccountId = widget.expense!.expenseAccountId;
        }

        final effectiveId = accounts.any((a) => a.id == _selectedAccountId)
            ? _selectedAccountId
            : null;

        if (effectiveId != null && _selectedAccount == null) {
          _selectedAccount =
              accounts.where((a) => a.id == effectiveId).firstOrNull;
        }

        return DropdownButtonFormField<int>(
          key: ValueKey(effectiveId),
          initialValue: effectiveId,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon:
                const Icon(Icons.account_balance_wallet_outlined, size: 20),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          hint: const Text('ખાતું પસંદ કરો (Select Account)'),
          items: accounts.map((account) {
            final isFixed = account.accountType == 'fixed';
            return DropdownMenuItem<int>(
              value: account.id,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${account.accountNameGujarati} (${account.accountNameEnglish ?? ''})',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          isFixed ? Colors.blue.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isFixed ? 'નિયમિત (Fixed)' : 'પરચૂરણ (Variable)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isFixed
                            ? Colors.blue.shade800
                            : Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (id) {
            final account = accounts.where((a) => a.id == id).firstOrNull;
            setState(() {
              _selectedAccountId = id;
              _selectedAccount = account;
              if (!_amountEdited &&
                  account != null &&
                  account.typicalAmount > 0) {
                _amountController.text =
                    account.typicalAmount.toStringAsFixed(0);
              }
            });
          },
          validator: (value) =>
              value == null ? 'કૃપા કરીને ખાતું પસંદ કરો' : null,
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, st) => Text(
        'ખાતા લોડ કરવામાં ભૂલ: $e',
        style: const TextStyle(color: Colors.red),
      ),
    );
  }

  void _showQuickAddAccountDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'નવું ખર્ચ ખાતું',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ખાતાનું નામ (ગુજરાતી અથવા English) *',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'દા.ત. ચા-નાસ્તો / Tea & Snacks',
                prefixIcon: const Icon(Icons.label_outline, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('રદ કરો (Cancel)'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final enteredName = nameController.text.trim();
              if (enteredName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('કૃપા કરીને ખાતાનું નામ દાખલ કરો'),
                  ),
                );
                return;
              }

              try {
                final repo = ref.read(expenseRepositoryProvider);
                final newAccount = ExpenseAccount(
                  accountNameGujarati: enteredName,
                  accountNameEnglish: enteredName,
                  accountType: 'variable',
                  typicalAmount: 0.0,
                  isActive: true,
                  createdAt: DateTime.now().toIso8601String(),
                );
                final newId = await repo.addExpenseAccount(newAccount);

                ref.invalidate(activeExpenseAccountsProvider);
                ref.invalidate(allExpenseAccountsProvider);

                if (!mounted) return;
                Navigator.of(ctx).pop();

                setState(() {
                  _selectedAccountId = newId;
                  _selectedAccount = ExpenseAccount(
                    id: newId,
                    accountNameGujarati: enteredName,
                    accountNameEnglish: enteredName,
                    accountType: 'variable',
                    typicalAmount: 0.0,
                    isActive: true,
                    createdAt: newAccount.createdAt,
                  );
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("'$enteredName' ખાતું સફળતાપૂર્વક ઉમેરાયું!"),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('ભૂલ: $e'),
                    backgroundColor: AppColors.alert,
                  ),
                );
              }
            },
            child: const Text('સાચવો (Save)'),
          ),
        ],
      ),
    );
  }
}
