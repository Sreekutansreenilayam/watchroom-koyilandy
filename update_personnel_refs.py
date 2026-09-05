import os

files_to_update = [
    r"e:\Softwares\Watchroom\lib\screens\sentry_register_screen.dart",
    r"e:\Softwares\Watchroom\lib\screens\sentry_confirmation_dialog.dart",
    r"e:\Softwares\Watchroom\lib\screens\sentry_exemptions_dialog.dart",
    r"e:\Softwares\Watchroom\lib\screens\duty_screen.dart",
    r"e:\Softwares\Watchroom\lib\screens\duty_register_screen.dart",
    r"e:\Softwares\Watchroom\lib\screens\fire_report_screen.dart",
    r"e:\Softwares\Watchroom\lib\screens\fire_report_form_screen.dart",
    r"e:\Softwares\Watchroom\lib\screens\incident_report_form_screen.dart",
    r"e:\Softwares\Watchroom\lib\widgets\equipment_dialogs.dart",
]

for file_path in files_to_update:
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # We are replacing specific accesses
    content = content.replace("manProvider.personnelList", "manProvider.activePersonnelList")
    content = content.replace("context.read<ManpowerProvider>().personnelList", "context.read<ManpowerProvider>().activePersonnelList")
    content = content.replace("context.watch<ManpowerProvider>().personnelList", "context.watch<ManpowerProvider>().activePersonnelList")
    content = content.replace("Provider.of<ManpowerProvider>(stateContext).personnelList", "Provider.of<ManpowerProvider>(stateContext).activePersonnelList")
    content = content.replace("Provider.of<ManpowerProvider>(context, listen: false).personnelList", "Provider.of<ManpowerProvider>(context, listen: false).activePersonnelList")
    
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)
        
print("Updated successfully")
