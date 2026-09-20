import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../errors/error_handler.dart';

class BackupService {
  final DatabaseHelper _dbHelper;

  BackupService([DatabaseHelper? dbHelper])
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Exports the current database and saves it as a JSON file.
  /// Returns the path to the saved file if successful, or null if it failed.
  Future<String?> createBackup() async {
    try {
      final db = await _dbHelper.database;
      final jsonStr = await DatabaseHelper.instance.exportToJson(db);
      
      final dir = await getApplicationDocumentsDirectory();

      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = p.join(dir.path, 'KiranaBackup_$stamp.json');
      
      final file = File(path);
      await file.writeAsString(jsonStr);
      
      if (kDebugMode) {
        debugPrint('Backup saved to $path');
      }
      return path;
    } catch (e, st) {
      ErrorHandler.handleSilently(e, st, context: 'BackupService.createBackup');
      return null;
    }
  }

  /// Prompts the user to pick a backup file and restores the database from it.
  /// Throws an exception if something goes wrong.
  Future<void> restoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      
      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null) {
        throw Exception('File path is null');
      }

      final file = File(path);
      final jsonStr = await file.readAsString();
      
      final db = await _dbHelper.database;
      await DatabaseHelper.instance.importFromJson(db, jsonStr);
      
      if (kDebugMode) {
        debugPrint('Backup restored successfully from $path');
      }
    } catch (e, st) {
      throw ErrorHandler.handle(e, st, context: 'BackupService.restoreBackup');
    }
  }
}
