import re
path = r'e:\Softwares\Watchroom\lib\screens\logbook_form_screen.dart'
with open(path, 'r', encoding='utf-8') as f: content = f.read()

# Add cupertino import if not present
if "import 'package:flutter/cupertino.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter/cupertino.dart';")

# Replace _selectTime
new_select_time = """  Future<void> _selectTime(TextEditingController controller) async {
    final now = DateTime.now();
    DateTime initialDateTime = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    
    if (controller.text.isNotEmpty) {
      final parts = controller.text.split(':');
      if (parts.length == 2) {
        int? h = int.tryParse(parts[0]);
        int? m = int.tryParse(parts[1]);
        if (h != null && m != null) {
          initialDateTime = DateTime(now.year, now.month, now.day, h, m);
        }
      }
    }

    DateTime selectedDateTime = initialDateTime;

    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 16)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('OK', style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    brightness: Brightness.dark,
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: initialDateTime,
                    onDateTimeChanged: (DateTime newDateTime) {
                      selectedDateTime = newDateTime;
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true) {
      setState(() {
        controller.text = DateFormat('HH:mm').format(selectedDateTime);
        if (controller == _pumpStartController || controller == _pumpEndController) {
          _calculatePumpDuration();
        }
      });
    }
  }"""

# Use regex to find the old _selectTime function block
pattern = r"  Future<void> _selectTime\(TextEditingController controller\) async \{.*?  \}"
content = re.sub(pattern, new_select_time, content, flags=re.DOTALL)

with open(path, 'w', encoding='utf-8') as f: f.write(content)
print('Replaced _selectTime with Cupertino rolling picker')
