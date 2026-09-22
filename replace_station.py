import os
import re

files_to_process = [
    'lib/services/voucher_pdf_generator.dart',
    'lib/services/sentry_pdf_generator.dart',
    'lib/services/paradestate_pdf_generator.dart',
    'lib/services/fuel_pdf_service.dart',
    'lib/services/duty_pdf_generator.dart',
    'lib/services/dosr_generator.dart',
    'lib/screens/voucher_form_screen.dart',
    'lib/screens/user_management_screen.dart',
    'lib/screens/manpower_screen.dart',
    'lib/screens/fire_report_form_screen.dart',
    'lib/providers/manpower_provider.dart',
]

def add_import(content):
    if 'import \'../config/app_config.dart\';' in content or 'import \'package:watchroom/config/app_config.dart\';' in content:
        return content
    
    # Try to find the last import and add it after
    lines = content.split('\n')
    last_import_idx = -1
    for i, line in enumerate(lines):
        if line.startswith('import '):
            last_import_idx = i
            
    if last_import_idx != -1:
        lines.insert(last_import_idx + 1, "import '../config/app_config.dart';")
        return '\n'.join(lines)
    return "import '../config/app_config.dart';\n" + content

def process_file(filepath):
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        return
        
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    # Replace specific strings
    # 'FIRE AND RESCUE STATION, MEENCHANDA'
    content = content.replace("'FIRE AND RESCUE STATION, MEENCHANDA'", "AppConfig.stationName.toUpperCase()")
    content = content.replace("'FIRE & RESCUE STATION MEENCHANDA'", "AppConfig.stationNamePdfHeader")
    content = content.replace("'FIRE & RESCUE STATION, MEENCHANDA'", "AppConfig.stationName.toUpperCase()")
    content = content.replace("'FRS Meenchanda'", "AppConfig.stationNameShort")
    content = content.replace("'frs meenchanda'", "AppConfig.stationNameShort.toLowerCase()")
    content = content.replace("'Fire & Rescue Station, Meenchanda'", "AppConfig.stationName")
    content = content.replace("'Fire &Rescue Station Meenchanda'", "AppConfig.stationName")
    
    # In DOSR:
    content = content.replace("Meenchanda", "Station")
    content = content.replace("meenchanda", "station")

    if content != original_content:
        content = add_import(content)
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {filepath}")
    else:
        print(f"No changes needed for {filepath}")

for f in files_to_process:
    process_file(f)
