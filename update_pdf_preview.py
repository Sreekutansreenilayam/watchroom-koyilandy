import os
import re

directory = 'lib/screens'

properties_to_add = """
        allowSharing: true,
        allowPrinting: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,"""

# We'll match PdfPreview( and ensure these properties are there.
# If some are missing, we can just replace PdfPreview( with PdfPreview( properties...
# A safer way is to find PdfPreview( and add them if they don't exist, but it's easier to just replace PdfPreview( with PdfPreview(allowSharing: true, ... and remove existing ones to avoid duplicates.

for filename in os.listdir(directory):
    if filename.endswith('.dart'):
        filepath = os.path.join(directory, filename)
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            
        if 'PdfPreview(' in content:
            # First remove existing ones to avoid duplicate named arguments
            content = re.sub(r'allowSharing:\s*(true|false),', '', content)
            content = re.sub(r'allowPrinting:\s*(true|false),', '', content)
            content = re.sub(r'canChangePageFormat:\s*(true|false),', '', content)
            content = re.sub(r'canChangeOrientation:\s*(true|false),', '', content)
            content = re.sub(r'canDebug:\s*(true|false),', '', content)
            
            # Now inject them right after PdfPreview(
            content = content.replace('PdfPreview(', 'PdfPreview(' + properties_to_add)
            
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Updated {filename}")
