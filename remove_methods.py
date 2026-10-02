import sys

with open('lib/screens/duty_register_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

methods_to_remove = [
    'void _autoAssignSFRO() {',
    'void _autoAssignFRO() {',
    'void _autoAssignFROMales() {',
    'void _autoAssignAccessories() {',
    'void _autoAssignDrivers() {',
    'void _autoAssignKHG() {',
]

new_lines = []
in_target_method = False
brace_count = 0

for line in lines:
    if not in_target_method:
        is_target = False
        for m in methods_to_remove:
            if m in line:
                is_target = True
                break
        
        if is_target:
            in_target_method = True
            brace_count = line.count('{') - line.count('}')
            continue
        else:
            new_lines.append(line)
    else:
        brace_count += line.count('{') - line.count('}')
        if brace_count == 0:
            in_target_method = False

with open('lib/screens/duty_register_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print('Done')
