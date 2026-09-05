import os
import re

with open(r'e:\Softwares\Watchroom\lib\services\fire_report_pdf_generator.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace class and model names
content = content.replace('FireReportPdfGenerator', 'IncidentReportPdfGenerator')
content = content.replace('FireReportModel', 'IncidentReportModel')
content = content.replace('fire_report_model.dart', 'incident_report_model.dart')

# Update title texts
content = content.replace('കെ. എഫ്. എഫ്. ഫോറം നമ്പർ 4', 'കെ. എഫ്. എഫ്. ഫോറം നമ്പർ 5')
content = content.replace('കേരള അഗ്നിശമനസേനാ തീപിടുത്ത റിപ്പോർട്ട്', 'കേരള അഗ്നിശമനസേന')

# Update top fields
content = content.replace('തീപിടുത്ത റിപ്പോർട്ട് നമ്പർ:', 'സംഭവ റിപ്പോർട്ട് നമ്പർ:')
content = content.replace('തീപിടുത്ത തീയതി:', 'സംഭവ തീയതി:')
content = content.replace('തീപിടുത്ത സ്ഥലത്ത് ചുമതല വഹിച്ച ആഫീസർ', 'സംഭവസ്ഥലത്ത് ചുമതല വഹിച്ച ആഫീസർ')

# Update section 2
content = content.replace('2. തീപിടുത്ത വിശദവിവരങ്ങൾ', '2. സംഭവത്തിന്റെ വിശദവിവരങ്ങൾ')
content = content.replace('തീപിടുത്തത്തിന്റെ കാരണം/വിശദവിവരങ്ങൾ', 'സംഭവത്തിന്റെ പൂർണ്ണ വിശദാംശങ്ങൾ')
content = content.replace('report.propertiesInvolved', 'report.fullDetails')
content = content.replace('നാശനഷ്ടങ്ങളുടെ വിവരണം', 'നൽകിയ സേവനം')
content = content.replace('report.damageDescription', 'report.serviceRendered')
content = content.replace('തീപിടുത്തത്തിന്റെ വ്യാപ്തി', 'തീപിടുത്തത്തിന്റെ വ്യാപ്തി') # Keep it if exists? Actually incident report doesn't have extent of fire.
content = content.replace('അവസാനം തീപിടുത്ത സ്ഥലത്തുനിന്ന് പോയ ആഫീസർ', 'അവസാനം സംഭവസ്ഥലത്തുനിന്ന് പോയ ആഫീസർ')
content = content.replace('തീപിടുത്ത സ്ഥലം വിട്ടുപോയ തീയതിയും സമയവും', 'സംഭവസ്ഥലം വിട്ടുപോയ തീയതിയും സമയവും')

# Remove the 'Estimates' (വിലമതിപ്പ്) section (Section 3)
pattern = r"buildSectionTitle\('3\. വിലമതിപ്പ്'\).*?(?=buildSectionTitle\('4\. രക്ഷപ്പെട്ടവരും രക്ഷിക്കപ്പെട്ടവരും'\))"
content = re.sub(pattern, '', content, flags=re.DOTALL)

# Remove extent of fire (തീപിടുത്തത്തിന്റെ വ്യാപ്തി) since it's not in incident report
content = re.sub(r"_buildInfoRow\('തീപിടുത്തത്തിന്റെ വ്യാപ്തി:'.*?,\s*bottomBorder:\s*true\),", "", content, flags=re.DOTALL)

# Update section numbers
content = content.replace("buildSectionTitle('4. രക്ഷപ്പെട്ടവരും രക്ഷിക്കപ്പെട്ടവരും')", "buildSectionTitle('3. രക്ഷപ്പെട്ടവരും രക്ഷിക്കപ്പെട്ടവരും')")
content = content.replace("buildSectionTitle('5. ആൾപ്പായങ്ങൾ')", "buildSectionTitle('4. ആൾപ്പായങ്ങൾ')")
content = content.replace("buildSectionTitle('6. തീപിടുത്ത സ്ഥലത്തെ ഹാജർ')", "buildSectionTitle('5. സംഭവസ്ഥലത്തെ ഹാജർ')")
content = content.replace("buildSectionTitle('7. തീപിടുത്ത സ്ഥലത്ത് അഗ്നിശമനസേനാംഗങ്ങളുടെ ഹാജർ')", "buildSectionTitle('6. സംഭവസ്ഥലത്ത് അഗ്നിശമനസേനാംഗങ്ങളുടെ ഹാജർ')")
content = content.replace("buildSectionTitle('8. മറ്റ് റിമാർക്കുകൾ')", "buildSectionTitle('7. മറ്റ് റിമാർക്കുകൾ')")

with open(r'e:\Softwares\Watchroom\lib\services\incident_report_pdf_generator.dart', 'w', encoding='utf-8') as f:
    f.write(content)
