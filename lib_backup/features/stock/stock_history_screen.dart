import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/models/stock_log_model.dart';
import 'stock_providers.dart';

class StockHistoryScreen extends ConsumerWidget {
  const StockHistoryScreen({
    super.key,
    required this.productId,
    required this.productName,
  });
  final int productId;
  final String productName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(
      stockHistoryProvider(HistoryParams(productId: productId)),
    );
    return Scaffold(
      appBar: AppBar(title: Text('સ્ટોક ઇતિહાસ — $productName')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'ઉત્પાદ: $productName',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Expanded(
            child: historyAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return const Center(child: Text('કોઈ ઇતિહાસ મળ્યો નહીં'));
                }
                return ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (ctx, i) => _StockHistoryRow(log: logs[i]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('ભૂલ: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockHistoryRow extends StatelessWidget {
  const _StockHistoryRow({required this.log});
  final StockLogEntry log;

  @override
  Widget build(BuildContext context) {
    final isAddition = log.qtyChange > 0;
    final bgColor = isAddition ? Colors.green.shade50 : Colors.red.shade50;
    final label = _typeLabel(log.transactionType);
    final qtyPrefix = isAddition ? '+' : '-';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bgColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('dd/MM/yyyy').format(DateTime.parse(log.createdAt)),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isAddition ? Colors.green : Colors.red,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '$qtyPrefix${log.qtyChange.toStringAsFixed(1)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isAddition ? Colors.green : Colors.red,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'બેલેન્સ: ${log.qtyAfter.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'purchase':
        return 'ખરીદી';
      case 'sale':
        return 'વેચાણ';
      case 'return':
        return 'પાછું';
      case 'replace_in':
        return 'બદલી-આવ્યું';
      case 'replace_out':
        return 'બદલી-ગયું';
      case 'manual_adjust':
        return 'જાતે સુધારો';
      default:
        return type;
    }
  }
}
