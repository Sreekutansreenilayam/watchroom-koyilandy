import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sentry_register_model.dart';
import '../models/manpower_model.dart';
import '../providers/sentry_provider.dart';
import '../providers/manpower_provider.dart';

class SentryExemptionsDialog extends StatefulWidget {
  const SentryExemptionsDialog({super.key});

  @override
  State<SentryExemptionsDialog> createState() => _SentryExemptionsDialogState();
}

class _SentryExemptionsDialogState extends State<SentryExemptionsDialog> {
  Manpower? _selectedPersonnel;
  final TextEditingController _reasonController = TextEditingController();

  void _addExemption() async {
    if (_selectedPersonnel == null || _reasonController.text.trim().isEmpty) return;

    final provider = context.read<SentryProvider>();
    List<SentryExemption> currentList = List.from(provider.globalExemptions);
    
    currentList.add(SentryExemption(
      personnelId: _selectedPersonnel!.idNumber,
      reason: _reasonController.text.trim(),
    ));

    await provider.saveGlobalExemptions(currentList);
    
    setState(() {
      _selectedPersonnel = null;
      _reasonController.clear();
    });
  }

  void _removeExemption(SentryExemption exemption) async {
    final provider = context.read<SentryProvider>();
    List<SentryExemption> currentList = List.from(provider.globalExemptions);
    
    currentList.removeWhere((e) => e.personnelId == exemption.personnelId);
    
    await provider.saveGlobalExemptions(currentList);
  }

  @override
  Widget build(BuildContext context) {
    final manProvider = context.read<ManpowerProvider>();
    final sentryProvider = context.watch<SentryProvider>();
    
    final eligiblePersonnel = manProvider.activePersonnelList.where((p) => 
        ['FRO', 'KHG', 'Trainees'].contains(p.designation) && 
        !sentryProvider.globalExemptions.any((e) => e.personnelId == p.idNumber)
    ).toList();

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('Global Sentry Exemptions', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add New Exemption:', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<Manpower>(
              initialValue: _selectedPersonnel,
              isExpanded: true,
              hint: const Text('Select Personnel', style: TextStyle(color: Colors.white54)),
              dropdownColor: const Color(0xFF2A2A2A),
              items: eligiblePersonnel.map((p) => DropdownMenuItem(
                value: p,
                child: Text('${p.name} (${p.idNumber})', style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (val) => setState(() => _selectedPersonnel = val),
              decoration: const InputDecoration(
                filled: true,
                fillColor: Color(0xFF2A2A2A),
                border: OutlineInputBorder(),
              ),
            ),
            if (_selectedPersonnel != null) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Reason for exemption...',
                  hintStyle: TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Color(0xFF2A2A2A),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _addExemption,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Add', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
            const Divider(color: Colors.white24, height: 32),
            const Text('Current Exemptions:', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: sentryProvider.globalExemptions.isEmpty
                ? const Center(child: Text('No active exemptions', style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    itemCount: sentryProvider.globalExemptions.length,
                    itemBuilder: (context, index) {
                      final ex = sentryProvider.globalExemptions[index];
                      final p = manProvider.activePersonnelList.where((m) => m.idNumber == ex.personnelId).firstOrNull;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(p?.name ?? ex.personnelId, style: const TextStyle(color: Colors.white)),
                        subtitle: Text('Reason: ${ex.reason}', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => _removeExemption(ex),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }
}
