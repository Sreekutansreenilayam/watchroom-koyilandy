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
    _slots = widget.register.slots.map((s) {
      List<SentryDutySegment>? segs = s.segments;
      // If no segments are explicitly defined but it's broken, try to reconstruct
      if (segs == null && s.isBroken && s.brokenTime != null && s.replacementPersonnelId != null) {
        final parts = s.timeLabel.split(' - ');
        if (parts.length == 2) {
           segs = [
             SentryDutySegment(personnelId: s.personnelId, startTime: parts[0].trim(), endTime: s.brokenTime!),
             SentryDutySegment(personnelId: s.replacementPersonnelId!, startTime: s.brokenTime!, endTime: parts[1].trim()),
           ];
        }
      } else if (segs == null && s.personnelId.isNotEmpty) {
        final parts = s.timeLabel.split(' - ');
        if (parts.length == 2) {
           segs = [
             SentryDutySegment(personnelId: s.personnelId, startTime: parts[0].trim(), endTime: parts[1].trim()),
           ];
        }
      }

      return SentrySlot(
        timeLabel: s.timeLabel,
        personnelId: s.personnelId,
        isBroken: s.isBroken,
        brokenTime: s.brokenTime,
        replacementPersonnelId: s.replacementPersonnelId,
        segments: segs,
      );
    }).toList();
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
    if (slot.segments == null || slot.segments!.isEmpty) return;

    List<SentryDutySegment> tempSegments = List.from(slot.segments!);

    final manProvider = context.read<ManpowerProvider>();
    final attProvider = context.read<AttendanceProvider>();

    final eligiblePersonnel = manProvider.getActivePersonnelForDate(widget.register.date).where((p) {
      if (!['FRO', 'KHG', 'Trainees'].contains(p.designation)) return false;
      
      final att = attProvider.attendanceMap[p.id];
      final status = att?.dailyStatus[widget.register.date.day];
      return (status == 'X' || status == null || status.isEmpty || status.toUpperCase() == 'X/R');
    }).toList();

    Future<void> splitSegment(StateSetter setDialogState, int segIndex) async {
         var seg = tempSegments[segIndex];
         
         DateTime startDt = DateFormat('HH:mm').parse(seg.startTime);
         DateTime endDt = DateFormat('HH:mm').parse(seg.endTime);
         if (endDt.isBefore(startDt) || endDt.isAtSameMomentAs(startDt)) {
            endDt = endDt.add(const Duration(days: 1));
         }

         TimeOfDay? pickedTime = await _showRollingTimePicker(context, TimeOfDay.fromDateTime(startDt));
         if (pickedTime == null) return;
         
         String pickedFormatted = '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
         DateTime pickedDt = DateFormat('HH:mm').parse(pickedFormatted);
         if (endDt.day > startDt.day && pickedDt.hour < 12 && startDt.hour >= 12) {
             pickedDt = pickedDt.add(const Duration(days: 1));
         }

         if (pickedDt.isBefore(startDt) || pickedDt.isAfter(endDt) || pickedDt.isAtSameMomentAs(startDt) || pickedDt.isAtSameMomentAs(endDt)) {
             if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Time must be strictly between start and end times.')));
             }
             return;
         }

         String? selectedReplacementId;
         bool confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) {
               return StatefulBuilder(builder: (ctx, setInnerState) {
                  return AlertDialog(
                     backgroundColor: const Color(0xFF1E1E1E),
                     title: const Text('Select Replacement', style: TextStyle(color: Colors.white)),
                     content: DropdownButtonFormField<String>(
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2A2A2A),
                        items: eligiblePersonnel.map((p) => DropdownMenuItem(value: p.idNumber, child: Text(p.name, style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setInnerState(() => selectedReplacementId = val),
                     ),
                     actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm', style: TextStyle(color: Colors.blueAccent))),
                     ]
                  );
               });
            }
         ) ?? false;

         if (confirmed && selectedReplacementId != null) {
            setDialogState(() {
               tempSegments[segIndex] = SentryDutySegment(personnelId: seg.personnelId, startTime: seg.startTime, endTime: pickedFormatted);
               tempSegments.insert(segIndex + 1, SentryDutySegment(personnelId: selectedReplacementId!, startTime: pickedFormatted, endTime: seg.endTime));
            });
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
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                   shrinkWrap: true,
                   itemCount: tempSegments.length,
                   itemBuilder: (ctx, i) {
                      var seg = tempSegments[i];
                      final pName = manProvider.getActivePersonnelForDate(widget.register.date).where((m) => m.idNumber == seg.personnelId).firstOrNull?.name ?? seg.personnelId;
                      return Card(
                        color: const Color(0xFF2A2A2A),
                        child: ListTile(
                           title: Text(pName, style: const TextStyle(color: Colors.white, fontSize: 13)),
                           subtitle: Text('${seg.startTime} - ${seg.endTime}', style: const TextStyle(color: Colors.orange)),
                           trailing: IconButton(
                              icon: const Icon(Icons.call_split, color: Colors.blueAccent),
                              onPressed: () => splitSegment(setDialogState, i),
                           ),
                        ),
                      );
                   },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () {
                     setState(() {
                       _slots[index] = SentrySlot(
                         timeLabel: slot.timeLabel,
                         personnelId: slot.personnelId,
                         isBroken: tempSegments.length > 1,
                         brokenTime: tempSegments.length > 1 ? tempSegments[0].endTime : null,
                         replacementPersonnelId: tempSegments.length > 1 ? tempSegments[1].personnelId : null,
                         segments: tempSegments,
                       );
                     });
                     Navigator.pop(context);
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

                        if (slot.isBroken && slot.segments != null) ...[
                           const SizedBox(height: 8),
                           Container(
                             padding: const EdgeInsets.all(8),
                             decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: slot.segments!.map((seg) {
                                  final pName = manProvider.getActivePersonnelForDate(widget.register.date).where((m) => m.idNumber == seg.personnelId).firstOrNull?.name ?? seg.personnelId;
                                  return Padding(
                                     padding: const EdgeInsets.only(bottom: 4),
                                     child: Text('${seg.startTime} - ${seg.endTime} : $pName', style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  );
                               }).toList(),
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
                                       final parts = slot.timeLabel.split(' - ');
                                       _slots[index] = SentrySlot(
                                         timeLabel: slot.timeLabel,
                                         personnelId: slot.personnelId,
                                         isBroken: false,
                                         brokenTime: null,
                                         replacementPersonnelId: null,
                                         segments: parts.length == 2 ? [
                                            SentryDutySegment(personnelId: slot.personnelId, startTime: parts[0].trim(), endTime: parts[1].trim())
                                         ] : null,
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
