import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../shared/models/customer_model.dart';
import 'udhaar_providers.dart';
import 'package:go_router/go_router.dart';

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
        // International format: 91 prefix for India
        final fullPhone = phone.length == 10 ? '91$phone' : phone;
        urlStr = 'https://wa.me/$fullPhone?text=$encoded';
      } else {
        // sms:
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
        // Log the reminder
        await ref
            .read(udhaarRepositoryProvider)
            .logReminder(
              widget.customer.id!,
              reminderType,
              widget.customer.totalOutstanding,
            );

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

                if (!hasAnyEnabled) ...[
                  const Text(
                    'Settings → Reminder Whatsapp / SMS ચાલુ કરો',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  // Type toggle chips
                  Wrap(
                    spacing: 8,
                    children: [
                      if (whatsappEnabled)
                        ChoiceChip(
                          label: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat, size: 16),
                              SizedBox(width: 4),
                              Text('WhatsApp'),
                            ],
                          ),
                          selected: _activeType == 'whatsapp',
                          selectedColor: const Color(0xFF25D366),
                          labelStyle: TextStyle(
                            color: _activeType == 'whatsapp'
                                ? Colors.white
                                : null,
                          ),
                          onSelected: (_) {
                            setState(() {
                              _activeType = 'whatsapp';
                              _messageCtrl.text = _buildWhatsAppMessage(
                                shopName,
                              );
                            });
                          },
                        ),
                      if (smsEnabled)
                        ChoiceChip(
                          label: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sms, size: 16),
                              SizedBox(width: 4),
                              Text('SMS'),
                            ],
                          ),
                          selected: _activeType == 'sms',
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: _activeType == 'sms' ? Colors.white : null,
                          ),
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
                  // Message preview / edit
                  Text('સંદેશ', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _messageCtrl
                      ..text = _messageCtrl.text.isEmpty
                          ? message
                          : _messageCtrl.text,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Send button
                  ElevatedButton.icon(
                    onPressed: _sending
                        ? null
                        : () => _send(_activeType, _messageCtrl.text, settings),
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
                            _activeType == 'whatsapp' ? Icons.chat : Icons.sms,
                            color: Colors.white,
                          ),
                    label: Text(
                      _activeType == 'whatsapp' ? 'WhatsApp ખોલો' : 'SMS ખોલો',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _activeType == 'whatsapp'
                          ? const Color(0xFF25D366)
                          : AppColors.primary,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) =>
          Padding(padding: const EdgeInsets.all(20), child: Text('ભૂલ: $e')),
    );
  }
}
