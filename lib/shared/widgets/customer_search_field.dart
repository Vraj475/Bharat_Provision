// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_helper.dart';
import '../../core/theme/app_colors.dart';

class CustomerSearchField extends ConsumerStatefulWidget {
  final String hintText;
  final Function(int customerId, String customerName) onCustomerSelected;
  final TextEditingController controller;

  const CustomerSearchField({
    super.key,
    required this.hintText,
    required this.onCustomerSelected,
    required this.controller,
  });

  @override
  ConsumerState<CustomerSearchField> createState() =>
      _CustomerSearchFieldState();
}

class _CustomerSearchResult {
  _CustomerSearchResult({
    required this.id,
    required this.nameGujarati,
    required this.nameEnglish,
    required this.phone,
    required this.totalOutstanding,
  });

  final int id;
  final String nameGujarati;
  final String? nameEnglish;
  final String? phone;
  final double totalOutstanding;
}

class _CustomerSearchFieldState extends ConsumerState<CustomerSearchField> {
  final FocusNode _textFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();
  final List<_CustomerSearchResult> _results = [];
  Timer? _searchDebounce;
  int _searchToken = 0;
  int _highlightedIndex = -1;
  bool _isDropdownOpen = false;

  @override
  void initState() {
    super.initState();
    _textFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _textFocusNode.removeListener(_handleFocusChange);
    _textFocusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted) {
      return;
    }

    if (!_textFocusNode.hasFocus) {
      setState(() {
        _isDropdownOpen = false;
        _results.clear();
        _highlightedIndex = -1;
      });
    }
  }

  Future<void> _searchCustomers(String query) async {
    final typed = query.trim();
    _searchDebounce?.cancel();

    if (typed.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _results.clear();
        _isDropdownOpen = false;
        _highlightedIndex = -1;
      });
      return;
    }

    final token = ++_searchToken;
    _searchDebounce = Timer(const Duration(milliseconds: 120), () async {
      try {
        final database = await DatabaseHelper.instance.database;
        final term = '%$typed%';
        final rows = await database.rawQuery(
          'SELECT id, name_gujarati, name_english, phone, total_outstanding FROM customers WHERE is_active = 1 AND (name_gujarati LIKE ? OR name_english LIKE ?) ORDER BY name_gujarati ASC LIMIT 10',
          [term, term],
        );

        if (!mounted || token != _searchToken) {
          return;
        }

        final nextResults = rows
            .map(
              (row) => _CustomerSearchResult(
                id: row['id'] as int,
                nameGujarati: row['name_gujarati'] as String,
                nameEnglish: row['name_english'] as String?,
                phone: row['phone'] as String?,
                totalOutstanding:
                    (row['total_outstanding'] as num?)?.toDouble() ?? 0.0,
              ),
            )
            .toList();

        setState(() {
          _results
            ..clear()
            ..addAll(nextResults);
          _isDropdownOpen = _results.isNotEmpty;
          _highlightedIndex = _results.isEmpty ? -1 : 0;
        });
      } catch (error) {
        debugPrint('CUSTOMER SEARCH ERROR: $error');
        if (!mounted || token != _searchToken) {
          return;
        }
        setState(() {
          _results.clear();
          _isDropdownOpen = false;
          _highlightedIndex = -1;
        });
      }
    });
  }

  void _clearResults() {
    setState(() {
      _results.clear();
      _isDropdownOpen = false;
      _highlightedIndex = -1;
    });
  }

  void _selectCustomer(_CustomerSearchResult customer) {
    debugPrint('CUSTOMER SELECTED IN CORRECT CONTROL: id=${customer.id}');
    _searchDebounce?.cancel();
    widget.controller.value = TextEditingValue(
      text: customer.nameGujarati,
      selection: TextSelection.collapsed(offset: customer.nameGujarati.length),
    );
    setState(() {
      _results.clear();
      _isDropdownOpen = false;
      _highlightedIndex = -1;
    });
    widget.onCustomerSelected(customer.id, customer.nameGujarati);
    _textFocusNode.unfocus();
  }

  void _moveHighlight(int delta) {
    if (_results.isEmpty) {
      return;
    }

    setState(() {
      final next = _highlightedIndex + delta;
      if (next < 0) {
        _highlightedIndex = _results.length - 1;
      } else if (next >= _results.length) {
        _highlightedIndex = 0;
      } else {
        _highlightedIndex = next;
      }
      _isDropdownOpen = true;
    });
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent || !_isDropdownOpen || _results.isEmpty) {
      return;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveHighlight(1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveHighlight(-1);
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_highlightedIndex >= 0 && _highlightedIndex < _results.length) {
        _selectCustomer(_results[_highlightedIndex]);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _clearResults();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _keyboardFocusNode,
      onKey: _handleKeyEvent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: widget.controller,
            focusNode: _textFocusNode,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: const Icon(Icons.person),
              suffixIcon: widget.controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        widget.controller.clear();
                        _clearResults();
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: const OutlineInputBorder(),
            ),
            onChanged: _searchCustomers,
          ),
          if (_isDropdownOpen && _results.isNotEmpty)
            Material(
              elevation: 8,
              color: Colors.white,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder: (context, separatorIndex) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final customer = _results[index];
                    final highlighted = index == _highlightedIndex;
                    return InkWell(
                      onTap: () => _selectCustomer(customer),
                      child: Container(
                        color: highlighted ? AppColors.primarySurface : null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.nameGujarati,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if ((customer.phone ?? '').trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        customer.phone!,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (customer.totalOutstanding > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  border: Border.all(
                                    color: Colors.orange.shade700,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'ઉધાર ₹${customer.totalOutstanding.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
