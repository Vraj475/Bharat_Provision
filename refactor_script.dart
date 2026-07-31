import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    var content = file.readAsStringSync();
    final original = content;
    
    // 1. Rename Provider
    content = content.replaceAll('RepositoryFutureProvider.future', 'RepositoryProvider');
    content = content.replaceAll('RepositoryFutureProvider', 'RepositoryProvider');
    
    // 2. Remove await for RepositoryProvider
    content = content.replaceAllMapped(RegExp(r'await\s+(ref\.read\s*\(\s*[a-zA-Z0-9_]+RepositoryProvider\s*\))'), (m) => m.group(1)!);
    content = content.replaceAllMapped(RegExp(r'await\s+(ref\.watch\s*\(\s*[a-zA-Z0-9_]+RepositoryProvider\s*\))'), (m) => m.group(1)!);
    
    // Check if there are any remaining `await ... RepositoryProvider`
    // e.g. await ref.read(
    //          xxxRepositoryProvider
    //      )
    content = content.replaceAllMapped(RegExp(r'await\s+(ref\.(?:read|watch)\s*\(\s*[a-zA-Z0-9_]+RepositoryProvider\s*\))', multiLine: true), (m) => m.group(1)!);
    
    if (content != original) {
      file.writeAsStringSync(content);
      print('Updated: \${file.path}');
    }
  }
}
