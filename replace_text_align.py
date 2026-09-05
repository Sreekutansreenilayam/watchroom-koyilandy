import re
path = r'e:\Softwares\Watchroom\lib\screens\logbook_form_screen.dart'
with open(path, 'r', encoding='utf-8') as f: content = f.read()

# Revert previous broken replacements
content = content.replace(', textAlign: TextAlign.center)', ')')

lines_to_replace = [
    ("Text('അവസാനിക്കുന്ന സമയം (Arrival Time) തുടങ്ങുന്ന സമയത്തേക്കാൾ (Departure Time) വലുതായിരിക്കണം!')", "Text('അവസാനിക്കുന്ന സമയം (Arrival Time) തുടങ്ങുന്ന സമയത്തേക്കാൾ (Departure Time) വലുതായിരിക്കണം!', textAlign: TextAlign.center)"),
    ("Text('തുടക്ക സമയം മുമ്പത്തെ യാത്ര അവസാനിച്ച സമയത്തിന് ($prevEndTimeStr) ശേഷമായിരിക്കണം!')", "Text('തുടക്ക സമയം മുമ്പത്തെ യാത്ര അവസാനിച്ച സമയത്തിന് ($prevEndTimeStr) ശേഷമായിരിക്കണം!', textAlign: TextAlign.center)"),
    ("Text('തുടക്കത്തിലെ Odometer റീഡിങ് മുമ്പത്തെ റീഡിങ്ങിനേക്കാൾ ($prevEndOdo) കുറവാകാൻ പാടില്ല!')", "Text('തുടക്കത്തിലെ Odometer റീഡിങ് മുമ്പത്തെ റീഡിങ്ങിനേക്കാൾ ($prevEndOdo) കുറവാകാൻ പാടില്ല!', textAlign: TextAlign.center)"),
    ("Text('അവസാനിക്കുന്ന സമയം അടുത്ത യാത്ര തുടങ്ങിയ സമയത്തേക്കാൾ ($nextStartTimeStr) മുന്നിലായിരിക്കണം!')", "Text('അവസാനിക്കുന്ന സമയം അടുത്ത യാത്ര തുടങ്ങിയ സമയത്തേക്കാൾ ($nextStartTimeStr) മുന്നിലായിരിക്കണം!', textAlign: TextAlign.center)"),
    ("Text('നിങ്ങൾ വാഹനം എമർജൻസി ചാർജ് എടുത്ത സമയത്തിന് മുൻപുള്ള വിവരങ്ങൾ രേഖപ്പെടുത്താൻ നിങ്ങൾക്ക് അനുമതിയില്ല')", "Text('നിങ്ങൾ വാഹനം എമർജൻസി ചാർജ് എടുത്ത സമയത്തിന് മുൻപുള്ള വിവരങ്ങൾ രേഖപ്പെടുത്താൻ നിങ്ങൾക്ക് അനുമതിയില്ല', textAlign: TextAlign.center)"),
    ("Text('Cannot drain more fuel than available in tank!')", "Text('Cannot drain more fuel than available in tank!', textAlign: TextAlign.center)"),
    ("Text('താങ്കൾ ഇതിനകം വാഹനം ചാർജിൽ എടുത്തിട്ടുണ്ട്')", "Text('താങ്കൾ ഇതിനകം വാഹനം ചാർജിൽ എടുത്തിട്ടുണ്ട്', textAlign: TextAlign.center)"),
    ("Text('Entry saved successfully')", "Text('Entry saved successfully', textAlign: TextAlign.center)"),
    ("Text('Error: ${provider.errorMessage}')", "Text('Error: ${provider.errorMessage}', textAlign: TextAlign.center)"),
]

for old, new in lines_to_replace:
    content = content.replace(old, new)

with open(path, 'w', encoding='utf-8') as f: f.write(content)
print('Done')
