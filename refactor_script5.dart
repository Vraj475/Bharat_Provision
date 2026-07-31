import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    var content = file.readAsStringSync();
    final original = content;
    
    // The broken string is `ref.\${m.group(1)}(\${m.group(2)})` literally!
    // In dart string literal, we write it as:
    final brokenString = r'ref.${m.group(1)}(${m.group(2)})';
    
    content = content.replaceAll(brokenString, 'ref.read(settingsRepositoryProvider)');
    
    // Let's also remove `await ` before `ref.read(settingsRepositoryProvider)` if it exists.
    content = content.replaceAll('await ref.read(settingsRepositoryProvider)', 'ref.read(settingsRepositoryProvider)');
    
    if (content != original) {
      file.writeAsStringSync(content);
      print('Updated: \${file.path}');
    }
  }
}
