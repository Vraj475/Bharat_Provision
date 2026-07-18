import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../../core/errors/error_logger.dart';
import '../../../core/errors/error_types.dart';
import '../../../shared/widgets/errors/error_dialogue.dart';
import '../../../data/providers.dart';

class BillingPrintService {
  final BlueThermalPrinter _bluePrinter = BlueThermalPrinter.instance;

  Future<void> attemptPrintSavedBill(
    BuildContext context,
    WidgetRef ref, {
    required int billId,
    required bool allowRetry,
    required GlobalKey desktopKey,
    required GlobalKey mobileKey,
    required VoidCallback onClearDraft,
  }) async {
    try {
      final billRepo = await ref.read(billRepositoryFutureProvider.future);

      final savedBill = await billRepo.getById(billId);
      final savedBillItems = await billRepo.getBillItems(billId);
      if (savedBill == null || savedBillItems.isEmpty) {
        throw StateError('PRINT_001');
      }

      final connected = await _bluePrinter.isConnected ?? false;
      if (!connected) {
        throw StateError('PRINT_001');
      }

      final billImageBytes = await captureBillImageBytes(desktopKey, mobileKey);
      if (billImageBytes == null) {
        throw StateError('PRINT_001');
      }

      await _bluePrinter.writeBytes(billImageBytes);
      if (!context.mounted) return;
      onClearDraft();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('બિલ પ્રિન્ટ થઈ રહ્યું છે.')),
      );
    } catch (error, stack) {
      final appError = AppError(
        code: 'PRINT_001',
        category: ErrorCategory.printing,
        technicalMessage: error.toString(),
        userMessage: 'પ્રિન્ટર સાથે જોડાણ નિષ્ફળ. કૃપા કરીને તપાસો કે પ્રિન્ટર ચાલુ છે.',
        isCritical: false,
        timestamp: DateTime.now(),
        stackTrace: stack,
      );
      await ErrorLogger.log(
        appError,
        currentScreen: 'BillingPrintService.attemptPrintSavedBill',
      );

      if (!context.mounted) return;

      if (!allowRetry) {
        onClearDraft();
        return;
      }

      ErrorDialogue.showSnackbar(
        context,
        message: 'પ્રિન્ટર સાથે જોડાણ નિષ્ફળ. કૃપા કરીને તપાસો કે પ્રિન્ટર ચાલુ છે.',
        code: 'PRINT_001',
        type: ErrorDialogueType.error,
        retryCallback: () {
          attemptPrintSavedBill(
            context,
            ref,
            billId: billId,
            allowRetry: false,
            desktopKey: desktopKey,
            mobileKey: mobileKey,
            onClearDraft: onClearDraft,
          );
        },
      );
    }
  }

  Future<Uint8List?> captureBillImageBytes(
    GlobalKey desktopKey,
    GlobalKey mobileKey,
  ) async {
    final boundary =
        (desktopKey.currentContext?.findRenderObject() as RenderRepaintBoundary?) ??
        (mobileKey.currentContext?.findRenderObject() as RenderRepaintBoundary?);
    
    if (boundary == null || !boundary.attached) return null;

    final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}
