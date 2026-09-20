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
      setState(() {
        _returns = rows;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('પાછું આપવાનો ઇતિહાસ'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHistory),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : _returns.isEmpty
          ? const Center(child: Text('No returns yet'))
          : ListView.builder(
              itemCount: _returns.length,
              itemBuilder: (context, index) {
                final r = _returns[index];
                return ListTile(
                  leading: const Icon(Icons.undo),
                  title: Text('Return #${r.id ?? ''}'),
                  subtitle: Text(
                    '${r.returnDate.substring(0, 10)} • ₹${r.totalReturnValue.toStringAsFixed(2)} • ${r.returnMode ?? ''}',
                  ),
                );
              },
            ),
    );
  }
}
