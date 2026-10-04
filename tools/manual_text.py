"""Pull the field manual's text out of scripts/manual.gd as plain text, for a
blind playtester that must not see the code.

    python3 tools/manual_text.py > manual.txt
"""
import os, re

src = open(os.path.join(os.path.dirname(__file__), '..', 'scripts', 'manual.gd')).read()
body = src[src.index('const TABS'):src.index('const ROWS')]
print('FIELD MANUAL  (in game: F1 opens it, F1 or Esc closes it)\n')
for line in body.splitlines():
    tab = re.match(r'\s*\["([^"]+)", \[$', line)
    if tab:
        print('\n=== %s ===' % tab.group(1))
        continue
    row = re.match(r'\s*\["([^"]*)", "([^"]*)", "([^"]*)"\],?$', line)
    if not row:
        continue
    key, name, desc = row.groups()
    if key == '#':
        print('\n-- %s --' % name)
    else:
        print('%-6s %s: %s' % ('[%s]' % key if key else '', name, desc))
