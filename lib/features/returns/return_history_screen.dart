import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/return_model.dart';
import 'returns_providers.dart';

class ReturnHistoryScreen extends ConsumerStatefulWidget {
  const ReturnHistoryScreen({super.key});

  @override
  ConsumerState<ReturnHistoryScreen> createState() =>
      _ReturnHistoryScreenState();
}

class _ReturnHistoryScreenState extends ConsumerState<ReturnHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<ReturnEntry> _returns = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(returnRepositoryProvider);
      final rows = await repo.getReturnHistory();
      if (!mounted) return;
      setState(() {
        _returns = rows;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _formatDate(String isoString) {
    final parsed = DateTime.tryParse(isoString);
    if (parsed != null) {
      return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    }
    return isoString;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('પાછું આપવાનો ઇતિહાસ (Return History)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHistory),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('ભૂલ: $_error'))
          : _returns.isEmpty
          ? const Center(child: Text('હજુ સુધી કોઈ પરત નોંધાયેલ નથી'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _returns.length,
              itemBuilder: (context, index) {
                final r = _returns[index];
                final modeLabel = r.returnMode == 'cash_refund'
                    ? 'કેશ રિફંડ'
                    : (r.returnMode == 'udhaar_credit' ? 'ઉધાર ક્રેડિટ' : (r.returnMode ?? 'અજ્ઞાત'));

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'રિટર્ન #${r.id ?? ''} (બિલ #${r.originalBillId ?? ''})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '₹${r.totalReturnValue.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (r.notes != null && r.notes!.trim().isNotEmpty) ...[
                          Text(
                            'ઉત્પાદન વિગત: ${r.notes}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'તારીખ: ${_formatDate(r.returnDate)}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Chip(
                              label: Text(
                                modeLabel,
                                style: const TextStyle(fontSize: 11),
                              ),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
