import sys

with open('lib/screens/duty_register_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    if i == 1800:
        continue # skip "         }"
    if i == 1801:
        new_lines.append("         } else if (vName.contains('Torch')) {\n")
        continue
    if i == 1802:
        new_lines.append("            _khgControllers[vName]?.text = formatIds(khgTorch);\n")
        continue
    if i == 1803:
        new_lines.append("         }\n")
        new_lines.append("       }\n")
        continue
    new_lines.append(line)

with open('lib/screens/duty_register_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print('Done UI')
