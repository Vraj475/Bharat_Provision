import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../shared/models/customer_model.dart';
import 'udhaar_providers.dart';

/// Bottom sheet for sending WhatsApp / SMS reminders to a customer.
/// Only shows reminder types that are enabled in settings.
class ReminderBottomSheet extends ConsumerStatefulWidget {
  const ReminderBottomSheet({
    super.key,
    required this.customer,
    this.initialTab,
  });
  final Customer customer;

  /// 'whatsapp' | 'sms' | null — which tab to open by default
  final String? initialTab;

  @override
  ConsumerState<ReminderBottomSheet> createState() =>
      _ReminderBottomSheetState();
}

class _ReminderBottomSheetState extends ConsumerState<ReminderBottomSheet> {
  late final TextEditingController _messageCtrl;
  bool _sending = false;
  String _activeType = 'whatsapp'; // default; overridden in build

  // Templates
  String _buildWhatsAppMessage(String shopName) {
    final balance = formatCurrency(widget.customer.totalOutstanding);
    final name = widget.customer.nameGujarati;
    return 'નમસ્તે $name 🙏\n\n*$shopName*\nતમારો બાકી હિસાબ:\n\n💰 કુલ બાકી: *$balance*\n\nકૃપા ચૂકવણી કરો.\nઆભાર 🙏';
  }

  String _buildSmsMessage(String shopName) {
    final balance = formatCurrency(widget.customer.totalOutstanding);
    final name = widget.customer.nameGujarati;
    return 'નમસ્તે $name, $shopName - બાકી: $balance. કૃપા ચૂકવો.';
  }

  @override
  void initState() {
    super.initState();
    _messageCtrl = TextEditingController();
    if (widget.initialTab != null) {
      _activeType = widget.initialTab!;
    }
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(
    String reminderType,
    String message,
    Map<String, String> settings,
  ) async {
    if (_sending) return;
    final phone = (widget.customer.phone ?? '').replaceAll(RegExp(r'\D'), '');

    if (phone.isEmpty && reminderType != 'pdf') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ગ્રાહકનો ફોન નંબર ઉમેરો')),
        );
      }
      return;
    }

    setState(() => _sending = true);
    try {
      String urlStr;
      if (reminderType == 'whatsapp') {
        final encoded = Uri.encodeComponent(message);
        final fullPhone = phone.length == 10 ? '91$phone' : phone;
        urlStr = 'https://wa.me/$fullPhone?text=$encoded';
      } else {
        final encoded = Uri.encodeComponent(message);
        urlStr = 'sms:+91$phone?body=$encoded';
      }

      final uri = Uri.parse(urlStr);
      bool launched = false;
      if (await canLaunchUrl(uri)) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      if (!mounted) return;

      if (launched) {
        // Log the reminder with null guard
        if (widget.customer.id != null) {
          await ref
              .read(udhaarRepositoryProvider)
              .logReminder(
                widget.customer.id!,
                reminderType,
                widget.customer.totalOutstanding,
              );
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              reminderType == 'whatsapp' ? 'WhatsApp ખોલ્યું' : 'SMS ખોલ્યું',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp / SMS ઉઘ્ડ્યું નહીં')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ભૂલ: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(udhaarSettingsProvider);

    return settingsAsync.when(
      data: (settings) {
        final shopName = settings['shop_name']?.isEmpty ?? true
            ? 'દુકાન'
            : settings['shop_name']!;
        final whatsappEnabled = settings['reminder_whatsapp'] == 'true';
        final smsEnabled = settings['reminder_sms'] == 'true';
        final hasAnyEnabled = whatsappEnabled || smsEnabled;

        // Default active type to first enabled
        if (whatsappEnabled && _activeType == 'whatsapp') {
          // already default
        } else if (!whatsappEnabled &&
            smsEnabled &&
            _activeType == 'whatsapp') {
          _activeType = 'sms';
        }

        // Build message based on active type
        final message = _activeType == 'whatsapp'
            ? _buildWhatsAppMessage(shopName)
            : _buildSmsMessage(shopName);

        // Sync controller if empty
        if (_messageCtrl.text.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_messageCtrl.text.isEmpty) {
              _messageCtrl.text = message;
            }
          });
        }

        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Header
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.customer.nameGujarati} — ${formatCurrency(widget.customer.totalOutstanding)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (!hasAnyEnabled)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Text(
                      'રિમાઇન્ડર મોકલો તે માટે સેટિંગ્સમાંથી WhatsApp અથવા SMS શરૂ કરો.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  )
                else ...[
                  // Type selection chips
                  Row(
                    children: [
                      if (whatsappEnabled)
                        ChoiceChip(
                          label: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 16,
                                color: Colors.green,
                              ),
                              SizedBox(width: 4),
                              Text('WhatsApp'),
                            ],
                          ),
                          selected: _activeType == 'whatsapp',
                          onSelected: (_) {
                            setState(() {
                              _activeType = 'whatsapp';
                              _messageCtrl.text =
                                  _buildWhatsAppMessage(shopName);
                            });
                          },
                        ),
                      if (whatsappEnabled && smsEnabled)
                        const SizedBox(width: 8),
                      if (smsEnabled)
                        ChoiceChip(
                          label: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sms_outlined,
                                size: 16,
                                color: Colors.blue,
                              ),
                              SizedBox(width: 4),
                              Text('SMS'),
                            ],
                          ),
                          selected: _activeType == 'sms',
                          onSelected: (_) {
                            setState(() {
                              _activeType = 'sms';
                              _messageCtrl.text = _buildSmsMessage(shopName);
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Message editable box
                  TextField(
                    controller: _messageCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'મેસેજ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Send button
                  ElevatedButton.icon(
                    onPressed: _sending
                        ? null
                        : () => _send(_activeType, _messageCtrl.text, settings),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _activeType == 'whatsapp'
                          ? Colors.green
                          : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _activeType == 'whatsapp'
                                ? Icons.chat
                                : Icons.send,
                          ),
                    label: Text(
                      _sending
                          ? 'મોકલી રહ્યા છે...'
                          : _activeType == 'whatsapp'
                              ? 'WhatsApp પર મોકલો'
                              : 'SMS પર મોકલો',
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) =>
          Padding(padding: const EdgeInsets.all(20), child: Text('ભૂલ: $e')),
    );
  }
}
