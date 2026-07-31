import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    var content = file.readAsStringSync();
    final original = content;
    
    // Fix databaseProvider.future
    content = content.replaceAll(RegExp(r'await\s+(ref\.read\s*\(\s*databaseProvider\.future\s*\))'), 'ref.read(databaseProvider)');
    content = content.replaceAll(RegExp(r'await\s+(ref\.watch\s*\(\s*databaseProvider\.future\s*\))'), 'ref.watch(databaseProvider)');
    // If it didn't have await, just replace the .future
    content = content.replaceAll('databaseProvider.future', 'databaseProvider');

    // Fix missed await ref.read(xxxRepositoryProvider) cases 
    // They might be spread across lines or my previous regex missed them because it didn't catch multiline whitespace correctly in dart (needed `multiLine: true` or `\s+` vs `\s*`).
    // In Dart RegExp, `\s` includes newlines.
    
    // We want to replace `await <space or newline> ref.read(...)` where `...` evaluates to a RepositoryProvider.
    // Instead of complex regex, let's just do a simpler search and replace for the specific providers.
    
    final providers = [
      'itemRepositoryProvider',
      'billRepositoryProvider',
      'customerRepositoryProvider',
      'khataRepositoryProvider',
      'reportRepositoryProvider',
      'settingsRepositoryProvider',
      'userRepositoryProvider',
      'expenseRepositoryProvider',
    ];
    
    for (final p in providers) {
      // Find `await ref.read(p)`
      content = content.replaceAll(RegExp('await\\\\s+ref\\\\.read\\\\(\\\\s*'+p+'\\\\s*\\\\)'), 'ref.read('+p+')');
      // Find `await ref.watch(p)`
      content = content.replaceAll(RegExp('await\\\\s+ref\\\\.watch\\\\(\\\\s*'+p+'\\\\s*\\\\)'), 'ref.watch('+p+')');
      // Fix instances where await is just before a variable that holds the repo
      // like `final repo = await ref.read(settingsRepositoryProvider);`
      content = content.replaceAll('await ref.read('+p+')', 'ref.read('+p+')');
      content = content.replaceAll('await ref.watch('+p+')', 'ref.watch('+p+')');
    }
    
    // Fix `.then` on reportRepositoryProvider (e.g. `ref.read(reportRepositoryProvider).then((repo) => ...)`
    // This is in `reports_home_screen.dart`
    // Actually, `ref.read(reportRepositoryProvider).then((repo) { ... })` becomes `final repo = ref.read(reportRepositoryProvider); { ... }` but that requires syntax tree awareness.
    // Let's just fix `reports_home_screen.dart` manually later if needed.
    
    if (content != original) {
      file.writeAsStringSync(content);
      print('Updated: \${file.path}');
    }
  }
}
