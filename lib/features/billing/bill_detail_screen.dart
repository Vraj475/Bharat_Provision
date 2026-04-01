import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/currency_format.dart';
import '../../data/models/bill.dart';
import '../../data/models/bill_item.dart';
import '../../data/providers.dart';

class BillDetailScreen extends ConsumerWidget {
  const BillDetailScreen({super.key, required this.billId});

  final int billId;

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
                      Text(
                        'Date: ${DateTime.fromMillisecondsSinceEpoch(bill.dateTime).toLocal()}',
                      ),
                      Text('Payment: ${bill.paymentMode.toUpperCase()}'),
                      const SizedBox(height: 8),
                      Text('Subtotal: ${formatCurrency(bill.subtotal)}'),
                      Text('Discount: ${formatCurrency(bill.discountAmount)}'),
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
                  title: Text('Item #${item.itemId}'),
                  subtitle: Text(
                    '${item.quantity.toStringAsFixed(2)} x ${formatCurrency(item.unitPrice)}',
                  ),
                  trailing: Text(formatCurrency(item.lineTotal)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<(Bill?, List<BillItem>)> _loadBill(WidgetRef ref) async {
    final repo = await ref.read(billRepositoryFutureProvider.future);
    final bill = await repo.getById(billId);
    if (bill == null) {
      return (null as Bill?, <BillItem>[]);
    }
    final items = await repo.getBillItems(billId);
    return (bill, items);
  }
}
