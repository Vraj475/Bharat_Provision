import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/expense_account_model.dart';
import '../expense_providers.dart';

/// Comprehensive view for managing Expense Accounts (Connected to SQLite DB)
/// Supports: View, Search, Insert, Edit, Delete, Toggle Active/Inactive, Reset
class ExpenseAccountsView extends ConsumerStatefulWidget {
  final bool showAppBar;
  const ExpenseAccountsView({super.key, this.showAppBar = false});

  @override
  ConsumerState<ExpenseAccountsView> createState() =>
      _ExpenseAccountsViewState();
}

class _ExpenseAccountsViewState extends ConsumerState<ExpenseAccountsView> {
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all | fixed | variable | active

  @override
  Widget build(BuildContext context) {
    final accountsAsyncValue = ref.watch(allExpenseAccountsProvider);

    final content = accountsAsyncValue.when(
      data: (accounts) {
        // Filter accounts
        final filteredAccounts = accounts.where((account) {
          // Search filter
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final guj = account.accountNameGujarati.toLowerCase();
            final eng = (account.accountNameEnglish ?? '').toLowerCase();
            if (!guj.contains(q) && !eng.contains(q)) return false;
          }
          // Type/Status filter
          if (_selectedFilter == 'fixed' && account.accountType != 'fixed') {
            return false;
          }
          if (_selectedFilter == 'variable' &&
              account.accountType != 'variable') {
            return false;
          }
          if (_selectedFilter == 'active' && !account.isActive) {
            return false;
          }
          return true;
        }).toList();

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(allExpenseAccountsProvider);
            ref.invalidate(activeExpenseAccountsProvider);
            ref.invalidate(expenseAccountsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Top Action Header
              _buildTopHeader(accounts.length),
              const SizedBox(height: 12),

              // Search & Filter Bar
              _buildSearchAndFilters(),
              const SizedBox(height: 14),

              // Accounts List
              if (filteredAccounts.isEmpty)
                _buildEmptyState(accounts.isEmpty)
              else
                ...filteredAccounts.map((account) {
                  return _ExpenseAccountCard(
                    account: account,
                    onEdit: () => _showAddEditDialog(existingAccount: account),
                    onDelete: () => _confirmDeleteAccount(account),
                    onToggle: (isActive) => _toggleAccount(account, isActive),
                  );
                }),
              const SizedBox(height: 24),

              // Reset to defaults button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade800,
                  side: BorderSide(color: Colors.orange.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _showResetConfirmation,
                icon: const Icon(Icons.restore_outlined),
                label: const Text('ડિફૉલ્ટ ખાતા પર રીસેટ કરો (Reset to Defaults)'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                'ભૂલ: $err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(allExpenseAccountsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('ફરી પ્રયાસ કરો (Retry)'),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('ખર્ચ ખાતા (Expense Accounts)'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'નવું ખાતું ઉમેરો',
              onPressed: () => _showAddEditDialog(),
            ),
          ],
        ),
        body: content,
      );
    }

    return content;
  }

  Widget _buildTopHeader(int totalCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ખર્ચ ખાતાઓ (Expense Accounts)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'ડેટાબેઝમાં કુલ $totalCount ખાતા જોડાયેલા છે',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 1,
            ),
            onPressed: () => _showAddEditDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'નવું ખાતું',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search text field
        TextField(
          decoration: InputDecoration(
            hintText: 'ખાતું શોધો (Search by name)...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => _searchQuery = ''),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
        ),
        const SizedBox(height: 8),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('all', 'બધા (All)'),
              const SizedBox(width: 8),
              _buildFilterChip('active', 'સક્રિય (Active)'),
              const SizedBox(width: 8),
              _buildFilterChip('fixed', 'નિયમિત (Fixed)'),
              const SizedBox(width: 8),
              _buildFilterChip('variable', 'પરચૂરણ (Variable)'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = key),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : Colors.black87,
      ),
      backgroundColor: Colors.grey.shade100,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildEmptyState(bool isTableEmpty) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            isTableEmpty
                ? 'કોઈ ખર્ચ ખાતા મળ્યા નથી'
                : 'આ ફિલ્ટર માટે કોઈ ખાતા મળ્યા નથી',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isTableEmpty
                ? 'ડેટાબેઝમાં નવું ખાતું ઉમેરો અથવા ડિફૉલ્ટ રીસેટ કરો'
                : 'બીજો શબ્દ શોધો અથવા ફિલ્ટર બદલો',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _showAddEditDialog(),
            icon: const Icon(Icons.add),
            label: const Text('નવું ખાતું ઉમેરો (Add Account)'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAccount(ExpenseAccount account, bool isActive) async {
    try {
      final repo = ref.read(expenseRepositoryProvider);
      await repo.toggleExpenseAccountStatus(account.id!, isActive);
      _invalidateProviders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isActive
                ? "'${account.accountNameGujarati}' સક્રિય કરવામાં આવ્યું"
                : "'${account.accountNameGujarati}' નિષ્ક્રિય કરવામાં આવ્યું",
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e, st) {
      if (!mounted) return;
      ErrorHandler.handleAndShowSnackbar(
        context,
        e,
        st,
        contextDescription: 'ExpenseAccountsView.toggleAccount',
      );
    }
  }

  Future<void> _confirmDeleteAccount(ExpenseAccount account) async {
    final repo = ref.read(expenseRepositoryProvider);
    final expenseCount = await repo.countExpensesForAccount(account.id!);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 8),
            const Expanded(child: Text('ખાતું કાઢી નાખવું છે?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                text: 'શું તમે ખરેખર ',
                children: [
                  TextSpan(
                    text: "'${account.accountNameGujarati}'",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' ખાતું કાયમ માટે કાઢી નાખવા માંગો છો?'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (expenseCount > 0)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange.shade800, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'આ ખાતા હેઠળ $expenseCount ખર્ચ નોંધાયેલા છે. ખાતું ડિલીટ કરવાથી તે જૂના ખર્ચ સુરક્ષિત રહેશે.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
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
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await repo.deleteExpenseAccount(account.id!);
                _invalidateProviders();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "'${account.accountNameGujarati}' ખાતું સફળતાપૂર્વક કાઢી નાખવામાં આવ્યું!",
                    ),
                    backgroundColor: Colors.red.shade700,
                  ),
                );
              } catch (e, st) {
                if (!mounted) return;
                ErrorHandler.handleAndShowSnackbar(
                  context,
                  e,
                  st,
                  contextDescription: 'ExpenseAccountsView.deleteAccount',
                );
              }
            },
            child: const Text('કાઢી નાખો (Delete)'),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog({ExpenseAccount? existingAccount}) {
    showDialog(
      context: context,
      builder: (ctx) => _AddEditAccountDialog(
        existingAccount: existingAccount,
        onSave: (gujaratiName, englishName, type, amount) async {
          try {
            final repo = ref.read(expenseRepositoryProvider);
            if (existingAccount == null) {
              // INSERT
              await repo.addExpenseAccount(
                ExpenseAccount(
                  accountNameGujarati: gujaratiName,
                  accountNameEnglish: englishName,
                  accountType: type.toLowerCase(),
                  typicalAmount: amount,
                  isActive: true,
                  createdAt: DateTime.now().toIso8601String(),
                ),
              );
              _invalidateProviders();
              if (!mounted) return;
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("'$gujaratiName' ખાતું સફળતાપૂર્વક ઉમેરાયું!"),
                  backgroundColor: AppColors.success,
                ),
              );
            } else {
              // UPDATE
              await repo.updateExpenseAccount(
                ExpenseAccount(
                  id: existingAccount.id,
                  accountNameGujarati: gujaratiName,
                  accountNameEnglish: englishName,
                  accountType: type.toLowerCase(),
                  typicalAmount: amount,
                  isActive: existingAccount.isActive,
                  createdAt: existingAccount.createdAt,
                ),
              );
              _invalidateProviders();
              if (!mounted) return;
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("'$gujaratiName' ખાતું સફળતાપૂર્વક સુધારાયું!"),
                  backgroundColor: AppColors.primary,
                ),
              );
            }
          } catch (e, st) {
            if (!mounted) return;
            ErrorHandler.handleAndShowSnackbar(
              context,
              e,
              st,
              contextDescription: 'ExpenseAccountsView.saveAccount',
            );
          }
        },
      ),
    );
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('ડિફૉલ્ટ પર રીસેટ કરવું?'),
        content: const Text(
          'આનાથી 6 મૂળભૂત ખાતા (ભાડું, વીજળી, પગાર, ફોન, ખરીદી, અન્ય) રીસેટ થશે. હાલના ખર્ચ સુરક્ષિત રહેશે.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('રદ કરો'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final repo = ref.read(expenseRepositoryProvider);
                await repo.resetExpenseAccountsToDefaults();
                _invalidateProviders();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('ડિફૉલ્ટ ખાતા સફળતાપૂર્વક રીસેટ થયા!'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } catch (e, st) {
                if (!mounted) return;
                ErrorHandler.handleAndShowSnackbar(
                  context,
                  e,
                  st,
                  contextDescription: 'ExpenseAccountsView.resetDefaults',
                );
              }
            },
            child: const Text('રીસેટ કરો', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _invalidateProviders() {
    ref.invalidate(allExpenseAccountsProvider);
    ref.invalidate(activeExpenseAccountsProvider);
    ref.invalidate(expenseAccountsProvider);
  }
}

class _ExpenseAccountCard extends StatelessWidget {
  final ExpenseAccount account;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(bool) onToggle;

  const _ExpenseAccountCard({
    required this.account,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isFixed = account.accountType == 'fixed';
    final hasAmount = account.typicalAmount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: account.isActive ? 1.5 : 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: account.isActive
              ? Colors.grey.shade200
              : Colors.grey.shade300,
        ),
      ),
      color: account.isActive ? Colors.white : const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left icon indicator
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isFixed
                    ? const Color(0xFFEFF6FF)
                    : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isFixed ? Icons.receipt : Icons.payments_outlined,
                color: isFixed
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFEA580C),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Middle: Name, Type, and Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          account.accountNameGujarati,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: account.isActive
                                ? const Color(0xFF0F172A)
                                : Colors.grey.shade500,
                            decoration: account.isActive
                                ? TextDecoration.none
                                : TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                      if (account.accountNameEnglish != null &&
                          account.accountNameEnglish!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '(${account.accountNameEnglish})',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      // Type Chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isFixed
                              ? Colors.blue.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isFixed
                                ? Colors.blue.shade200
                                : Colors.orange.shade200,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          isFixed ? 'નિયમિત (Fixed)' : 'પરચૂરણ (Variable)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isFixed
                                ? Colors.blue.shade800
                                : Colors.orange.shade900,
                          ),
                        ),
                      ),
                      if (hasAmount) ...[
                        const SizedBox(width: 8),
                        Text(
                          'અંદાજે: ₹${account.typicalAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                      if (!account.isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'નિષ્ક્રિય',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Active Switch
            Switch(
              value: account.isActive,
              activeThumbColor: AppColors.primary,
              onChanged: onToggle,
            ),

            // Edit button
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: const Color(0xFF475569),
              tooltip: 'સુધારો (Edit)',
              onPressed: onEdit,
            ),

            // Delete button
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: Colors.red.shade700,
              tooltip: 'કાઢી નાખો (Delete)',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddEditAccountDialog extends StatefulWidget {
  final ExpenseAccount? existingAccount;
  final Function(String gujarati, String? english, String type, double amount)
      onSave;

  const _AddEditAccountDialog({
    this.existingAccount,
    required this.onSave,
  });

  @override
  State<_AddEditAccountDialog> createState() => _AddEditAccountDialogState();
}

class _AddEditAccountDialogState extends State<_AddEditAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final acc = widget.existingAccount;
    _nameController = TextEditingController(
      text: acc?.accountNameGujarati.isNotEmpty == true
          ? acc!.accountNameGujarati
          : (acc?.accountNameEnglish ?? ''),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingAccount != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            isEditing ? Icons.edit : Icons.add_circle_outline,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            isEditing ? 'ખાતું સુધારો' : 'નવું ખાતું ઉમેરો',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ખાતાનું નામ (ગુજરાતી અથવા English) *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'દા.ત. ચા-નાસ્તો / Tea & Snacks',
                  prefixIcon: const Icon(Icons.label_outline, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'કૃપા કરીને ખાતાનું નામ દાખલ કરો';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('રદ કરો (Cancel)'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;

            final enteredName = _nameController.text.trim();
            widget.onSave(
              enteredName,
              enteredName,
              widget.existingAccount?.accountType ?? 'variable',
              widget.existingAccount?.typicalAmount ?? 0.0,
            );
          },
          child: Text(
            isEditing ? 'અપડેટ કરો' : 'સાચવો',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
