import 'package:flutter/material.dart';

import '../../shared/models/product_model.dart';

/// Visual theme configuration for authentic Kirana/grocery products using reliable vector icons.
class ProductVisualTheme {
  final IconData icon;
  final Color iconColor;
  final Color gradientStart;
  final Color gradientEnd;
  final Color borderColor;
  final Color shadowColor;
  final String categoryLabel;

  const ProductVisualTheme({
    required this.icon,
    required this.iconColor,
    required this.gradientStart,
    required this.gradientEnd,
    required this.borderColor,
    required this.shadowColor,
    required this.categoryLabel,
  });
}

/// Returns a realistic, authentic Kirana/grocery visual theme based on product name.
ProductVisualTheme getProductVisualTheme(String name) {
  final lower = name.toLowerCase();

  // 1. Edible Oils (તેલ / સીંગતેલ / કપાસિયા / સરસવ)
  if (lower.contains('તેલ') ||
      lower.contains('સીંગતેલ') ||
      lower.contains('કપાસિયા') ||
      lower.contains('સરસવ') ||
      lower.contains('સનફ્લાવર') ||
      lower.contains('કોપરેલ') ||
      lower.contains('oil')) {
    return const ProductVisualTheme(
      icon: Icons.opacity,
      iconColor: Color(0xFFD97706),
      gradientStart: Color(0xFFFFFBEB),
      gradientEnd: Color(0xFFFEF3C7),
      borderColor: Color(0xFFF59E0B),
      shadowColor: Color(0xFFD97706),
      categoryLabel: 'તેલ',
    );
  }

  // 2. Pure Ghee & Butter (ઘી / માખણ)
  if (lower.contains('ઘી') ||
      lower.contains('ghee') ||
      lower.contains('માખણ') ||
      lower.contains('butter')) {
    return const ProductVisualTheme(
      icon: Icons.breakfast_dining,
      iconColor: Color(0xFFCA8A04),
      gradientStart: Color(0xFFFEFCE8),
      gradientEnd: Color(0xFFFEF08A),
      borderColor: Color(0xFFEAB308),
      shadowColor: Color(0xFFCA8A04),
      categoryLabel: 'ઘી / માખણ',
    );
  }

  // 3. Grains & Wheat (ઘઉં / અનાજ)
  if (lower.contains('ઘઉં') ||
      lower.contains('ટુકડા') ||
      lower.contains('શરબતી') ||
      lower.contains('wheat')) {
    return const ProductVisualTheme(
      icon: Icons.grain,
      iconColor: Color(0xFFA16207),
      gradientStart: Color(0xFFFEF9C3),
      gradientEnd: Color(0xFFFDE68A),
      borderColor: Color(0xFFCA8A04),
      shadowColor: Color(0xFFA16207),
      categoryLabel: 'ઘઉં / અનાજ',
    );
  }

  // 4. Rice (ચોખા / બાસમતી / કોલમ)
  if (lower.contains('ચોખા') ||
      lower.contains('રાઇસ') ||
      lower.contains('બાસમતી') ||
      lower.contains('જીરાસાર') ||
      lower.contains('કોલમ') ||
      lower.contains('rice')) {
    return const ProductVisualTheme(
      icon: Icons.rice_bowl,
      iconColor: Color(0xFF475569),
      gradientStart: Color(0xFFF8FAFC),
      gradientEnd: Color(0xFFF1F5F9),
      borderColor: Color(0xFF94A3B8),
      shadowColor: Color(0xFF64748B),
      categoryLabel: 'ચોખા',
    );
  }

  // 5. Millets, Corn, Poha & Cereals (બાજરી / જુવાર / મકાઈ / પૌંઆ / સાબુદાણા / મમરા)
  if (lower.contains('બાજરી') ||
      lower.contains('જુવાર') ||
      lower.contains('મકાઈ') ||
      lower.contains('corn') ||
      lower.contains('પૌંઆ') ||
      lower.contains('પૌવા') ||
      lower.contains('સાબુદાણા') ||
      lower.contains('મમરા')) {
    return const ProductVisualTheme(
      icon: Icons.grass,
      iconColor: Color(0xFFB45309),
      gradientStart: Color(0xFFFEFCE8),
      gradientEnd: Color(0xFFFDE68A),
      borderColor: Color(0xFFEAB308),
      shadowColor: Color(0xFFCA8A04),
      categoryLabel: 'ધાન્ય / કઠોળ',
    );
  }

  // 6. Pulses & Dal (દાળ / કઠોળ / ચણા / મગ / તુવેર / અડદ / રાજમા)
  if (lower.contains('દાળ') ||
      lower.contains('તુવેર') ||
      lower.contains('કઠોળ') ||
      lower.contains('ચણા') ||
      lower.contains('મગ') ||
      lower.contains('વાલ') ||
      lower.contains('વટાણા') ||
      lower.contains('રાજમા') ||
      lower.contains('અડદ') ||
      lower.contains('મસૂર') ||
      lower.contains('ચોળી') ||
      lower.contains('કાબુલી') ||
      lower.contains('dal') ||
      lower.contains('pulses')) {
    return const ProductVisualTheme(
      icon: Icons.spa,
      iconColor: Color(0xFF15803D),
      gradientStart: Color(0xFFF0FDF4),
      gradientEnd: Color(0xFFDCFCE7),
      borderColor: Color(0xFF22C55E),
      shadowColor: Color(0xFF16A34A),
      categoryLabel: 'દાળ / કઠોળ',
    );
  }

  // 7. Hot Spices - Chili (લાલ મરચું)
  if (lower.contains('મરચ') ||
      lower.contains('chilli') ||
      lower.contains('chili') ||
      lower.contains('કાશ્મીરી') ||
      lower.contains('રેશમપટ્ટો')) {
    return const ProductVisualTheme(
      icon: Icons.local_fire_department,
      iconColor: Color(0xFFDC2626),
      gradientStart: Color(0xFFFEF2F2),
      gradientEnd: Color(0xFFFEE2E2),
      borderColor: Color(0xFFEF4444),
      shadowColor: Color(0xFFDC2626),
      categoryLabel: 'મરચું',
    );
  }

  // 8. Spices & Masala (હળદર / જીરું / રાઈ / ધાણાજીરું / હિંગ / તજ / લવિંગ / ગરમ મસાલો)
  if (lower.contains('હળદર') ||
      lower.contains('જીરું') ||
      lower.contains('રાઈ') ||
      lower.contains('રાય') ||
      lower.contains('ધાણા') ||
      lower.contains('મસાલા') ||
      lower.contains('મેથી') ||
      lower.contains('હિંગ') ||
      lower.contains('તજ') ||
      lower.contains('લવિંગ') ||
      lower.contains('અજમો') ||
      lower.contains('એલચી') ||
      lower.contains('ઈલાયચી') ||
      lower.contains('મરી') ||
      lower.contains('ગરમ મસાલો') ||
      lower.contains('turmeric') ||
      lower.contains('cumin') ||
      lower.contains('masala')) {
    return const ProductVisualTheme(
      icon: Icons.scatter_plot,
      iconColor: Color(0xFFD97706),
      gradientStart: Color(0xFFFFFBEB),
      gradientEnd: Color(0xFFFDE68A),
      borderColor: Color(0xFFF59E0B),
      shadowColor: Color(0xFFD97706),
      categoryLabel: 'મસાલા',
    );
  }

  // 9. Sweeteners (ખાંડ / ગોળ / સાકર)
  if (lower.contains('ગોળ') || lower.contains('jaggery')) {
    return const ProductVisualTheme(
      icon: Icons.cake,
      iconColor: Color(0xFFB45309),
      gradientStart: Color(0xFFFEF3C7),
      gradientEnd: Color(0xFFFDE68A),
      borderColor: Color(0xFFD97706),
      shadowColor: Color(0xFFB45309),
      categoryLabel: 'ગોળ',
    );
  }
  if (lower.contains('ખાંડ') || lower.contains('sugar') || lower.contains('સાકર') || lower.contains('બૂરું')) {
    return const ProductVisualTheme(
      icon: Icons.icecream,
      iconColor: Color(0xFF2563EB),
      gradientStart: Color(0xFFEFF6FF),
      gradientEnd: Color(0xFFDBEAFE),
      borderColor: Color(0xFF60A5FA),
      shadowColor: Color(0xFF3B82F6),
      categoryLabel: 'ખાંડ / સાકર',
    );
  }

  // 10. Beverages - Tea & Coffee (ચા / કોફી)
  if (lower.contains('ચા') || lower.contains('tea') || lower.contains('વાઘ બકરી') || lower.contains('ટાટા ટી')) {
    return const ProductVisualTheme(
      icon: Icons.emoji_food_beverage,
      iconColor: Color(0xFFC2410C),
      gradientStart: Color(0xFFFFF7ED),
      gradientEnd: Color(0xFFFFEDD5),
      borderColor: Color(0xFFEA580C),
      shadowColor: Color(0xFFC2410C),
      categoryLabel: 'ચા',
    );
  }
  if (lower.contains('કોફી') || lower.contains('coffee') || lower.contains('nescafe') || lower.contains('bru')) {
    return const ProductVisualTheme(
      icon: Icons.coffee,
      iconColor: Color(0xFF6D4C41),
      gradientStart: Color(0xFFF5EBE1),
      gradientEnd: Color(0xFFE5D5C5),
      borderColor: Color(0xFF8D5B4C),
      shadowColor: Color(0xFF6D4C41),
      categoryLabel: 'કોફી',
    );
  }

  // 11. Dairy - Milk, Curd, Buttermilk (દૂધ / દહીં / છાશ / પનીર)
  if (lower.contains('દૂધ') ||
      lower.contains('milk') ||
      lower.contains('દહીં') ||
      lower.contains('છાશ') ||
      lower.contains('પનીર') ||
      lower.contains('amul') ||
      lower.contains('અમૂલ')) {
    return const ProductVisualTheme(
      icon: Icons.local_drink,
      iconColor: Color(0xFF0284C7),
      gradientStart: Color(0xFFF0FDF4),
      gradientEnd: Color(0xFFE0F2FE),
      borderColor: Color(0xFF38BDF8),
      shadowColor: Color(0xFF0284C7),
      categoryLabel: 'ડેરી / દૂધ',
    );
  }

  // 12. Flours & Atta (લોટ / આટો / મેંદો / બેસન / રવો / સુજી)
  if (lower.contains('લોટ') ||
      lower.contains('આટો') ||
      lower.contains('flour') ||
      lower.contains('atta') ||
      lower.contains('મેંદો') ||
      lower.contains('બેસન') ||
      lower.contains('રવો') ||
      lower.contains('સુજી') ||
      lower.contains('સોજી')) {
    return const ProductVisualTheme(
      icon: Icons.takeout_dining,
      iconColor: Color(0xFF475569),
      gradientStart: Color(0xFFF8FAFC),
      gradientEnd: Color(0xFFF1F5F9),
      borderColor: Color(0xFF94A3B8),
      shadowColor: Color(0xFF64748B),
      categoryLabel: 'લોટ / આટો',
    );
  }

  // 13. Biscuits & Bakery (બિસ્કિટ / પારલે / ટોસ્ટ / ખારી / બ્રેડ)
  if (lower.contains('બિસ્કિટ') ||
      lower.contains('biscuit') ||
      lower.contains('કૂકી') ||
      lower.contains('cookie') ||
      lower.contains('પારલે') ||
      lower.contains('ટોસ્ટ') ||
      lower.contains('ખારી') ||
      lower.contains('બ્રેડ')) {
    return const ProductVisualTheme(
      icon: Icons.cookie,
      iconColor: Color(0xFFB45309),
      gradientStart: Color(0xFFFEF3C7),
      gradientEnd: Color(0xFFFDE68A),
      borderColor: Color(0xFFD97706),
      shadowColor: Color(0xFFB45309),
      categoryLabel: 'બિસ્કિટ / બેકરી',
    );
  }

  // 14. Snacks & Farsan (વેફર / સેવ / ગાંઠિયા / ચેવડો / ખાખરા / નાસ્તો / પાપડ)
  if (lower.contains('વેફર') ||
      lower.contains('ચીપ્સ') ||
      lower.contains('chips') ||
      lower.contains('સેવ') ||
      lower.contains('ગાંઠિયા') ||
      lower.contains('ચેવડો') ||
      lower.contains('ખાખરા') ||
      lower.contains('પાપડ') ||
      lower.contains('નાસ્તો') ||
      lower.contains('ચવાણું') ||
      lower.contains('farsan') ||
      lower.contains('snacks')) {
    return const ProductVisualTheme(
      icon: Icons.fastfood,
      iconColor: Color(0xFFEA580C),
      gradientStart: Color(0xFFFFF7ED),
      gradientEnd: Color(0xFFFFEDD5),
      borderColor: Color(0xFFF97316),
      shadowColor: Color(0xFFEA580C),
      categoryLabel: 'નાસ્તો / ફરસાણ',
    );
  }

  // 15. Dry Fruits & Nuts (કાજુ / બદામ / કિસમિસ / અખરોટ / પિસ્તા / સીંગદાણા)
  if (lower.contains('કાજુ') ||
      lower.contains('બદામ') ||
      lower.contains('કિસમિસ') ||
      lower.contains('દ્રાક્ષ') ||
      lower.contains('અખરોટ') ||
      lower.contains('પિસ્તા') ||
      lower.contains('ડ્રાયફ્રૂટ') ||
      lower.contains('સીંગ') ||
      lower.contains('મગફળી') ||
      lower.contains('મખાના') ||
      lower.contains('ખજૂર') ||
      lower.contains('અંજીર') ||
      lower.contains('almond') ||
      lower.contains('cashew') ||
      lower.contains('peanut') ||
      lower.contains('dryfruit')) {
    return const ProductVisualTheme(
      icon: Icons.eco,
      iconColor: Color(0xFF78350F),
      gradientStart: Color(0xFFF5EBE1),
      gradientEnd: Color(0xFFE5D5C5),
      borderColor: Color(0xFFB45309),
      shadowColor: Color(0xFF78350F),
      categoryLabel: 'ડ્રાયફ્રૂટ્સ / સીંગ',
    );
  }

  // 16. Soaps & Cleaning (સાબુ / શેમ્પૂ / ડિટર્જન્ટ / સર્ફ / વીલ / વિમ)
  if (lower.contains('સાબુ') ||
      lower.contains('soap') ||
      lower.contains('શેમ્પૂ') ||
      lower.contains('shampoo')) {
    return const ProductVisualTheme(
      icon: Icons.soap,
      iconColor: Color(0xFF059669),
      gradientStart: Color(0xFFF0FDF4),
      gradientEnd: Color(0xFFDCFCE7),
      borderColor: Color(0xFF34D399),
      shadowColor: Color(0xFF059669),
      categoryLabel: 'સાબુ / પર્સનલ કેર',
    );
  }
  if (lower.contains('ડિટર્જન્ટ') ||
      lower.contains('વોશિંગ') ||
      lower.contains('detergent') ||
      lower.contains('સર્ફ') ||
      lower.contains('વીલ') ||
      lower.contains('વિમ') ||
      lower.contains('હાર્પિક') ||
      lower.contains('લાઈઝોલ') ||
      lower.contains('ક્લીનર') ||
      lower.contains('લિક્વિડ')) {
    return const ProductVisualTheme(
      icon: Icons.sanitizer,
      iconColor: Color(0xFF0284C7),
      gradientStart: Color(0xFFEFF6FF),
      gradientEnd: Color(0xFFDBEAFE),
      borderColor: Color(0xFF38BDF8),
      shadowColor: Color(0xFF0284C7),
      categoryLabel: 'ડિટર્જન્ટ / સફાઈ',
    );
  }

  // 17. Salt (મીઠું / નમક / સિંધવ)
  if (lower.contains('મીઠું') || lower.contains('નમક') || lower.contains('salt') || lower.contains('સિંધવ') || lower.contains('સંચળ')) {
    return const ProductVisualTheme(
      icon: Icons.blur_on,
      iconColor: Color(0xFF0284C7),
      gradientStart: Color(0xFFF0F9FF),
      gradientEnd: Color(0xFFE0F2FE),
      borderColor: Color(0xFF38BDF8),
      shadowColor: Color(0xFF0284C7),
      categoryLabel: 'મીઠું',
    );
  }

  // 18. Pooja Items (અગરબત્તી / ધૂપ / કપૂર / દીવો / દિવેટ / માચીસ)
  if (lower.contains('અગરબત્તી') ||
      lower.contains('ધૂપ') ||
      lower.contains('કપૂર') ||
      lower.contains('દીવો') ||
      lower.contains('દિવેટ') ||
      lower.contains('માચીસ') ||
      lower.contains('સિંદૂર') ||
      lower.contains('પૂજા')) {
    return const ProductVisualTheme(
      icon: Icons.auto_awesome,
      iconColor: Color(0xFFEA580C),
      gradientStart: Color(0xFFFFF7ED),
      gradientEnd: Color(0xFFFFEDD5),
      borderColor: Color(0xFFFB923C),
      shadowColor: Color(0xFFEA580C),
      categoryLabel: 'પૂજા સામગ્રી',
    );
  }

  // 19. Cold Drinks & Water (પાણી / શરબત / કોલ્ડ્રિંક / સોડા / જ્યુસ)
  if (lower.contains('પાણી') ||
      lower.contains('water') ||
      lower.contains('શરબત') ||
      lower.contains('કોલ્ડ્રિંક') ||
      lower.contains('સોડા') ||
      lower.contains('જ્યુસ')) {
    return const ProductVisualTheme(
      icon: Icons.sports_bar,
      iconColor: Color(0xFF0284C7),
      gradientStart: Color(0xFFF0FDF4),
      gradientEnd: Color(0xFFDCFCE7),
      borderColor: Color(0xFF38BDF8),
      shadowColor: Color(0xFF0284C7),
      categoryLabel: 'પીણાં / સોડા',
    );
  }

  // Default Kirana Grocery Provision Badge
  return const ProductVisualTheme(
    icon: Icons.storefront,
    iconColor: Color(0xFFD97706),
    gradientStart: Color(0xFFFFFBEB),
    gradientEnd: Color(0xFFFEF3C7),
    borderColor: Color(0xFFF59E0B),
    shadowColor: Color(0xFFD97706),
    categoryLabel: 'કરિયાણું',
  );
}

/// Helper that returns the visual IconData for product name.
IconData getProductVisualIcon(String name) {
  return getProductVisualTheme(name).icon;
}

/// Builds an authentic, reliable, guaranteed-to-render product badge widget.
Widget buildRealisticProductBadge(
  Product item, {
  double size = 44,
  bool showStockIndicator = true,
}) {
  final theme = getProductVisualTheme(item.nameGujarati);
  final isOutOfStock = item.stockQty <= 0;
  final isLowStock = !isOutOfStock && item.isLowStock;

  final indicatorColor = isOutOfStock
      ? const Color(0xFFDC2626)
      : (isLowStock ? const Color(0xFFD97706) : const Color(0xFF16A34A));

  return SizedBox(
    width: size,
    height: size,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        // Main realistic badge container
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.gradientStart,
                theme.gradientEnd,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.borderColor.withValues(alpha: 0.45),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.14),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
              const BoxShadow(
                color: Colors.white,
                blurRadius: 1,
                offset: Offset(-0.5, -0.5),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              theme.icon,
              size: size * 0.52,
              color: theme.iconColor,
            ),
          ),
        ),

        // Live stock status indicator dot on the badge
        if (showStockIndicator)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: indicatorColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: indicatorColor.withValues(alpha: 0.4),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
