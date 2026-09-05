import os
import re

file_path = r'e:\Softwares\Watchroom\lib\screens\incident_report_form_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Translations
translations = {
    # Stepper controls
    '"Next"': '"അടുത്തത്"',
    '"Back"': '"പുറകോട്ട്"',
    '"Save Report"': '"സേവ് ചെയ്യുക"',
    "'Cancel'": "'റദ്ദാക്കുക'",
    "'Done'": "'പൂർത്തിയായി'",
    "'Select Time'": "'സമയം തിരഞ്ഞെടുക്കുക'",
    '"New Incident Report"': '"പുതിയ സംഭവ റിപ്പോർട്ട്"',
    '"Edit Incident Report"': '"സംഭവ റിപ്പോർട്ട് എഡിറ്റ് ചെയ്യുക"',

    # General
    '"General"': '"പൊതുവിവരങ്ങൾ"',
    '"Report Number"': '"സംഭവ റിപ്പോർട്ട് നമ്പർ"',
    '"Location"': '"സ്ഥലം"',
    '"Officer In Charge"': '"സംഭവസ്ഥലത്ത് ചുമതല വഹിച്ച ആഫീസർ"',

    # Call Details
    '"Call Details"': '"അറിയിപ്പ്"',
    '"Caller Name"': '"വിളിച്ച ആൾ"',
    '"Caller Phone"': '"ടെലിഫോൺ/തീപിടുത്ത അറിയിപ്പ് നമ്പർ"',
    '"Address of Involved Buildings"': '"ഉൾപ്പെട്ട കെട്ടിടങ്ങളുടെ വിവരങ്ങൾ"',
    '"Occupant Name"': '"പാർപ്പുകാരൻ്റെ പേര്"',
    '"Occupation"': '"ജോലി"',
    '"Owner Name & Address"': '"ഉടമസ്ഥൻ്റെ പേരും വിലാസവും"',
    '"Call Time"': '"വിളിച്ച സമയം"',
    '"Turnout Time"': '"ആദ്യം പുറപ്പെട്ട സമയം"',
    '"Reached Time"': '"സംഭവസ്ഥലത്ത് എത്തിയ സമയം"',
    '"Distance From Station (Km)"': '"സ്റ്റേഷനിൽ നിന്ന് സംഭവസ്ഥലത്തേക്കുള്ള ദൂരം (കി. മി.)"',

    # Incident Details
    '"Incident Details"': '"വിവരങ്ങൾ"',
    '"Full Details of Incident"': '"സംഭവത്തിന്റെ പൂർണ്ണ വിശദാംശങ്ങൾ"',
    '"Confirmed Cause"': '"ഉറപ്പിക്കപ്പെടുന്ന കാരണം"',
    '"Service Rendered"': '"നൽകിയ സേവനം"',
    '"Officer who left last"': '"അവസാനം സംഭവസ്ഥലത്തുനിന്ന് പോയ ആഫീസർ"',
    '"Time Left"': '"സംഭവസ്ഥലം വിട്ടുപോയ സമയം"',
    '"Total Working Hrs"': '"ആകെ പണിയെടുത്ത സമയം (മണിക്കൂർ)"',
    '"Total Working Mins"': '"ആകെ പണിയെടുത്ത സമയം (മിനിറ്റ്)"',

    # Rescued
    '"Rescued"': '"രക്ഷപ്പെട്ടവരും രക്ഷിക്കപ്പെട്ടവരും"',
    '"Without Fire Force Help"': '"അഗ്നിശമന സേനയുടെ സഹായമില്ലാതെ രക്ഷപ്പെട്ടവർ"',
    '"Male"': '"പുരുഷൻ"',
    '"Female"': '"സ്ത്രീ"',
    '"With Fire Force (No Equipments)"': '"ഉപകരണങ്ങൾ കൂടാതെ അഗ്നിശമനസേന രക്ഷിച്ചവർ"',
    '"With Fire Force (With Equipments)"': '"ഉപകരണങ്ങളുപയോഗിച്ച് അഗ്നിശമനസേന രക്ഷിച്ചവർ"',

    # Casualties
    '"Casualties"': '"ആളപായങ്ങൾ"',
    '"Fire Force Personnel"': '"അഗ്നിശമനസേന"',
    '"Names"': '"പേര്"',
    '"Addresses"': '"വിലാസം"',
    '"Others"': '"മറ്റുള്ളവർ"',

    # Vehicles
    '"Vehicles"': '"സംഭവസ്ഥലത്തെ ഹാജർ"',
    '"Add Dummy Vehicle (For testing)"': '"വാഹനം ചേർക്കുക (Testing)"',

    # Personnel
    '"Personnel"': '"ഹാജരായ അഗ്നിശമന സേനാംഗങ്ങൾ"',
    '"Attending Officers"': '"ആഫീസർമാർ"',
    '"Attending Personnel"': '"സേനാംഗങ്ങൾ"',

    # Remarks
    '"Remarks"': '"മറ്റ് റിമാർക്കുകൾ"',
    '"Other Remarks"': '"വേറെ എന്തെങ്കിലും വിവരം ചേർക്കാനുണ്ടെങ്കിൽ അത് താഴെ എഴുതുക"',
}

for eng, mal in translations.items():
    content = content.replace(eng, mal)

# We need to add natureOfDeath to Casualties Step
if '_buildTextField("Addresses", _casOthAddressCtrl),' in content or '_buildTextField('"വിലാസം"', _casOthAddressCtrl),' in content:
    # Adding nature of death text field logic in dart, we need a controller for it too
    pass

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
