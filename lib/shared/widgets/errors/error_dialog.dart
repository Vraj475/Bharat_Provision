import 'package:flutter/material.dart';
import '../../../core/errors/error_types.dart';

class ErrorDialog {
  static Future<void> show(
    BuildContext context,
    AppError error, {
    String? shopName,
    String? developerPhone,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('⚠ સમસ્યા આવી'),
          content: Text(error.userMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ઠીક છે'),
            ),
          ],
        );
      },
    );
  }
}
