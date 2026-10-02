import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/sentry_register_model.dart';
import '../providers/sentry_provider.dart';
import '../providers/manpower_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/manpower_model.dart';
import '../services/access_control.dart';
import 'sentry_exemptions_dialog.dart';
import 'sentry_pdf_preview_screen.dart';
import 'sentry_confirmation_dialog.dart';
import '../widgets/lock_hold_dialog.dart';

class SentryRegisterScreen extends StatefulWidget {
  final DateTime? initialDate;
  const SentryRegisterScreen({super.key, this.initialDate});

  @override
  State<SentryRegisterScreen> createState() => _SentryRegisterScreenState();
}

class _SentryRegisterScreenState extends State<SentryRegisterScreen> {
  DateTime _selectedDate = DateTime.now();
  SentryRegisterModel? _register;
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;

  final List<SentryRegisterModel> _undoStack = [];
  final List<SentryRegisterModel> _redoStack = [];

  // Removed _heldSlotIndex as UI is redesigned

  final List<String> _timeLabels = [
    '09:00 - 11:00',
    '11:00 - 13:00',
    '13:00 - 15:00',
    '15:00 - 17:00',
    '17:00 - 19:00',
    '19:00 - 21:00',
    '21:00 - 23:00',
    '23:00 - 01:00',
    '01:00 - 03:00',
    '03:00 - 05:00',
    '05:00 - 07:00',
    '07:00 - 09:00',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    } else {
      final now = DateTime.now();
      if (now.hour < 9) {
        _selectedDate = now.subtract(const Duration(days: 1));
      }
    }
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final sentryProvider = context.read<SentryProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();

    await sentryProvider.fetchSentryRegisters();
    await attendanceProvider.loadAttendanceForMonth(_selectedDate);

    _findOrCreateRegister();
    setState(() => _isLoading = false);
  }

  void _findOrCreateRegister() {
    final registers = context.read<SentryProvider>().registers;
    final existing = registers
        .where(
          (r) =>
              r.date.year == _selectedDate.year &&
              r.date.month == _selectedDate.month &&
              r.date.day == _selectedDate.day,
        )
        .toList();

    if (existing.isNotEmpty) {
      _register = existing.first;
    } else {
      _register = SentryRegisterModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        ),
        slots: _timeLabels.map((t) => SentrySlot(timeLabel: t)).toList(),
        spares: [],
        exemptions: [],
      );
    }
    _undoStack.clear();
    _redoStack.clear();
    _hasUnsavedChanges = false;
  }

  SentryRegisterModel _cloneRegister(SentryRegisterModel r) {
    return SentryRegisterModel(
      id: r.id,
      date: r.date,
      slots: r.slots
          .map(
            (s) => SentrySlot(
              timeLabel: s.timeLabel,
              personnelId: s.personnelId,
              isBroken: s.isBroken,
              brokenTime: s.brokenTime,
              replacementPersonnelId: s.replacementPersonnelId,
            ),
          )
          .toList(),
      spares: List.from(r.spares),
      exemptions: r.exemptions
          .map(
            (e) =>
                SentryExemption(personnelId: e.personnelId, reason: e.reason),
          )
          .toList(),
    );
  }

  void _saveState() {
    _hasUnsavedChanges = true;
    if (_register != null) {
      _undoStack.add(_cloneRegister(_register!));
      if (_undoStack.length > 20) _undoStack.removeAt(0);
      _redoStack.clear();
    }
  }

  void _undo() {
    _hasUnsavedChanges = true;
    if (_undoStack.isNotEmpty) {
      setState(() {
        _redoStack.add(_cloneRegister(_register!));
        _register = _undoStack.removeLast();
      });
    }
  }

  void _redo() {
    _hasUnsavedChanges = true;
    if (_redoStack.isNotEmpty) {
      setState(() {
        _undoStack.add(_cloneRegister(_register!));
        _register = _redoStack.removeLast();
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    if (_hasUnsavedChanges) {
      final confirm = await _onWillPop();
      if (!confirm) return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minDate = AccessControl.isAdmin(context)
        ? DateTime(2020)
        : today.subtract(const Duration(days: 1));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: minDate,
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.orange,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      final sentryProvider = context.read<SentryProvider>();
      final exists = sentryProvider.registers.any((r) => 
        r.date.year == picked.year && 
        r.date.month == picked.month && 
        r.date.day == picked.day
      );

      if (exists) {
        final unlocked = await showDialog<bool>(
          context: context,
          builder: (context) => LockHoldDialog(date: picked, title: 'സെൻട്രി രജിസ്റ്റർ ലോക്ക് ചെയ്തിരിക്കുന്നു'),
        );
        if (unlocked != true) return;
      }

      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }

  void _showHistoryDialog() {
    final sentryProvider = context.read<SentryProvider>();
    final manProvider = context.read<ManpowerProvider>();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SentryHistoryScreen(
          allRegisters: sentryProvider.registers,
          personnelList: manProvider.getActivePersonnelForDate(_selectedDate),
        ),
      ),
    );
  }

  Future<void> _saveRegister() async {
    if (_register == null) return;

    final manProvider = context.read<ManpowerProvider>();
    final sentryProvider = context.read<SentryProvider>();
    final attProvider = context.read<AttendanceProvider>();

    final eligiblePersonnel = manProvider.getActivePersonnelForDate(_selectedDate).where((p) {
      if (!['FRO', 'KHG', 'Trainees'].contains(p.designation)) return false;
      if (sentryProvider.globalExemptions.any((e) => e.personnelId == p.idNumber)) return false;
      if (_register!.exemptions.contains(p.idNumber)) return false;
      
      final att = attProvider.attendanceMap[p.id];
      final status = att?.dailyStatus[_selectedDate.day];
      return (status == 'X' || status == null || status.isEmpty || status.toUpperCase() == 'X/R');
    }).toList();

    List<String> unassignedNames = [];
    for (var p in eligiblePersonnel) {
        bool inSlot = _register!.slots.any((s) => s.personnelId == p.idNumber || s.replacementPersonnelId == p.idNumber);
        bool inSpares = _register!.spares.contains(p.idNumber);
        if (!inSlot && !inSpares) {
            unassignedNames.add("${p.name} (${p.idNumber})");
        }
    }

    if (unassignedNames.isNotEmpty) {
        bool? proceed = await showDialog<bool>(
           context: context,
           builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Center(child: Text('മുന്നറിയിപ്പ്', style: TextStyle(color: Colors.orange))),
              content: Text(
                 'താഴെ പറയുന്നവരെ ഡ്യൂട്ടിയിലോ സ്പെയറിലോ ഉൾപ്പെടുത്തിയിട്ടില്ല:\n\n'
                 '${unassignedNames.join('\n')}\n\n'
                 'ഇവരെ ഒഴിവാക്കി സേവ് ചെയ്യണമെന്നുറപ്പാണോ?',
                 textAlign: TextAlign.center,
                 style: const TextStyle(color: Colors.white),
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                 TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel', style: TextStyle(color: Colors.blueAccent)),
                 ),
                 TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Save Anyway', style: TextStyle(color: Colors.redAccent)),
                 ),
              ]
           )
        );
        if (proceed != true) return;
    }

    setState(() => _isLoading = true);
    final success = await sentryProvider.saveSentryRegister(
      _register!,
    );
    setState(() => _isLoading = false);
    if (success && mounted) {
      setState(() => _hasUnsavedChanges = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved successfully!')));
    }
  }

  Future<void> _autoFill() async {
    if (_register == null) return;
    
    bool hasAssignments = _register!.slots.any((s) => s.personnelId.isNotEmpty);
    if (hasAssignments) {
      bool? confirmOverwrite = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Center(child: Text('മുന്നറിയിപ്പ്', style: TextStyle(color: Colors.orange))),
          content: const Text(
            'ഈ ദിവസത്തെ ഡ്യൂട്ടികൾ നൽകിക്കഴിഞ്ഞു, ഇത് മാറ്റി പുതിയത് ഉണ്ടാക്കണോ?',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Overwrite', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
      if (confirmOverwrite != true) return;
    }

    final attProvider = context.read<AttendanceProvider>();
    final manProvider = context.read<ManpowerProvider>();
    final sentryProvider = context.read<SentryProvider>();

    final allRegsSorted = List<SentryRegisterModel>.from(
      sentryProvider.registers,
    )..sort((a, b) => b.date.compareTo(a.date));

    // Check for unconfirmed previous day
    final prevReg = allRegsSorted
        .where((r) => r.date.isBefore(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)))
        .firstOrNull;
    if (prevReg != null) {
      // Always auto-trigger confirmation when Auto Generate is clicked.
      final confirmed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => SentryConfirmationDialog(register: prevReg),
        ),
      );
      if (confirmed != true) {
        return; // Abort autofill if not confirmed
      }
      // Reload registers
      allRegsSorted.clear();
      allRegsSorted.addAll(
        List<SentryRegisterModel>.from(sentryProvider.registers)
          ..sort((a, b) => b.date.compareTo(a.date)),
      );
    }

    final eligible = manProvider.getActivePersonnelForDate(_selectedDate).where((p) {
      if (!['FRO', 'KHG', 'Trainees'].contains(p.designation)) return false;
      if (_register!.exemptions.any((e) => e.personnelId == p.idNumber)) return false;
      if (sentryProvider.globalExemptions.any((e) => e.personnelId == p.idNumber)) return false;

      final att = attProvider.attendanceMap[p.id];
      final status = att?.dailyStatus[_selectedDate.day];
      return (status == 'X' || status == null || status.isEmpty || status.toUpperCase() == 'X/R');
    }).toList();

    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No eligible personnel found!')));
      return;
    }

    _saveState();


    Map<String, SentryRegisterModel> dateToReg = {};
    for (var r in allRegsSorted) {
      dateToReg[DateFormat('yyyy-MM-dd').format(r.date)] = r;
    }

    DateTime yesterday = _selectedDate.subtract(const Duration(days: 1));
    DateTime dby = _selectedDate.subtract(const Duration(days: 2));

    SentryRegisterModel? regY =
        dateToReg[DateFormat('yyyy-MM-dd').format(yesterday)];
    SentryRegisterModel? regDBY =
        dateToReg[DateFormat('yyyy-MM-dd').format(dby)];

    bool didPersonGetCreditForSlot(SentryRegisterModel? reg, int slotIdx, String id) {
      if (reg == null) return false;
      if (slotIdx < 0 || slotIdx >= reg.slots.length) return false;
      final slot = reg.slots[slotIdx];
      if (slot.segments != null && slot.segments!.isNotEmpty) {
         for (var seg in slot.segments!) {
            if (seg.personnelId == id) {
                try {
                    final startDt = DateFormat('HH:mm').parse(seg.startTime);
                    var endDt = DateFormat('HH:mm').parse(seg.endTime);
                    if (endDt.isBefore(startDt) || endDt.isAtSameMomentAs(startDt)) endDt = endDt.add(const Duration(days: 1));
                    if (endDt.difference(startDt).inMinutes >= 30) {
                        return true;
                    }
                } catch(_) {}
            }
         }
      } else {
         if (slot.personnelId == id) {
             if (slot.isBroken && slot.brokenTime != null) {
                 try {
                     final parts = slot.timeLabel.split(' - ');
                     final startDt = DateFormat('HH:mm').parse(parts[0].trim());
                     var endDt = DateFormat('HH:mm').parse(slot.brokenTime!);
                     if (endDt.isBefore(startDt) || endDt.isAtSameMomentAs(startDt)) endDt = endDt.add(const Duration(days: 1));
                     if (endDt.difference(startDt).inMinutes >= 30) return true;
                 } catch(_) {}
             } else {
                 return true;
             }
         } else if (slot.replacementPersonnelId == id && slot.brokenTime != null) {
             try {
                 final parts = slot.timeLabel.split(' - ');
                 final startDt = DateFormat('HH:mm').parse(slot.brokenTime!);
                 var endDt = DateFormat('HH:mm').parse(parts[1].trim());
                 if (endDt.isBefore(startDt) || endDt.isAtSameMomentAs(startDt)) endDt = endDt.add(const Duration(days: 1));
                 if (endDt.difference(startDt).inMinutes >= 30) return true;
             } catch(_) {}
         }
      }
      return false;
    }

    int getSlotForPerson(SentryRegisterModel? reg, String id) {
      if (reg == null) return -1;
      for (int i = reg.slots.length - 1; i >= 0; i--) {
        if (didPersonGetCreditForSlot(reg, i, id)) return i;
      }
      return -1;
    }

    Map<String, Map<String, dynamic>> personStats = {};
    DateTime currentMidnight = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    for (var p in eligible) {
      int daysSinceLastDuty = 99999;
      int lastSlot = -1;
      int dutiesSinceSpare = 0;
      bool foundSpare = false;
      bool wasSpareYesterday = false;
      bool wasSpareLastDuty = false;
      bool foundLastActivity = false;

      for (var reg in allRegsSorted) {
        DateTime regMidnight = DateTime(reg.date.year, reg.date.month, reg.date.day);
        if (regMidnight.isBefore(currentMidnight)) {
          int lastDutySlotToday = -1;
          int firstDutySlotToday = -1;

          for (int idx = 0; idx < reg.slots.length; idx++) {
            if (didPersonGetCreditForSlot(reg, idx, p.idNumber)) {
              if (firstDutySlotToday == -1) firstDutySlotToday = idx;
              lastDutySlotToday = idx;
            }
          }

          bool isSpare = reg.spares.contains(p.idNumber);

          if (!foundSpare) {
            if (isSpare) {
              foundSpare = true;
            } else if (lastDutySlotToday != -1) {
              dutiesSinceSpare++;
            }
          }

          if (lastDutySlotToday != -1 || isSpare) {
            if (!foundLastActivity) {
              foundLastActivity = true;
              if (isSpare && lastDutySlotToday == -1) wasSpareLastDuty = true;
            }
          }

          if (isSpare && currentMidnight.difference(regMidnight).inDays == 1) {
            wasSpareYesterday = true;
          }

          if (lastDutySlotToday != -1) {
            int diff = currentMidnight.difference(regMidnight).inDays;
            if (diff < daysSinceLastDuty) {
                daysSinceLastDuty = diff;
                lastSlot = firstDutySlotToday;
            }
          }
        }
      }


      Map<int, int> slotFreqs = {};
      for (var reg in allRegsSorted) {
        DateTime regMidnight = DateTime(reg.date.year, reg.date.month, reg.date.day);
        if (regMidnight.isBefore(currentMidnight) &&
            regMidnight.year == currentMidnight.year && 
            regMidnight.month == currentMidnight.month) {
            for (int idx = 0; idx < reg.slots.length; idx++) {
                if (reg.slots[idx].personnelId == p.idNumber || reg.slots[idx].replacementPersonnelId == p.idNumber) {
                    slotFreqs[idx] = (slotFreqs[idx] ?? 0) + 1;
                }
            }
        }
      }

      int spareBalance = 0;
      for (var reg in allRegsSorted.reversed) {
        DateTime regMidnight = DateTime(
          reg.date.year,
          reg.date.month,
          reg.date.day,
        );
        if (regMidnight.isBefore(currentMidnight) &&
            regMidnight.year == currentMidnight.year && 
            regMidnight.month == currentMidnight.month) {
          int dSlot = getSlotForPerson(reg, p.idNumber);
          // 8 and 9 were used for spare balance accumulation before. Now just check if they are in spares.
          if (reg.spares.contains(p.idNumber)) {
            spareBalance--;
            if (spareBalance < 0) spareBalance = 0;
          }
        }
      }

      final att = attProvider.attendanceMap[p.id];
      bool isXR = att?.dailyStatus[_selectedDate.day]?.toUpperCase() == 'X/R';

      personStats[p.idNumber] = {
        'person': p,
        'daysSinceLastDuty': daysSinceLastDuty,
        'lastSlot': lastSlot,
        'wasSpareYesterday': wasSpareYesterday,
        'wasSpareLastDuty': wasSpareLastDuty,
        'dutiesSinceSpare': dutiesSinceSpare,
        'isXR': isXR,
        'spareBalance': spareBalance,
        'slotFreqs': slotFreqs,
        'ySlot': getSlotForPerson(regY, p.idNumber),
        'dbySlot': getSlotForPerson(regDBY, p.idNumber),
        'assignedToday': 0,
      };
    }

    List<Manpower> activeDutyList = List.from(eligible);
    
    // 1. Sort personnel by the new priorities
    activeDutyList.sort((a, b) {
      String idA = a.idNumber;
      String idB = b.idNumber;

      // Extreme priority for XR personnel
      bool xrA = personStats[idA]!['isXR'];
      bool xrB = personStats[idB]!['isXR'];
      if (xrA && !xrB) return -1;
      if (!xrA && xrB) return 1;

      int daysA = personStats[idA]!['daysSinceLastDuty'];
      int daysB = personStats[idB]!['daysSinceLastDuty'];
      
      // Priority 1: Absentees (days > 2)
      bool isAbsenteeA = daysA > 2;
      bool isAbsenteeB = daysB > 2;
      if (isAbsenteeA && !isAbsenteeB) return -1;
      if (!isAbsenteeA && isAbsenteeB) return 1;
      if (isAbsenteeA && isAbsenteeB) {
          if (daysA != daysB) return daysB.compareTo(daysA);
      }

      // Priority 2: Was Spare Last Duty (prevents consecutive spares)
      bool spareA = personStats[idA]!['wasSpareLastDuty'];
      bool spareB = personStats[idB]!['wasSpareLastDuty'];
      if (spareA && !spareB) return -1;
      if (!spareA && spareB) return 1;

      // Priority 3: Regular vs Continuous (Days == 2 vs Days == 1)
      if (daysA != daysB) return daysB.compareTo(daysA);

      // Priority 4: Last day seniority (first slot of their last duty day) (Ascending)
      int slotA = personStats[idA]!['lastSlot'];
      int slotB = personStats[idB]!['lastSlot'];
      if (slotA != slotB) return slotA.compareTo(slotB); 
      
      // Priority 5: General sort order
      return a.sortOrder.compareTo(b.sortOrder);
    });

    List<Manpower> sparesList = [];
    if (activeDutyList.length > 12) {
      sparesList = activeDutyList.sublist(12);
      activeDutyList = activeDutyList.sublist(0, 12);
    }

    List<SentrySlot> newSlots = _timeLabels.map((t) => SentrySlot(timeLabel: t)).toList();
    Set<int> assignedSlots = {};

    List<int> remainingSlots = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
    
    // Assign 1st turn to the top personnel
    for (var p in activeDutyList) {
      String id = p.idNumber;
      
      for (int i in remainingSlots) {
        if (assignedSlots.contains(i)) continue;
        
        if (personStats[id]!['isXR'] && i > 3) continue;

        bool hasConsecutive = false;
        if (i > 0 && newSlots[i - 1].personnelId == id) hasConsecutive = true;
        if (i < 11 && newSlots[i + 1].personnelId == id) hasConsecutive = true;
        if (hasConsecutive) continue;

        int ySlot = personStats[id]!['ySlot'];
        if (ySlot != -1) {
           if (ySlot == 8 && i < 1) continue;
           if (ySlot == 9 && i < 2) continue;
           if (ySlot == 10 && i < 3) continue;
           if (ySlot == 11 && i < 4) continue;
        }

        // Found the first valid slot for this person!
        newSlots[i] = SentrySlot(
          timeLabel: _timeLabels[i],
          personnelId: id,
        );
        personStats[id]!['assignedToday'] = 1;
        assignedSlots.add(i);
        break; // Move to the next person
      }
    }

    // Second Turn (Fixed Mapping for Shortages)
    List<int> emptyBlackSlots = remainingSlots.where((s) => !assignedSlots.contains(s)).toList();
    if (emptyBlackSlots.isNotEmpty && activeDutyList.isNotEmpty) {
       // Get personnel who got a slot today, sorted by the slot they got (chronological)
       List<Map<String, dynamic>> filledBlackPersonnel = [];
       for (var p in activeDutyList) {
           String id = p.idNumber;
           if (personStats[id]!['isXR']) continue; // XR strictly max 1 duty
           int existingSlot = -1;
           for (int s in remainingSlots) {
               if (newSlots[s].personnelId == id) {
                   existingSlot = s;
                   break;
               }
           }
           if (existingSlot != -1) {
               filledBlackPersonnel.add({'id': id, 'slot': existingSlot});
           }
       }
       
       filledBlackPersonnel.sort((a, b) => (a['slot'] as int).compareTo(b['slot'] as int));
       
       if (filledBlackPersonnel.isNotEmpty) {
           for (int i = 0; i < emptyBlackSlots.length; i++) {
               int emptySlot = emptyBlackSlots[i];
               // Fixed mapping: ith empty slot goes to ith personnel (wrapping around if needed)
               String assignedId = filledBlackPersonnel[i % filledBlackPersonnel.length]['id'];
               
               // Avoid consecutive if possible by swapping with the next person in line
               bool isConsecutive(String pId, int slot) {
                   if (slot > 0 && newSlots[slot - 1].personnelId == pId) return true;
                   if (slot < 11 && newSlots[slot + 1].personnelId == pId) return true;
                   return false;
               }
               
               if (isConsecutive(assignedId, emptySlot) && filledBlackPersonnel.length > 1) {
                   String nextId = filledBlackPersonnel[(i + 1) % filledBlackPersonnel.length]['id'];
                   if (!isConsecutive(nextId, emptySlot)) {
                       assignedId = nextId;
                   }
               }

               newSlots[emptySlot] = SentrySlot(
                   timeLabel: _timeLabels[emptySlot],
                   personnelId: assignedId,
               );
               personStats[assignedId]!['assignedToday'] = (personStats[assignedId]!['assignedToday'] as int) + 1;
               assignedSlots.add(emptySlot);
           }
       }
    }
    
    setState(() {
      _register = SentryRegisterModel(
        id: _register!.id,
        date: _register!.date,
        slots: newSlots,
        spares: sparesList.reversed.map((p) => p.idNumber).toList(),
        exemptions: _register!.exemptions,
      );
    });
  }

  void _triggerEmergency(int emergencySlotIndex) {
    if (_register == null) return;

    _saveState();

    List<SentrySlot> currentSlots = List.from(_register!.slots);
    List<String> currentSpares = List.from(_register!.spares);

    String leavingPersonId = currentSlots[emergencySlotIndex].personnelId;
    if (leavingPersonId.isNotEmpty) {
      currentSpares.add(leavingPersonId);
    }

    for (int i = emergencySlotIndex; i < 11; i++) {
      currentSlots[i] = SentrySlot(
        timeLabel: currentSlots[i].timeLabel,
        personnelId: currentSlots[i + 1].personnelId,
        isBroken: false,
      );
    }

    String newPersonForLastSlot = '';
    if (currentSpares.isNotEmpty) {
      newPersonForLastSlot = currentSpares.first;
      currentSpares.removeAt(0);
    }
    currentSlots[11] = SentrySlot(
      timeLabel: currentSlots[11].timeLabel,
      personnelId: newPersonForLastSlot,
    );

    setState(() {
      _register = SentryRegisterModel(
        id: _register!.id,
        date: _register!.date,
        slots: currentSlots,
        spares: currentSpares,
        exemptions: _register!.exemptions,
      );
    });
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Center(child: Text('സേവ് ചെയ്യാത്ത മാറ്റങ്ങൾ', style: TextStyle(color: Colors.white))),
        content: const Text(
          'സേവ് ചെയ്യാത്ത മാറ്റങ്ങളുണ്ട്.\nസേവ് ചെയ്യാതെ പുറത്ത് പോകണമെന്നുറപ്പാണോ?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.blueAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exit', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }

  Future<void> _changeDate(int days) async {
    if (_hasUnsavedChanges) {
      final confirm = await _onWillPop();
      if (!confirm) return;
    }

    final newDate = _selectedDate.add(Duration(days: days));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minDate = AccessControl.isAdmin(context)
        ? DateTime(2020)
        : today.subtract(const Duration(days: 1));

    if (newDate.isBefore(minDate)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot select older dates.')));
      }
      return;
    }
    if (newDate.isAfter(DateTime(2101))) return;

    final sentryProvider = context.read<SentryProvider>();
    final exists = sentryProvider.registers.any((r) => 
      r.date.year == newDate.year && 
      r.date.month == newDate.month && 
      r.date.day == newDate.day
    );

    if (exists) {
      final unlocked = await showDialog<bool>(
        context: context,
        builder: (context) => LockHoldDialog(date: newDate, title: 'സെൻട്രി രജിസ്റ്റർ ലോക്ക് ചെയ്തിരിക്കുന്നു'),
      );
      if (unlocked != true) return;
    }

    setState(() {
      _selectedDate = newDate;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.orange),
                onPressed: () => _changeDate(-1),
              ),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 24),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.orange),
                onPressed: () => _changeDate(1),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _showHistoryDialog,
            tooltip: 'History',
          ),
          IconButton(
            icon: const Icon(Icons.save, color: Colors.blue),
            onPressed: _saveRegister,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _register == null
          ? const Center(child: Text('Error loading register'))
          : _buildMainContent(),
    ));
  }

  Widget _buildMainContent() {
    final manProvider = context.read<ManpowerProvider>();
    final sentryProvider = context.read<SentryProvider>();
    final attProvider = context.read<AttendanceProvider>();

    final eligiblePersonnel = manProvider.getActivePersonnelForDate(_selectedDate).where((p) {
      if (!['FRO', 'KHG', 'Trainees'].contains(p.designation)) return false;
      if (sentryProvider.globalExemptions.any(
        (e) => e.personnelId == p.idNumber,
      )) {
        return false;
      }

      final att = attProvider.attendanceMap[p.id];
      final status = att?.dailyStatus[_selectedDate.day];
      return (status == 'X' ||
          status == null ||
          status.isEmpty ||
          status.toUpperCase() == 'X/R');
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _autoFill,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Auto Generate Duties', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sentry Duty Slots',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.orange,
                    ),
                    onPressed: () {
                      if (_register == null) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              SentryPdfPreviewScreen(dayRegister: _register!),
                        ),
                      );
                    },
                    tooltip: 'Generate PDF',
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_off, color: Colors.orange),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const SentryExemptionsDialog(),
                      );
                    },
                    tooltip: 'Exemption Entry',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(_register!.slots.length, (index) {
            final slot = _register!.slots[index];
            final person = slot.personnelId.isNotEmpty
                ? eligiblePersonnel.firstWhere(
                    (p) => p.idNumber == slot.personnelId,
                    orElse: () => Manpower(
                      id: '',
                      name: 'Unknown',
                      idNumber: slot.personnelId,
                      designation: '',
                      gender: '',
                      sortOrder: 0,
                      mobileNumber: '',
                      isDriver: false,
                    ),
                  )
                : null;

            return Card(
              color: Colors.white.withOpacity(0.05),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Text(
                  slot.timeLabel,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: person != null
                    ? Text(
                        '${person.name} (${person.idNumber})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      )
                    : const Text(
                        'Tap to assign personnel',
                        style: TextStyle(
                          color: Colors.white54,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (person != null)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _saveState();
                          setState(() {
                            _register!.slots[index] = SentrySlot(
                              timeLabel: slot.timeLabel,
                              personnelId: '',
                              isBroken: slot.isBroken,
                              brokenTime: slot.brokenTime,
                              replacementPersonnelId:
                                  slot.replacementPersonnelId,
                            );
                          });
                        },
                      ),
                    const Icon(Icons.chevron_right, color: Colors.white38),
                  ],
                ),
                onTap: () =>
                    _showAssignmentSheet(context, index, eligiblePersonnel),
              ),
            );
          }),
          const SizedBox(height: 24),
          const Text(
            'Spares (Standby)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_register!.spares.isEmpty)
                  const Text(
                    'No spares available.',
                    style: TextStyle(color: Colors.white54),
                  )
                else
                  ..._register!.spares.map((s) {
                    final p = manProvider.getActivePersonnelForDate(_selectedDate).firstWhere(
                      (p) => p.idNumber == s,
                      orElse: () => Manpower(
                        id: '',
                        name: 'Unknown',
                        idNumber: s,
                        designation: '',
                        gender: '',
                        sortOrder: 0,
                        mobileNumber: '',
                        isDriver: false,
                      ),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.white54,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${p.name} (${p.idNumber})',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            onPressed: () {
                              _saveState();
                              setState(() {
                                _register!.spares.remove(s);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () =>
                      _showSpareAssignmentSheet(context, eligiblePersonnel),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Spare'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent.withOpacity(0.2),
                    foregroundColor: Colors.blueAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAssignmentSheet(
    BuildContext context,
    int slotIndex,
    List<Manpower> eligiblePersonnel,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Assign for ${_register!.slots[slotIndex].timeLabel}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: eligiblePersonnel.length,
                    itemBuilder: (context, index) {
                      final p = eligiblePersonnel[index];
                      // Check how many times they are already assigned today
                      int dutiesToday = _register!.slots
                          .where((s) => s.personnelId == p.idNumber)
                          .length;
                      bool isCurrentlyAssigned =
                          _register!.slots[slotIndex].personnelId == p.idNumber;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getColorForDesignation(
                            p.designation,
                          ).withOpacity(0.2),
                          child: Text(
                            p.designation.substring(0, 1),
                            style: TextStyle(
                              color: _getColorForDesignation(p.designation),
                            ),
                          ),
                        ),
                        title: Text(
                          '${p.name} (${p.idNumber})',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: dutiesToday > 0
                            ? Text(
                                'Assigned $dutiesToday time(s) today',
                                style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 12,
                                ),
                              )
                            : const Text(
                                'Available',
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 12,
                                ),
                              ),
                        trailing: isCurrentlyAssigned
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.blueAccent,
                              )
                            : null,
                        onTap: () {
                          _saveState();
                          setState(() {
                            _register!.spares.remove(p.idNumber);
                            
                            _register!.slots[slotIndex] = SentrySlot(
                              timeLabel: _register!.slots[slotIndex].timeLabel,
                              personnelId: p.idNumber,
                              isBroken: false,
                              brokenTime: null,
                              replacementPersonnelId: null,
                            );
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSpareAssignmentSheet(
    BuildContext context,
    List<Manpower> eligiblePersonnel,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Spare Personnel',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: eligiblePersonnel.length,
                    itemBuilder: (context, index) {
                      final p = eligiblePersonnel[index];
                      bool isAlreadySpare = _register!.spares.contains(
                        p.idNumber,
                      );

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey.withOpacity(0.2),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white54,
                          ),
                        ),
                        title: Text(
                          '${p.name} (${p.idNumber})',
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: isAlreadySpare
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.greenAccent,
                              )
                            : const Icon(
                                Icons.add_circle_outline,
                                color: Colors.blueAccent,
                              ),
                        onTap: () {
                          if (!isAlreadySpare) {
                            _saveState();
                            setState(() {
                              _register!.spares.add(p.idNumber);
                            });
                          }
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _getColorForDesignation(String desig) {
    switch (desig) {
      case 'FRO':
        return Colors.blue;
      case 'KHG':
        return Colors.orange;
      case 'Trainees':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

class SentryHistoryScreen extends StatefulWidget {
  final List<SentryRegisterModel> allRegisters;
  final List<Manpower> personnelList;

  const SentryHistoryScreen({
    super.key,
    required this.allRegisters,
    required this.personnelList,
  });

  @override
  State<SentryHistoryScreen> createState() => _SentryHistoryScreenState();
}

class _SentryHistoryScreenState extends State<SentryHistoryScreen> {
  late DateTime _selectedMonth;
  bool _isSlotWise = false;

  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _bodyScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  @override
  void dispose() {
    _headerScrollController.dispose();
    _bodyScrollController.dispose();
    super.dispose();
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthRegisters =
        widget.allRegisters
            .where(
              (r) =>
                  r.date.year == _selectedMonth.year &&
                  r.date.month == _selectedMonth.month,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Duty History'),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E1E1E),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_left,
                        color: Colors.orange,
                      ),
                      onPressed: _previousMonth,
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(_selectedMonth),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_right,
                        color: Colors.orange,
                      ),
                      onPressed: _nextMonth,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isSlotWise = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _isSlotWise
                                  ? Colors.orange
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Member List',
                              style: TextStyle(
                                color: _isSlotWise
                                    ? Colors.black
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isSlotWise = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !_isSlotWise
                                  ? Colors.orange
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Member Grid',
                              style: TextStyle(
                                color: !_isSlotWise
                                    ? Colors.black
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: monthRegisters.isEmpty
                ? const Center(
                    child: Text(
                      'No duties recorded in this month',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : _isSlotWise
                ? _buildSlotWiseList(monthRegisters)
                : _buildMemberWiseTable(monthRegisters),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotWiseList(List<SentryRegisterModel> monthRegisters) {
    Map<String, List<Map<String, dynamic>>> memberDuties = {};
    for (var reg in monthRegisters) {
      for (var slot in reg.slots) {
        if (slot.personnelId.isNotEmpty) {
          bool originalGetsCredit = true;
          if (slot.isBroken) {
            int diffMins = 0;
            try {
              final startStr = slot.timeLabel.split(' - ')[0];
              final startDt = DateFormat('HH:mm').parse(startStr);
              final breakDt = DateFormat('HH:mm').parse(slot.brokenTime!);
              diffMins = breakDt.difference(startDt).inMinutes;
              if (diffMins < 0) diffMins += 24 * 60;
            } catch (e) {}
            if (diffMins < 30) originalGetsCredit = false;
          }

          if (originalGetsCredit) {
            memberDuties.putIfAbsent(slot.personnelId, () => []).add({
              'date': reg.date,
              'timeLabel': slot.isBroken
                  ? '${slot.timeLabel} (Broken at ${slot.brokenTime})'
                  : slot.timeLabel,
            });
          }

          if (slot.isBroken &&
              slot.replacementPersonnelId != null &&
              slot.replacementPersonnelId!.isNotEmpty) {
            memberDuties
                .putIfAbsent(slot.replacementPersonnelId!, () => [])
                .add({
                  'date': reg.date,
                  'timeLabel': '${slot.timeLabel} (Replaced original)',
                });
          }
        }
      }
    }

    if (memberDuties.isEmpty) {
      return const Center(
        child: Text(
          'No duties assigned',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    var activeMembers = widget.personnelList
        .where((p) => memberDuties.containsKey(p.idNumber))
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activeMembers.length,
      itemBuilder: (context, index) {
        final p = activeMembers[index];
        final duties = memberDuties[p.idNumber]!;
        duties.sort(
          (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
        );

        return Card(
          color: const Color(0xFF1E1E1E),
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(p.name, style: const TextStyle(color: Colors.white70)),
            iconColor: Colors.orange,
            collapsedIconColor: Colors.white54,
            children: duties.map((d) {
              return ListTile(
                title: Text(
                  DateFormat('dd MMM yyyy').format(d['date']),
                  style: const TextStyle(color: Colors.orange, fontSize: 13),
                ),
                subtitle: Text(
                  d['timeLabel'],
                  style: const TextStyle(color: Colors.white),
                ),
                dense: true,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildMemberWiseTable(List<SentryRegisterModel> monthRegisters) {
    Map<String, Map<int, List<String>>> memberDayDuties = {};
    for (var reg in monthRegisters) {
      int day = reg.date.day;
      for (var slot in reg.slots) {
        if (slot.personnelId.isNotEmpty) {
          bool originalGetsCredit = true;
          if (slot.isBroken) {
            int diffMins = 0;
            try {
              final startStr = slot.timeLabel.split(' - ')[0];
              final startDt = DateFormat('HH:mm').parse(startStr);
              final breakDt = DateFormat('HH:mm').parse(slot.brokenTime!);
              diffMins = breakDt.difference(startDt).inMinutes;
              if (diffMins < 0) diffMins += 24 * 60;
            } catch (e) {}
            if (diffMins < 30) originalGetsCredit = false;
          }

          if (originalGetsCredit) {
            memberDayDuties.putIfAbsent(slot.personnelId, () => {});
            memberDayDuties[slot.personnelId]!
                .putIfAbsent(day, () => [])
                .add(slot.timeLabel);
          }

          if (slot.isBroken &&
              slot.replacementPersonnelId != null &&
              slot.replacementPersonnelId!.isNotEmpty) {
            memberDayDuties.putIfAbsent(slot.replacementPersonnelId!, () => {});
            memberDayDuties[slot.replacementPersonnelId!]!
                .putIfAbsent(day, () => [])
                .add(slot.timeLabel);
          }
        }
      }
    }

    if (memberDayDuties.isEmpty) {
      return const Center(
        child: Text(
          'No duties assigned',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    int daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    var activeMembers = widget.personnelList
        .where((p) => memberDayDuties.containsKey(p.idNumber))
        .toList();

    const double leftColWidth = 140.0;
    const double dayColWidth = 48.0;

    return Column(
      children: [
        // Fixed Top Header Row
        Container(
          color: const Color(0xFF2A2A2A),
          child: Row(
            children: [
              Container(
                width: leftColWidth,
                padding: const EdgeInsets.all(12),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Name',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _headerScrollController,
                  scrollDirection: Axis.horizontal,
                  physics:
                      const NeverScrollableScrollPhysics(), // Prevent manual scrolling of header
                  child: Row(
                    children: List.generate(
                      daysInMonth,
                      (index) => Container(
                        width: dayColWidth,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Scrollable Body
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sticky Left Column (Names)
                Container(
                  width: leftColWidth,
                  color: const Color(0xFF1E1E1E),
                  child: Column(
                    children: activeMembers
                        .map(
                          (p) => Container(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.centerLeft,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.white12),
                              ),
                            ),
                            child: Text(
                              p.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                // Scrollable Grid
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification notification) {
                      if (notification is ScrollUpdateNotification) {
                        _headerScrollController.jumpTo(
                          _bodyScrollController.offset,
                        );
                      }
                      return false;
                    },
                    child: SingleChildScrollView(
                      controller: _bodyScrollController,
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        children: activeMembers
                            .map(
                              (p) => Container(
                                height: 50,
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: Colors.white12),
                                  ),
                                ),
                                child: Row(
                                  children: List.generate(
                                    daysInMonth,
                                    (index) => Container(
                                      width: dayColWidth,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          left: BorderSide(
                                            color: Colors.white12,
                                          ),
                                        ),
                                      ),
                                      child: _buildDutyCell(
                                        memberDayDuties[p.idNumber]?[index + 1],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDutyCell(List<String>? labels) {
    if (labels == null || labels.isEmpty) {
      return const Center(
        child: Text('-', style: TextStyle(color: Colors.white24)),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: labels.map((label) {
        Color c = Colors.white70;
        Color bgColor = Colors.transparent;
        String shortLabel = "";

        if (label.contains("09:00 - 11:00")) {
          shortLabel = "09-11";
        } else if (label.contains("11:00 - 13:00"))
          shortLabel = "11-13";
        else if (label.contains("13:00 - 15:00"))
          shortLabel = "13-15";
        else if (label.contains("15:00 - 17:00"))
          shortLabel = "15-17";
        else if (label.contains("17:00 - 19:00"))
          shortLabel = "17-19";
        else if (label.contains("19:00 - 21:00"))
          shortLabel = "19-21";
        else if (label.contains("21:00 - 23:00"))
          shortLabel = "21-23";
        else if (label.contains("23:00 - 01:00")) {
          shortLabel = "23-01";
          c = Colors.greenAccent;
          bgColor = Colors.green.withOpacity(0.2);
        } else if (label.contains("01:00 - 03:00")) {
          shortLabel = "01-03";
          c = Colors.redAccent;
          bgColor = Colors.red.withOpacity(0.2);
        } else if (label.contains("03:00 - 05:00")) {
          shortLabel = "03-05";
          c = Colors.redAccent;
          bgColor = Colors.red.withOpacity(0.2);
        } else if (label.contains("05:00 - 07:00")) {
          shortLabel = "05-07";
          c = Colors.greenAccent;
          bgColor = Colors.green.withOpacity(0.2);
        } else if (label.contains("07:00 - 09:00"))
          shortLabel = "07-09";

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          margin: const EdgeInsets.only(bottom: 1),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            shortLabel,
            style: TextStyle(
              color: c,
              fontSize: 10,
              fontWeight: c != Colors.white70
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        );
      }).toList(),
    );
  }
}
