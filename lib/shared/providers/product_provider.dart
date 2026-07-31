import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:string_similarity/string_similarity.dart';

import '../../core/database/database_helper.dart';
import '../../core/errors/error_handler.dart';
import '../models/product_model.dart';

final productProvider = AsyncNotifierProvider<ProductProvider, List<Product>>(() {
  return ProductProvider();
});

class ProductProvider extends AsyncNotifier<List<Product>> {
  DatabaseHelper get _dbHelper => DatabaseHelper.instance;

  @override
  FutureOr<List<Product>> build() {
    return _fetchAllProducts();
  }

  Future<List<Product>> _fetchAllProducts() async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'products',
        where: 'is_active = 1',
        orderBy: 'name_gujarati COLLATE NOCASE',
      );
      return rows
          .map<Product>((m) => Product.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      throw ErrorHandler.handle(
        e,
        st,
        context: 'ProductProvider.loadAllProducts',
      );
    }
  }

  Future<void> loadAllProducts() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchAllProducts());
  }

  Future<void> addProduct(Product product) async {
    try {
      await _dbHelper.runInTransaction((txn) async {
        final now = DateTime.now().toIso8601String();
        final productMap = {
          ...product.toMap(),
          'created_at': product.createdAt ?? now,
          'updated_at': product.updatedAt ?? now,
          'transliteration_keys': _normalizeTranslit(
            product.transliterationKeys,
          ),
        };

        final id = await txn.insert('products', productMap);

        if (product.stockQty > 0) {
          final before = 0.0;
          final after = product.stockQty;
          await txn.insert('stock_log', {
            'product_id': id,
            'transaction_type': 'purchase',
            'qty_change': product.stockQty,
            'qty_before': before,
            'qty_after': after,
            'reference_id': null,
            'reference_type': 'manual',
            'note': null,
            'created_at': now,
          });
        }
      });
      ref.invalidateSelf();
    } catch (e, st) {
      throw ErrorHandler.handle(
        e,
        st,
        context: 'ProductProvider.addProduct',
      );
    }
  }

  Future<void> updateProduct(Product product) async {
    if (product.id == null) return;
    try {
      await _dbHelper.runInTransaction((txn) async {
        final now = DateTime.now().toIso8601String();
        await txn.update(
          'products',
          {
            ...product.toMap(),
            'updated_at': now,
            'transliteration_keys': _normalizeTranslit(
              product.transliterationKeys,
            ),
          },
          where: 'id = ?',
          whereArgs: [product.id],
        );
      });
      ref.invalidateSelf();
    } catch (e, st) {
      throw ErrorHandler.handle(
        e,
        st,
        context: 'ProductProvider.updateProduct',
      );
    }
  }

  Future<void> deleteProduct(Product product) async {
    if (product.id == null) return;
    try {
      await _dbHelper.runInTransaction((txn) async {
        await txn.delete('products', where: 'id = ?', whereArgs: [product.id]);
      });
      ref.invalidateSelf();
    } catch (e, st) {
      throw ErrorHandler.handle(
        e,
        st,
        context: 'ProductProvider.deleteProduct',
      );
    }
  }

  Future<void> searchProducts(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      await loadAllProducts();
      return;
    }
    
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        final db = await _dbHelper.database;
        final like = '%$q%';

        final rows = await db.rawQuery(
          '''
          SELECT DISTINCT p.*
          FROM products p
          LEFT JOIN transliteration_dictionary t
            ON t.gujarati_text = p.name_gujarati
          WHERE p.is_active = 1
            AND (
              p.name_gujarati LIKE ? OR
              p.name_english LIKE ? OR
              CAST(p.sell_price AS TEXT) LIKE ? OR
              p.transliteration_keys LIKE ? OR
              t.phonetic_key LIKE ?
            )
        ''',
          [like, like, like, like, like],
        );

        final products = rows
            .map<Product>((m) => Product.fromMap(m as Map<String, dynamic>))
            .toList();

        // Fuzzy ranking
        final queryLower = q.toLowerCase();
        products.sort((a, b) {
          final aKey = _bestSearchKey(a).toLowerCase();
          final bKey = _bestSearchKey(b).toLowerCase();

          int rank(String key) {
            if (key == queryLower) return 0;
            if (key.startsWith(queryLower)) return 1;
            if (key.contains(queryLower)) return 2;
            final score = StringSimilarity.compareTwoStrings(key, queryLower);
            return score > 0.6 ? 3 : 4;
          }

          final ra = rank(aKey);
          final rb = rank(bKey);
          if (ra != rb) return ra.compareTo(rb);
          return a.nameGujarati.compareTo(b.nameGujarati);
        });

        return products;
      } catch (e, st) {
        throw ErrorHandler.handle(
          e,
          st,
          context: 'ProductProvider.searchProducts',
        );
      }
    });
  }

  Future<List<Product>> getLowStockProducts() async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.rawQuery('''
        SELECT * FROM products
        WHERE is_active = 1
          AND stock_qty <= min_stock_qty
      ''');
      return rows
          .map<Product>((m) => Product.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      ErrorHandler.handleSilently(
        e,
        st,
        context: 'ProductProvider.getLowStockProducts',
      );
      return [];
    }
  }

  String _normalizeTranslit(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return jsonEncode(<String>[]);
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        final list = decoded.map((e) => e.toString()).toList();
        return jsonEncode(list);
      }
    } catch (_) {}

    final parts = trimmed
        .split(RegExp(r'[\s,]+'))
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    return jsonEncode(parts);
  }

  String _bestSearchKey(Product p) {
    // Prefer transliteration keys (flattened) for fuzzy ranking; fallback to Gujarati name.
    final raw = p.transliterationKeys.trim();
    if (raw.isEmpty) return p.nameGujarati;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).join(' ');
      }
    } catch (_) {}
    return raw;
  }
}
