import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

// Models for transliteration
class TransliterationEntry {
  final String phoneticKey;
  final String gujaratiText;
  final bool isBuiltIn;

  TransliterationEntry({
    required this.phoneticKey,
    required this.gujaratiText,
    this.isBuiltIn = false,
  });

  TransliterationEntry copyWith({
    String? phoneticKey,
    String? gujaratiText,
    bool? isBuiltIn,
  }) {
    return TransliterationEntry(
      phoneticKey: phoneticKey ?? this.phoneticKey,
      gujaratiText: gujaratiText ?? this.gujaratiText,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }
}

class TransliterationDictionaryScreen extends ConsumerStatefulWidget {
  const TransliterationDictionaryScreen({super.key});

  @override
  ConsumerState<TransliterationDictionaryScreen> createState() =>
      _TransliterationDictionaryScreenState();
}

class _TransliterationDictionaryScreenState
    extends ConsumerState<TransliterationDictionaryScreen> {
  final List<TransliterationEntry> _entries = [
    // Built-in entries (examples)
    TransliterationEntry(
      phoneticKey: 'bhaji',
      gujaratiText: 'ભાજી',
      isBuiltIn: true,
    ),
    TransliterationEntry(
      phoneticKey: 'dal',
      gujaratiText: 'દાળ',
      isBuiltIn: true,
    ),
    TransliterationEntry(
      phoneticKey: 'tameta',
      gujaratiText: 'ટમેટા',
      isBuiltIn: true,
    ),
    TransliterationEntry(
      phoneticKey: 'piyaz',
      gujaratiText: 'પ્યાજ',
      isBuiltIn: true,
    ),
  ];

  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final filteredEntries = _entries
        .where(
          (entry) =>
              entry.phoneticKey.contains(_searchQuery) ||
              entry.gujaratiText.contains(_searchQuery),
        )
        .toList();

    // Check access - only Admin and Superadmin
    if (session == null ||
        (session.role != 'admin' && session.role != 'superadmin')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Text('Only Admin and Superadmin can access this'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transliteration Dictionary'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search entries',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          // Entries list
          Expanded(
            child: filteredEntries.isEmpty
                ? const Center(child: Text('No entries found'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredEntries.length,
                    itemBuilder: (context, index) {
                      final entry = filteredEntries[index];
                      return _TransliterationEntryTile(
                        entry: entry,
                        onEdit: () {
                          if (!entry.isBuiltIn) {
                            _showEditDialog(entry);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Built-in entries cannot be edited',
                                ),
                              ),
                            );
                          }
                        },
                        onDelete: () {
                          if (!entry.isBuiltIn) {
                            _showDeleteConfirmation(entry);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cannot delete built-in entries'),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Custom Entry'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    onPressed: _showResetConfirmation,
                    child: const Text('Reset Custom Entries'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddEditEntryDialog(
        onSave: (phoneticKey, gujaratiText) {
          setState(() {
            _entries.add(
              TransliterationEntry(
                phoneticKey: phoneticKey,
                gujaratiText: gujaratiText,
                isBuiltIn: false,
              ),
            );
          });
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$phoneticKey" → "$gujaratiText" added')),
          );
        },
      ),
    );
  }

  void _showEditDialog(TransliterationEntry entry) {
    showDialog(
      context: context,
      builder: (context) => _AddEditEntryDialog(
        initialPhoneticKey: entry.phoneticKey,
        initialGujaratiText: entry.gujaratiText,
        isEdit: true,
        onSave: (phoneticKey, gujaratiText) {
          setState(() {
            final index = _entries.indexOf(entry);
            _entries[index] = entry.copyWith(
              phoneticKey: phoneticKey,
              gujaratiText: gujaratiText,
            );
          });
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$phoneticKey" → "$gujaratiText" updated')),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(TransliterationEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text(
          'Delete "${entry.phoneticKey}" → "${entry.gujaratiText}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _entries.remove(entry);
              });
              context.pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"${entry.phoneticKey}" deleted')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Custom Entries?'),
        content: const Text(
          'This will remove all custom entries. Built-in entries will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _entries.removeWhere((entry) => !entry.isBuiltIn);
              });
              context.pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Custom entries removed')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _TransliterationEntryTile extends StatelessWidget {
  final TransliterationEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TransliterationEntryTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        title: Text(entry.gujaratiText),
        subtitle: Text(
          '"${entry.phoneticKey}"${entry.isBuiltIn ? ' (Built-in)' : ' (Custom)'}',
        ),
        trailing: entry.isBuiltIn
            ? Tooltip(
                message: 'Built-in entry - cannot be modified',
                child: Icon(Icons.lock, color: Colors.grey[600]),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: onDelete,
                  ),
                ],
              ),
      ),
    );
  }
}

class _AddEditEntryDialog extends StatefulWidget {
  final String? initialPhoneticKey;
  final String? initialGujaratiText;
  final bool isEdit;
  final Function(String, String) onSave;

  const _AddEditEntryDialog({
    this.initialPhoneticKey,
    this.initialGujaratiText,
    this.isEdit = false,
    required this.onSave,
  });

  @override
  State<_AddEditEntryDialog> createState() => _AddEditEntryDialogState();
}

class _AddEditEntryDialogState extends State<_AddEditEntryDialog> {
  late TextEditingController _phoneticController;
  late TextEditingController _gujaratiController;

  @override
  void initState() {
    super.initState();
    _phoneticController = TextEditingController(
      text: widget.initialPhoneticKey ?? '',
    );
    _gujaratiController = TextEditingController(
      text: widget.initialGujaratiText ?? '',
    );
  }

  @override
  void dispose() {
    _phoneticController.dispose();
    _gujaratiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEdit ? 'Edit Entry' : 'Add Custom Entry'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _phoneticController,
              decoration: const InputDecoration(
                labelText: 'Phonetic Key',
                hintText: 'e.g., kothmir',
                border: OutlineInputBorder(),
              ),
              enabled: !widget.isEdit,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _gujaratiController,
              decoration: const InputDecoration(
                labelText: 'Gujarati Text',
                hintText: 'e.g., કોથમીર',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_phoneticController.text.isEmpty ||
                _gujaratiController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please fill all fields')),
              );
              return;
            }

            widget.onSave(_phoneticController.text, _gujaratiController.text);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
