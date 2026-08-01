import os
import glob
import re

def find_matching_paren(text, start_idx):
    count = 0
    for i in range(start_idx, len(text)):
        if text[i] == '(':
            count += 1
        elif text[i] == ')':
            count -= 1
            if count == 0:
                return i
    return -1

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content
    modified = False

    # Regex to find print( or debugPrint(
    # We want to match exactly those function names, not part of another word (e.g., myprint)
    # Also we want to capture what precedes it to check if it's already wrapped
    
    # We will iterate and find all indices
    import re
    # Find all "print(" and "debugPrint("
    # Using regex to find word boundaries
    pattern = re.compile(r'\b(print|debugPrint)\s*\(')
    
    # We must process from right to left (bottom to top) to not mess up indices
    matches = list(pattern.finditer(content))
    matches.reverse()

    for match in matches:
        func_name = match.group(1)
        start_idx = match.start()
        paren_start_idx = content.find('(', start_idx)
        
        # Check if it's already wrapped in if (kDebugMode)
        # Look at the text before start_idx
        text_before = content[:start_idx].rstrip()
        
        # If it's already inside an if (kDebugMode) block, the preceding text might end with
        # "if (kDebugMode)" or "if (kDebugMode) {" or it might be deeply nested.
        # A simple check: if the preceding non-whitespace text is "if (kDebugMode)" or "if (kDebugMode) {"
        # Actually, it's safer to just check if "if (kDebugMode)" is on the same line or the previous line
        # But even simpler: check if the string "if (kDebugMode)" appears right before.
        # Let's just look at the last 20-30 characters before the print statement
        
        if text_before.endswith('if (kDebugMode)') or text_before.endswith('if (kDebugMode) {') or text_before.endswith('if(kDebugMode)') or text_before.endswith('if(kDebugMode){'):
            # Already wrapped, but we might still need to change print to debugPrint
            if func_name == 'print':
                end_idx = find_matching_paren(content, paren_start_idx)
                if end_idx != -1:
                    content = content[:start_idx] + 'debugPrint' + content[start_idx+5:]
                    modified = True
            continue

        # Find the end of the statement (the closing parenthesis and the semicolon)
        end_idx = find_matching_paren(content, paren_start_idx)
        if end_idx == -1:
            continue # Malformed or couldn't find matching paren

        # Find the semicolon after the closing paren
        semicolon_idx = content.find(';', end_idx)
        if semicolon_idx == -1:
            # If no semicolon, it might be in an expression. Wrapping it in an if statement would break it.
            # Example: true ? print('a') : print('b'); -> this would break if we blindly wrap.
            # However, most debugPrint/print are statements.
            # Let's check if there's a semicolon right after (ignoring whitespace)
            remaining = content[end_idx+1:]
            if remaining.lstrip().startswith(';'):
                semicolon_idx = end_idx + 1 + remaining.find(';')
            else:
                print(f"Skipping {func_name} in {filepath} (no trailing semicolon found, might be an expression)")
                # If it's a 'print' without semicolon, we at least change it to debugPrint
                if func_name == 'print':
                    content = content[:start_idx] + 'debugPrint' + content[start_idx+5:]
                    modified = True
                continue

        statement = content[start_idx:semicolon_idx+1]
        
        # Replace print with debugPrint if needed
        if statement.startswith('print'):
            statement = 'debugPrint' + statement[5:]

        # Create the replacement
        replacement = f"if (kDebugMode) {{\n      {statement}\n    }}"
        
        # But wait, what if it's inline like `() => print('hello')`?
        # If we replace it with `if (kDebugMode) { debugPrint('hello'); }`, it might need to be wrapped in braces for the closure.
        # `() => if (kDebugMode) { ... }` is invalid Dart.
        # Dart closures require `() { if (kDebugMode) { ... } }`
        
        # A safer replacement for expressions is `if (kDebugMode) debugPrint(...)` but wait, `if` is a statement.
        # If it's an arrow function: `() => print(...)`, changing to `() => { if (kDebugMode) debugPrint(...) }` is wrong syntax in Dart.
        # Better replacement: just change `print(...)` to `debugPrint(...)` and leave `if (kDebugMode)` wrapping to human if it's complex.
        
        # Let's check what precedes the start_idx. If it's `=>`, we can't just drop an `if` statement.
        if text_before.endswith('=>'):
            print(f"Skipping wrap for arrow function in {filepath}")
            if func_name == 'print':
                content = content[:start_idx] + 'debugPrint' + content[start_idx+5:]
                modified = True
            continue
            
        # Get indentation of the line
        last_newline = content.rfind('\n', 0, start_idx)
        indent = ""
        if last_newline != -1:
            line_start = content[last_newline+1:start_idx]
            if not line_start.strip():
                indent = line_start
        
        # If statement already ends with semicolon
        replacement = f"if (kDebugMode) {{\n{indent}  {statement}\n{indent}}}"
        
        # Edge case: if we are inside a single-line if statement: `if (condition) print('x');`
        # This will become `if (condition) if (kDebugMode) { debugPrint('x'); }` which is valid.

        content = content[:start_idx] + replacement + content[semicolon_idx+1:]
        modified = True

    if modified:
        # Check if flutter/foundation.dart is imported
        if 'package:flutter/foundation.dart' not in content:
            # Find the last import
            last_import = content.rfind('import ')
            if last_import != -1:
                end_of_last_import = content.find('\n', last_import)
                if end_of_last_import == -1:
                    end_of_last_import = len(content)
                content = content[:end_of_last_import] + "\nimport 'package:flutter/foundation.dart';" + content[end_of_last_import:]
            else:
                # No imports, add to top
                content = "import 'package:flutter/foundation.dart';\n" + content
                
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {filepath}")

for filepath in glob.glob('lib/**/*.dart', recursive=True):
    process_file(filepath)

print("Done.")
