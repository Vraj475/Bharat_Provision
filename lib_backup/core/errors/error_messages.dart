import 'error_types.dart';

/// Represents a localized Gujarati error message and metadata for an error code.
class ErrorMessage {
  final String code;
  final ErrorCategory category;
  final String gujarati;
  final String technical;
  final bool isCritical;

  const ErrorMessage({
    required this.code,
    required this.category,
    required this.gujarati,
    required this.technical,
    required this.isCritical,
  });
}

/// Central registry of all supported error codes and their Gujarati user-facing messages.
///
/// The UI should only ever show the `gujarati` field to the user. Technical
/// details are saved to the log file for developers.
class ErrorMessages {
  static const Map<String, ErrorMessage> _messages = {
    // Database errors
    'DB_001': ErrorMessage(
      code: 'DB_001',
      category: ErrorCategory.database,
      gujarati: 'ડેટા સેવ કરવામાં મુશ્કેલી આવી. ફરી પ્રયાસ કરો.',
      technical: 'Database insert failed',
      isCritical: false,
    ),
    'DB_002': ErrorMessage(
      code: 'DB_002',
      category: ErrorCategory.database,
      gujarati: 'ડેટા લોડ કરવામાં સમસ્યા આવી. એપ ફરી શરૂ કરો.',
      technical: 'Database read failed',
      isCritical: false,
    ),
    'DB_003': ErrorMessage(
      code: 'DB_003',
      category: ErrorCategory.database,
      gujarati: 'બિલ સેવ કરવામાં નિષ્ફળ. કોઈ ડેટા બદલાયો નથી. ફરી પ્રયાસ કરો.',
      technical: 'Transaction rollback occurred',
      isCritical: false,
    ),
    'DB_004': ErrorMessage(
      code: 'DB_004',
      category: ErrorCategory.database,
      gujarati: 'ડેટાબેઝ ખોલવામાં સમસ્યા. PIN તપાસો અને ફરી પ્રયાસ કરો.',
      technical: 'SQLCipher database open failed — wrong key or corrupted file',
      isCritical: true,
    ),
    'DB_005': ErrorMessage(
      code: 'DB_005',
      category: ErrorCategory.database,
      gujarati: 'ડેટા અપડેટ કરવામાં સમસ્યા આવી. ફરી પ્રયાસ કરો.',
      technical: 'Database update failed',
      isCritical: false,
    ),
    'DB_006': ErrorMessage(
      code: 'DB_006',
      category: ErrorCategory.database,
      gujarati: 'ડેટા કાઢી નાખવામાં સમસ્યા આવી. ફરી પ્રયાસ કરો.',
      technical: 'Database delete failed',
      isCritical: false,
    ),
    'DB_007': ErrorMessage(
      code: 'DB_007',
      category: ErrorCategory.database,
      gujarati: 'ડેટાબેઝ ભ્રષ્ટ થઈ ગયો છે. બેકઅપથી પુનઃસ્થાપિત કરો.',
      technical: 'Database integrity check failed',
      isCritical: true,
    ),

    // Billing errors
    'BILL_001': ErrorMessage(
      code: 'BILL_001',
      category: ErrorCategory.database,
      gujarati: 'બિલ નંબર બનાવવામાં સમસ્યા. ફરી प्रयास કરો.',
      technical: 'Bill number generation failed',
      isCritical: false,
    ),
    'BILL_002': ErrorMessage(
      code: 'BILL_002',
      category: ErrorCategory.database,
      gujarati: 'બિલ આઇટમ ઉમેરવામાં સમસ્યા. ફરી પ્રયાસ કરો.',
      technical: 'Bill item insert failed',
      isCritical: false,
    ),
    'BILL_003': ErrorMessage(
      code: 'BILL_003',
      category: ErrorCategory.database,
      gujarati: 'સ્ટોક ઘટાડવામાં સમસ્યા. બિલ સેવ કર્યું નથી.',
      technical: 'Stock deduction failed during bill save',
      isCritical: false,
    ),
    'BILL_004': ErrorMessage(
      code: 'BILL_004',
      category: ErrorCategory.database,
      gujarati: 'ઉધાર ખાતામાં નોંધ કરવામાં સમસ્યા. બિલ સેવ થયું નથી.',
      technical: 'Udhaar ledger insert failed',
      isCritical: false,
    ),
    'BILL_005': ErrorMessage(
      code: 'BILL_005',
      category: ErrorCategory.database,
      gujarati: 'બિલ સંપૂર્ણ સેવ ન થઈ શક્યું. બધો ડેટા પૂર્વવત્ થઈ ગયો.',
      technical: 'Full bill transaction rollback',
      isCritical: false,
    ),

    // Calculation errors
    'CALC_001': ErrorMessage(
      code: 'CALC_001',
      category: ErrorCategory.calculation,
      gujarati: 'વેચાણ કિંમત શૂન્ય છે. પ્રોડક્ટની કિંમત સુધારો.',
      technical: 'Division by zero in weight calculation — sell price is 0',
      isCritical: false,
    ),
    'CALC_002': ErrorMessage(
      code: 'CALC_002',
      category: ErrorCategory.calculation,
      gujarati: 'નકારાત્મક વજન ચાલશે નહીં. સાચી સંખ્યા દાખલ કરો.',
      technical: 'Negative weight value entered',
      isCritical: false,
    ),
    'CALC_003': ErrorMessage(
      code: 'CALC_003',
      category: ErrorCategory.calculation,
      gujarati: 'રકમ ખૂબ મોટી છે. સાચી સંખ્યા દાખલ કરો.',
      technical: 'Amount overflow — value exceeds maximum',
      isCritical: false,
    ),
    'CALC_004': ErrorMessage(
      code: 'CALC_004',
      category: ErrorCategory.calculation,
      gujarati: 'વળતર મૂલ્ય ગણવામાં મુશ્કેલી. ફરી પ્રયાસ કરો.',
      technical: 'Replace calculation failed — price data inconsistency',
      isCritical: false,
    ),

    // Printing errors
    'PRINT_001': ErrorMessage(
      code: 'PRINT_001',
      category: ErrorCategory.printing,
      gujarati: 'પ્રિન્ટર કનેક્ટ નથી. Bluetooth તપાસો.',
      technical: 'Bluetooth printer not connected',
      isCritical: false,
    ),
    'PRINT_002': ErrorMessage(
      code: 'PRINT_002',
      category: ErrorCategory.printing,
      gujarati: 'પ્રિન્ટ મોકલવામાં સમસ્યા. ફરી પ્રયાસ કરો.',
      technical: 'ESC/POS command send failed',
      isCritical: false,
    ),
    'PRINT_003': ErrorMessage(
      code: 'PRINT_003',
      category: ErrorCategory.printing,
      gujarati: 'બિલ ઇમેજ બનાવવામાં સમસ્યા. ફરી પ્રયાસ કરો.',
      technical: 'RepaintBoundary image capture failed',
      isCritical: false,
    ),
    'PRINT_004': ErrorMessage(
      code: 'PRINT_004',
      category: ErrorCategory.printing,
      gujarati: 'પ્રિન્ટર કાગળ ખૂટ્યો છે. કાગળ ભરો.',
      technical: 'Printer paper out error code received',
      isCritical: false,
    ),
    'PRINT_005': ErrorMessage(
      code: 'PRINT_005',
      category: ErrorCategory.printing,
      gujarati: 'Bluetooth ઍક્સેસ નકારવામાં આવ્યો. Settings માં અનુમતિ આપો.',
      technical: 'Bluetooth permission denied',
      isCritical: false,
    ),

    // Authentication errors
    'AUTH_001': ErrorMessage(
      code: 'AUTH_001',
      category: ErrorCategory.authentication,
      gujarati: 'PIN ખોટો છે. ફરી પ્રયાસ કરો.',
      technical: 'PIN hash mismatch',
      isCritical: false,
    ),
    'AUTH_002': ErrorMessage(
      code: 'AUTH_002',
      category: ErrorCategory.authentication,
      gujarati: '3 વખત ખોટો PIN. 30 સેકન્ડ રાહ જુઓ.',
      technical: '3 failed PIN attempts — lockout triggered',
      isCritical: false,
    ),
    'AUTH_003': ErrorMessage(
      code: 'AUTH_003',
      category: ErrorCategory.authentication,
      gujarati: 'PIN સ્ટોરેજ સમસ્યા. Developer નો સંપર્ક કરો.',
      technical: 'FlutterSecureStorage read/write failed',
      isCritical: true,
    ),
    'AUTH_004': ErrorMessage(
      code: 'AUTH_004',
      category: ErrorCategory.authentication,
      gujarati: 'સત્ર સમાપ્ત. ફરી લૉગ ઇન કરો.',
      technical: 'Session timeout triggered',
      isCritical: false,
    ),

    // Stock errors
    'STOCK_001': ErrorMessage(
      code: 'STOCK_001',
      category: ErrorCategory.database,
      gujarati: 'સ્ટોક ઉમેરવામાં સમસ્યા. ફરી પ્રયાસ કરો.',
      technical: 'Stock addition transaction failed',
      isCritical: false,
    ),
    'STOCK_002': ErrorMessage(
      code: 'STOCK_002',
      category: ErrorCategory.database,
      gujarati: 'આ પ્રોડક્ટ સ્ટોકમાં નથી.',
      technical: 'Stock qty is 0 or negative',
      isCritical: false,
    ),
    'STOCK_003': ErrorMessage(
      code: 'STOCK_003',
      category: ErrorCategory.database,
      gujarati: 'વળતર જથ્થો મૂળ ખરીદી કરતાં વધારે છે.',
      technical: 'Return qty exceeds original bill qty',
      isCritical: false,
    ),

    // Storage errors
    'STORE_001': ErrorMessage(
      code: 'STORE_001',
      category: ErrorCategory.storage,
      gujarati: 'બેકઅપ ફાઇલ બનાવવામાં સમસ્યા. Storage permission તપાસો.',
      technical: 'Backup file write failed',
      isCritical: false,
    ),
    'STORE_002': ErrorMessage(
      code: 'STORE_002',
      category: ErrorCategory.storage,
      gujarati: 'Error log ફાઇલ મળી નથી.',
      technical: 'Error log file does not exist',
      isCritical: false,
    ),
    'STORE_003': ErrorMessage(
      code: 'STORE_003',
      category: ErrorCategory.storage,
      gujarati: 'Storage ભરેલું છે. ફોન Storage ખાલી કરો.',
      technical: 'Device storage full — file write failed',
      isCritical: false,
    ),

    // Udhaar errors
    'UDH_001': ErrorMessage(
      code: 'UDH_001',
      category: ErrorCategory.database,
      gujarati: 'ઉધાર ખાતું અપડેટ કરવામાં સમસ્યા. ફરી પ્રયાસ કરો.',
      technical: 'Udhaar ledger update failed',
      isCritical: false,
    ),
    'UDH_002': ErrorMessage(
      code: 'UDH_002',
      category: ErrorCategory.validation,
      gujarati: 'ગ્રાહક ક્રેડિટ લિમિટ ઊલટાઈ ગઈ છે.',
      technical: 'Customer credit limit exceeded',
      isCritical: false,
    ),
    'UDH_003': ErrorMessage(
      code: 'UDH_003',
      category: ErrorCategory.validation,
      gujarati: 'ઉધારે આપવા માટે ગ્રાહક પસંદ કરવો જરૂરી છે.',
      technical: 'Udhaar payment mode selected without customer',
      isCritical: false,
    ),

    // Return errors
    'RET_001': ErrorMessage(
      code: 'RET_001',
      category: ErrorCategory.database,
      gujarati: 'રિટર્ન પ્રક્રિયા નિષ્ફળ. ડેટા પૂર્વવત્ થઈ ગયો.',
      technical: 'Return transaction rollback',
      isCritical: false,
    ),
    'RET_002': ErrorMessage(
      code: 'RET_002',
      category: ErrorCategory.validation,
      gujarati: 'આ આઇટમ પહેલેથી પાછી આવી ગઈ છે.',
      technical: 'Item already marked as returned',
      isCritical: false,
    ),
    'RET_003': ErrorMessage(
      code: 'RET_003',
      category: ErrorCategory.validation,
      gujarati: 'મૂળ બિલ મળ્યો નથી.',
      technical: 'Original bill not found for return',
      isCritical: false,
    ),

    // Unknown errors
    'UNK_001': ErrorMessage(
      code: 'UNK_001',
      category: ErrorCategory.unknown,
      gujarati: 'કંઈક ખોટું થયું. કૃપા કરીને ફરી પ્રયાસ કરો.',
      technical: 'Unhandled exception caught by global handler',
      isCritical: false,
    ),
  };

  static ErrorMessage of(String code) {
    return _messages[code] ?? _messages['UNK_001']!;
  }

  static String getUserMessage(String code) => of(code).gujarati;

  static bool isCritical(String code) => of(code).isCritical;

  static ErrorCategory getCategory(String code) => of(code).category;
}
