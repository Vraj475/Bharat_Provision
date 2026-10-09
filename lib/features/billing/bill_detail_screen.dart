import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/utils/currency_format.dart';
import '../../data/providers.dart';
import '../../routing/app_router.dart';
import '../../shared/models/bill_item_model.dart';
import '../../shared/models/bill_model.dart';
import '../../shared/models/customer_model.dart';
import 'bill_history_widgets.dart';

class BillDetailData {
  const BillDetailData({
    required this.bill,
    required this.items,
    this.customer,
  });

  final Bill bill;
  final List<BillItem> items;
  final Customer? customer;
}

class BillDetailScreen extends ConsumerStatefulWidget {
  const BillDetailScreen({super.key, required this.billId});

  final int billId;

  @override
  ConsumerState<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends ConsumerState<BillDetailScreen> {
  late Future<BillDetailData?> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _fetchBillData();
  }

  void _reload() {
    setState(() {
      _loadFuture = _fetchBillData();
    });
  }

  Future<BillDetailData?> _fetchBillData() async {
    final billRepo = ref.read(billRepositoryProvider);
    final bill = await billRepo.getById(widget.billId);
    if (bill == null) return null;

    final items = await billRepo.getBillItems(widget.billId);

    Customer? customer;
    if (bill.customerId != null) {
      try {
        final custRepo = ref.read(customerRepositoryProvider);
        customer = await custRepo.getById(bill.customerId!);
      } catch (_) {}
    }

    return BillDetailData(bill: bill, items: items, customer: customer);
  }

  String _formatDateTime(String rawDate, String createdAt) {
    String datePart = rawDate;
    final parsedDate = DateTime.tryParse(rawDate);
    if (parsedDate != null) {
      datePart = DateFormat('dd/MM/yyyy').format(parsedDate.toLocal());
    }

    final parsedCreated = DateTime.tryParse(createdAt);
    if (parsedCreated != null) {
      final timePart = DateFormat('hh:mm a').format(parsedCreated.toLocal());
      return '$datePart • $timePart';
    }

    return datePart;
  }

  String _formatQuantity(double qty) {
    if (qty == qty.truncateToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(2);
  }

  void _copyReceiptToClipboard(Bill bill, List<BillItem> items, Customer? customer) {
    final buffer = StringBuffer();
    buffer.writeln('=================================');
    buffer.writeln('     ભારત પ્રોવિઝન સ્ટોર');
    buffer.writeln('=================================');
    buffer.writeln('બિલ નં. #${bill.billNumber}');
    buffer.writeln('તારીખ: ${_formatDateTime(bill.billDate, bill.createdAt)}');

    final isCash = (bill.paymentMode?.toLowerCase() == 'cash') ||
        (bill.paymentStatus == 'paid' &&
            (bill.customerNameSnapshot == null || bill.customerNameSnapshot!.trim().isEmpty));

    if (isCash) {
      buffer.writeln('ચૂકવણી: રોકડ');
      if (bill.customerNameSnapshot != null && bill.customerNameSnapshot!.trim().isNotEmpty) {
        buffer.writeln('ગ્રાહક: ${bill.customerNameSnapshot!.trim()}');
      }
    } else {
      final name = bill.customerNameSnapshot ?? customer?.nameGujarati ?? 'ઉધાર ગ્રાહક';
      buffer.writeln('ગ્રાહક: $name');
      if (customer?.phone != null) buffer.writeln('મોબાઈલ: ${customer!.phone}');
      buffer.writeln('ચૂકવણી: ઉધાર (ખાતા)');
    }

    buffer.writeln('---------------------------------');
    buffer.writeln('વસ્તુ | જથ્થો | ભાવ | રકમ');
    buffer.writeln('---------------------------------');

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final name = item.productNameSnapshot ?? 'ઉત્પાદન #${item.productId}';
      final qtyStr = '${_formatQuantity(item.qty)} ${item.unitTypeSnapshot ?? ''}'.trim();
      final rateStr = formatCurrency(item.sellPriceSnapshot ?? 0);
      final amtStr = formatCurrency(item.amount);
      final returnedTag = item.isReturned ? ' [પરત]' : '';
      buffer.writeln('${i + 1}. $name$returnedTag');
      buffer.writeln('   જથ્થો: $qtyStr | ભાવ: $rateStr | રકમ: $amtStr');
    }

    buffer.writeln('---------------------------------');
    buffer.writeln('સબટોટલ: ${formatCurrency(bill.subtotal)}');
    if (bill.discount > 0) {
      buffer.writeln('ડિસ્કાઉન્ટ: -${formatCurrency(bill.discount)}');
    }
    buffer.writeln('કુલ રકમ: ${formatCurrency(bill.totalAmount)}');
    if (bill.udhaarAmount > 0) {
      buffer.writeln('ચૂકવેલ: ${formatCurrency(bill.paidAmount)}');
      buffer.writeln('બાકી ઉધાર: ${formatCurrency(bill.udhaarAmount)}');
    }
    buffer.writeln('=================================');
    buffer.writeln('     આભાર! ફરી પધારશો.');
    buffer.writeln('=================================');

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('બિલ રસીદ ક્લિપબોર્ડ પર કોપી થઈ ગઈ'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('બિલ વિગતો'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'રિફ્રેશ કરો',
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<BillDetailData?>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    'બિલ વિગતો લોડ થઈ રહી છે...',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 54, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      'વિગતો મેળવવામાં ભૂલ થઈ: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('ફરી પ્રયાસ કરો'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 54, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    Text(
                      'બિલ #${widget.billId} મળ્યું નથી',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('પાછા જાઓ'),
                    ),
                  ],
                ),
              ),
            );
          }

          final bill = data.bill;
          final items = data.items;
          final customer = data.customer;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(bill),
                const SizedBox(height: 14),
                _buildCustomerCard(bill, customer),
                const SizedBox(height: 14),
                _buildItemsCard(items),
                const SizedBox(height: 14),
                _buildSummaryCard(bill),
                const SizedBox(height: 20),
                _buildActionButtons(bill, items, customer),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(Bill bill) {
    final dateTimeText = _formatDateTime(bill.billDate, bill.createdAt);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ભારત પ્રોવિઝન સ્ટોર',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'બિલ વિગતવાર રસીદ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                BillHistoryStatusBadge(status: bill.paymentStatus),
              ],
            ),
            const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tag, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      'બિલ નં. #${bill.billNumber}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 15, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      dateTimeText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(Bill bill, Customer? customer) {
    final normalizedMode = (bill.paymentMode ?? '').trim().toLowerCase();
    final normalizedStatus = (bill.paymentStatus ?? '').trim().toLowerCase();
    final hasCustomerName =
        bill.customerNameSnapshot != null &&
        bill.customerNameSnapshot!.trim().isNotEmpty;

    final isUdhaar =
        normalizedStatus == 'udhaar' ||
        normalizedMode == 'udhaar' ||
        bill.udhaarAmount > 0;

    final isCash =
        !isUdhaar &&
        (normalizedMode == 'cash' ||
            normalizedMode.isEmpty ||
            (!hasCustomerName && normalizedStatus == 'paid'));

    if (isCash) {
      return Card(
        elevation: 0,
        color: const Color(0xFFF0FDF4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFBBF7D0), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.payments_outlined, color: Color(0xFF16A34A), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'રોકડ ચૂકવણી (Cash Payment)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15803D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasCustomerName
                          ? 'ગ્રાહક: ${bill.customerNameSnapshot!.trim()}'
                          : 'કાઉન્ટર રોકડ ગ્રાહક • કોઈ બાકી રકમ નથી',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Udhaar or with customer
    final displayName = bill.customerNameSnapshot?.trim().isNotEmpty ?? false
        ? bill.customerNameSnapshot!.trim()
        : (customer?.nameGujarati ?? 'ઉધાર ગ્રાહક');

    return Card(
      elevation: 0,
      color: const Color(0xFFFFF7ED),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFFED7AA), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDD5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person, color: Color(0xFFEA580C), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9A3412),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFED7AA),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isUdhaar ? 'ઉધાર ખાતું' : 'નિયમિત ગ્રાહક',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFC2410C),
                          ),
                        ),
                      ),
                      if (customer?.phone != null && customer!.phone!.trim().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          'ફોન: ${customer.phone}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7C2D12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard(List<BillItem> items) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_bag_outlined, size: 20, color: Color(0xFF1E293B)),
                const SizedBox(width: 8),
                Text(
                  'ખરીદેલ વસ્તુઓ (${items.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'કોઈ વસ્તુ નોંધાયેલ નથી',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ),
              )
            else ...[
              // Table Header with larger, bold column titles
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text(
                        '#',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Text(
                        'વસ્તુ (Item)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'જથ્થો (Qty)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'ભાવ (Rate)',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'રકમ (Total)',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Items List with separated quantity, rate, and amount columns
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF1F5F9),
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final name = item.productNameSnapshot?.trim().isNotEmpty ?? false
                      ? item.productNameSnapshot!
                      : 'ઉત્પાદન #${item.productId}';
                  final qtyText = '${_formatQuantity(item.qty)} ${item.unitTypeSnapshot ?? 'નંગ'}'.trim();
                  final rateText = formatCurrency(item.sellPriceSnapshot ?? 0);
                  final isReturned = item.isReturned;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 26,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                  decoration: isReturned ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              if (isReturned)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'પરત કરેલ',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            qtyText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            rateText,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            formatCurrency(item.amount),
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isReturned ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                              decoration: isReturned ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Bill bill) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'હિસાબ સારાંશ (Billing Summary)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            _buildSummaryRow('સબટોટલ (Subtotal)', formatCurrency(bill.subtotal)),
            if (bill.discount > 0) ...[
              const SizedBox(height: 8),
              _buildSummaryRow(
                'ડિસ્કાઉન્ટ / છૂટ',
                '- ${formatCurrency(bill.discount)}',
                valueColor: const Color(0xFF16A34A),
              ),
            ],
            if (bill.gstAmount > 0) ...[
              const SizedBox(height: 8),
              _buildSummaryRow('ટેક્સ / GST', formatCurrency(bill.gstAmount)),
            ],
            const Divider(height: 20, thickness: 1.5, color: Color(0xFFE2E8F0)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'કુલ રકમ (Grand Total)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  formatCurrency(bill.totalAmount),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            if (bill.udhaarAmount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDBA74)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ચૂકવેલ: ${formatCurrency(bill.paidAmount)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF15803D),
                      ),
                    ),
                    Text(
                      'બાકી ઉધાર: ${formatCurrency(bill.udhaarAmount)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor ?? const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Bill bill, List<BillItem> items, Customer? customer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _copyReceiptToClipboard(bill, items, customer),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text(
                  'રસીદ કોપી કરો',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  context.push(AppRouter.returnsReplace);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.assignment_return_outlined, size: 18),
                label: const Text(
                  'પરત / બદલો',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
