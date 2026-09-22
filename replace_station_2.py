import os

files = {
    'lib/services/paradestate_pdf_generator.dart': [
        ("'PARADE STATEMENT OF FIRE AND RESCUE STATION, MEENCHANDA ON $dateStr'", "'PARADE STATEMENT OF ${AppConfig.stationName.toUpperCase()} ON $dateStr'")
    ],
    'lib/services/duty_pdf_generator.dart': [
        ("'PERFORMA DUTY DETAILING OF PERSONNEL - FIRE & RESCUE STATION MEENCHANDA'", "'PERFORMA DUTY DETAILING OF PERSONNEL - ${AppConfig.stationNamePdfHeader}'")
    ],
    'lib/models/voucher_model.dart': [
        ("this.issueStation = 'Fire & Rescue Station, Meenchanda'", "this.issueStation = 'Fire & Rescue Station, Meenchanda'")
    ],
    'lib/models/manpower_model.dart': [
        ("this.currentStation = 'FRS Meenchanda'", "this.currentStation = ''"),
        ("currentStation.trim().toLowerCase() != 'frs meenchanda'", "currentStation.trim().toLowerCase() != AppConfig.stationNameShort.toLowerCase()"),
        ("currentStation: map['currentStation'] ?? 'FRS Meenchanda'", "currentStation: map['currentStation'] ?? ''")
    ]
}

def add_import(content):
    if 'import \'../config/app_config.dart\';' in content or 'import \'package:watchroom/config/app_config.dart\';' in content:
        return content
    lines = content.split('\n')
    last_import_idx = -1
    for i, line in enumerate(lines):
        if line.startswith('import '):
            last_import_idx = i
    if last_import_idx != -1:
        lines.insert(last_import_idx + 1, "import '../config/app_config.dart';")
        return '\n'.join(lines)
    return "import '../config/app_config.dart';\n" + content

for filepath, replacements in files.items():
    if not os.path.exists(filepath):
        continue
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    orig = content
    for old, new in replacements:
        if filepath == 'lib/models/voucher_model.dart':
             # Need to fix the default value. But models shouldn't depend on config if possible.
             # I'll just change to use AppConfig.stationName but wait, default params must be constant.
             # So I can't use AppConfig.stationName in default param. I'll just leave it empty string and handle in UI.
             content = content.replace("this.issueStation = 'Fire & Rescue Station, Meenchanda'", "this.issueStation = ''")
        else:
             content = content.replace(old, new)
    if content != orig:
        content = add_import(content)
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
