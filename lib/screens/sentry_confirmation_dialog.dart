import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/sentry_register_model.dart';
import '../providers/attendance_provider.dart';
import '../providers/sentry_provider.dart';
import '../providers/manpower_provider.dart';
import '../models/attendance_model.dart';

class SentryConfirmationDialog extends StatefulWidget {
  final SentryRegisterModel register;

  const SentryConfirmationDialog({super.key, required this.register});

  @override
  State<SentryConfirmationDialog> createState() => _SentryConfirmationDialogState();
}

class _SentryConfirmationDialogState extends State<SentryConfirmationDialog> {
  late List<SentrySlot> _slots;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _slots = widget.register.slots.map((s) => SentrySlot(
      timeLabel: s.timeLabel,
      personnelId: s.personnelId,
      isBroken: s.isBroken,
      brokenTime: s.brokenTime,
      replacementPersonnelId: s.replacementPersonnelId,
    )).toList();
  }

  Future<void> _confirm() async {
    setState(() => _isLoading = true);

    final updatedRegister = SentryRegisterModel(
      id: widget.register.id,
      date: widget.register.date,
      slots: _slots,
      spares: widget.register.spares,
      exemptions: widget.register.exemptions,
      isConfirmed: true,
    );

    final provider = context.read<SentryProvider>();
    await provider.saveSentryRegister(updatedRegister);

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<TimeOfDay?> _showRollingTimePicker(BuildContext context, TimeOfDay initialTime) async {
    TimeOfDay? pickedTime = initialTime;
    final result = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (BuildContext builderContext) {
        return SizedBox(
          height: 250,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(builderContext).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(builderContext).pop(pickedTime),
                    child: const Text('Done', style: TextStyle(color: Colors.blueAccent)),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: DateTime(2000, 1, 1, initialTime.hour, initialTime.minute),
                  onDateTimeChanged: (DateTime newDateTime) {
                    pickedTime = TimeOfDay(hour: newDateTime.hour, minute: newDateTime.minute);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    return result;
  }

  void _showBrokenDialog(int index) {
    final slot = _slots[index];
    TimeOfDay? selectedTime;
    String? selectedReplacementId;

    if (slot.brokenTime != null) {
      try {
        final dt = DateFormat('HH:mm').parse(slot.brokenTime!);
        selectedTime = TimeOfDay.fromDateTime(dt);
      } catch (e) {
        // ignore
      }
    }

    final manProvider = context.read<ManpowerProvider>();

    final Set<String> assignedIds = {};
    for (var s in widget.register.slots) {
      if (s.personnelId.isNotEmpty) {
        assignedIds.add(s.personnelId);
      }
    }
    assignedIds.addAll(widget.register.spares);

    final eligiblePersonnel = manProvider.getActivePersonnelForDate(widget.register.date).where((p) {
      return assignedIds.contains(p.idNumber);
    }).toList();

    if (slot.replacementPersonnelId != null) {
      final exists = eligiblePersonnel.any((p) => p.idNumber == slot.replacementPersonnelId);
      if (exists) {
         selectedReplacementId = slot.replacementPersonnelId;
      } else {
         final missing = manProvider.getActivePersonnelForDate(widget.register.date).where((p) => p.idNumber == slot.replacementPersonnelId).firstOrNull;
         if (missing != null) eligiblePersonnel.add(missing);
         selectedReplacementId = slot.replacementPersonnelId;
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Text('Edit Duty (${slot.timeLabel})', style: const TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('If this duty was broken or changed, record the exact time and who took over.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Time of Break', style: TextStyle(color: Colors.white70)),
                    subtitle: Text(selectedTime != null ? selectedTime!.format(context) : 'Not Set', style: const TextStyle(color: Colors.orange)),
                    trailing: const Icon(Icons.access_time, color: Colors.orange),
                    onTap: () async {
                      TimeOfDay? slotStartTime;
                      try {
                        final startStr = slot.timeLabel.split(' - ')[0].trim();
                        final parts = startStr.split(':');
                        slotStartTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
                      } catch (_) {}

                      final t = await _showRollingTimePicker(
                        context,
                        selectedTime ?? slotStartTime ?? TimeOfDay.now(),
                      );
                      if (t != null) setDialogState(() => selectedTime = t);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReplacementId,
                    isExpanded: true,
                    hint: const Text('Select Replacement', style: TextStyle(color: Colors.white54)),
                    dropdownColor: const Color(0xFF2A2A2A),
                    items: () {
                      final Set<String> seenIds = {};
                      final uniquePersonnel = eligiblePersonnel.where((p) {
                        if (seenIds.contains(p.idNumber)) return false;
                        seenIds.add(p.idNumber);
                        return true;
                      }).toList();

                      return uniquePersonnel.map((p) => DropdownMenuItem<String>(
                        value: p.idNumber,
                        child: Text(p.name, style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                      )).toList();
                    }(),
                    onChanged: (val) => setDialogState(() => selectedReplacementId = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () {
                    if (selectedTime != null && selectedReplacementId != null) {
                       try {
                           final parts = slot.timeLabel.split(' - ');
                           if (parts.length == 2) {
                               DateTime startDt = DateFormat('HH:mm').parse(parts[0].trim());
                               DateTime endDt = DateFormat('HH:mm').parse(parts[1].trim());
                               if (endDt.isBefore(startDt) || endDt.isAtSameMomentAs(startDt)) {
                                   endDt = endDt.add(const Duration(days: 1));
                               }

                               String pickedFormatted = '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';
                               DateTime pickedDt = DateFormat('HH:mm').parse(pickedFormatted);

                               // If the slot crosses midnight, and picked time is in the morning while start time is evening
                               if (endDt.day > startDt.day && pickedDt.hour < 12 && startDt.hour >= 12) {
                                   pickedDt = pickedDt.add(const Duration(days: 1));
                               }

                               if (pickedDt.isBefore(startDt) || pickedDt.isAfter(endDt)) {
                                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                       content: Text('Time must be between ${slot.timeLabel}'),
                                       backgroundColor: Colors.redAccent,
                                   ));
                                   return;
                               }
                           }
                       } catch (e) {
                           // ignore parse errors and proceed
                       }

                       setState(() {
                         _slots[index] = SentrySlot(
                           timeLabel: slot.timeLabel,
                           personnelId: slot.personnelId,
                           isBroken: true,
                           brokenTime: '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
                           replacementPersonnelId: selectedReplacementId,
                         );
                       });
                       Navigator.pop(context);
                    } else {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select time and replacement.')));
                    }
                  },
                  child: const Text('Save Changes', style: TextStyle(color: Colors.orange)),
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
    final manProvider = context.read<ManpowerProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Confirm Previous Duty'),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E1E1E),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date: ${DateFormat('dd MMM yyyy').format(widget.register.date)}', style: const TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Please confirm that the following duties were carried out as planned. If any duty was broken or someone was replaced, tap "Edit" to record the changes.', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _slots.length,
              onReorder: (oldIndex, newIndex) {
                 if (oldIndex < newIndex) {
                   newIndex -= 1;
                 }
                 setState(() {
                    final item = _slots.removeAt(oldIndex);
                    _slots.insert(newIndex, item);

                    for (int i = 0; i < _slots.length; i++) {
                       _slots[i] = SentrySlot(
                         timeLabel: widget.register.slots[i].timeLabel,
                         personnelId: _slots[i].personnelId,
                         isBroken: _slots[i].isBroken,
                         brokenTime: _slots[i].brokenTime,
                         replacementPersonnelId: _slots[i].replacementPersonnelId,
                       );
                    }
                 });
              },
              itemBuilder: (context, index) {
                final slot = _slots[index];
                if (slot.personnelId.isEmpty) return SizedBox(key: ValueKey('empty_$index'));

                final p = manProvider.getActivePersonnelForDate(widget.register.date).where((m) => m.idNumber == slot.personnelId).firstOrNull;
                final name = p?.name ?? slot.personnelId;

                return Card(
                  key: ValueKey('slot_${slot.personnelId}_$index'),
                  color: const Color(0xFF1E1E1E),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(slot.timeLabel, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                            if (slot.isBroken)
                               const Text('MODIFIED', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))
                            else
                               const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Assigned: $name', style: TextStyle(color: slot.isBroken ? Colors.white54 : Colors.white, decoration: slot.isBroken ? TextDecoration.lineThrough : null)),

                        if (slot.isBroken) ...[
                           const SizedBox(height: 8),
                           Container(
                             padding: const EdgeInsets.all(8),
                             decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text('Broken at: ${slot.brokenTime}', style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                                 Text('Replaced by: ${manProvider.getActivePersonnelForDate(widget.register.date).where((m) => m.idNumber == slot.replacementPersonnelId).firstOrNull?.name ?? slot.replacementPersonnelId}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                               ],
                             ),
                           )
                        ],

                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (slot.isBroken)
                               TextButton.icon(
                                 onPressed: () {
                                    setState(() {
                                      _slots[index] = SentrySlot(
                                        timeLabel: slot.timeLabel,
                                        personnelId: slot.personnelId,
                                      );
                                    });
                                 },
                                 icon: const Icon(Icons.restore, color: Colors.orange, size: 16),
                                 label: const Text('Reset', style: TextStyle(color: Colors.orange)),
                               ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => _showBrokenDialog(index),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit / Mark Broken'),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E1E1E),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm & Save Duties', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }
}
