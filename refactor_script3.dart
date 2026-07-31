import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    var content = file.readAsStringSync();
    final original = content;
    
    // Replace multiline variants:
    // await ref.read(
    //   settingsRepositoryProvider,
    // )
    final p1 = RegExp(r'await\s+ref\.(read|watch)\(\s*([a-zA-Z0-9_]+RepositoryProvider)\s*,\s*\)');
    content = content.replaceAllMapped(p1, (m) => 'ref.\${m.group(1)}(\${m.group(2)})');
    
    final p2 = RegExp(r'await\s+ref\.(read|watch)\(\s*([a-zA-Z0-9_]+RepositoryProvider)\s*\)');
    content = content.replaceAllMapped(p2, (m) => 'ref.\${m.group(1)}(\${m.group(2)})');

    if (content != original) {
      file.writeAsStringSync(content);
      print('Updated: \${file.path}');
    }
  }
}
