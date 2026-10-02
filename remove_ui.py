import sys

with open('lib/screens/duty_register_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
skip = False
for i, line in enumerate(lines):
    if 'if (!AppConfig.isKoyilandy) ...[' in line:
        skip = True
        continue
    if skip and '] else ...[' in line:
        skip = False
        continue
    if skip:
        continue
    new_lines.append(line)

with open('lib/screens/duty_register_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print('Done UI')
