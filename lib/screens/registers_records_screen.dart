import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import 'hose_register_pdf_preview_screen.dart';
import 'duty_roaster_list_screen.dart';

class RegistersRecordsScreen extends StatelessWidget {
  const RegistersRecordsScreen({super.key});

  void _showHoseSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedHose;
        return StatefulBuilder(
          builder: (context, setState) {
            final equipmentList = Provider.of<EquipmentProvider>(context, listen: false).equipments;
            final hoseList = equipmentList.where((e) => e.name.toLowerCase().contains('hose') || e.category.toLowerCase().contains('hose')).toList();

            return AlertDialog(
              title: const Text('Select Hose', style: TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFF1E1E1E),
              content: DropdownButtonFormField<String>(
                value: selectedHose,
                dropdownColor: const Color(0xFF2C2C2C),
                decoration: const InputDecoration(
                  labelText: 'Hose',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  filled: true,
                  fillColor: Color(0xFF2C2C2C),
                ),
                items: hoseList.map((h) => DropdownMenuItem(value: h.name, child: Text(h.name, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (v) => setState(() => selectedHose = v),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                TextButton(
                  onPressed: () {
                    if (selectedHose != null) {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => HoseRegisterPdfPreviewScreen(hoseName: selectedHose!)));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a hose')));
                    }
                  },
                  child: const Text('Open Register', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> registers = [
      {'title': 'Hose Register', 'icon': Icons.water_drop, 'onTap': () => _showHoseSelectionDialog(context)},
      {'title': 'Duty Roaster', 'icon': Icons.calendar_today, 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DutyRoasterListScreen()))},
      // Add more registers here in the future
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Registers & Records', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.5,
            colors: [Color(0xFF2C0B0B), Color(0xFF0A0A0A)],
          ),
        ),
        child: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: registers.length,
            itemBuilder: (context, index) {
              final register = registers[index];
              return Card(
                color: const Color(0xFF1E1E1E),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white.withOpacity(0.1))),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.redAccent.withOpacity(0.2),
                    child: Icon(register['icon'] as IconData, color: Colors.redAccent),
                  ),
                  title: Text(register['title'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                  onTap: register['onTap'] as VoidCallback,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
