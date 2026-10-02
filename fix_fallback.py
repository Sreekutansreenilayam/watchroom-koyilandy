import sys

with open('lib/screens/duty_register_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    if i == 1674: # line 1675 (0-indexed 1674)
        new_lines.append(line)
        new_lines.append("       if (khgTorch.isEmpty) { String p = getBalancedDriverList([khg9874, khgMist]); if(p.isNotEmpty) khgTorch.add(p); }\n")
        continue
    new_lines.append(line)

with open('lib/screens/duty_register_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print('Done fallback')
