import 'package:flutter/material.dart';

import '../localization/app_strings.dart';

/// Confirmation dialog before delete or irreversible actions
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = AppStrings.deleteConfirm,
    this.cancelLabel = AppStrings.cancelButton,
    this.isDestructive = true,
    this.onConfirm,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final VoidCallback? onConfirm;

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = AppStrings.deleteConfirm,
    String cancelLabel = AppStrings.cancelButton,
    bool isDestructive = true,
    VoidCallback? onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(false);
            }
          },
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          onPressed: () {
            onConfirm?.call();
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(true);
            }
          },
          style: isDestructive
              ? ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
