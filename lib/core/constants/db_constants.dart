/// Centralized SQLite schema constants for Kirana POS database
class DbConstants {
  DbConstants._();

  static const String dbName = 'kirana.db';
  static const int dbVersion = 1;

  // Table names
  static const String tableSettings = 'settings';
  static const String tableUsers = 'users';
  static const String tableCategories = 'categories';
  static const String tableProducts = 'products';
  static const String tableCustomers = 'customers';
  static const String tableBills = 'bills';
  static const String tableBillItems = 'bill_items';
  static const String tableBillPayments = 'bill_payments';
  static const String tableStockLog = 'stock_log';
  static const String tableUdhaarLedger = 'udhaar_ledger';
  static const String tableExpenseAccounts = 'expense_accounts';
  static const String tableExpenses = 'expenses';
  static const String tableKhataLedger = 'khata_ledger';
  static const String tableReturns = 'returns';
  static const String tableReturnItems = 'return_items';
  static const String tableReplaceTransactions = 'replace_transactions';
  static const String tableReminderLog = 'reminder_log';
  static const String tableTransliterationDict = 'transliteration_dictionary';

  // Common Column names
  static const String colId = 'id';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';

  // Products Table Columns
  static const String colProductNameGuj = 'name_gu';
  static const String colProductNameEng = 'name_en';
  static const String colProductCategoryId = 'category_id';
  static const String colProductBuyPrice = 'buy_price';
  static const String colProductSellPrice = 'sell_price';
  static const String colProductStockQty = 'stock_qty';
  static const String colProductMinStockAlert = 'min_stock_alert';
  static const String colProductUnitType = 'unit_type';
  static const String colProductIsActive = 'is_active';

  // Bills Table Columns
  static const String colBillNumber = 'bill_number';
  static const String colBillCustomerId = 'customer_id';
  static const String colBillCustomerName = 'customer_name_snapshot';
  static const String colBillSubtotal = 'subtotal';
  static const String colBillDiscount = 'discount';
  static const String colBillGstAmount = 'gst_amount';
  static const String colBillTotalAmount = 'total_amount';
  static const String colBillPaidAmount = 'paid_amount';
  static const String colBillUdhaarAmount = 'udhaar_amount';
  static const String colBillPaymentMode = 'payment_mode';
  static const String colBillPaymentStatus = 'payment_status';
  static const String colBillIsPrinted = 'is_printed';
  static const String colBillDate = 'bill_date';

  // Customers Table Columns
  static const String colCustomerName = 'name';
  static const String colCustomerMobile = 'mobile';
  static const String colCustomerAddress = 'address';
  static const String colCustomerTotalOutstanding = 'total_outstanding';
  static const String colCustomerCreditLimit = 'credit_limit';
}
