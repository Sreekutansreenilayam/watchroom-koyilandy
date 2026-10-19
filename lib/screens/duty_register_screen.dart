import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../widgets/lock_hold_dialog.dart';
import '../models/duty_register_model.dart';
import '../models/manpower_model.dart';
import '../services/access_control.dart';
import '../providers/duty_provider.dart';
import '../providers/manpower_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/sentry_provider.dart';
import '../models/sentry_register_model.dart';
import '../providers/vehicle_provider.dart';
import '../config/app_config.dart';

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
    final isJeepCondemned = !date.isBefore(DateTime(2026, 10, 20));
    
    List<DutyVehicleAssignment> list = [];
    final vehicleProvider = context.read<VehicleProvider>();
    int seniority = 1;
    for (var v in vehicleProvider.vehicles) {
      if (v.status.toUpperCase() == 'CONDEMNED') continue;
      if (isJeepCondemned && (v.regNumber.contains('3717') || v.type.toUpperCase().contains('JEEP'))) {
        continue;
      }
      list.add(DutyVehicleAssignment(
        vehicleName: '${v.type} ${v.regNumber}'.trim(),
        seniority: seniority++,
        isOffRoad: v.status != 'READY',
      ));
    }
    
    if (AppConfig.isKoyilandy) {
      final kOrder = [
        'MTU KL01CU9874',
        'MTU KL01BZ7112',
        'WATER MIST KL01CC6015',
        'AMBULANCE KL01CK792',
        'BULLET KL01BB7142',
        'MUV KL01DK2865',
        'MNI MTU KL01BB2997',
        if (!isJeepCondemned) 'JEEP KL01BB3717'
      ];
      list.sort((a, b) {
        int indexA = kOrder.indexWhere((o) => a.vehicleName.contains(o));
        int indexB = kOrder.indexWhere((o) => b.vehicleName.contains(o));
        if (indexA == -1) indexA = 999;
        if (indexB == -1) indexB = 999;
        return indexA.compareTo(indexB);
      });
      for (int i = 0; i < list.length; i++) {
        list[i] = DutyVehicleAssignment(
          vehicleName: list[i].vehicleName,
          seniority: i + 1,
          isOffRoad: list[i].isOffRoad,
        );
      }
      list.add(DutyVehicleAssignment(vehicleName: 'Aska, Portable Pump, Chainsaw', seniority: list.length + 1));
      list.add(DutyVehicleAssignment(vehicleName: 'Outboard Engine, Chainsaw, Hydraulic Equipment, Honda Generator, Dinghy & Accessories', seniority: list.length + 1));
      list.add(DutyVehicleAssignment(vehicleName: 'SCUBA', seniority: list.length + 1));
      list.add(DutyVehicleAssignment(vehicleName: 'Torch', seniority: list.length + 1));
    } else if (AppConfig.isMeenchanda) {
      list.addAll([
        DutyVehicleAssignment(vehicleName: isNewRule ? 'C/S - 1, 7, 8, 13, Aska-III (I-F/T)' : 'C/S - 1, 7, 8, 13, Aska-III (I-MTU)', seniority: seniority++),
        DutyVehicleAssignment(vehicleName: isNewRule ? 'C/S - 4, 5, 6, 11, Fanergy, Float Pump, Hydraulic Lukas (II-W/B)' : 'C/S - 4, 5, 6, 11, Fanergy, Float Pump, Hydraulic Lukas (F/T)', seniority: seniority++),
        DutyVehicleAssignment(vehicleName: 'C/S-2, 3, 9, 10, 12, Gen EU-65, EXK-2800, OBM, Mini Moon Light (QRV)', seniority: seniority++),
        DutyVehicleAssignment(vehicleName: 'Wireless, Interactive Flat Panel Display', seniority: seniority++),
        DutyVehicleAssignment(vehicleName: 'Blower, Torch set', seniority: seniority++),
        DutyVehicleAssignment(vehicleName: 'BA Set, Gas Detector', seniority: seniority++),
      ]);
    }
    
    return list;
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

        // From 20-Oct-2026 onwards, JEEP KL01BB3717 is condemned and removed from station
        if (!date.isBefore(DateTime(2026, 10, 20))) {
          completeVehiclesList.removeWhere((v) => v.vehicleName.contains('KL01BB3717') || v.vehicleName.toUpperCase().contains('JEEP'));
        }

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

        final defaults = _getDefaultVehicles(targetDate: date);
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
        
        _vehicles = _getDefaultVehicles(targetDate: date);
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
      if (['SFRO'].contains(p.designation)) {
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
          return ['SFRO'].contains(p.designation);
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
                      if (vehicleName == v1) {
                        targetAcc = acc1;
                      } else if (vehicleName == v2) targetAcc = acc2;
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
      String digits = match.group(0)!;
      int num = int.parse(digits);
      
      if (num < 100) return num + 200000; // 1 or 2-digit numbers are most junior
      if (num < 1000) return num + 100000; // 3-digit numbers are junior (probation)
      if (digits.startsWith('10')) return num + 50000; // 4-digit numbers starting with 10 are temporary/junior
      
      return num; // Normal 4-digit numbers (like 6015, 7112) are senior
    }
    return 999999;
  }

  int _getRotatedSeniorityRank(String idNumber) {
    List<Manpower> active = context.read<ManpowerProvider>().personnelList;
    if (active.isEmpty) return _getSeniorityRank(idNumber);

    List<Manpower> sorted = List.from(active);
    sorted.sort((a, b) => _getSeniorityRank(a.idNumber).compareTo(_getSeniorityRank(b.idNumber)));
    
    int index = sorted.indexWhere((p) => p.idNumber == idNumber);
    if (index == -1) return _getSeniorityRank(idNumber); // fallback
    
    return (index + _selectedDate.day) % sorted.length;
  }

  int _getConsecutive(String id) {
    final manpowerProvider = context.read<ManpowerProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    final pList = manpowerProvider.personnelList.where((p) => p.idNumber == id).toList();
    if (pList.isEmpty) return 0;
    final att = attendanceProvider.attendanceMap[pList.first.id];
    if (att == null) return 0;
    int count = 0;
    int currentDay = _selectedDate.day - 1;
    while (currentDay > 0) {
      final status = att.dailyStatus[currentDay];
      if (status == null || status.trim().isEmpty || status.trim().toUpperCase() == 'X' || status.trim().toUpperCase() == 'X/R') break;
      count++;
      currentDay--;
    }
    return count;
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
          if (history.isNotEmpty && history[0].contains(targetV)) score += 2000000;
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




  void _autoAssignVehicles() {
    setState(() {
      for (var v in _vehicles) {
        _sfroControllers[v.vehicleName]?.clear();
        _froControllers[v.vehicleName]?.clear();
        _khgControllers[v.vehicleName]?.clear();
        _froDControllers[v.vehicleName]?.clear();
      }

      // Fetch All Available Personnel
      final allSfro = List<Manpower>.from(_getOnDutyPersonnel('SFRO'));
      final allFro = List<Manpower>.from(_getOnDutyPersonnel('FRO'));
      final allKhg = List<Manpower>.from(_getOnDutyPersonnel('KHG'));
      final allFroD = List<Manpower>.from(_getOnDutyPersonnel('FRO(D)'));

      final dutyProvider = context.read<DutyProvider>();
      Map<String, int> assignmentsToday = {};

      String pickForDuty(List<Manpower> pool, String dutyTypeOrVehicle) {
        if (pool.isEmpty) return '';
        List<Manpower> sortedPool = List.from(pool);
        sortedPool.sort((a, b) {
          int assignA = assignmentsToday[a.idNumber] ?? 0;
          int assignB = assignmentsToday[b.idNumber] ?? 0;
          if (assignA != assignB) return assignA.compareTo(assignB);
          
          int scoreA = 0;
          int scoreB = 0;
          var aHist = _getLast3Duties(a.idNumber, _selectedDate, dutyProvider);
          var bHist = _getLast3Duties(b.idNumber, _selectedDate, dutyProvider);
          
          // History penalty
          bool isOtherDuty = dutyTypeOrVehicle == 'Phone Duty' || dutyTypeOrVehicle == 'Watch Room/Wireless' || dutyTypeOrVehicle == 'Messenger';
          
          bool hasDuty(Set<String> d, String target) {
             if (isOtherDuty) return d.any((x) => x.contains(target));
             return d.any((x) => x.contains(target)); // They are mixed in history
          }
          
          if (aHist.isNotEmpty && hasDuty(aHist[0], dutyTypeOrVehicle)) scoreA += 10;
          if (bHist.isNotEmpty && hasDuty(bHist[0], dutyTypeOrVehicle)) scoreB += 10;
          if (aHist.length > 1 && hasDuty(aHist[1], dutyTypeOrVehicle)) scoreA += 5;
          if (bHist.length > 1 && hasDuty(bHist[1], dutyTypeOrVehicle)) scoreB += 5;
          
          if (scoreA != scoreB) return scoreA.compareTo(scoreB);
          
          int freqA = 0;
          int freqB = 0;
          for (var reg in dutyProvider.registers) {
             if (isOtherDuty) {
                if (dutyTypeOrVehicle == 'Phone Duty' && reg.phoneDutyIds.contains(a.idNumber)) freqA++;
                if (dutyTypeOrVehicle == 'Watch Room/Wireless' && reg.controlRoomIds.contains(a.idNumber)) freqA++;
                if (dutyTypeOrVehicle == 'Messenger' && reg.messengerIds.contains(a.idNumber)) freqA++;
                
                if (dutyTypeOrVehicle == 'Phone Duty' && reg.phoneDutyIds.contains(b.idNumber)) freqB++;
                if (dutyTypeOrVehicle == 'Watch Room/Wireless' && reg.controlRoomIds.contains(b.idNumber)) freqB++;
                if (dutyTypeOrVehicle == 'Messenger' && reg.messengerIds.contains(b.idNumber)) freqB++;
             } else {
                for (var v in reg.vehicleAssignments) {
                    if (v.vehicleName.contains(dutyTypeOrVehicle)) {
                        if (v.sfro.contains(a.idNumber) || v.fro.contains(a.idNumber) || v.khg.contains(a.idNumber) || v.froD.contains(a.idNumber)) freqA++;
                        if (v.sfro.contains(b.idNumber) || v.fro.contains(b.idNumber) || v.khg.contains(b.idNumber) || v.froD.contains(b.idNumber)) freqB++;
                    }
                }
             }
          }
          if (freqA != freqB) return freqA.compareTo(freqB);
          
          int consA = _getConsecutive(a.idNumber);
          int consB = _getConsecutive(b.idNumber);
          if (consA != consB) return consB.compareTo(consA); // DESCENDING
          
          return _getRotatedSeniorityRank(a.idNumber).compareTo(_getRotatedSeniorityRank(b.idNumber));
        });
        
        final best = sortedPool.first;
        assignmentsToday[best.idNumber] = (assignmentsToday[best.idNumber] ?? 0) + 1;
        pool.removeWhere((p) => p.idNumber == best.idNumber);
        return best.idNumber;
      }

      _phoneDutyIds.clear();
      _controlRoomIds.clear();
      _messengerIds.clear();

      // --- ASSIGN OTHER DUTIES (Phone, Watch Room, Messenger) ---
      // 1. Phone Duty:
      // Always detailed to the senior-most SFRO (SFROs are never on sentry duty).
      // If NO SFRO is on duty, the senior-most FRO takes SFRO charge & Phone Duty.
      if (allSfro.isNotEmpty) {
         final sortedSfro = List<Manpower>.from(allSfro);
         sortedSfro.sort((a, b) {
           if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
           return _getSeniorityRank(a.idNumber).compareTo(_getSeniorityRank(b.idNumber));
         });
         _phoneDutyIds = [sortedSfro.first.idNumber];
      } else {
         final sortedFro = List<Manpower>.from(allFro);
         if (sortedFro.isNotEmpty) {
             sortedFro.sort((a, b) {
                 if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
                 return _getSeniorityRank(a.idNumber).compareTo(_getSeniorityRank(b.idNumber));
             });
             _phoneDutyIds = [sortedFro.first.idNumber];
         }
      }

      // 2. Watch Room / Wireless (Control Room):
      // Additional assignment on top of normal duty! Picked from on-duty FROs (excluding acting SFRO).
      final froPoolForWatchRoom = allFro.where((p) => !_phoneDutyIds.contains(p.idNumber)).toList();
      if (froPoolForWatchRoom.isNotEmpty) {
         String picked = pickForDuty(froPoolForWatchRoom, 'Watch Room/Wireless'); // This maps to controlRoom in DB
         if (picked.isNotEmpty) {
           _controlRoomIds = [picked];
           // Watch Room is an additional duty, reset penalty load so it does not affect vehicle assignment
           if ((assignmentsToday[picked] ?? 0) > 0) {
             assignmentsToday[picked] = assignmentsToday[picked]! - 1;
           }
         }
      }

      // 3. Messenger:
      // (Selected by rotation from H/Gs posted to Bullet or Ambulance after vehicle assignment)

      // --- AVAILABLE POOLS FOR VEHICLES ---
      // SFRO on Phone Duty can still lead vehicles; SFRO never does sentry
      final availableSFRO = List<Manpower>.from(allSfro);
      
      // All FROs are available for vehicles (including Watch Room and Sentry FROs).
      // The only exception is if an FRO is holding charge of SFRO (on Phone Duty when no SFRO present).
      final availableFRO = allFro.where((p) {
        if (allSfro.isEmpty && _phoneDutyIds.contains(p.idNumber)) return false;
        return true;
      }).toList();
      final availableKHG = allKhg.where((p) => !_sentryDutyIds.contains(p.idNumber)).toList();
      final availableFROD = allFroD.where((p) => !_sentryDutyIds.contains(p.idNumber)).toList();

      // --- FRO(D) DRIVER ASSIGNMENT ---
      String driver9874 = '';
      String driver7112 = '';
      String driverMist = '';
      String driverAmb = '';
      String driverMuv = '';
      String driverBullet = '';
      String driverMniMtu = '';
      String driverJeep = ''; // Jeep is condemned

      List<Manpower> sortedDrivers = List.from(availableFROD);
      sortedDrivers.sort((a, b) => _getRotatedSeniorityRank(a.idNumber).compareTo(_getRotatedSeniorityRank(b.idNumber)));
      List<String> dList = sortedDrivers.map((p) => p.idNumber).toList();

      if (dList.length == 2) {
        // I. 2 പേർ മാത്രമെങ്കിൽ:
        // 1st MTU: Amb, Bullet, Mini MTU
        // 2nd MTU: W/mist, MUV
        driver9874 = dList[0];
        driverAmb = dList[0];
        driverBullet = dList[0];
        driverMniMtu = dList[0];

        driver7112 = dList[1];
        driverMist = dList[1];
        driverMuv = dList[1];
      } else if (dList.length == 3) {
        // II. 3 പേർ ആണെങ്കിൽ:
        // 1: 1st, Amb, Bullet
        // 2: 2nd, MUV
        // 3: W/mist & Mini MTU
        driver9874 = dList[0];
        driverAmb = dList[0];
        driverBullet = dList[0];

        driver7112 = dList[1];
        driverMuv = dList[1];

        driverMist = dList[2];
        driverMniMtu = dList[2];
      } else if (dList.length >= 4) {
        // III. 4 പേർ ആണെങ്കിൽ:
        // 1: 1st, Bullet
        // 2: 2nd, MUV
        // 3: Amb
        // 4: W/mist & Mini MTU
        driver9874 = dList[0];
        driverBullet = dList[0];

        driver7112 = dList[1];
        driverMuv = dList[1];

        driverAmb = dList[2];

        driverMist = dList[3];
        driverMniMtu = dList[3];
      } else if (dList.length == 1) {
        driver9874 = dList[0];
        driver7112 = dList[0];
        driverMist = dList[0];
        driverAmb = dList[0];
        driverMuv = dList[0];
        driverBullet = dList[0];
        driverMniMtu = dList[0];
      }

      // --- FRO CREW ASSIGNMENT ---
      List<String> fro9874 = [];
      List<String> fro7112 = [];
      List<String> froMist = [];
      List<String> froMuv = [];
      List<String> froAmb = [];
      List<String> froBullet = [];
      List<String> froMniMtu = [];

      List<Manpower> sortedFroPool = List.from(availableFRO);
      sortedFroPool.sort((a, b) => _getRotatedSeniorityRank(a.idNumber).compareTo(_getRotatedSeniorityRank(b.idNumber)));
      List<String> froIds = sortedFroPool.map((p) => p.idNumber).toList();

      if (froIds.length <= 4) {
        // I. 4 പേർ ആണെങ്കിൽ (Rotation-wise):
        // a) 1st MTU & Mini MTU: 3 പേർ (same crew)
        fro9874 = froIds.take(3).toList();
        froMniMtu = List.from(fro9874);

        // b) 2nd MTU & MUV: 4-ാമൻ + 1st MTU-വിലെ 2 പേർ (same crew, ആകെ 3)
        String fourth = froIds.length >= 4 ? froIds[3] : '';
        List<String> firstMtuTwo = fro9874.length >= 2 ? fro9874.sublist(fro9874.length - 2) : List.from(fro9874);
        fro7112 = [if (fourth.isNotEmpty) fourth, ...firstMtuTwo].toSet().toList();
        froMuv = List.from(fro7112);

        // c) Water Mist: 1st MTU Sr. FRO (1 പേർ) + 2nd MTU Sr. FRO (1 പേർ)
        List<String> srFro9874 = List.from(fro9874)..sort((a, b) => _getSeniorityRank(a).compareTo(_getSeniorityRank(b)));
        List<String> srFro7112 = List.from(fro7112)..sort((a, b) => _getSeniorityRank(a).compareTo(_getSeniorityRank(b)));
        String wMist1 = srFro9874.isNotEmpty ? srFro9874.first : '';
        String wMist2 = srFro7112.firstWhere((id) => id != wMist1, orElse: () => (srFro7112.isNotEmpty ? srFro7112.first : ''));
        froMist = [if (wMist1.isNotEmpty) wMist1, if (wMist2.isNotEmpty && wMist2 != wMist1) wMist2];

        // d) Ambulance: 2nd MTU-ൽ ഉൾപ്പെടാത്ത FRO (1 പേർ)
        String ambFro = fro9874.firstWhere((id) => !fro7112.contains(id), orElse: () => (froIds.isNotEmpty ? froIds.first : ''));
        if (ambFro.isNotEmpty) froAmb = [ambFro];

        // e) Bullet: No FRO (1 FRO(D) & 1 H/G only)
        froBullet = [];
      } else if (froIds.length == 5) {
        // II. 5 പേർ ആണെങ്കിൽ (Rotation-wise):
        // a) 1st MTU & Mini MTU: 3 പേർ (same crew)
        fro9874 = froIds.take(3).toList();
        froMniMtu = List.from(fro9874);

        // b) 2nd MTU & MUV: 4-ാമൻ + 5-ാമൻ + 1st MTU-വിലെ Sr. FRO (same crew, ആകെ 3)
        String fourth = froIds[3];
        String fifth = froIds[4];
        List<String> srFro9874 = List.from(fro9874)..sort((a, b) => _getSeniorityRank(a).compareTo(_getSeniorityRank(b)));
        String firstSr = srFro9874.first;
        fro7112 = [fourth, fifth, firstSr];
        froMuv = List.from(fro7112);

        // c) Water Mist: 1st MTU Sr. FRO (1) + 2nd MTU Sr. FRO (1)
        List<String> srFro7112 = List.from(fro7112)..sort((a, b) => _getSeniorityRank(a).compareTo(_getSeniorityRank(b)));
        String wMist1 = firstSr;
        String wMist2 = srFro7112.firstWhere((id) => id != wMist1, orElse: () => (srFro7112.isNotEmpty ? srFro7112.first : ''));
        froMist = [wMist1, if (wMist2.isNotEmpty && wMist2 != wMist1) wMist2];

        // d) Ambulance: 2nd MTU-ൽ ഉൾപ്പെടാത്ത FRO (1 പേർ)
        List<String> notIn7112 = fro9874.where((id) => !fro7112.contains(id)).toList();
        String ambFro = notIn7112.isNotEmpty ? notIn7112.first : froIds.first;
        froAmb = [ambFro];

        // e) Bullet: No FRO (1 FRO(D) & 1 H/G only)
        froBullet = [];
      } else {
        // 5-ൽ കൂടുതൽ പേർ ആണെങ്കിൽ:
        fro9874 = froIds.take(3).toList();
        froMniMtu = List.from(fro9874);

        List<String> remaining = froIds.skip(3).toList();
        fro7112 = remaining.take(3).toList();
        if (fro7112.length < 3) {
          for (var id in fro9874) {
            if (fro7112.length >= 3) break;
            if (!fro7112.contains(id)) fro7112.add(id);
          }
        }
        froMuv = List.from(fro7112);

        List<String> srFro9874 = List.from(fro9874)..sort((a, b) => _getSeniorityRank(a).compareTo(_getSeniorityRank(b)));
        List<String> srFro7112 = List.from(fro7112)..sort((a, b) => _getSeniorityRank(a).compareTo(_getSeniorityRank(b)));
        String wMist1 = srFro9874.isNotEmpty ? srFro9874.first : '';
        String wMist2 = srFro7112.firstWhere((id) => id != wMist1, orElse: () => (srFro7112.isNotEmpty ? srFro7112.first : ''));
        froMist = [if (wMist1.isNotEmpty) wMist1, if (wMist2.isNotEmpty && wMist2 != wMist1) wMist2];

        String ambFro = fro9874.firstWhere((id) => !fro7112.contains(id), orElse: () => froIds.first);
        froAmb = [ambFro];
        froBullet = [];
      }

      // --- KHG (HOME GUARD) ASSIGNMENT ---
      List<String> khg9874 = [];
      List<String> khg7112 = [];
      List<String> khgMist = [];
      List<String> khgMuv = [];
      List<String> khgAmb = [];
      List<String> khgMniMtu = [];
      List<String> khgBullet = [];
      List<String> khgTorch = [];

      List<Manpower> sortedKhgPool = List.from(availableKHG);
      sortedKhgPool.sort((a, b) => _getRotatedSeniorityRank(a.idNumber).compareTo(_getRotatedSeniorityRank(b.idNumber)));
      List<String> khgIds = sortedKhgPool.map((p) => p.idNumber).toList();

      // 1. Single H/G each for 1st MTU, 2nd MTU, Water Mist, MUV
      if (khgIds.isNotEmpty) khg9874.add(khgIds.removeAt(0));
      if (khgIds.isNotEmpty) khg7112.add(khgIds.removeAt(0));
      if (khgIds.isNotEmpty) khgMist.add(khgIds.removeAt(0));
      if (khgIds.isNotEmpty) khgMuv.add(khgIds.removeAt(0));
      if (khgMuv.isEmpty && khg7112.isNotEmpty) khgMuv.add(khg7112.first);

      // 2. Mini MTU: 2 H/G
      for (int i = 0; i < 2; i++) {
        if (khgIds.isNotEmpty) {
          khgMniMtu.add(khgIds.removeAt(0));
        }
      }
      if (khgMniMtu.isEmpty && khg9874.isNotEmpty) khgMniMtu.add(khg9874.first);
      if (khgMniMtu.length < 2 && khgMist.isNotEmpty && !khgMniMtu.contains(khgMist.first)) khgMniMtu.add(khgMist.first);

      // 3. Ambulance: 2 H/G (must NOT include 2nd MTU or MUV H/Gs!)
      List<String> forbiddenForAmb = [...khg7112, ...khgMuv];
      while (khgAmb.length < 2 && khgIds.isNotEmpty) {
        String cand = khgIds.firstWhere((id) => !forbiddenForAmb.contains(id), orElse: () => '');
        if (cand.isNotEmpty) {
          khgAmb.add(cand);
          khgIds.remove(cand);
        } else {
          break;
        }
      }
      // If shortage, borrow from 9874, Mist, Mini MTU (strictly avoiding 7112 & MUV)
      List<String> safeBorrowPool = [...khg9874, ...khgMist, ...khgMniMtu].where((id) => !forbiddenForAmb.contains(id)).toList();
      for (var id in safeBorrowPool) {
        if (khgAmb.length >= 2) break;
        if (!khgAmb.contains(id)) khgAmb.add(id);
      }

      // 4. Bullet H/G
      if (khgIds.isNotEmpty) {
        khgBullet.add(khgIds.removeAt(0));
      } else if (khgAmb.isNotEmpty) {
        khgBullet.add(khgAmb.first);
      } else if (khg9874.isNotEmpty) {
        khgBullet.add(khg9874.first);
      }

      // 5. Surplus KHGs (if any remaining) distributed
      while (khgIds.isNotEmpty) {
        khg9874.add(khgIds.removeAt(0));
        if (khgIds.isNotEmpty) khg7112.add(khgIds.removeAt(0));
        if (khgIds.isNotEmpty) khgMist.add(khgIds.removeAt(0));
      }

      // 6. Torch: 1st MTU posting H/G
      khgTorch = List.from(khg9874);

      // 7. Messenger: Selected by rotation from H/Gs posted to Bullet or Ambulance
      List<String> messengerCandidates = [...khgBullet, ...khgAmb].toSet().toList();
      if (messengerCandidates.isNotEmpty) {
        final messengerPool = allKhg.where((p) => messengerCandidates.contains(p.idNumber)).toList();
        if (messengerPool.isNotEmpty) {
          String picked = pickForDuty(messengerPool, 'Messenger');
          if (picked.isNotEmpty) {
            _messengerIds = [picked];
            if ((assignmentsToday[picked] ?? 0) > 0) {
              assignmentsToday[picked] = assignmentsToday[picked]! - 1;
            }
          }
        }
      }

      // --- SFRO ASSIGNMENT ---
      Map<String, String> sfroAssignments = {};
      if (availableSFRO.length == 1) {
         String sfroId = availableSFRO.first.idNumber;
         sfroAssignments['MTU KL01CU9874'] = sfroId;
         sfroAssignments['MUV KL01DK2865'] = sfroId;
         sfroAssignments['MTU KL01BZ7112'] = sfroId;
         sfroAssignments['MNI MTU KL01BB2997'] = sfroId;
      } else if (availableSFRO.length > 1) {
         sfroAssignments['MTU KL01CU9874'] = pickForDuty(availableSFRO, 'MTU KL01CU9874');
         sfroAssignments['MUV KL01DK2865'] = pickForDuty(availableSFRO, 'MUV KL01DK2865');
         sfroAssignments['MTU KL01BZ7112'] = pickForDuty(availableSFRO, 'MTU KL01BZ7112');
         sfroAssignments['MNI MTU KL01BB2997'] = sfroAssignments['MTU KL01CU9874']!;
         
         if (availableSFRO.length > 3) {
             sfroAssignments['WATER MIST KL01CC6015'] = pickForDuty(availableSFRO, 'WATER MIST KL01CC6015');
         }
      }

      String formatIds(List<String> ids) {
          if (ids.isEmpty) return '';
          var uniqueIds = ids.where((id) => id.isNotEmpty).toSet().toList();
          uniqueIds.sort((a, b) => _getSeniorityRank(a).compareTo(_getSeniorityRank(b)));
          return uniqueIds.join(', ');
      }

      // --- SCUBA CREW ASSIGNMENT ---
      // Priority 1: FRO 7569 and FRO(D) 2855 (their original designations).
      // - If both present: both posted (7569 in FRO, 2855 in FRO(D)).
      // - If single person present: only the present person is posted (no sr. FRO added).
      // - If neither present: 2 Senior FROs posted to FRO column.
      final p7569List = allFro.where((p) => p.idNumber.contains('7569')).toList();
      if (p7569List.isEmpty) {
        p7569List.addAll(allFroD.where((p) => p.idNumber.contains('7569')));
      }
      final p2855List = allFroD.where((p) => p.idNumber.contains('2855')).toList();
      if (p2855List.isEmpty) {
        p2855List.addAll(allFro.where((p) => p.idNumber.contains('2855')));
      }

      String scubaFro = '';
      String scubaFroD = '';

      bool has7569 = p7569List.isNotEmpty;
      bool has2855 = p2855List.isNotEmpty;

      if (has7569 && has2855) {
        scubaFro = p7569List.first.idNumber;
        scubaFroD = p2855List.first.idNumber;
      } else if (has7569 && !has2855) {
        scubaFro = p7569List.first.idNumber;
        scubaFroD = '';
      } else if (!has7569 && has2855) {
        scubaFro = '';
        scubaFroD = p2855List.first.idNumber;
      } else {
        // Neither present: 2 Senior FROs posted to FRO column
        List<Manpower> availableForScuba = allFro.where((p) => !_phoneDutyIds.contains(p.idNumber)).toList();
        if (availableForScuba.isEmpty) availableForScuba = List.from(allFro);
        
        availableForScuba.sort((a, b) {
          if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
          return _getSeniorityRank(a.idNumber).compareTo(_getSeniorityRank(b.idNumber));
        });
        
        List<String> top2FroIds = availableForScuba.take(2).map((p) => p.idNumber).toList();
        scubaFro = formatIds(top2FroIds);
        scubaFroD = '';
      }

      // Write to controllers

      for (var v in _vehicles) {
        final vName = v.vehicleName;
        if (vName.contains('MTU KL01CU9874')) {
           _froDControllers[vName]?.text = driver9874;
           _khgControllers[vName]?.text = formatIds(khg9874);
           _froControllers[vName]?.text = formatIds(fro9874);
           if (sfroAssignments.containsKey('MTU KL01CU9874')) _sfroControllers[vName]?.text = sfroAssignments['MTU KL01CU9874']!;
        } else if (vName.contains('MTU KL01BZ7112')) {
           _froDControllers[vName]?.text = driver7112;
           _khgControllers[vName]?.text = formatIds(khg7112);
           _froControllers[vName]?.text = formatIds(fro7112);
           if (sfroAssignments.containsKey('MTU KL01BZ7112')) _sfroControllers[vName]?.text = sfroAssignments['MTU KL01BZ7112']!;
        } else if (vName.contains('WATER MIST KL01CC6015')) {
           _froDControllers[vName]?.text = driverMist;
           _khgControllers[vName]?.text = formatIds(khgMist);
           _froControllers[vName]?.text = formatIds(froMist);
           if (sfroAssignments.containsKey('WATER MIST KL01CC6015')) _sfroControllers[vName]?.text = sfroAssignments['WATER MIST KL01CC6015']!;
        } else if (vName.contains('AMBULANCE KL01CK792')) {
           _froDControllers[vName]?.text = driverAmb;
           _khgControllers[vName]?.text = formatIds(khgAmb);
           _froControllers[vName]?.text = formatIds(froAmb);
        } else if (vName.contains('MUV KL01DK2865')) {
           _froDControllers[vName]?.text = driverMuv;
           _khgControllers[vName]?.text = formatIds(khgMuv);
           _froControllers[vName]?.text = formatIds(froMuv);
           if (sfroAssignments.containsKey('MUV KL01DK2865')) _sfroControllers[vName]?.text = sfroAssignments['MUV KL01DK2865']!;
        } else if (vName.contains('BULLET KL01BB7142')) {
           _froDControllers[vName]?.text = driverBullet;
           _khgControllers[vName]?.text = formatIds(khgBullet);
           _froControllers[vName]?.text = formatIds(froBullet);
        } else if (vName.contains('JEEP KL01BB3717')) {
           _froDControllers[vName]?.text = driverJeep;
        } else if (vName.contains('MNI MTU KL01BB2997')) {
           _froDControllers[vName]?.text = driverMniMtu;
           _khgControllers[vName]?.text = formatIds(khgMniMtu);
           _froControllers[vName]?.text = formatIds(froMniMtu);
           if (sfroAssignments.containsKey('MNI MTU KL01BB2997')) _sfroControllers[vName]?.text = sfroAssignments['MNI MTU KL01BB2997']!;
        } else if (vName.contains('Aska, Portable Pump, Chainsaw')) {
           _froDControllers[vName]?.text = driver9874;
        } else if (vName.contains('Outboard Engine') || vName.contains('Hydraulic Equipment')) {
           _froDControllers[vName]?.text = driver7112;
        } else if (vName == 'SCUBA' || vName.contains('SCUBA')) {
           _froControllers[vName]?.text = scubaFro;
           _froDControllers[vName]?.text = scubaFroD;
        } else if (vName.contains('Torch')) {
           _khgControllers[vName]?.text = formatIds(khgTorch);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicles & Duties Auto-assigned.'), backgroundColor: Colors.green),
      );
    });
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
                    BlinkingAutoAssignButton(
                      onPressed: _autoAssignVehicles,
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
                  items: List.generate((_vehicles.length > 30 ? _vehicles.length + 10 : 30), (i) => i + 1).map((int value) {
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
                  'Watch Room/Wireless Personnel',
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

class BlinkingAutoAssignButton extends StatefulWidget {
  final VoidCallback onPressed;
  const BlinkingAutoAssignButton({super.key, required this.onPressed});

  @override
  State<BlinkingAutoAssignButton> createState() => _BlinkingAutoAssignButtonState();
}

class _BlinkingAutoAssignButtonState extends State<BlinkingAutoAssignButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _hasClicked = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.2, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.repeat(reverse: true);
  }

  void _handlePress() {
    if (!_hasClicked) {
      setState(() {
        _hasClicked = true;
        _controller.stop();
        _controller.value = 1.0;
      });
    }
    widget.onPressed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        margin: const EdgeInsets.all(2), // Prevent border clipping
        child: OutlinedButton.icon(
          onPressed: _handlePress,
          icon: const Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
          label: const Text(
            'Auto Assign Vehicles',
            style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.amber, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ),
    );
  }
}








