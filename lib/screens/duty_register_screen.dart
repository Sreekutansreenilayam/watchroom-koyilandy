import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'duty_history_screen.dart';
import '../widgets/lock_hold_dialog.dart';
import '../models/duty_register_model.dart';
import '../models/manpower_model.dart';
import '../services/access_control.dart';
import '../providers/duty_provider.dart';
import '../providers/manpower_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/sentry_provider.dart';
import '../models/sentry_register_model.dart';

class ColoredTextEditingController extends TextEditingController {
  List<String> highlightWords;

  ColoredTextEditingController({this.highlightWords = const [], super.text});

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (highlightWords.isEmpty || text.isEmpty) {
      return TextSpan(text: text, style: style);
    }
    List<TextSpan> spans = [];
    final parts = text.split(',');
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      final trimmed = part.trim();
      if (trimmed.isEmpty) {
        spans.add(TextSpan(text: part + (i < parts.length - 1 ? ',' : ''), style: style));
        continue;
      }
      bool highlight = highlightWords.any((w) => trimmed.contains(w));
      spans.add(TextSpan(
        text: part + (i < parts.length - 1 ? ',' : ''),
        style: style?.copyWith(color: highlight ? Colors.greenAccent : null, fontWeight: highlight ? FontWeight.bold : null),
      ));
    }
    return TextSpan(children: spans, style: style);
  }
}

class DutyRegisterScreen extends StatefulWidget {
  const DutyRegisterScreen({super.key});

  @override
  State<DutyRegisterScreen> createState() => _DutyRegisterScreenState();
}

class _DutyRegisterScreenState extends State<DutyRegisterScreen> {
  int _currentStep = 0;

  // General Info
  DateTime _selectedDate = DateTime.now();
  bool _isDateSelected = false;
  final _timeController = TextEditingController();
  final _vacancyCountController = TextEditingController();
  final _vacancyDetailsController = TextEditingController();
  String _selectedShift = '24 Hrs';

  // Section 2: Overrides and Manual Selections
  List<String> _stationWriterIds = [];
  List<String> _specialDutyIds = [];
  List<String> _trainingOverrideIds = [];
  String _existingRegisterId = '';

  // Section 4: Other Duties
  List<String> _phoneDutyIds = [];
  List<String> _messengerIds = [];
  List<String> _sentryDutyIds = [];
  List<String> _controlRoomIds = [];

  // Section 3: Vehicles
  List<DutyVehicleAssignment> _vehicles = [];
  final Map<String, bool> _vehicleOffRoadStatus = {};
  final Map<String, bool> _vehicleAttachedStatus = {};

  List<DutyVehicleAssignment> _getDefaultVehicles({DateTime? targetDate}) {
    final date = targetDate ?? _selectedDate;
    final isNewRule = !date.isBefore(DateTime(2026, 7, 23));
    
    return [
      DutyVehicleAssignment(vehicleName: 'F/T KL-01-CS-2796', seniority: isNewRule ? 1 : 2),
      DutyVehicleAssignment(vehicleName: 'W/B KL-01-CK-2479', seniority: isNewRule ? 2 : 3),
      DutyVehicleAssignment(vehicleName: 'MTU KL-01-BU-843', seniority: isNewRule ? 3 : 1),
      DutyVehicleAssignment(vehicleName: 'FRV KL-01-CL-4213', seniority: 4),
      DutyVehicleAssignment(
        vehicleName: 'SCUBA VEH. KL-01-CE-1669', 
        seniority: 5,
        isAttached: true,
        remarks: 'FRS, Vellimadukunnu',
      ),
      DutyVehicleAssignment(vehicleName: 'AMB KL-01-CS-2707', seniority: 6),
      DutyVehicleAssignment(vehicleName: 'JEEP KL-01-CS-1207', seniority: 7),
      DutyVehicleAssignment(vehicleName: 'ICV KL-01-CU-9768', seniority: 8),
      DutyVehicleAssignment(vehicleName: 'CCV KL-01-CU-5201', seniority: 9),
      DutyVehicleAssignment(vehicleName: 'BULLET KL-01-BG-3497', seniority: 10),
      DutyVehicleAssignment(vehicleName: 'TC KL-01-CY-1774', seniority: 11),
      DutyVehicleAssignment(vehicleName: 'QRV KL-01-BF-8623', seniority: 12),
      DutyVehicleAssignment(vehicleName: isNewRule ? 'C/S - 1, 7, 8, 13, Aska-III (I-F/T)' : 'C/S - 1, 7, 8, 13, Aska-III (I-MTU)', seniority: 13),
      DutyVehicleAssignment(vehicleName: isNewRule ? 'C/S - 4, 5, 6, 11, Fanergy, Float Pump, Hydraulic Lukas (II-W/B)' : 'C/S - 4, 5, 6, 11, Fanergy, Float Pump, Hydraulic Lukas (F/T)', seniority: 14),
      DutyVehicleAssignment(vehicleName: 'C/S-2, 3, 9, 10, 12, Gen EU-65, EXK-2800, OBM, Mini Moon Light (QRV)', seniority: 15),
      DutyVehicleAssignment(vehicleName: 'Wireless, Interactive Flat Panel Display', seniority: 16),
      DutyVehicleAssignment(vehicleName: 'Blower, Torch set', seniority: 17),
      DutyVehicleAssignment(vehicleName: 'BA Set, Gas Detector', seniority: 18),
    ];
  }

  // We map the editable controllers for vehicles by vehicleName
  final Map<String, TextEditingController> _sfroControllers = {};
  final Map<String, TextEditingController> _froControllers = {};
  final Map<String, TextEditingController> _khgControllers = {};
  final Map<String, TextEditingController> _froDControllers = {};
  final Map<String, TextEditingController> _remarksControllers = {};
  final Map<String, List<String>> _manuallyEditedIdsPerVehicle = {};

  String _toRoman(int number) {
    const romanMap = {1: 'I', 2: 'II', 3: 'III', 4: 'IV', 5: 'V', 6: 'VI', 7: 'VII', 8: 'VIII', 9: 'IX', 10: 'X', 11: 'XI', 12: 'XII', 13: 'XIII', 14: 'XIV', 15: 'XV', 16: 'XVI', 17: 'XVII', 18: 'XVIII', 19: 'XIX', 20: 'XX'};
    return romanMap[number] ?? number.toString();
  }

  bool _hasDuplicateSeniority(int seniority) {
    int count = _vehicles.where((v) => v.seniority == seniority).length;
    return count > 1;
  }

  void _initOrUpdateControllers(List<DutyVehicleAssignment> assignments) {
    for (var v in assignments) {
      final vName = v.vehicleName;
      _sfroControllers.putIfAbsent(vName, () => ColoredTextEditingController()).text = v.sfro;
      _froControllers.putIfAbsent(vName, () => TextEditingController()).text = v.fro;
      _khgControllers.putIfAbsent(vName, () => TextEditingController()).text = v.khg;
      _froDControllers.putIfAbsent(vName, () => TextEditingController()).text = v.froD;
      
      // Migrate legacy SCUBA remarks to Attached state
      bool isLegacyScuba = vName == 'SCUBA VEH. KL-01-CE-1669' && 
                           !v.isAttached && 
                           !v.isOffRoad && 
                           (v.remarks.contains('Vellimadukunnu') || v.remarks.isEmpty || v.remarks.contains('Attached'));
                           
      String initialRemarks = isLegacyScuba ? 'FRS, Vellimadukunnu' : v.remarks;
      _remarksControllers.putIfAbsent(vName, () => TextEditingController()).text = initialRemarks;
      
      if (isLegacyScuba) {
        _vehicleAttachedStatus[vName] = true;
      }
      _manuallyEditedIdsPerVehicle[vName] = List.from(v.manuallyEditedIds);

      // Apply highlights
      if (_sfroControllers[vName] is ColoredTextEditingController) {
        (_sfroControllers[vName] as ColoredTextEditingController).highlightWords = _manuallyEditedIdsPerVehicle[vName]!;
      }
      if (_froControllers[vName] is ColoredTextEditingController) {
        (_froControllers[vName] as ColoredTextEditingController).highlightWords = _manuallyEditedIdsPerVehicle[vName]!;
      }
      if (_khgControllers[vName] is ColoredTextEditingController) {
        (_khgControllers[vName] as ColoredTextEditingController).highlightWords = _manuallyEditedIdsPerVehicle[vName]!;
      }
      if (_froDControllers[vName] is ColoredTextEditingController) {
        (_froDControllers[vName] as ColoredTextEditingController).highlightWords = _manuallyEditedIdsPerVehicle[vName]!;
      }

      // SCUBA logic removed
      if (vName == 'CCV KL-01-CU-5201') {
        _froDControllers[vName]!.text = '2311';
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _vehicles = _getDefaultVehicles();
    _timeController.text = '08:45';
    _initOrUpdateControllers(_vehicles);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<AttendanceProvider>().loadAttendanceForMonth(_selectedDate);
      
      final dutyProvider = context.read<DutyProvider>();
      if (dutyProvider.registers.isEmpty) {
        await dutyProvider.fetchDutyRegisters();
      }
      
      final sentryProvider = context.read<SentryProvider>();
      if (sentryProvider.registers.isEmpty) {
        await sentryProvider.fetchSentryRegisters();
      }
      if (mounted && _isDateSelected) {
        _loadDataForDate(_selectedDate);
      }
    });
  }

  void _loadDataForDate(DateTime date) {
    final dutyProvider = context.read<DutyProvider>();
    final existingRegister = dutyProvider.registers.where((r) => 
      r.date.year == date.year && 
      r.date.month == date.month && 
      r.date.day == date.day
    ).firstOrNull;

    if (existingRegister != null) {
      // Editing Mode
      setState(() {
        _existingRegisterId = existingRegister.id;
        _timeController.text = existingRegister.rollCallTime;
        _vacancyCountController.text = existingRegister.vacancyCount;
        _vacancyDetailsController.text = existingRegister.vacancyDetails;
        _selectedShift = existingRegister.shift;
        
        _stationWriterIds = List.from(existingRegister.stationWriterIds);
        _specialDutyIds = List.from(existingRegister.specialDutyIds);
        _trainingOverrideIds = List.from(existingRegister.trainingOverrideIds);

        final completeVehiclesList = List<DutyVehicleAssignment>.from(existingRegister.vehicleAssignments);
        
        // Remove TRU safely
        completeVehiclesList.removeWhere((v) => v.vehicleName.contains('TRU'));
        final isNewRule = !date.isBefore(DateTime(2026, 7, 23));
        
        // Remove standalone Blower and Torch set since they are merged
        completeVehiclesList.removeWhere((v) => v.vehicleName == 'Blower' || v.vehicleName == 'Torch set');

        // Migrate old vehicle names
        for (int i = 0; i < completeVehiclesList.length; i++) {
          final vName = completeVehiclesList[i].vehicleName;
          if (vName == 'C/S: 1/15, 3/15, 6/15, ASKA-III & Hy.Eq-I (I-MTU)' || vName == 'C/S - 1, 7, 8, 13, Aska-III (I-MTU)' || vName == 'C/S - 1, 7, 8, 13, Aska-III (I-F/T)') {
            completeVehiclesList[i] = DutyVehicleAssignment(
              vehicleName: isNewRule ? 'C/S - 1, 7, 8, 13, Aska-III (I-F/T)' : 'C/S - 1, 7, 8, 13, Aska-III (I-MTU)',
              seniority: completeVehiclesList[i].seniority,
              sfro: completeVehiclesList[i].sfro,
              fro: completeVehiclesList[i].fro,
              khg: completeVehiclesList[i].khg,
              froD: completeVehiclesList[i].froD,
              remarks: completeVehiclesList[i].remarks,
              isOffRoad: completeVehiclesList[i].isOffRoad,
              isAttached: completeVehiclesList[i].isAttached,
              manuallyEditedIds: completeVehiclesList[i].manuallyEditedIds,
            );
          } else if (vName == 'C/S: 1, 2, 3, 4, 5, Hy.Eq. II & A/J (II-MTU)' || vName == 'C/S - 4, 5, 6, 11, Fanergy, Float Pump, Hydraulic Lukas (F/T)' || vName == 'C/S - 4, 5, 6, 11, Fanergy, Float Pump, Hydraulic Lukas (II-W/B)') {
            completeVehiclesList[i] = DutyVehicleAssignment(
              vehicleName: isNewRule ? 'C/S - 4, 5, 6, 11, Fanergy, Float Pump, Hydraulic Lukas (II-W/B)' : 'C/S - 4, 5, 6, 11, Fanergy, Float Pump, Hydraulic Lukas (F/T)',
              seniority: completeVehiclesList[i].seniority,
              sfro: completeVehiclesList[i].sfro,
              fro: completeVehiclesList[i].fro,
              khg: completeVehiclesList[i].khg,
              froD: completeVehiclesList[i].froD,
                 remarks: completeVehiclesList[i].remarks,
                 isOffRoad: completeVehiclesList[i].isOffRoad,
                 isAttached: completeVehiclesList[i].isAttached,
                 manuallyEditedIds: completeVehiclesList[i].manuallyEditedIds,
            );
          } else if (vName == 'C/S: 1/22, F/P, P/S, Gen-I & II, PTEL, Portable Pump, OB Engine (QRV)' || 
              vName == 'C/S: 1/22, F/P, P/S, Gen-I & II & PTEL (QRV)' || 
              vName == 'C/S: 1/22, F/P, P/S, Gen-I & II, PTEL, Portable Pump, Outboard Engine (QRV)' ||
              vName == 'C/S-10, Gen EU-65, EXK-2800, OBM, Mini Moon Light') {
            completeVehiclesList[i] = DutyVehicleAssignment(
              vehicleName: 'C/S-2, 3, 9, 10, 12, Gen EU-65, EXK-2800, OBM, Mini Moon Light (QRV)',
              seniority: completeVehiclesList[i].seniority,
              sfro: completeVehiclesList[i].sfro,
              fro: completeVehiclesList[i].fro,
              khg: completeVehiclesList[i].khg,
              froD: completeVehiclesList[i].froD,
                 remarks: completeVehiclesList[i].remarks,
                 isOffRoad: completeVehiclesList[i].isOffRoad,
                 isAttached: completeVehiclesList[i].isAttached,
                 manuallyEditedIds: completeVehiclesList[i].manuallyEditedIds,
            );
          } else if (vName == 'Wireless') {
            completeVehiclesList[i] = DutyVehicleAssignment(
              vehicleName: 'Wireless, Interactive Flat Panel Display',
              seniority: completeVehiclesList[i].seniority,
              sfro: completeVehiclesList[i].sfro,
              fro: completeVehiclesList[i].fro,
              khg: completeVehiclesList[i].khg,
              froD: completeVehiclesList[i].froD,
              remarks: completeVehiclesList[i].remarks,
              isOffRoad: completeVehiclesList[i].isOffRoad,
              isAttached: completeVehiclesList[i].isAttached,
              manuallyEditedIds: completeVehiclesList[i].manuallyEditedIds,
            );
          }
        }

        final defaults = _getDefaultVehicles();
        for (var defaultV in defaults) {
          if (!completeVehiclesList.any((v) => v.vehicleName == defaultV.vehicleName)) {
            completeVehiclesList.add(defaultV);
          }
        }
        
        // Align existing vehicle seniorities with default ones
        for (int i = 0; i < completeVehiclesList.length; i++) {
           var name = completeVehiclesList[i].vehicleName;
           var defaultIndex = defaults.indexWhere((dv) => dv.vehicleName == name);
           if (defaultIndex != -1) {
              completeVehiclesList[i] = DutyVehicleAssignment(
                 vehicleName: name,
                 seniority: defaults[defaultIndex].seniority,
                 sfro: completeVehiclesList[i].sfro,
                 fro: completeVehiclesList[i].fro,
                 khg: completeVehiclesList[i].khg,
                 froD: completeVehiclesList[i].froD,
                 remarks: completeVehiclesList[i].remarks,
                 isOffRoad: completeVehiclesList[i].isOffRoad,
                 isAttached: completeVehiclesList[i].isAttached,
                 manuallyEditedIds: completeVehiclesList[i].manuallyEditedIds,
              );
           }
        }
        
        completeVehiclesList.sort((a, b) => a.seniority.compareTo(b.seniority));

        // Enforce strictly ascending, non-duplicate seniorities
        int nextValid = 1;
        for (int i = 0; i < completeVehiclesList.length; i++) {
          if (completeVehiclesList[i].seniority < nextValid) {
            completeVehiclesList[i] = DutyVehicleAssignment(
                 vehicleName: completeVehiclesList[i].vehicleName,
                 seniority: nextValid,
                 sfro: completeVehiclesList[i].sfro,
                 fro: completeVehiclesList[i].fro,
                 khg: completeVehiclesList[i].khg,
                 froD: completeVehiclesList[i].froD,
                 remarks: completeVehiclesList[i].remarks,
                 isOffRoad: completeVehiclesList[i].isOffRoad,
                 isAttached: completeVehiclesList[i].isAttached,
                 manuallyEditedIds: completeVehiclesList[i].manuallyEditedIds,
            );
          }
          nextValid = completeVehiclesList[i].seniority + 1;
        }

        _vehicles = completeVehiclesList;
        _vehicleOffRoadStatus.clear();
        _vehicleAttachedStatus.clear();
        for (var v in _vehicles) {
          _vehicleOffRoadStatus[v.vehicleName] = v.isOffRoad;
          _vehicleAttachedStatus[v.vehicleName] = v.isAttached;
        }
        _initOrUpdateControllers(_vehicles);

        _phoneDutyIds = List.from(existingRegister.phoneDutyIds);
        _messengerIds = List.from(existingRegister.messengerIds);
        _sentryDutyIds = List.from(existingRegister.sentryDutyIds);
        _controlRoomIds = List.from(existingRegister.controlRoomIds);
      });
    } else {
      // Create Mode
      setState(() {
        _existingRegisterId = '';
        _timeController.text = '08:45';
        _vacancyCountController.clear();
        _vacancyDetailsController.clear();
        _selectedShift = '24 Hrs';
        
        _vehicles = _getDefaultVehicles();
        _vehicleOffRoadStatus.clear();
        _vehicleAttachedStatus.clear();
        for (var v in _vehicles) {
          _vehicleOffRoadStatus[v.vehicleName] = v.isOffRoad;
          _vehicleAttachedStatus[v.vehicleName] = v.isAttached;
        }
        _initOrUpdateControllers(_vehicles);

        // Load overridable defaults from previous register if available
        if (dutyProvider.registers.isNotEmpty) {
          DutyRegisterModel? previousRegister;
          for (var reg in dutyProvider.registers) {
            DateTime regDate = DateTime(reg.date.year, reg.date.month, reg.date.day);
            DateTime selDate = DateTime(date.year, date.month, date.day);
            if (regDate.isBefore(selDate)) {
              previousRegister = reg;
              break;
            }
          }
          previousRegister ??= dutyProvider.registers.first;

          _stationWriterIds = List.from(previousRegister.stationWriterIds);
          
          // Find the most recent register (before selected date) that actually has vacancy details
          DutyRegisterModel? registerWithVacancy;
          for (var reg in dutyProvider.registers) {
            DateTime regDate = DateTime(reg.date.year, reg.date.month, reg.date.day);
            DateTime selDate = DateTime(date.year, date.month, date.day);
            if (regDate.isBefore(selDate) && (reg.vacancyCount.isNotEmpty || reg.vacancyDetails.isNotEmpty)) {
              registerWithVacancy = reg;
              break;
            }
          }
          registerWithVacancy ??= previousRegister;

          _vacancyCountController.text = registerWithVacancy.vacancyCount;
          _vacancyDetailsController.text = registerWithVacancy.vacancyDetails;
          
          _phoneDutyIds = [];
          _messengerIds = [];
          _sentryDutyIds = [];
          _controlRoomIds = [];

          for (int i = 0; i < _vehicles.length; i++) {
            var v = _vehicles[i];
            final vName = v.vehicleName;
            _sfroControllers[vName]!.clear();
            _froControllers[vName]!.clear();
            _khgControllers[vName]!.clear();
            _froDControllers[vName]!.clear();
            
            // Handle migrated vehicle names for backwards compatibility
            final isNewRule = !date.isBefore(DateTime(2026, 7, 23));
            var prevV = previousRegister.vehicleAssignments.where((pv) {
               String pvName = pv.vehicleName;
               if (pvName == 'C/S: 1/15, 3/15, 6/15, ASKA-III & Hy.Eq-I (I-MTU)' || pvName == 'C/S - 1, 7, 8, 13, Aska-III (I-MTU)' || pvName == 'C/S - 1, 7, 8, 13, Aska-III (I-F/T)') {
                 pvName = isNewRule ? 'C/S - 1, 7, 8, 13, Aska-III (I-F/T)' : 'C/S - 1, 7, 8, 13, Aska-III (I-MTU)';
               } else if (pvName == 'C/S: 1, 2, 3, 4, 5, Hy.Eq. II & A/J (II-MTU)' || pvName == 'C/S - 4, 5, 6, 11, Fanergy, Float Pump, Hydraulic Lukas (F/T)' || pvName == 'C/S - 4, 5, 6, 11, Fanergy, Float Pump, Hydraulic Lukas (II-W/B)') {
                 pvName = isNewRule ? 'C/S - 4, 5, 6, 11, Fanergy, Float Pump, Hydraulic Lukas (II-W/B)' : 'C/S - 4, 5, 6, 11, Fanergy, Float Pump, Hydraulic Lukas (F/T)';
               } else if (pvName == 'C/S: 1/22, F/P, P/S, Gen-I & II, PTEL, Portable Pump, OB Engine (QRV)' || 
                   pvName == 'C/S: 1/22, F/P, P/S, Gen-I & II & PTEL (QRV)' || 
                   pvName == 'C/S: 1/22, F/P, P/S, Gen-I & II, PTEL, Portable Pump, Outboard Engine (QRV)' ||
                   pvName == 'C/S-10, Gen EU-65, EXK-2800, OBM, Mini Moon Light') {
                 pvName = 'C/S-2, 3, 9, 10, 12, Gen EU-65, EXK-2800, OBM, Mini Moon Light (QRV)';
               }
               return pvName.trim() == vName.trim();
            }).firstOrNull;
            if (prevV != null) {
              bool isLegacyScuba = vName == 'SCUBA VEH. KL-01-CE-1669' && 
                                   !prevV.isAttached && 
                                   !prevV.isOffRoad && 
                                   (prevV.remarks.contains('Vellimadukunnu') || prevV.remarks.isEmpty || prevV.remarks.contains('Attached'));
              
              _vehicleOffRoadStatus[vName] = prevV.isOffRoad;
              _vehicleAttachedStatus[vName] = isLegacyScuba ? true : prevV.isAttached;
              _remarksControllers[vName]!.text = isLegacyScuba ? 'FRS, Vellimadukunnu' : prevV.remarks;
              
              _vehicles[i] = DutyVehicleAssignment(
                 vehicleName: vName,
                 seniority: v.seniority,
                 sfro: '',
                 fro: '',
                 khg: '',
                 froD: '',
                 remarks: _remarksControllers[vName]!.text,
                 isOffRoad: _vehicleOffRoadStatus[vName]!,
                 isAttached: _vehicleAttachedStatus[vName]!,
              );
            } else {
              _remarksControllers[vName]!.clear();
            }
          }
        } else {
          _stationWriterIds = [];
          _specialDutyIds = [];
          _trainingOverrideIds = [];
          _phoneDutyIds = [];
          _messengerIds = [];
          _sentryDutyIds = [];
          _controlRoomIds = [];

          for (var v in _vehicles) {
            final vName = v.vehicleName;
            _sfroControllers[vName]!.clear();
            _froControllers[vName]!.clear();
            _khgControllers[vName]!.clear();
            _froDControllers[vName]!.clear();
            _remarksControllers[vName]!.clear();
          }
        }
      });
    }

    // Auto-fetch Sentry Duty personnel for the date (works for both Create and Edit modes)
    setState(() {
      final sentryProvider = context.read<SentryProvider>();
      SentryRegisterModel? todaySentry;
      for (var reg in sentryProvider.registers) {
        if (reg.date.year == date.year && reg.date.month == date.month && reg.date.day == date.day) {
          todaySentry = reg;
          break;
        }
      }
      if (todaySentry != null && todaySentry.slots.isNotEmpty) {
         final firstSlot = todaySentry.slots.first; // usually 09:00 - 11:00
         if (firstSlot.personnelId.isNotEmpty) {
           _sentryDutyIds = [firstSlot.personnelId];
         }
      }
    });
  }

  @override
  void dispose() {
    _timeController.dispose();
    _vacancyCountController.dispose();
    _vacancyDetailsController.dispose();
    for (var c in _sfroControllers.values) {
      c.dispose();
    }
    for (var c in _froControllers.values) {
      c.dispose();
    }
    for (var c in _khgControllers.values) {
      c.dispose();
    }
    for (var c in _froDControllers.values) {
      c.dispose();
    }
    for (var c in _remarksControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minDate = AccessControl.isAdmin(context) ? DateTime(2020) : today.subtract(const Duration(days: 1));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: minDate,
      lastDate: DateTime(2101),
    );
    if (picked != null && (picked != _selectedDate || !_isDateSelected)) {
      final dutyProvider = context.read<DutyProvider>();
      final exists = dutyProvider.registers.any((r) => 
        r.date.year == picked.year && 
        r.date.month == picked.month && 
        r.date.day == picked.day
      );

      if (exists) {
        final unlocked = await showDialog<bool>(
          context: context,
          builder: (context) => LockHoldDialog(date: picked, title: 'രജിസ്റ്റർ ലോക്ക് ചെയ്തിരിക്കുന്നു'),
        );
        if (unlocked != true) return;
      }

      setState(() {
        _selectedDate = picked;
        _isDateSelected = true;
      });
      context.read<AttendanceProvider>().loadAttendanceForMonth(_selectedDate);
      _loadDataForDate(_selectedDate);
    }
  }

  Manpower? _getSeniorMostFroAsSfro() {
    final personnelList = context.read<ManpowerProvider>().getActivePersonnelForDate(_selectedDate);
    final attendanceMap = context.read<AttendanceProvider>().attendanceMap;
    final day = _selectedDate.day;

    bool hasSfro = false;
    for (var p in personnelList) {
      if (['SFRO', 'SFRO (M)'].contains(p.designation)) {
        final att = attendanceMap[p.id];
        final status = att?.dailyStatus[day];
        if (status == 'X' || status == null || status.trim().isEmpty || status.toUpperCase() == 'X/R') {
          hasSfro = true;
          break;
        }
      }
    }

    if (!hasSfro) {
      final froList = personnelList.where((p) {
        if (p.designation != 'FRO') return false;
        final att = attendanceMap[p.id];
        final status = att?.dailyStatus[day];
        return (status == 'X' || status == null || status.trim().isEmpty || status.toUpperCase() == 'X/R');
      }).toList();
      
      if (froList.isNotEmpty) {
        froList.sort((a, b) {
          if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
          return _getSeniorityRank(a.idNumber).compareTo(_getSeniorityRank(b.idNumber));
        });
        return froList.first;
      }
    }
    return null;
  }

  List<Manpower> _getOnDutyPersonnel(String category) {
    final personnelList = context.read<ManpowerProvider>().getActivePersonnelForDate(_selectedDate);
    final attendanceMap = context.read<AttendanceProvider>().attendanceMap;
    final day = _selectedDate.day;
    final seniorMostFroAsSfro = _getSeniorMostFroAsSfro();

    return personnelList.where((p) {
      if (_stationWriterIds.contains(p.idNumber)) return false; // Exclude Station Writers
      final attendance = attendanceMap[p.id];
      final status = attendance?.dailyStatus[day];
      if (status == 'X' || status == null || status.trim().isEmpty || status.toUpperCase() == 'X/R') {
        if (category == 'SFRO') {
          if (seniorMostFroAsSfro != null && p.id == seniorMostFroAsSfro.id) return true;
          return ['SFRO', 'SFRO (M)', 'STO', 'ASTO'].contains(p.designation);
        } else if (category == 'FRO') {
          if (seniorMostFroAsSfro != null && p.id == seniorMostFroAsSfro.id) return false;
          return p.designation == 'FRO';
        } else if (category == 'KHG') {
          return p.designation == 'KHG';
        } else if (category == 'FRO(D)') {
          return p.designation == 'FRO (D)';
        }
      }
      return false;
    }).toList();
  }

  List<Manpower> _getOtherDutiesPersonnel({bool includeSfroM = true}) {
    final personnelList = context.read<ManpowerProvider>().getActivePersonnelForDate(_selectedDate);
    final attendanceMap = context.read<AttendanceProvider>().attendanceMap;
    final day = _selectedDate.day;
    final excludedDesignations = ['STO', 'ASTO', 'FRO (D)'];
    if (!includeSfroM) {
      excludedDesignations.add('SFRO (M)');
    }

    return personnelList.where((p) {
      final attendance = attendanceMap[p.id];
      final status = attendance?.dailyStatus[day];
      if (status == 'X' || status == null || status.trim().isEmpty || status.toUpperCase() == 'X/R') {
        if (!excludedDesignations.contains(p.designation)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

    Future<void> _showVehiclePersonnelSelectionDialog(
      String category, String vehicleName, TextEditingController controller) async {
    final availablePersonnel = _getOnDutyPersonnel(category);
    
    List<String> tempSelected = controller.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
        
    List<String> initialSelected = List.from(tempSelected);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Text('Select $category for $vehicleName', style: const TextStyle(color: Colors.white, fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: availablePersonnel.isEmpty 
                  ? const Center(child: Text('No personnel on duty for this category today.', style: TextStyle(color: Colors.white70)))
                  : ListView.builder(
                  shrinkWrap: true,
                  itemCount: availablePersonnel.length,
                  itemBuilder: (context, index) {
                    final person = availablePersonnel[index];
                    final isSelected = tempSelected.contains(person.idNumber);
                    
                    List<String> assignedVehicles = [];
                    for (var v in _vehicles) {
                      final vName = v.vehicleName;
                      if (vName == vehicleName) continue;
                      TextEditingController? otherCtrl;
                      if (category == 'SFRO') {
                        otherCtrl = _sfroControllers[vName];
                      } else if (category == 'FRO') otherCtrl = _froControllers[vName];
                      else if (category == 'KHG') otherCtrl = _khgControllers[vName];
                      else if (category == 'FRO(D)') otherCtrl = _froDControllers[vName];
                      
                      if (otherCtrl != null && otherCtrl.text.contains(person.idNumber)) {
                        assignedVehicles.add(vName);
                      }
                    }

                    String subtitleStr = person.designation;
                    if (assignedVehicles.isNotEmpty) {
                      subtitleStr += '\nAlready in: ${assignedVehicles.join(', ')}';
                    }

                    return CheckboxListTile(
                      title: Text('${person.name} (${person.idNumber})', style: const TextStyle(color: Colors.white)),
                      subtitle: Text(subtitleStr, style: TextStyle(color: assignedVehicles.isNotEmpty ? Colors.orangeAccent : Colors.white70)),
                      value: isSelected,
                      activeColor: Colors.blueAccent,
                      checkColor: Colors.white,
                      onChanged: (bool? value) {
                        if (value == true) {
                          if (category == 'FRO(D)' && tempSelected.isNotEmpty && !tempSelected.contains(person.idNumber)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Only one driver (FRO (D)) can be selected per vehicle.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          setStateDialog(() {
                            tempSelected.add(person.idNumber);
                          });
                        } else {
                          setStateDialog(() {
                            tempSelected.remove(person.idNumber);
                          });
                        }
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      controller.text = tempSelected.join(', ');
                      
                      // Track manually added IDs
                      for (var id in tempSelected) {
                        if (!initialSelected.contains(id)) {
                          _manuallyEditedIdsPerVehicle.putIfAbsent(vehicleName, () => []).add(id);
                        }
                      }
                      if (controller is ColoredTextEditingController) {
                         controller.highlightWords = _manuallyEditedIdsPerVehicle[vehicleName] ?? [];
                      }

                      // Auto-sync accessories if main vehicle is edited
                      String v1 = _vehicles.firstWhere((v) => v.vehicleName.contains('F/T') && !v.vehicleName.contains('C/S'), orElse: () => _getDefaultVehicles()[0]).vehicleName;
                      String v2 = _vehicles.firstWhere((v) => v.vehicleName.contains('W/B') && !v.vehicleName.contains('C/S'), orElse: () => _getDefaultVehicles()[1]).vehicleName;
                      String qrv = _vehicles.firstWhere((v) => v.vehicleName.contains('QRV') && !v.vehicleName.contains('C/S'), orElse: () => _getDefaultVehicles()[11]).vehicleName;
                      
                      final isNewRule = !_selectedDate.isBefore(DateTime(2026, 7, 23));
                      String acc1 = _vehicles.firstWhere((v) => v.vehicleName.contains(isNewRule ? 'I-F/T' : 'I-MTU'), orElse: () => _getDefaultVehicles()[12]).vehicleName;
                      String acc2 = _vehicles.firstWhere((v) => v.vehicleName.contains(isNewRule ? 'II-W/B' : 'Hydraulic Lukas') || v.vehicleName.contains('II-MTU'), orElse: () => _getDefaultVehicles()[13]).vehicleName;
                      String accQrv = _vehicles.firstWhere((v) => v.vehicleName.contains('C/S-2') || v.vehicleName.contains('C/S-10') || v.vehicleName.contains('(QRV)') && v.vehicleName.contains('C/S'), orElse: () => _getDefaultVehicles()[14]).vehicleName;

                      String? targetAcc;
                      if (vehicleName == v1) targetAcc = acc1;
                      else if (vehicleName == v2) targetAcc = acc2;
                      else if (vehicleName == qrv) targetAcc = accQrv;

                      if (targetAcc != null) {
                        TextEditingController? targetController;
                        if (category == 'SFRO' && _sfroControllers.containsKey(targetAcc)) {
                          targetController = _sfroControllers[targetAcc];
                        } else if (category == 'FRO' && _froControllers.containsKey(targetAcc)) {
                          targetController = _froControllers[targetAcc];
                        } else if (category == 'KHG' && _khgControllers.containsKey(targetAcc)) {
                          targetController = _khgControllers[targetAcc];
                        } else if (category == 'FRO(D)' && _froDControllers.containsKey(targetAcc)) {
                          targetController = _froDControllers[targetAcc];
                        }

                        if (targetController != null) {
                          targetController.text = controller.text;

                          // Track manually added IDs for the accessory vehicle as well
                          for (var id in tempSelected) {
                            if (!initialSelected.contains(id)) {
                              _manuallyEditedIdsPerVehicle.putIfAbsent(targetAcc, () => []).add(id);
                            }
                          }
                          if (targetController is ColoredTextEditingController) {
                             targetController.highlightWords = _manuallyEditedIdsPerVehicle[targetAcc] ?? [];
                          }
                        }
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.blueAccent)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showManualSelectionDialog(String title, List<String> initialSelected, Function(List<String>) onSave, {List<Manpower>? customPersonnelList}) async {
    final personnelList = customPersonnelList ?? context.read<ManpowerProvider>().getActivePersonnelForDate(_selectedDate);
    final List<String> tempSelected = List.from(initialSelected);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: personnelList.isEmpty
                  ? const Center(child: Text('No personnel available', style: TextStyle(color: Colors.white70)))
                  : ListView.builder(
                  shrinkWrap: true,
                  itemCount: personnelList.length,
                  itemBuilder: (context, index) {
                    final person = personnelList[index];
                    final isSelected = tempSelected.contains(person.idNumber);
                    return CheckboxListTile(
                      title: Text('${person.name} (${person.idNumber})', style: const TextStyle(color: Colors.white)),
                      subtitle: Text(person.designation, style: const TextStyle(color: Colors.white70)),
                      value: isSelected,
                      activeColor: Colors.blueAccent,
                      checkColor: Colors.white,
                      onChanged: (bool? value) {
                        setStateDialog(() {
                          if (value == true) {
                            tempSelected.add(person.idNumber);
                          } else {
                            tempSelected.remove(person.idNumber);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                TextButton(
                  onPressed: () {
                    onSave(tempSelected);
                    Navigator.pop(context);
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.blueAccent)),
                ),
              ],
            );
          },
        );
      },
    );
  }


  Future<void> _saveRegister() async {
    // Validate seniority duplication
    final duplicateSeniorities = _vehicles.map((v) => v.seniority).toSet().length != _vehicles.length;
    if (duplicateSeniorities) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot save! Duplicate vehicle seniorities found. Please fix red highlighted items.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
      return;
    }

    // Validate attachment remarks
    final attachedWithoutRemarks = _vehicles.where((v) => (_vehicleAttachedStatus[v.vehicleName] ?? false) && _remarksControllers[v.vehicleName]!.text.trim().isEmpty).toList();
    if (attachedWithoutRemarks.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot save! Remarks are mandatory for attached vehicles: ${attachedWithoutRemarks.map((e) => e.vehicleName).join(", ")}', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
      return;
    }

    // Warn if Sentry Duty is missing
    final sentryProvider = context.read<SentryProvider>();
    bool hasSentry = sentryProvider.registers.any((r) => 
       r.date.year == _selectedDate.year && 
       r.date.month == _selectedDate.month && 
       r.date.day == _selectedDate.day
    );
    
    if (!hasSentry) {
      final formattedDate = DateFormat('dd/MM/yyyy').format(_selectedDate);
      bool proceed = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Missing Sentry Duty', style: TextStyle(color: Colors.orangeAccent)),
          content: Text(
            'You didn\'t create Sentry Duty of $formattedDate. Do you want to continue without adding it?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ) ?? false;
      
      if (!proceed) return;
    }

    // Collect vehicle data
    List<DutyVehicleAssignment> savedVehicles = [];
    for (var v in _vehicles) {
      final vName = v.vehicleName;
      List<String> allAssignedIds = [
        ..._sfroControllers[vName]!.text.split(','),
        ..._froControllers[vName]!.text.split(','),
        ..._khgControllers[vName]!.text.split(','),
        ..._froDControllers[vName]!.text.split(',')
      ].map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      List<String> filteredManualIds = (_manuallyEditedIdsPerVehicle[vName] ?? [])
          .where((id) => allAssignedIds.contains(id))
          .toList();

      savedVehicles.add(DutyVehicleAssignment(
        vehicleName: vName,
        seniority: v.seniority,
        sfro: _sfroControllers[vName]!.text,
        fro: _froControllers[vName]!.text,
        khg: _khgControllers[vName]!.text,
        froD: _froDControllers[vName]!.text,
        remarks: _remarksControllers[vName]!.text,
        isOffRoad: _vehicleOffRoadStatus[vName] ?? false,
        isAttached: _vehicleAttachedStatus[vName] ?? false,
        manuallyEditedIds: filteredManualIds,
      ));
    }

    final newRegister = DutyRegisterModel(
      id: _existingRegisterId,
      date: _selectedDate,
      rollCallTime: _timeController.text,
      shift: _selectedShift,
      vacancyCount: _vacancyCountController.text,
      vacancyDetails: _vacancyDetailsController.text,
      staffSummaries: [], // TODO: Auto fill from attendance
      homeGuardSummaries: [],
      trainingSummaries: [],
      stationWriterIds: _stationWriterIds,
      specialDutyIds: _specialDutyIds,
      trainingOverrideIds: _trainingOverrideIds,
      vehicleAssignments: savedVehicles,
      phoneDutyIds: _phoneDutyIds,
      messengerIds: _messengerIds,
      sentryDutyIds: _sentryDutyIds,
      controlRoomIds: _controlRoomIds,
    );

    await Provider.of<DutyProvider>(context, listen: false).saveDutyRegister(newRegister);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duty Register Saved Successfully!')));
      Navigator.pop(context);
    }
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
    );
  }

  bool _isAbsent(String idNumber) {
    final manpowerProvider = context.read<ManpowerProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    
    final personList = manpowerProvider.personnelList.where((p) => p.idNumber == idNumber).toList();
    if (personList.isEmpty) return true;
    final person = personList.first;
    
    final att = attendanceProvider.attendanceMap[person.id];
    final status = att?.dailyStatus[_selectedDate.day];
    
    if (status == null || status.trim().isEmpty || status.trim().toUpperCase() == 'X' || status.trim().toUpperCase() == 'X/R') {
      return false;
    }
    return true;
  }

  String _sortPersonnelIds(String text) {
    if (text.isEmpty) return '';
    final personnelList = context.read<ManpowerProvider>().getActivePersonnelForDate(_selectedDate);
    final ids = text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    
    ids.sort((a, b) {
       Manpower? pA;
       Manpower? pB;
       try { 
         pA = personnelList.firstWhere((p) {
           String pNum = RegExp(r'\d+').firstMatch(p.idNumber)?.group(0) ?? '';
           String aNum = RegExp(r'\d+').firstMatch(a)?.group(0) ?? '';
           return p.idNumber == a || (pNum.isNotEmpty && pNum == aNum);
         }); 
       } catch (_) {}
       try { 
         pB = personnelList.firstWhere((p) {
           String pNum = RegExp(r'\d+').firstMatch(p.idNumber)?.group(0) ?? '';
           String bNum = RegExp(r'\d+').firstMatch(b)?.group(0) ?? '';
           return p.idNumber == b || (pNum.isNotEmpty && pNum == bNum);
         }); 
       } catch (_) {}
       
       int genderA = (pA?.gender == 'Female') ? 1 : 0;
       int genderB = (pB?.gender == 'Female') ? 1 : 0;
       if (genderA != genderB) return genderA.compareTo(genderB);
       
       int orderA = pA?.sortOrder ?? 999;
       int orderB = pB?.sortOrder ?? 999;
       if (orderA != orderB) return orderA.compareTo(orderB);
       
       return _getSeniorityRank(a).compareTo(_getSeniorityRank(b));
    });
    return ids.join(', ');
  }

  Widget _buildSelectionField(String label, String category, String vehicleName, TextEditingController controller, {bool isRedHighlighted = false}) {
    return InkWell(
      onTap: () => _showVehiclePersonnelSelectionDialog(category, vehicleName, controller),
      borderRadius: BorderRadius.circular(12),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          Color bgColor = Colors.white.withOpacity(0.05);
          Color borderColor = Colors.white.withOpacity(0.1);
          
          if (isRedHighlighted) {
            if (value.text.isEmpty) {
              bgColor = Colors.redAccent.withOpacity(0.1);
              borderColor = Colors.redAccent;
            } else {
              bgColor = Colors.green.withOpacity(0.1);
              borderColor = Colors.green;
            }
          }

          return Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 2),
                      Expanded(
                        child: Text(
                          value.text.isEmpty ? '' : _sortPersonnelIds(value.text),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white70),
              ],
            ),
          );
        },
      ),
    );
  }

  List<DutyVehicleAssignment> get _activeVehicles {
    var active = _vehicles.where((v) => !(_vehicleOffRoadStatus[v.vehicleName] ?? false) && !(_vehicleAttachedStatus[v.vehicleName] ?? false)).toList();
    active.sort((a, b) => a.seniority.compareTo(b.seniority));
    if (active.isEmpty) active = _vehicles; // Fallback just in case all are off-road
    return active;
  }

  String _getV1() => _activeVehicles.isNotEmpty ? _activeVehicles[0].vehicleName : _vehicles[0].vehicleName;
  String _getV2() => _activeVehicles.length > 1 ? _activeVehicles[1].vehicleName : _getV1();
  String _getV3() => _activeVehicles.length > 2 ? _activeVehicles[2].vehicleName : _getV2();

  int _getSeniorityRank(String idNumber) {
    final match = RegExp(r'\d+').firstMatch(idNumber);
    if (match != null) {
      int num = int.parse(match.group(0)!);
      if (num < 100) return num + 200000; // 1 or 2-digit numbers are most junior
      if (num < 1000) return num + 100000; // 3-digit numbers are junior
      return num;
    }
    return 999999;
  }

  List<DutyVehicleAssignment> get _assignableVehicles {
    return _activeVehicles.where((v) => 
       !v.vehicleName.contains('SCUBA') && 
       !v.vehicleName.contains('CCV') && 
       !v.vehicleName.contains('C/S') && 
       !v.vehicleName.contains('Wireless') && 
       !v.vehicleName.contains('Blower') && 
       !v.vehicleName.contains('Torch') && 
       !v.vehicleName.contains('BA Set') && !v.vehicleName.contains('Gas Detector')
    ).toList();
  }

  String _getDynamicV(int index) {
    var assignable = _assignableVehicles;
    return assignable.length > index ? assignable[index].vehicleName : '';
  }

  void _autoAssignSFRO() {
    final attendanceProvider = context.read<AttendanceProvider>();
    final dutyProvider = context.read<DutyProvider>();
    final personnelList = context.read<ManpowerProvider>().getActivePersonnelForDate(_selectedDate);

    DutyRegisterModel? previousRegister;
    for (var reg in dutyProvider.registers) {
      DateTime regDate = DateTime(reg.date.year, reg.date.month, reg.date.day);
      DateTime selDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      if (regDate.isBefore(selDate)) {
        previousRegister = reg;
        break;
      }
    }

    final sfroDesignations = ['SFRO'];
    
    // Get all present SFROs
    final sfroList = personnelList.where((p) {
      if (!sfroDesignations.contains(p.designation)) return false;
      if (_stationWriterIds.contains(p.idNumber)) return false;
      final attendance = attendanceProvider.attendanceMap[p.id];
      final status = attendance?.dailyStatus[_selectedDate.day];
      return (status == null || status.trim().isEmpty || status.trim().toUpperCase() == 'X' || status.trim().toUpperCase() == 'X/R');
    }).toList();

    if (sfroList.isEmpty) {
      final seniorFroAsSfro = _getSeniorMostFroAsSfro();
      if (seniorFroAsSfro != null) {
        sfroList.add(seniorFroAsSfro);
      }
    }

    // Auto-assign phone duty
    if (sfroList.isNotEmpty) {
      final sortedSfroList = List<Manpower>.from(sfroList);
      sortedSfroList.sort((a, b) {
        if (a.sortOrder != b.sortOrder) {
          return a.sortOrder.compareTo(b.sortOrder);
        }
        return _getSeniorityRank(a.idNumber).compareTo(_getSeniorityRank(b.idNumber));
      });
      
      _phoneDutyIds = [sortedSfroList.first.idNumber];
    }
    
    // Auto-assign control room to the senior-most available FRO
    final actingSfro = _getSeniorMostFroAsSfro();
    final froListForControlRoom = personnelList.where((p) {
      if (p.designation != 'FRO') return false;
      if (_stationWriterIds.contains(p.idNumber)) return false;
      if (actingSfro != null && p.id == actingSfro.id) return false;
      if (_phoneDutyIds.contains(p.idNumber)) return false;
      final attendance = attendanceProvider.attendanceMap[p.id];
      final status = attendance?.dailyStatus[_selectedDate.day];
      return (status == null || status.trim().isEmpty || status.trim().toUpperCase() == 'X' || status.trim().toUpperCase() == 'X/R');
    }).toList();

    if (froListForControlRoom.isNotEmpty) {
      final sortedFroList = List<Manpower>.from(froListForControlRoom);
      sortedFroList.sort((a, b) {
        if (a.sortOrder != b.sortOrder) {
          return a.sortOrder.compareTo(b.sortOrder);
        }
        return _getSeniorityRank(a.idNumber).compareTo(_getSeniorityRank(b.idNumber));
      });
      _controlRoomIds = [sortedFroList.first.idNumber];
    }

    List<Map<String, dynamic>> driverStats = [];
    for (var person in sfroList) {
      final att = attendanceProvider.attendanceMap[person.id];
      int absentDays = 0;
      
      if (att != null) {
        int currentDay = _selectedDate.day - 1;
        bool blockEnded = false;
        while (currentDay > 0 && !blockEnded) {
          final status = att.dailyStatus[currentDay];
          if (status == null || status.trim().isEmpty || status.trim().toUpperCase() == 'X' || status.trim().toUpperCase() == 'X/R') {
            blockEnded = true;
          } else {
            absentDays++;
            currentDay--;
          }
        }
      }

      List<String> primaryOrder = [
        _getDynamicV(0), _getDynamicV(1), _getDynamicV(2), _getDynamicV(3),
        _getDynamicV(4), _getDynamicV(5), _getDynamicV(6), _getDynamicV(7),
        _getDynamicV(8), _getDynamicV(9),
      ];

      int previousRank = 999;
      for (var reg in dutyProvider.registers) {
        DateTime regDate = DateTime(reg.date.year, reg.date.month, reg.date.day);
        DateTime selDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        if (regDate.isBefore(selDate)) {
          bool found = false;
          int bestPrimaryIdx = 999;
          for (var v in reg.vehicleAssignments) {
            if (v.sfro.contains(person.idNumber)) {
               found = true;
               for (int pIdx = 0; pIdx < primaryOrder.length; pIdx++) {
                 if (primaryOrder[pIdx].isNotEmpty && v.vehicleName == primaryOrder[pIdx]) {
                   if (pIdx < bestPrimaryIdx) bestPrimaryIdx = pIdx;
                 }
               }
            }
          }
          if (found) {
            if (bestPrimaryIdx != 999) previousRank = bestPrimaryIdx;
            break; 
          }
        }
      }
      
      driverStats.add({
        'person': person,
        'absentDays': absentDays,
        'previousRank': previousRank,
        'shiftedRank': 999,
      });
    }

    int maxPreviousRank = -1;
    for (var stat in driverStats) {
      if (stat['previousRank'] != 999) {
         if (stat['previousRank'] > maxPreviousRank) {
           maxPreviousRank = stat['previousRank'];
         }
      }
    }

    for (var stat in driverStats) {
      int prev = stat['previousRank'];
      if (prev != 999) {
        if (prev == maxPreviousRank) {
           stat['shiftedRank'] = 0;
        } else {
           stat['shiftedRank'] = prev + 1;
        }
      }
    }

    driverStats.sort((a, b) {
      int cmp = (b['absentDays'] as int).compareTo(a['absentDays'] as int);
      if (cmp != 0) return cmp;
      int rankCmp = (a['shiftedRank'] as int).compareTo(b['shiftedRank'] as int);
      if (rankCmp != 0) return rankCmp;
      return (a['person'] as Manpower).name.compareTo((b['person'] as Manpower).name);
    });

    // Clear previous assignments
    _sfroControllers.forEach((key, controller) {
      controller.text = '';
    });

    int assignedCount = 0;
    for (int i = 0; i < driverStats.length; i++) {
      if (_activeVehicles.isNotEmpty) {
        String vehicleName = _activeVehicles[i % _activeVehicles.length].vehicleName;
        if (_sfroControllers.containsKey(vehicleName)) {
          String id = (driverStats[i]['person'] as Manpower).idNumber;
          String current = _sfroControllers[vehicleName]!.text;
          if (current.isEmpty) {
            _sfroControllers[vehicleName]!.text = id;
          } else {
            if (!current.contains(id)) _sfroControllers[vehicleName]!.text = '$current, $id';
          }
          assignedCount++;
        }
      }
    }

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auto-assigned $assignedCount SFRO personnel to vehicles I to IX.')));
  }

  void _executeDynamicAssignment(List<Map<String, dynamic>> driverStats, List<Map<String, dynamic>> targets, {required bool isMale, required String v1, required String v2, required String v3}) {
    Map<String, Set<String>> personAssignments = {};
    for (var stat in driverStats) {
       personAssignments[(stat['person'] as Manpower).idNumber] = {};
    }

    for (var target in targets) {
       String vehName = target['v'];
       int requiredCount = target['count'];
       if (vehName.isEmpty || requiredCount <= 0) continue;
       if (_vehicleOffRoadStatus[vehName] == true) continue;
       if (_vehicleAttachedStatus[vehName] == true) continue;
       
       int assignedHere = 0;
       int loopSafety = 0;
       while (assignedHere < requiredCount && loopSafety < 100) {
          loopSafety++;
          Map<String, dynamic>? bestCandidate;
          int bestScore = 999999;
          
          for (int i = 0; i < driverStats.length; i++) {
             var stat = driverStats[i];
             String id = (stat['person'] as Manpower).idNumber;
             var assignedTo = personAssignments[id]!;
             
             if (assignedTo.contains(vehName)) continue;
             
             bool isV1 = assignedTo.contains(v1);
             bool isV2 = assignedTo.contains(v2);
             bool isV3 = assignedTo.contains(v3);
             bool isAMB = vehName.contains('AMB') || assignedTo.any((v) => v.contains('AMB'));
             bool isFRV = vehName.contains('FRV') || assignedTo.any((v) => v.contains('FRV'));
             bool isQRV = vehName.contains('QRV');
             bool checkingVehIsAMB = vehName.contains('AMB');
             bool checkingVehIsV1 = vehName == v1;
             bool checkingVehIsV2 = vehName == v2;
             bool checkingVehIsV3 = vehName == v3;
             bool checkingVehIsFRV = vehName.contains('FRV');
             
             // Prevent V1 and V2 clash
             if ((checkingVehIsV2 && isV1) || (checkingVehIsV1 && isV2)) {
                 bool othersAllBusy = true;
                 for (var otherStat in driverStats) {
                    String oid = (otherStat['person'] as Manpower).idNumber;
                    if (oid != id && !personAssignments[oid]!.contains(v1) && !personAssignments[oid]!.contains(v2)) {
                       if (personAssignments[oid]!.length <= 2 && !personAssignments[oid]!.contains(vehName)) {
                          othersAllBusy = false;
                          break;
                       }
                    }
                 }
                 if (!othersAllBusy) continue;
             }
             
             // Prevent FRV and V1
             if ((checkingVehIsFRV && isV1) || (checkingVehIsV1 && assignedTo.any((v) => v.contains('FRV')))) continue;
             
             // Prevent AMB with F/T(V1) or FRV
             if ((checkingVehIsAMB && (isV1 || assignedTo.any((v) => v.contains('FRV')))) || 
                 (checkingVehIsV1 && assignedTo.any((v) => v.contains('AMB'))) || 
                 (checkingVehIsFRV && assignedTo.any((v) => v.contains('AMB')))) {
                 bool othersAllBusy = true;
                 for (var otherStat in driverStats) {
                    String oid = (otherStat['person'] as Manpower).idNumber;
                    if (oid != id && !personAssignments[oid]!.contains(v1) && !personAssignments[oid]!.any((v) => v.contains('AMB')) && !personAssignments[oid]!.any((v) => v.contains('FRV'))) {
                       othersAllBusy = false;
                       break;
                    }
                 }
                 if (!othersAllBusy) continue;
             }

             if (isQRV && isV1) {
                bool othersAllBusy = true;
                for (var otherStat in driverStats) {
                   String oid = (otherStat['person'] as Manpower).idNumber;
                   if (oid != id && !personAssignments[oid]!.contains(v1)) {
                      if (personAssignments[oid]!.length <= 2 && !personAssignments[oid]!.contains(vehName)) {
                         othersAllBusy = false;
                         break;
                      }
                   }
                }
                if (!othersAllBusy) continue;
             }
             
             int score = 0;
             score += assignedTo.length * 1000;
             
             List<String> prevVehs = stat['prevVehicles'] as List<String>? ?? [];
             if (prevVehs.contains(vehName)) {
                score += isMale ? 5000 : 500;
             }
             
             score += i;
             
             if (score < bestScore) {
                bestScore = score;
                bestCandidate = stat;
             }
          }
          
          if (bestCandidate != null) {
             String id = (bestCandidate['person'] as Manpower).idNumber;
             personAssignments[id]!.add(vehName);
             
             if (_froControllers.containsKey(vehName)) {
                String current = _froControllers[vehName]!.text;
                if (current.isEmpty) {
                   _froControllers[vehName]!.text = id;
                } else {
                   if (!current.contains(id)) {
                      _froControllers[vehName]!.text = '$current, $id';
                   }
                }
             }
             assignedHere++;
          } else {
             break;
          }
       }
    }
    
    if (isMale) {
       for (var stat in driverStats) {
          String id = (stat['person'] as Manpower).idNumber;
          if (personAssignments[id]!.isEmpty) {
             String wireless = 'Wireless, Interactive Flat Panel Display';
             if (_froControllers.containsKey(wireless)) {
                String current = _froControllers[wireless]!.text;
                if (current.isEmpty) {
                   _froControllers[wireless]!.text = id;
                } else if (!current.contains(id)) {
                   _froControllers[wireless]!.text = '$current, $id';
                }
             }
          }
       }
    }
  }

  List<Set<String>> _getLast3Duties(String idNumber, DateTime selectedDate, DutyProvider dutyProvider) {
    List<Set<String>> history = [];
    int daysChecked = 0;
    for (var reg in dutyProvider.registers) {
      DateTime regDate = DateTime(reg.date.year, reg.date.month, reg.date.day);
      DateTime selDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      if (regDate.isBefore(selDate)) {
        bool foundAny = false;
        Set<String> vehiclesThisDay = {};
        for (var v in reg.vehicleAssignments) {
          if (v.fro.contains(idNumber) || v.sfro.contains(idNumber) || v.khg.contains(idNumber) || v.froD.contains(idNumber)) {
             foundAny = true;
             vehiclesThisDay.add(v.vehicleName);
          }
        }
        if (foundAny) {
          history.add(vehiclesThisDay);
        }
        daysChecked++;
        if (daysChecked >= 15) break; 
        if (history.length >= 3) break;
      }
    }
    return history;
  }

  void _assignTargetsDFS(
    List<Map<String, dynamic>> sortedPersonnel,
    List<Map<String, dynamic>> targets,
    Map<String, Set<String>> assignments,
    Map<String, List<String>> dailyAssign,
    String v1, String v2, String v3, String frv, String amb, String qrv
  ) {
    for (var target in targets) {
      String targetV = target['v'];
      int count = target['count'];
      if (targetV.isEmpty || count <= 0) continue;

      int assignedHere = 0;
      while (assignedHere < count) {
        String? bestPerson;
        int bestScore = 999999999;

        for (var stat in sortedPersonnel) {
          String personId = stat['person'].idNumber;
          if (assignments[personId]!.contains(targetV)) continue;

          var assignedTo = assignments[personId]!;
          if (targetV == v1 && (assignedTo.contains(v2) || assignedTo.contains(frv) || assignedTo.contains(qrv) || assignedTo.contains(amb))) continue;
          if (targetV == v2 && assignedTo.contains(v1)) continue;
          if (targetV == frv && (assignedTo.contains(v1) || assignedTo.contains(amb))) continue;
          if (targetV == amb && (assignedTo.contains(v1) || assignedTo.contains(frv))) continue;
          if (targetV == qrv && assignedTo.contains(v1)) continue;

          int score = (stat['shiftedRank'] as int);
          
          List<Set<String>> history = stat['history'];
          if (history.length >= 1 && history[0].contains(targetV)) score += 2000000;
          if (history.length >= 2 && history[1].contains(targetV)) score += 800000;
          if (history.length >= 3 && history[2].contains(targetV)) score += 400000;

          score += assignments[personId]!.length * 1000000;

          if (score < bestScore) {
            bestScore = score;
            bestPerson = personId;
          }
        }

        if (bestPerson != null) {
          assignments[bestPerson]!.add(targetV);
          dailyAssign[targetV] ??= [];
          dailyAssign[targetV]!.add(bestPerson);
          assignedHere++;
        } else {
          break;
        }
      }
    }
  }

  void _autoAssignFRO() {
    final attendanceProvider = context.read<AttendanceProvider>();
    final dutyProvider = context.read<DutyProvider>();
    final personnelList = context.read<ManpowerProvider>().getActivePersonnelForDate(_selectedDate);

    final actingSfro = _getSeniorMostFroAsSfro();
    final froList = personnelList.where((p) {
      if (p.designation != 'FRO' || p.gender != 'Female') return false;
      if (_stationWriterIds.contains(p.idNumber)) return false;
      if (actingSfro != null && p.id == actingSfro.id) return false;
      final attendance = attendanceProvider.attendanceMap[p.id];
      final status = attendance?.dailyStatus[_selectedDate.day];
      return (status == null || status.trim().isEmpty || status.trim().toUpperCase() == 'X' || status.trim().toUpperCase() == 'X/R');
    }).toList();

    List<Map<String, dynamic>> driverStats = [];
    for (var person in froList) {
      final att = attendanceProvider.attendanceMap[person.id];
      int absentDays = 0;
      
      if (att != null) {
        int currentDay = _selectedDate.day - 1;
        bool blockEnded = false;
        while (currentDay > 0 && !blockEnded) {
          final status = att.dailyStatus[currentDay];
          if (status == null || status.trim().isEmpty || status.trim().toUpperCase() == 'X' || status.trim().toUpperCase() == 'X/R') {
            blockEnded = true;
          } else {
            absentDays++;
            currentDay--;
          }
        }
      }

      int previousRank = _getSeniorityRank(person.idNumber);
      List<Set<String>> history = _getLast3Duties(person.idNumber, _selectedDate, dutyProvider);

      driverStats.add({
        'person': person,
        'absentDays': absentDays,
        'previousRank': previousRank,
        'shiftedRank': previousRank,
        'history': history,
      });
    }

    driverStats.sort((a, b) {
      return (a['shiftedRank'] as int).compareTo(b['shiftedRank'] as int);
    });

    final allFemaleFroIds = personnelList.where((p) => p.designation == 'FRO' && p.gender == 'Female').map((p) => p.idNumber).toSet();
    _froControllers.forEach((key, controller) {
      if (controller.text.isNotEmpty) {
        List<String> currentIds = controller.text.split(',').map((s) => s.trim()).toList();
        currentIds.removeWhere((id) => allFemaleFroIds.contains(id));
        controller.text = currentIds.join(', ');
      }
    });

    String v1 = _getDynamicV(0);
    String v2 = _getDynamicV(1);
    String v3 = _getDynamicV(2);
    String frv = _getDynamicV(3);
    String amb = _getDynamicV(4);
    String qrv = _getDynamicV(9);

    List<Map<String, dynamic>> targets = [
      {'v': v1, 'count': 1},
      {'v': amb, 'count': 1},
      {'v': v2, 'count': 1},
      {'v': v3, 'count': 1},
      {'v': frv, 'count': 1},
      {'v': qrv, 'count': 1},
    ];

    Map<String, Set<String>> assignments = { for (var stat in driverStats) stat['person'].idNumber: <String>{} };
    Map<String, List<String>> dailyAssign = {};

    _assignTargetsDFS(driverStats, targets, assignments, dailyAssign, v1, v2, v3, frv, amb, qrv);

    for (var target in targets) {
      String targetV = target['v'];
      int targetCount = target['count'];
      if (targetV.isEmpty) continue;
      
      int currentCount = dailyAssign[targetV]?.length ?? 0;
      while (currentCount < targetCount) {
        bool assigned = false;
        
        // Load balancing: Sort by current number of assignments (ascending), then by original rank
        driverStats.sort((a, b) {
          int countA = assignments[a['person'].idNumber]?.length ?? 0;
          int countB = assignments[b['person'].idNumber]?.length ?? 0;
          if (countA != countB) return countA.compareTo(countB);
          return (a['shiftedRank'] as int).compareTo(b['shiftedRank'] as int);
        });

        for (var stat in driverStats) {
          String pId = stat['person'].idNumber;
          if (!assignments[pId]!.contains(targetV)) {
             assignments[pId]!.add(targetV);
             dailyAssign[targetV] ??= [];
             dailyAssign[targetV]!.add(pId);
             assigned = true;
             currentCount++;
             break;
          }
        }
        if (!assigned) break;
      }
    }

    dailyAssign.forEach((vehicle, ids) {
      if (_froControllers.containsKey(vehicle)) {
        String current = _froControllers[vehicle]!.text;
        _froControllers[vehicle]!.text = current.isEmpty ? ids.join(', ') : '$current, ${ids.join(', ')}';
      }
    });

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auto-assigned ${driverStats.length} FRO (Female) personnel.')));
  }

  void _autoAssignFROMales() {
    final attendanceProvider = context.read<AttendanceProvider>();
    final dutyProvider = context.read<DutyProvider>();
    final personnelList = context.read<ManpowerProvider>().getActivePersonnelForDate(_selectedDate);

    final actingSfro = _getSeniorMostFroAsSfro();
    final froList = personnelList.where((p) {
      if (p.designation != 'FRO' || p.gender != 'Male') return false;
      if (_stationWriterIds.contains(p.idNumber)) return false;
      if (actingSfro != null && p.id == actingSfro.id) return false;
      final attendance = attendanceProvider.attendanceMap[p.id];
      final status = attendance?.dailyStatus[_selectedDate.day];
      return (status == null || status.trim().isEmpty || status.trim().toUpperCase() == 'X' || status.trim().toUpperCase() == 'X/R');
    }).toList();

    List<Map<String, dynamic>> driverStats = [];
    for (var person in froList) {
      final att = attendanceProvider.attendanceMap[person.id];
      int absentDays = 0;
      
      if (att != null) {
        int currentDay = _selectedDate.day - 1;
        bool blockEnded = false;
        while (currentDay > 0 && !blockEnded) {
          final status = att.dailyStatus[currentDay];
          if (status == null || status.trim().isEmpty || status.trim().toUpperCase() == 'X' || status.trim().toUpperCase() == 'X/R') {
            blockEnded = true;
          } else {
            absentDays++;
            currentDay--;
          }
        }
      }

      int previousRank = _getSeniorityRank(person.idNumber);
      List<Set<String>> history = _getLast3Duties(person.idNumber, _selectedDate, dutyProvider);

      driverStats.add({
        'person': person,
        'absentDays': absentDays,
        'previousRank': previousRank,
        'shiftedRank': previousRank,
        'history': history,
      });
    }

    driverStats.sort((a, b) {
      return (a['shiftedRank'] as int).compareTo(b['shiftedRank'] as int);
    });

    final allMaleFroIds = personnelList.where((p) => p.designation == 'FRO' && p.gender == 'Male').map((p) => p.idNumber).toSet();
    _froControllers.forEach((key, controller) {
      if (controller.text.isNotEmpty) {
        List<String> currentIds = controller.text.split(',').map((s) => s.trim()).toList();
        currentIds.removeWhere((id) => allMaleFroIds.contains(id));
        controller.text = currentIds.join(', ');
      }
    });

    int n = driverStats.length;
    if (n == 0) return;

    String v1 = _getDynamicV(0);
    String v2 = _getDynamicV(1);
    String v3 = _getDynamicV(2);
    String frv = _getDynamicV(3);
    String amb = _getDynamicV(4);
    String qrv = _getDynamicV(9);
    String jeep = _getDynamicV(5);
    String tc = _getDynamicV(8);

    int v3MaleCount = n >= 14 ? 3 : (n == 13 ? 2 : 1);
    int ambCount = n >= 15 ? 2 : 1;
    int jeepCount = 0;
    if (n == 16) jeepCount = 1;
    if (n >= 17) jeepCount = 2;
    int tcCount = 0;
    if (n >= 18) tcCount = n - 17;

    List<Map<String, dynamic>> targets = [
      {'v': v1, 'count': 2},
      {'v': amb, 'count': 1}, 
      {'v': v1, 'count': 1},
      {'v': v2, 'count': 3},
      {'v': v3, 'count': v3MaleCount},
      {'v': frv, 'count': 2},
      {'v': qrv, 'count': 2},
    ];

    if (ambCount == 2) targets.add({'v': amb, 'count': 1});
    if (jeepCount > 0 && jeep.isNotEmpty) targets.add({'v': jeep, 'count': jeepCount});
    if (tcCount > 0 && tc.isNotEmpty) targets.add({'v': tc, 'count': tcCount});

    Map<String, Set<String>> assignments = { for (var stat in driverStats) stat['person'].idNumber: <String>{} };
    Map<String, List<String>> dailyAssign = {};

    _assignTargetsDFS(driverStats, targets, assignments, dailyAssign, v1, v2, v3, frv, amb, qrv);

    for (var target in targets) {
      String targetV = target['v'];
      int targetCount = target['count'];
      if (targetV.isEmpty) continue;
      
      int currentCount = dailyAssign[targetV]?.length ?? 0;
      while (currentCount < targetCount) {
        bool assigned = false;
        
        // Load balancing: Sort by current number of assignments (ascending), then by original rank
        driverStats.sort((a, b) {
          int countA = assignments[a['person'].idNumber]?.length ?? 0;
          int countB = assignments[b['person'].idNumber]?.length ?? 0;
          if (countA != countB) return countA.compareTo(countB);
          return (a['shiftedRank'] as int).compareTo(b['shiftedRank'] as int);
        });

        for (var stat in driverStats) {
          String pId = stat['person'].idNumber;
          if (!assignments[pId]!.contains(targetV)) {
             assignments[pId]!.add(targetV);
             dailyAssign[targetV] ??= [];
             dailyAssign[targetV]!.add(pId);
             assigned = true;
             currentCount++;
             break;
          }
        }
        if (!assigned) break; 
      }
    }

    dailyAssign.forEach((vehicle, ids) {
      if (_froControllers.containsKey(vehicle)) {
        String current = _froControllers[vehicle]!.text;
        _froControllers[vehicle]!.text = current.isEmpty ? ids.join(', ') : '$current, ${ids.join(', ')}';
      }
    });

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auto-assigned $n FRO (Male) personnel.')));
  }

  void _autoAssignAccessories() {
    final personnelList = context.read<ManpowerProvider>().getActivePersonnelForDate(_selectedDate);

    Manpower? getPerson(String id) {
      try {
        return personnelList.firstWhere((p) => p.idNumber == id.trim());
      } catch (_) {
        return null;
      }
    }

    String v1 = _getV1();
    String v2 = _getV2();
    String qrv = _vehicles.firstWhere((v) => v.vehicleName.contains('QRV') && !v.vehicleName.contains('C/S'), orElse: () => _getDefaultVehicles()[11]).vehicleName;
    
    final isNewRule = !_selectedDate.isBefore(DateTime(2026, 7, 23));
    
    String acc1 = _vehicles.firstWhere((v) => v.vehicleName.contains(isNewRule ? 'I-F/T' : 'I-MTU'), orElse: () => _getDefaultVehicles()[12]).vehicleName;
    String acc2 = _vehicles.firstWhere((v) => v.vehicleName.contains(isNewRule ? 'II-W/B' : 'Hydraulic Lukas') || v.vehicleName.contains('II-MTU'), orElse: () => _getDefaultVehicles()[13]).vehicleName;
    String accQrv = _vehicles.firstWhere((v) => v.vehicleName.contains('C/S-2') || v.vehicleName.contains('C/S-10') || v.vehicleName.contains('(QRV)') && v.vehicleName.contains('C/S'), orElse: () => _getDefaultVehicles()[14]).vehicleName;
    String wireless = 'Wireless, Interactive Flat Panel Display';
    String torch = 'Blower, Torch set';
    String baSet = 'BA Set, Gas Detector';

    void copyTo(String source, String dest) {
      if (_froControllers.containsKey(dest)) _froControllers[dest]!.text = _froControllers[source]?.text ?? '';
      if (_froDControllers.containsKey(dest)) _froDControllers[dest]!.text = _froDControllers[source]?.text ?? '';
      if (_khgControllers.containsKey(dest)) _khgControllers[dest]!.text = _khgControllers[source]?.text ?? '';
      // SFRO remains blank
    }

    copyTo(v1, acc1);
    copyTo(v2, acc2);
    copyTo(qrv, accQrv);

    List<String> getIds(String text) => text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    // Wireless Set
    List<String> v1FroIds = getIds(_froControllers[v1]?.text ?? '');
    List<String> wirelessFros = [];
    List<Manpower> v1MaleFros = [];
    for (var id in v1FroIds) {
      final p = getPerson(id);
      if (p != null) {
        if (p.gender == 'Female') {
          wirelessFros.add(id);
        } else if (p.gender == 'Male') {
          v1MaleFros.add(p);
        }
      }
    }

    // BA Set / Gas Detector
    if (isNewRule) {
      // Senior-most Male FRO from V1
      List<String> v1FroIds_ = getIds(_froControllers[v1]?.text ?? '');
      List<Manpower> v1MaleFros_ = [];
      for (var id in v1FroIds_) {
        final p = getPerson(id);
        if (p != null && p.gender == 'Male') v1MaleFros_.add(p);
      }
      v1MaleFros_.sort((a, b) => _getSeniorityRank(a.idNumber).compareTo(_getSeniorityRank(b.idNumber))); // ascending -> senior first
      
      // Senior-most Male FRO from V2
      List<String> v2FroIds_ = getIds(_froControllers[v2]?.text ?? '');
      List<Manpower> v2MaleFros_ = [];
      for (var id in v2FroIds_) {
        final p = getPerson(id);
        if (p != null && p.gender == 'Male') v2MaleFros_.add(p);
      }
      v2MaleFros_.sort((a, b) => _getSeniorityRank(a.idNumber).compareTo(_getSeniorityRank(b.idNumber))); // ascending -> senior first
      
      List<String> assignedBAs = [];
      if (v1MaleFros_.isNotEmpty) assignedBAs.add(v1MaleFros_.first.idNumber);
      if (v2MaleFros_.isNotEmpty) assignedBAs.add(v2MaleFros_.first.idNumber);
      
      if (_froControllers.containsKey(baSet) && assignedBAs.isNotEmpty) {
        _froControllers[baSet]!.text = assignedBAs.join(', ');
      }
    } else {
      String v3 = _getV3();
      List<String> v3FroIds = getIds(_froControllers[v3]?.text ?? '');
      List<Manpower> v3MaleFros = [];
      for (var id in v3FroIds) {
        final p = getPerson(id);
        if (p != null && p.gender == 'Male') v3MaleFros.add(p);
      }
      if (v3MaleFros.isNotEmpty) {
        v3MaleFros.sort((a, b) => _getSeniorityRank(b.idNumber).compareTo(_getSeniorityRank(a.idNumber))); // descending -> junior first
        if (_froControllers.containsKey(baSet)) {
          _froControllers[baSet]!.text = v3MaleFros.first.idNumber;
        }
      }
    }

    if (v1MaleFros.isNotEmpty) {
      v1MaleFros.sort((a, b) => _getSeniorityRank(b.idNumber).compareTo(_getSeniorityRank(a.idNumber))); // descending -> junior first
      wirelessFros.add(v1MaleFros.first.idNumber);
    }
    if (_froControllers.containsKey(wireless)) {
      _froControllers[wireless]!.text = wirelessFros.join(', ');
    }

    // Torch Set
    List<String> v2FroIds = getIds(_froControllers[v2]?.text ?? '');
    List<String> torchFros = [];
    for (var id in v2FroIds) {
      final p = getPerson(id);
      if (p != null && p.gender == 'Female') {
        torchFros.add(id);
      }
    }
    if (_froControllers.containsKey(torch)) _froControllers[torch]!.text = torchFros.join(', ');
    if (_khgControllers.containsKey(torch)) _khgControllers[torch]!.text = _khgControllers[v2]?.text ?? '';

    // BA Set
    List<String> baFros = [];
    if (v1MaleFros.isNotEmpty) {
      v1MaleFros.sort((a, b) => _getSeniorityRank(a.idNumber).compareTo(_getSeniorityRank(b.idNumber))); // ascending -> senior first
      baFros.add(v1MaleFros.first.idNumber);
    }
    List<Manpower> v2MaleFros = [];
    for (var id in v2FroIds) {
      final p = getPerson(id);
      if (p != null && p.gender == 'Male') v2MaleFros.add(p);
    }
    if (v2MaleFros.isNotEmpty) {
      v2MaleFros.sort((a, b) => _getSeniorityRank(a.idNumber).compareTo(_getSeniorityRank(b.idNumber))); // ascending -> senior first
      baFros.add(v2MaleFros.first.idNumber);
    }
    if (_froControllers.containsKey(baSet)) {
      _froControllers[baSet]!.text = baFros.toSet().toList().join(', '); // remove potential duplicates
    }
    
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auto-assigned Accessories & Equipments.')));
  }

  void _autoAssignDrivers() {
    final attendanceProvider = context.read<AttendanceProvider>();
    final dutyProvider = context.read<DutyProvider>();

    final froDList = _getOnDutyPersonnel('FRO(D)').where((p) {
      if (_stationWriterIds.contains(p.idNumber)) return false;
      final attendance = attendanceProvider.attendanceMap[p.id];
      final status = attendance?.dailyStatus[_selectedDate.day];
      return (status == null || status.trim().isEmpty || status.trim().toUpperCase() == 'X' || status.trim().toUpperCase() == 'X/R');
    }).toList();

    List<Map<String, dynamic>> lateReportersStats = [];
    List<Map<String, dynamic>> normalDriversStats = [];

    String v1 = _getDynamicV(0);
    String v2 = _getDynamicV(1);
    String v3 = _getDynamicV(2);
    String frv = _getDynamicV(3);
    String amb = _getDynamicV(4);
    String jeep = _getDynamicV(5);
    String icv = _getDynamicV(6);
    String bullet = _getDynamicV(7);
    String tc = _getDynamicV(8);
    String qrv = _getDynamicV(9);

    for (var person in froDList) {
      final att = attendanceProvider.attendanceMap[person.id];
      int absentDays = 0;
      bool isLateReporter = false;
      
      if (att != null) {
        int currentDay = _selectedDate.day - 1; 
        bool blockEnded = false;
        bool foundML = false;

        while (currentDay > 0 && !blockEnded) {
          final status = att.dailyStatus[currentDay]?.trim().toUpperCase() ?? '';
          if (status == 'X' || status == 'X/R') {
            blockEnded = true;
          } else if (status == 'R' || status == 'OFF' || status.isEmpty) {
            currentDay--;
          } else {
            absentDays++;
            if (status == 'ML') foundML = true;
            currentDay--;
          }
        }
        if (absentDays > 0 && foundML) {
          isLateReporter = true;
        }
      }

      List<Set<String>> history = _getLast3Duties(person.idNumber, _selectedDate, dutyProvider);

      Map<String, dynamic> stat = {
        'person': person,
        'absentDays': absentDays,
        'history': history,
        'seniority': _getSeniorityRank(person.idNumber),
      };

      if (isLateReporter) {
        lateReportersStats.add(stat);
      } else {
        normalDriversStats.add(stat);
      }
    }

    normalDriversStats.sort((a, b) {
      return (a['seniority'] as int).compareTo(b['seniority'] as int);
    });

    _froDControllers.forEach((key, controller) {
      if (key != 'CCV KL-01-CU-5201' && key != 'SCUBA VEH. KL-01-CE-1669') controller.text = '';
    });

    if (lateReportersStats.isNotEmpty) {
      List<String> tcList = [];
      List<String> jeepList = [];
      for (var stat in lateReportersStats) {
         tcList.add((stat['person'] as Manpower).idNumber);
         jeepList.add((stat['person'] as Manpower).idNumber);
      }
      if (tc.isNotEmpty && _froDControllers.containsKey(tc)) _froDControllers[tc]?.text = tcList.join(', ');
      if (jeep.isNotEmpty && _froDControllers.containsKey(jeep)) _froDControllers[jeep]?.text = jeepList.join(', ');
    }

    int totalNormalDrivers = normalDriversStats.length;
    
    List<String> getVehiclesForSlot(int slot, int n) {
      if (n == 1) {
        if (slot == 0) return [v1, v2, v3, amb, frv, bullet, qrv, icv, jeep, tc];
      } else if (n == 2) {
        if (slot == 0) return [v1, v3, bullet, qrv, icv];
        if (slot == 1) return [v2, frv, jeep, tc, amb]; 
      } else if (n == 3) {
        if (slot == 0) return [v1, bullet];
        if (slot == 1) return [v2, frv, jeep, tc];
        if (slot == 2) return [v3, amb, qrv, icv];
      } else if (n == 4) {
        if (slot == 0) return [v1, bullet];
        if (slot == 1) return [v2, jeep, tc];
        if (slot == 2) return [v3, amb, frv];
        if (slot == 3) return [qrv, icv];
      } else if (n == 5) {
        if (slot == 0) return [v1, bullet];
        if (slot == 1) return [v2, tc];
        if (slot == 2) return [v3, amb];
        if (slot == 3) return [qrv, jeep];
        if (slot == 4) return [icv, frv];
      } else if (n == 6) {
        if (slot == 0) return [v1, bullet];
        if (slot == 1) return [v2, tc];
        if (slot == 2) return [v3, jeep];
        if (slot == 3) return [qrv, amb];
        if (slot == 4) return [icv];
        if (slot == 5) return [frv];
      } else if (n == 7) {
        if (slot == 0) return [v1, bullet];
        if (slot == 1) return [v2];
        if (slot == 2) return [v3, jeep];
        if (slot == 3) return [qrv, amb];
        if (slot == 4) return [icv];
        if (slot == 5) return [frv];
        if (slot == 6) return [tc];
      } else if (n == 8) {
        if (slot == 0) return [v1, bullet];
        if (slot == 1) return [v2];
        if (slot == 2) return [v3];
        if (slot == 3) return [qrv, amb];
        if (slot == 4) return [icv];
        if (slot == 5) return [frv];
        if (slot == 6) return [tc];
        if (slot == 7) return [jeep];
      } else if (n >= 9) {
        if (slot == 0) return [v1, bullet];
        if (slot == 1) return [v2];
        if (slot == 2) return [v3];
        if (slot == 3) return [qrv];
        if (slot == 4) return [icv];
        if (slot == 5) return [frv];
        if (slot == 6) return [tc];
        if (slot == 7) return [jeep];
        if (slot == 8) return [amb];
      }
      return [];
    }

    List<List<int>> penaltyMatrix = List.generate(totalNormalDrivers, (i) => List.filled(totalNormalDrivers, 0));
    for (int i = 0; i < totalNormalDrivers; i++) {
       List<Set<String>> history = normalDriversStats[i]['history'];
       for (int slot = 0; slot < totalNormalDrivers; slot++) {
           List<String> proposedVehicles = getVehiclesForSlot(slot, totalNormalDrivers);
           int penalty = slot * 10;
           for (String pv in proposedVehicles) {
              if (history.length >= 1 && history[0].contains(pv)) penalty += 10000;
              if (history.length >= 2 && history[1].contains(pv)) penalty += 5000;
              if (history.length >= 3 && history[2].contains(pv)) penalty += 2500;
           }
           penaltyMatrix[i][slot] = penalty;
       }
    }

    int minTotalPenalty = 9999999;
    List<int> bestAssignment = [];
    int iterations = 0;

    void solve(int driverIdx, List<int> currentAssignment, int currentPenalty) {
       if (iterations > 50000) return; // Safely cap iterations to prevent freeze
       if (currentPenalty >= minTotalPenalty) return; 
       
       if (driverIdx == totalNormalDrivers) {
          minTotalPenalty = currentPenalty;
          bestAssignment = List.from(currentAssignment);
          return;
       }
       
       for (int slot = 0; slot < totalNormalDrivers; slot++) {
          if (!currentAssignment.contains(slot)) {
             currentAssignment.add(slot);
             iterations++;
             solve(driverIdx + 1, currentAssignment, currentPenalty + penaltyMatrix[driverIdx][slot]);
             currentAssignment.removeLast();
          }
       }
    }

    solve(0, [], 0);

    Map<String, int> finalAssignments = {};
    for (int i = 0; i < totalNormalDrivers; i++) {
       if (i < bestAssignment.length) {
          String personId = (normalDriversStats[i]['person'] as Manpower).id;
          finalAssignments[personId] = bestAssignment[i];
       }
    }

    void assignSlot(String idNumber, int slot) {
      List<String> vNames = getVehiclesForSlot(slot, totalNormalDrivers);
      for (var v in vNames) {
        if (_vehicleOffRoadStatus[v] == true) continue;
        if (v.isNotEmpty && _froDControllers.containsKey(v)) {
          String current = _froDControllers[v]!.text;
          if (current.isEmpty) {
            _froDControllers[v]!.text = idNumber;
          } else {
            if (!current.contains(idNumber)) _froDControllers[v]!.text = '$current, $idNumber';
          }
        }
      }
    }

    for (var stat in normalDriversStats) {
      String idNumber = (stat['person'] as Manpower).idNumber;
      String id = (stat['person'] as Manpower).id;
      if (finalAssignments.containsKey(id)) {
        assignSlot(idNumber, finalAssignments[id]!);
      }
    }

    if (normalDriversStats.isNotEmpty) {
      String lastDriverId = (normalDriversStats.last['person'] as Manpower).idNumber;
      _vehicleOffRoadStatus.forEach((vehName, isOffRoad) {
        if (isOffRoad && _froDControllers.containsKey(vehName)) {
          String current = _froDControllers[vehName]!.text;
          if (!current.contains(lastDriverId)) {
            _froDControllers[vehName]!.text = current.isEmpty ? lastDriverId : '$current, $lastDriverId';
          }
        }
      });
    }

    _froDControllers['CCV KL-01-CU-5201']?.text = '2311';

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auto-assigned $totalNormalDrivers normal drivers and ${lateReportersStats.length} late reporters.')));
  }

  void _autoAssignKHG() {
    final attendanceProvider = context.read<AttendanceProvider>();
    final dutyProvider = context.read<DutyProvider>();

    final khgList = _getOnDutyPersonnel('KHG').where((p) => !_stationWriterIds.contains(p.idNumber)).toList();

    List<Map<String, dynamic>> driverStats = [];
    for (var person in khgList) {
      final att = attendanceProvider.attendanceMap[person.id];
      bool isContinuous = false;
      
      if (att != null) {
        int currentDay = _selectedDate.day - 1;
        while (currentDay > 0) {
          final status = att.dailyStatus[currentDay]?.trim().toUpperCase() ?? '';
          if (status == 'X' || status == 'X/R') {
             isContinuous = true;
             break;
          } else if (status == 'R' || status == 'OFF' || status.isEmpty) {
             currentDay--;
          } else {
             break;
          }
        }
      }

      List<Set<String>> history = _getLast3Duties(person.idNumber, _selectedDate, dutyProvider);

      driverStats.add({
        'person': person,
        'history': history,
      });
    }

    driverStats.sort((a, b) {
      return (a['person'] as Manpower).name.compareTo((b['person'] as Manpower).name);
    });

    int n = driverStats.length;
    String v1 = _getDynamicV(0);
    String v2 = _getDynamicV(1);
    String v3 = _getDynamicV(2);
    String frv = _getDynamicV(3);
    String amb = _getDynamicV(4);
    String jeep = _getDynamicV(5);
    String icv = _getDynamicV(6);
    String bullet = _getDynamicV(7);
    String tc = _getDynamicV(8);
    String qrv = _getDynamicV(9);

    Map<int, List<String>> rankToVehicles = {};
    if (n == 1) {
      rankToVehicles[0] = [v1, v2, v3, amb, frv, bullet, qrv, icv, jeep, tc];
    } else if (n == 2) {
      rankToVehicles[0] = [v1, v3, amb, bullet, qrv, icv];
      rankToVehicles[1] = [v2, frv, jeep, tc];
    } else if (n == 3) {
      rankToVehicles[0] = [v1, bullet];
      rankToVehicles[1] = [v2, frv, jeep, tc];
      rankToVehicles[2] = [v3, amb, qrv, icv];
    } else if (n == 4) {
      rankToVehicles[0] = [v1, bullet];
      rankToVehicles[1] = [v2, jeep, tc];
      rankToVehicles[2] = [v3, amb];
      rankToVehicles[3] = [qrv, frv, icv];
    } else if (n == 5) {
      rankToVehicles[0] = [v1, bullet];
      rankToVehicles[1] = [v2, tc];
      rankToVehicles[2] = [v3, amb];
      rankToVehicles[3] = [qrv, jeep];
      rankToVehicles[4] = [icv, frv];
    } else if (n == 6) {
      rankToVehicles[0] = [v1, bullet];
      rankToVehicles[1] = [v2, tc];
      rankToVehicles[2] = [v3, jeep];
      rankToVehicles[3] = [qrv, amb];
      rankToVehicles[4] = [icv];
      rankToVehicles[5] = [frv];
    } else if (n == 7) {
      rankToVehicles[0] = [v1, bullet];
      rankToVehicles[1] = [v2];
      rankToVehicles[2] = [v3, jeep];
      rankToVehicles[3] = [qrv, amb];
      rankToVehicles[4] = [icv];
      rankToVehicles[5] = [frv];
      rankToVehicles[6] = [tc];
    } else if (n == 8) {
      rankToVehicles[0] = [v1, bullet];
      rankToVehicles[1] = [v2];
      rankToVehicles[2] = [v3];
      rankToVehicles[3] = [qrv, amb];
      rankToVehicles[4] = [icv];
      rankToVehicles[5] = [frv];
      rankToVehicles[6] = [tc];
      rankToVehicles[7] = [jeep];
    } else if (n >= 9) {
      rankToVehicles[0] = [v1, bullet];
      rankToVehicles[1] = [v2];
      rankToVehicles[2] = [v3];
      rankToVehicles[3] = [qrv];
      rankToVehicles[4] = [icv];
      rankToVehicles[5] = [frv];
      rankToVehicles[6] = [tc];
      rankToVehicles[7] = [jeep];
      rankToVehicles[8] = [amb];
    }

    List<int> allDrivers = [];
    for (int i = 0; i < n; i++) {
       if ((driverStats[i]['person'] as Manpower).isDriver) {
          allDrivers.add(i);
       }
    }

    // Score drivers based on recent driving (ICV or JEEP)
    // Score 3 if drove in last duty, 2 if in 2nd last, 1 if in 3rd last. 0 otherwise.
    Map<int, int> driverScores = {};
    for (int idx in allDrivers) {
       int score = 0;
       List<Set<String>> hist = driverStats[idx]['history'];
       if (hist.length > 0 && (hist[0].contains(icv) || hist[0].contains(jeep))) score = 3;
       else if (hist.length > 1 && (hist[1].contains(icv) || hist[1].contains(jeep))) score = 2;
       else if (hist.length > 2 && (hist[2].contains(icv) || hist[2].contains(jeep))) score = 1;
       driverScores[idx] = score;
    }

    // Sort drivers by score ascending (lowest score = hasn't driven recently, gets priority).
    // If scores tie, index order (alphabetical) is preserved naturally.
    allDrivers.sort((a, b) => driverScores[a]!.compareTo(driverScores[b]!));

    List<int> hgIndices = allDrivers.take(2).toList();

    // If exactly 2 drivers selected, optimize their assignment between ICV and JEEP based on penalty
    if (hgIndices.length == 2) {
       int getPenalty(int idx, String v) {
          int penalty = 0;
          List<Set<String>> hist = driverStats[idx]['history'];
          if (hist.length > 0 && hist[0].contains(v)) penalty += 10000;
          if (hist.length > 1 && hist[1].contains(v)) penalty += 5000;
          if (hist.length > 2 && hist[2].contains(v)) penalty += 2500;
          return penalty;
       }
       
       int option1Penalty = getPenalty(hgIndices[0], icv) + getPenalty(hgIndices[1], jeep);
       int option2Penalty = getPenalty(hgIndices[0], jeep) + getPenalty(hgIndices[1], icv);
       
       if (option2Penalty < option1Penalty) {
          int temp = hgIndices[0];
          hgIndices[0] = hgIndices[1];
          hgIndices[1] = temp;
       }
    }

    Map<String, int> finalAssignments = {};
    int numSlots = n > 9 ? 9 : n;
    
    List<int> allPersons = List.generate(n, (i) => i);
    List<int> allSlots = List.generate(numSlots, (i) => i);
    
    // In case of more people than slots, they get fallback slot 8
    while(allSlots.length < allPersons.length) {
       allSlots.add(8);
    }

    int minTotalPenalty = 9999999;
    List<int> bestAssignment = [];
    int iterations = 0;

    void solve(int pIdx, List<int> currentAssignment, int currentPenalty) {
       if (iterations > 50000) return;
       if (currentPenalty >= minTotalPenalty) return;
       
       if (pIdx == allPersons.length) {
          minTotalPenalty = currentPenalty;
          bestAssignment = List.from(currentAssignment);
          return;
       }
       
       int personIndex = allPersons[pIdx];
       List<Set<String>> history = driverStats[personIndex]['history'];
       
       for (int sIdx = 0; sIdx < allSlots.length; sIdx++) {
          if (!currentAssignment.contains(sIdx)) {
             int slot = allSlots[sIdx];
             int penalty = 0;
             List<String> proposedVehicles = rankToVehicles[slot] ?? [];
             for (String pv in proposedVehicles) {
                if (history.length >= 1 && history[0].contains(pv)) penalty += 10000;
                if (history.length >= 2 && history[1].contains(pv)) penalty += 5000;
                if (history.length >= 3 && history[2].contains(pv)) penalty += 2500;
             }
             
             currentAssignment.add(sIdx);
             iterations++;
             solve(pIdx + 1, currentAssignment, currentPenalty + penalty);
             currentAssignment.removeLast();
          }
       }
    }

    solve(0, [], 0);

    for (int i = 0; i < allPersons.length; i++) {
       if (i < bestAssignment.length) {
          String pId = (driverStats[allPersons[i]]['person'] as Manpower).id;
          finalAssignments[pId] = allSlots[bestAssignment[i]];
       }
    }

    // Now swap ICV and JEEP into the slots assigned to the top 2 drivers
    void applySwap(int driverIdx, String specialVehicle) {
        String pId = (driverStats[driverIdx]['person'] as Manpower).id;
        int driverSlot = finalAssignments[pId]!;
        
        int victimSlot = -1;
        for (int i = 0; i < numSlots; i++) {
            if (rankToVehicles[i] != null && rankToVehicles[i]!.contains(specialVehicle) && i != driverSlot) {
                victimSlot = i;
                break;
            }
        }
        
        if (victimSlot != -1) {
            rankToVehicles[victimSlot]!.remove(specialVehicle);
            if (rankToVehicles[driverSlot] != null && rankToVehicles[driverSlot]!.isNotEmpty) {
                String lastVehicle = rankToVehicles[driverSlot]!.last;
                rankToVehicles[driverSlot]!.removeLast();
                rankToVehicles[victimSlot]!.add(lastVehicle);
            }
            rankToVehicles[driverSlot]!.add(specialVehicle);
        } else {
            if (rankToVehicles[driverSlot] != null && !rankToVehicles[driverSlot]!.contains(specialVehicle)) {
                rankToVehicles[driverSlot]!.add(specialVehicle);
            }
        }
    }

    if (hgIndices.isNotEmpty) {
        applySwap(hgIndices[0], icv);
        if (hgIndices.length > 1) {
            applySwap(hgIndices[1], jeep);
        }
    }

    _khgControllers.forEach((key, controller) {
      controller.text = '';
    });

    for (int i = 0; i < n; i++) {
      String personId = (driverStats[i]['person'] as Manpower).id;
      if (!finalAssignments.containsKey(personId)) continue;
      
      int assignedSlot = finalAssignments[personId]!;
      String idNumber = (driverStats[i]['person'] as Manpower).idNumber;
      
      List<String> assignedVehicles = rankToVehicles[assignedSlot] ?? [];
      for (var vName in assignedVehicles) {
        if (_vehicleOffRoadStatus[vName] == true) continue;
        if (vName.isNotEmpty && _khgControllers.containsKey(vName)) {
           String current = _khgControllers[vName]!.text;
           if (current.isEmpty) {
             _khgControllers[vName]!.text = idNumber;
           } else {
             if (!current.contains(idNumber)) {
               _khgControllers[vName]!.text = '$current, $idNumber';
             }
           }
        }
      }
    }


    // Messenger Duty Assignment
    List<Map<String, dynamic>> eligibleForMessenger = [];
    for (int i = 1; i < driverStats.length; i++) {
       eligibleForMessenger.add(driverStats[i]);
    }

    if (eligibleForMessenger.isNotEmpty) {
       DateTime veryOld = DateTime(2000, 1, 1);
       for (var stat in eligibleForMessenger) {
          stat['lastMessengerDate'] = veryOld;
          Manpower p = stat['person'];
          for (var reg in dutyProvider.registers) {
             if (reg.date.isBefore(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day))) {
                if (reg.messengerIds.contains(p.idNumber)) {
                   stat['lastMessengerDate'] = reg.date;
                   break;
                }
             }
          }
       }
       
       eligibleForMessenger.sort((a, b) {
          DateTime dateA = a['lastMessengerDate'];
          DateTime dateB = b['lastMessengerDate'];
          return dateA.compareTo(dateB);
       });

       String messengerId = (eligibleForMessenger.first['person'] as Manpower).idNumber;
       _messengerIds = [messengerId];
    }

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auto-assigned KHGs and Messenger.')));
  }

  Widget _buildManualSelectionBlock(String title, List<String> items, Function(List<String>) onSave, {List<Manpower>? customList}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...items.map((id) {
              final isAbsent = _isAbsent(id);
              final chip = Chip(
                label: Text(id, style: TextStyle(
                  color: isAbsent ? Colors.redAccent : Colors.white,
                  fontWeight: isAbsent ? FontWeight.bold : FontWeight.normal,
                )),
                backgroundColor: isAbsent ? Colors.redAccent.withOpacity(0.1) : Colors.blueAccent.withOpacity(0.2),
                deleteIconColor: isAbsent ? Colors.redAccent : Colors.white70,
                onDeleted: () {
                  setState(() {
                    items.remove(id);
                  });
                },
              );
              
              if (isAbsent) {
                return BlinkingWidget(child: chip);
              }
              return chip;
            }),
            ActionChip(
              label: const Text('+ Add Personnel', style: TextStyle(color: Colors.blueAccent)),
              backgroundColor: Colors.transparent,
              shape: const StadiumBorder(side: BorderSide(color: Colors.blueAccent)),
              onPressed: () => _showManualSelectionDialog(title, items, onSave, customPersonnelList: customList),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Duty Register Form'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.blueAccent,
            surface: Color(0xFF0A0A0A),
          ),
        ),
        child: Stepper(
          currentStep: _currentStep,
          onStepTapped: (step) {
            if (step > 0 && !_isDateSelected) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select a Date first.'), backgroundColor: Colors.redAccent),
              );
              return;
            }
            setState(() => _currentStep = step);
          },
          onStepContinue: () {
            if (_currentStep == 0 && !_isDateSelected) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select a Date first.'), backgroundColor: Colors.redAccent),
              );
              return;
            }
            if (_currentStep < 3) {
              setState(() => _currentStep += 1);
            } else {
              _saveRegister();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep -= 1);
            }
          },
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(
                      _currentStep == 3 
                        ? (_existingRegisterId.isNotEmpty ? 'Update Register' : 'Save Register') 
                        : 'Next',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Back', style: TextStyle(color: Colors.white70)),
                    ),
                ],
              ),
            );
          },
          steps: [
          Step(
            title: const Text('General Info', style: TextStyle(color: Colors.white)),
            content: Column(
              children: [
                ListTile(
                  title: const Text('Date', style: TextStyle(color: Colors.white70)),
                  subtitle: Text(_isDateSelected ? DateFormat('dd-MMM-yyyy').format(_selectedDate) : 'Select Date', 
                    style: TextStyle(color: _isDateSelected ? Colors.white : Colors.redAccent, fontSize: 16, fontWeight: _isDateSelected ? FontWeight.normal : FontWeight.bold)),
                  trailing: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                  onTap: _selectDate,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(flex: 1, child: _buildTextField('Vacancy Count', _vacancyCountController)),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: _buildTextField('Vacancy Details', _vacancyDetailsController)),
                  ],
                ),
              ],
            ),
            isActive: _currentStep >= 0,
          ),
          Step(
            title: const Text('Personnel Summary', style: TextStyle(color: Colors.white)),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'This section will automatically pull data from the Attendance Register. Manual overrides will be added here in the next phase.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                _buildManualSelectionBlock('നിലയം എഴുത്തുകാരൻ (Station Writer)', _stationWriterIds, (selected) => setState(() => _stationWriterIds = selected), customList: _getOtherDutiesPersonnel(includeSfroM: false)),
              ],
            ),
            isActive: _currentStep >= 1,
          ),
          Step(
            title: const Text('Vehicle Detailing', style: TextStyle(color: Colors.white)),
            content: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: _autoAssignSFRO,
                      icon: const Icon(Icons.star, color: Colors.yellowAccent, size: 16),
                      label: const Text('Auto SFRO', style: TextStyle(color: Colors.yellowAccent, fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: _autoAssignDrivers,
                      icon: const Icon(Icons.directions_car, color: Colors.blueAccent, size: 16),
                      label: const Text('Auto FRO(D)', style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: _autoAssignFROMales,
                      icon: const Icon(Icons.male, color: Colors.lightBlueAccent, size: 16),
                      label: const Text('Auto FRO (M)', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: _autoAssignFRO,
                      icon: const Icon(Icons.female, color: Colors.pinkAccent, size: 16),
                      label: const Text('Auto FRO (F)', style: TextStyle(color: Colors.pinkAccent, fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: _autoAssignKHG,
                      icon: const Icon(Icons.security, color: Colors.orangeAccent, size: 16),
                      label: const Text('Auto KHG', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: _autoAssignAccessories,
                      icon: const Icon(Icons.build, color: Colors.grey, size: 16),
                      label: const Text('Auto Accessories', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  ],
                ),
                ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _vehicles.length,
              itemBuilder: (context, index) {
                final v = _vehicles[index];
                final vName = v.vehicleName;
                final isDuplicate = _hasDuplicateSeniority(v.seniority);
                
                Widget dropdown = DropdownButton<int>(
                  value: v.seniority,
                  dropdownColor: const Color(0xFF1E1E1E),
                  style: TextStyle(color: isDuplicate ? Colors.redAccent : Colors.white, fontWeight: FontWeight.bold),
                  underline: Container(),
                  items: List.generate(20, (i) => i + 1).map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text(_toRoman(value)),
                    );
                  }).toList(),
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      setState(() {
                        final vIndex = _vehicles.indexWhere((veh) => veh.vehicleName == vName);
                        if (vIndex != -1) {
                          _vehicles[vIndex] = DutyVehicleAssignment(
                            vehicleName: vName,
                            seniority: newValue,
                            sfro: v.sfro, fro: v.fro, khg: v.khg, froD: v.froD,
                            remarks: v.remarks
                          );
                          _vehicles.sort((a, b) => a.seniority.compareTo(b.seniority));
                        }
                      });
                    }
                  },
                );

                if (isDuplicate) {
                  dropdown = BlinkingWidget(child: dropdown);
                }

                // SCUBA check removed
                bool isCcv = vName == 'CCV KL-01-CU-5201';
                bool isOffRoad = _vehicleOffRoadStatus[vName] ?? false;
                bool isAttached = _vehicleAttachedStatus[vName] ?? false;
                bool ignorePersonnel = isCcv;
                
                String dropdownValue = 'Active';
                if (isOffRoad) dropdownValue = 'Off the road';
                if (isAttached) dropdownValue = 'Attachment';

                return Card(
                  color: Colors.white.withOpacity(0.05),
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(vName, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Status: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                DropdownButton<String>(
                                  value: dropdownValue,
                                  dropdownColor: const Color(0xFF1E1E1E),
                                  style: TextStyle(
                                    color: isOffRoad ? Colors.redAccent : (isAttached ? Colors.orangeAccent : Colors.white), 
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 12
                                  ),
                                  underline: Container(),
                                  items: ['Active', 'Off the road', 'Attachment'].map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _vehicleOffRoadStatus[vName] = newValue == 'Off the road';
                                        _vehicleAttachedStatus[vName] = newValue == 'Attachment';
                                        if (newValue != 'Active') {
                                          _sfroControllers[vName]!.clear();
                                          _froControllers[vName]!.clear();
                                          _khgControllers[vName]!.clear();
                                          // Do not clear FRO(D) as it is auto-posted
                                        }
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            dropdown,
                          ],
                        ),
                        const Text('Posted Personnel (IDs):', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        Opacity(
                          opacity: ignorePersonnel ? 0.3 : 1.0,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: IgnorePointer(ignoring: ignorePersonnel, child: _buildSelectionField('SFRO', 'SFRO', vName, _sfroControllers[vName]!, isRedHighlighted: isAttached || isOffRoad))),
                                  const SizedBox(width: 8),
                                  Expanded(child: IgnorePointer(ignoring: ignorePersonnel, child: _buildSelectionField('FRO', 'FRO', vName, _froControllers[vName]!, isRedHighlighted: isAttached || isOffRoad))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: IgnorePointer(ignoring: ignorePersonnel, child: _buildSelectionField('KHG', 'KHG', vName, _khgControllers[vName]!, isRedHighlighted: isAttached || isOffRoad))),
                                  const SizedBox(width: 8),
                                  Expanded(child: IgnorePointer(ignoring: ignorePersonnel, child: _buildSelectionField('FRO(D)', 'FRO(D)', vName, _froDControllers[vName]!, isRedHighlighted: isAttached))),
                                ],
                              ),
                            ]
                          )
                        ),
                        const SizedBox(height: 8),
                        _buildTextField('Remarks', _remarksControllers[vName]!),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        isActive: _currentStep >= 2,
      ),
          Step(
            title: const Text('Other Duties', style: TextStyle(color: Colors.white)),
            content: Column(
              children: [
                _buildManualSelectionBlock(
                  'Phone Duty Personnel',
                  _phoneDutyIds,
                  (selected) => setState(() => _phoneDutyIds = selected),
                  customList: _getOtherDutiesPersonnel(),
                ),
                const SizedBox(height: 16),
                _buildManualSelectionBlock(
                  'Messenger Personnel',
                  _messengerIds,
                  (selected) => setState(() => _messengerIds = selected),
                  customList: _getOtherDutiesPersonnel(includeSfroM: false),
                ),
                const SizedBox(height: 16),
                _buildManualSelectionBlock(
                  'Sentry Duty Personnel',
                  _sentryDutyIds,
                  (selected) => setState(() => _sentryDutyIds = selected),
                  customList: _getOtherDutiesPersonnel(includeSfroM: false),
                ),
                const SizedBox(height: 16),
                _buildManualSelectionBlock(
                  'Control Room Personnel',
                  _controlRoomIds,
                  (selected) => setState(() => _controlRoomIds = selected),
                  customList: _getOtherDutiesPersonnel(includeSfroM: false),
                ),
              ],
            ),
            isActive: _currentStep >= 3,
          ),
        ],
      ),
      ),
    );
  }
}

class BlinkingWidget extends StatefulWidget {
  final Widget child;
  const BlinkingWidget({super.key, required this.child});

  @override
  State<BlinkingWidget> createState() => _BlinkingWidgetState();
}

class _BlinkingWidgetState extends State<BlinkingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_controller),
      child: widget.child,
    );
  }
}

