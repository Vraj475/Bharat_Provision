import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/currency_format.dart';
import '../../shared/models/bill_model.dart';
import '../../shared/models/bill_item_model.dart';
import '../../data/providers.dart';

class BillDetailScreen extends ConsumerWidget {
  const BillDetailScreen({super.key, required this.billId});

  final int billId;

  String _formatDate(String rawDate) {
    if (rawDate.isEmpty) return 'N/A';
    try {
      final parsed = DateTime.parse(rawDate);
      return DateFormat('dd/MM/yyyy hh:mm a').format(parsed.toLocal());
    } catch (_) {
      final epoch = int.tryParse(rawDate);
      if (epoch != null) {
        final parsed = DateTime.fromMillisecondsSinceEpoch(epoch);
        return DateFormat('dd/MM/yyyy hh:mm a').format(parsed.toLocal());
      }
      return rawDate;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Bill #$billId')),
      body: FutureBuilder<(Bill?, List<BillItem>)>(
        future: _loadBill(ref),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final (bill, items) = snapshot.data!;
          if (bill == null) {
            return const Center(child: Text('Bill not found'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bill Number: ${bill.billNumber}'),
                      Text('Date: ${_formatDate(bill.createdAt)}'),
                      Text('Payment: ${bill.paymentMode?.toUpperCase() ?? "CASH"}'),
                      const SizedBox(height: 8),
                      Text('Subtotal: ${formatCurrency(bill.subtotal)}'),
                      Text('Discount: ${formatCurrency(bill.discount)}'),
                      Text(
                        'Total: ${formatCurrency(bill.totalAmount)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Items',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...items.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    item.productNameSnapshot != null &&
                            item.productNameSnapshot!.isNotEmpty
                        ? item.productNameSnapshot!
                        : 'Item #${item.productId}',
                  ),
                  subtitle: Text(
                    '${item.qty.toStringAsFixed(2)} ${item.unitTypeSnapshot ?? ''} x ${formatCurrency(item.sellPriceSnapshot ?? 0)}'.trim(),
                  ),
                  trailing: Text(formatCurrency(item.amount)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<(Bill?, List<BillItem>)> _loadBill(WidgetRef ref) async {
    final repo = ref.read(billRepositoryProvider);
    final bill = await repo.getById(billId);
    if (bill == null) {
      return (null as Bill?, <BillItem>[]);
    }
    final items = await repo.getBillItems(billId);
    return (bill, items);
  }
}
