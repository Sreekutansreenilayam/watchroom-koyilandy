import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehicle_model.dart';
import '../models/logbook_model.dart';
import '../providers/logbook_provider.dart';
import '../providers/duty_provider.dart';
import '../providers/manpower_provider.dart';
import '../providers/fuel_provider.dart';
import '../models/duty_register_model.dart';
import '../models/manpower_model.dart';
import '../models/fuel_model.dart';
import '../services/access_control.dart';
import '../providers/auth_provider.dart';

class LogbookFormScreen extends StatefulWidget {
  final VehicleModel vehicle;
  final LogbookEntry? entryToEdit;
  final DateTime selectedDate;
  final bool canEdit;
  final bool isEmergencyOnly;

  const LogbookFormScreen({
    super.key,
    required this.vehicle,
    this.entryToEdit,
    required this.selectedDate,
    this.canEdit = true,
    this.isEmergencyOnly = false,
  });

  @override
  State<LogbookFormScreen> createState() => _LogbookFormScreenState();
}

class _LogbookFormScreenState extends State<LogbookFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _date;
  bool _isDateSelected = false;
  String? _selectedActionType;

  List<String> get _currentAvailableActions {
    final provider = context.read<LogbookProvider>();
    final entriesToday = provider.entries.where((e) =>
        e.date.year == _date.year &&
        e.date.month == _date.month &&
        e.date.day == _date.day
    ).toList();

    List<String> actions = [];

    if (widget.isEmergencyOnly) {
       bool hasEmergencyTaken = entriesToday.any((e) =>
         e.actionType == 'Emergency Taking on Charge' &&
         e.operatorName == _operatorController.text
       );

       if (hasEmergencyTaken && widget.entryToEdit?.actionType != 'Emergency Taking on Charge') {
         actions = ['Onward Journey', 'Return Journey', 'Fuel Drain/Decanting'];
       } else {
         actions = ['Emergency Taking on Charge'];
       }
    } else {
       actions = ['Taking on Charge', 'Onward Journey', 'Return Journey', 'Fuel Drain/Decanting'];
    }

    if (_selectedActionType != null && !actions.contains(_selectedActionType)) {
      actions.add(_selectedActionType!);
    }

    return actions;
  }

  final _prevKmsController = TextEditingController();
  final _remFuelController = TextEditingController();
  final _supFuelController = TextEditingController();
  final _oilController = TextEditingController();
  final _greaseController = TextEditingController();
  final _dWaterController = TextEditingController();

  final _depTimeController = TextEditingController();
  final _fromPlaceController = TextEditingController();
  final _toPlaceController = TextEditingController();
  final _arrTimeController = TextEditingController();
  final _distController = TextEditingController();
  final _currOdoController = TextEditingController();
  bool _isUpdatingOdo = false;

  final _pumpStartController = TextEditingController();
  final _pumpEndController = TextEditingController();
  final _pumpDurController = TextEditingController();
  final _pumpKmController = TextEditingController();

  final _fuelJrnController = TextEditingController();
  final _fuelPumpController = TextEditingController();

  final _remarksController = TextEditingController();
  final _checkTimeController = TextEditingController();
  final _operatorController = TextEditingController();
  final _drainedFuelController = TextEditingController();

  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _date = widget.entryToEdit?.date ?? widget.selectedDate;
    if (widget.entryToEdit != null) _isDateSelected = true;

    if (widget.entryToEdit != null) {
      final e = widget.entryToEdit!;
      _prevKmsController.text = e.previousKms % 1 == 0 ? e.previousKms.toInt().toString() : e.previousKms.toString();
      _remFuelController.text = e.remainingFuelInTank.toString();
      _supFuelController.text = e.suppliedFuel.toString();
      _oilController.text = e.oil.toString();
      _greaseController.text = e.grease.toString();
      _dWaterController.text = e.dWater.toString();
      _depTimeController.text = e.departureTime;
      _fromPlaceController.text = e.fromPlace;
      _toPlaceController.text = e.toPlace;
      _arrTimeController.text = e.arrivalTime;
      _distController.text = e.travelledDistance.toString();

      double storedPumpKm = e.pumpKm;
      if (storedPumpKm == 0 && e.fuelConsumedForPump > 0 && widget.vehicle.mileageOnPumping > 0) {
        storedPumpKm = e.fuelConsumedForPump * widget.vehicle.mileageOnPumping;
      }

      double initCurrOdo = e.previousKms + e.travelledDistance + storedPumpKm;
      _currOdoController.text = initCurrOdo > 0 ? _formatDecimal(initCurrOdo) : '';

      _pumpStartController.text = e.pumpStartTime;
      _pumpEndController.text = e.pumpEndTime;
      _pumpDurController.text = e.pumpDuration;
      _pumpKmController.text = storedPumpKm > 0 ? _formatDecimal(storedPumpKm) : '';
      _fuelJrnController.text = e.fuelConsumedForJourney.toString();
      _fuelPumpController.text = e.fuelConsumedForPump.toString();
      _remarksController.text = e.remarks;
      _checkTimeController.text = e.vehicleCheckTime;
      _operatorController.text = e.operatorName;
      if (e.actionType == 'Fuel Drain/Decanting' && e.suppliedFuel < 0) {
        _drainedFuelController.text = (-e.suppliedFuel).toString();
      }
      if (e.actionType.isNotEmpty) {
        _selectedActionType = e.actionType;
      }
    } else {
      final logbookProvider = context.read<LogbookProvider>();
      if (logbookProvider.entries.isNotEmpty) {
        final last = logbookProvider.entries.last;
        double lastEndingOdo = last.previousKms + last.travelledDistance + last.pumpKm;
        double lastEndingFuel = (last.remainingFuelInTank + last.suppliedFuel - last.fuelConsumedForJourney - last.fuelConsumedForPump).clamp(0.0, 99999.0);

        if (lastEndingOdo > 0) {
          _prevKmsController.text = lastEndingOdo % 1 == 0 ? lastEndingOdo.toInt().toString() : lastEndingOdo.toString();
        }
        _remFuelController.text = _formatDecimal(lastEndingFuel);
      } else {
        if (widget.vehicle.currentOdometer > 0) {
          _prevKmsController.text = widget.vehicle.currentOdometer % 1 == 0 ? widget.vehicle.currentOdometer.toInt().toString() : widget.vehicle.currentOdometer.toString();
        }
        if (widget.vehicle.currentFuelInTank > 0) {
          _remFuelController.text = widget.vehicle.currentFuelInTank % 1 == 0 ? widget.vehicle.currentFuelInTank.toInt().toString() : widget.vehicle.currentFuelInTank.toString();
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoFillDriverFromDutyRegister();
        _fetchFuelLedgerData();
        if (logbookProvider.entries.isEmpty) {
          _fetchAbsoluteLatestLogbookEntry();
        }
      });
    }

    _isInitializing = false;

    _fuelJrnController.addListener(_recalculateRemainingFuel);
    _fuelPumpController.addListener(_recalculateRemainingFuel);
    _drainedFuelController.addListener(_recalculateRemainingFuel);
    _distController.addListener(_onDistanceChanged);
    _currOdoController.addListener(_onCurrentOdoChanged);
    _pumpKmController.addListener(_onDistanceChanged);
    _prevKmsController.addListener(() {
      if (_distController.text.isNotEmpty) {
        _onDistanceChanged();
      } else if (_currOdoController.text.isNotEmpty) {
        _onCurrentOdoChanged();
      }
    });
  }

  @override
  void dispose() {
    _prevKmsController.dispose();
    _remFuelController.dispose();
    _supFuelController.dispose();
    _oilController.dispose();
    _greaseController.dispose();
    _dWaterController.dispose();
    _depTimeController.dispose();
    _fromPlaceController.dispose();
    _toPlaceController.dispose();
    _arrTimeController.dispose();
    _distController.dispose();
    _currOdoController.dispose();
    _pumpStartController.dispose();
    _pumpEndController.dispose();
    _pumpDurController.dispose();
    _pumpKmController.dispose();
    _fuelJrnController.dispose();
    _fuelPumpController.dispose();
    _drainedFuelController.dispose();
    _remarksController.dispose();
    _checkTimeController.dispose();
    _operatorController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(TextEditingController controller) async {
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
    } else {
      String inheritFrom = '';
      if (controller == _arrTimeController) {
        inheritFrom = _depTimeController.text;
      } else if (controller == _pumpEndController) {
        inheritFrom = _pumpStartController.text;
      } else if (controller == _pumpStartController) {
        inheritFrom = _depTimeController.text;
      }

      if (inheritFrom.isNotEmpty) {
        final parts = inheritFrom.split(':');
        if (parts.length == 2) {
          int? h = int.tryParse(parts[0]);
          int? m = int.tryParse(parts[1]);
          if (h != null && m != null) {
            initialDateTime = DateTime(now.year, now.month, now.day, h, m);
          }
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
  }


  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: Color(0xFFE53935)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _isDateSelected = true;
      });
      _autoFillDriverFromDutyRegister();
      _fetchFuelLedgerData();
      _checkSaturdayDS();
    }
  }

  DateTime? _getEmergencyTakingTime() {
    final linkedPersonId = context.read<AuthProvider>().linkedPersonId;
    if (linkedPersonId == null || linkedPersonId.isEmpty) return null;

    final person = context.read<ManpowerProvider>().personnelList.firstWhere((p) => p.id == linkedPersonId, orElse: () => Manpower(id: '', idNumber: '', name: '', designation: '', mobileNumber: '', isDriver: false));
    if (person.id.isEmpty) return null;

    final provider = context.read<LogbookProvider>();
    try {
      final emergencyEntry = provider.entries.firstWhere((e) =>
          e.date.year == _date.year &&
          e.date.month == _date.month &&
          e.date.day == _date.day &&
          e.actionType == 'Emergency Taking on Charge' &&
          (e.operatorName.contains(person.name) || e.operatorName.contains(person.idNumber)));

      if (emergencyEntry.vehicleCheckTime.isNotEmpty) {
        final parts = emergencyEntry.vehicleCheckTime.split(':');
        if (parts.length == 2) {
          return DateTime(_date.year, _date.month, _date.day, int.parse(parts[0]), int.parse(parts[1]));
        }
      }
    } catch (_) {}
    return null;
  }

  int _timeToDutyMinutes(String timeStr) {
    if (timeStr.isEmpty) return 0;
    final parts = timeStr.split(':');
    if (parts.length != 2) return 0;
    int hour = int.tryParse(parts[0]) ?? 0;
    int min = int.tryParse(parts[1]) ?? 0;
    int totalMins = hour * 60 + min;
    int dutyStartMins = 9 * 60;
    if (totalMins >= dutyStartMins) {
      return totalMins - dutyStartMins;
    } else {
      return (24 * 60 - dutyStartMins) + totalMins;
    }
  }

  bool _isContinuousDuty(DateTime pastDate) {
    final now = DateTime.now();
    final todayDuty = AccessControl.getDutyDate(now);

    if (!pastDate.isBefore(todayDuty)) return false;

    DateTime checkDate = DateTime(pastDate.year, pastDate.month, pastDate.day);
    while (!checkDate.isAfter(todayDuty)) {
      bool present = AccessControl.isPresentOnDuty(context, checkDate);
      if (!present) return false;

      final assignedVehicles = AccessControl.getAssignedVehicles(context, checkDate);
      if (assignedVehicles.isEmpty) return false;

      final cleanReg = widget.vehicle.regNumber.replaceAll('-', '').replaceAll(' ', '').toLowerCase();
      final cleanType = widget.vehicle.type.replaceAll('-', '').replaceAll(' ', '').toLowerCase();
      
      bool isAssigned = assignedVehicles.any((assignedId) {
        final nameLower = assignedId.replaceAll('-', '').replaceAll(' ', '').toLowerCase();
        return (cleanReg.isNotEmpty && nameLower.contains(cleanReg)) ||
               (cleanType.isNotEmpty && nameLower.contains(cleanType));
      });

      if (!isAssigned) {
        return false;
      }
      checkDate = checkDate.add(const Duration(days: 1));
    }
    return true;
  }

  void _saveEntry() async {
    if (widget.entryToEdit != null && widget.entryToEdit!.actionType == 'Fuel Receipt') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ഈ എൻട്രി ഫ്യുവൽ ലെഡ്ജറിൽ നിന്നും സ്വയമേവ വന്നതാണ്. ഇത് ലോഗ്ബുക്കിൽ നിന്നും തിരുത്താനോ ഡിലീറ്റ് ചെയ്യാനോ സാധിക്കില്ല, അതിനായി ഫ്യുവൽ ലെഡ്ജറിൽ പോകുക.',
            textAlign: TextAlign.center,
          ),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final activeDates = AccessControl.getActiveDutyDates();
    bool isDateActive = activeDates.any((d) => d.year == _date.year && d.month == _date.month && d.day == _date.day);

    if (!isDateActive) {
      // Check if it's a continuous double/triple duty for this past date
      if (_date.isBefore(activeDates.first) && _isContinuousDuty(_date)) {
        isDateActive = true;
      }
    }

    if (!isDateActive) {
      final isAdminOrSfroM = AccessControl.isAdmin(context) || AccessControl.isSfroM(context);
      if (!isAdminOrSfroM) {
        bool isFuture = _date.isAfter(activeDates.last);
        String msg = isFuture
            ? 'ഭാവിയിലുള്ള ദിവസങ്ങളിലെ എൻട്രികൾ ചേർക്കാനോ തിരുത്താനോ നിങ്ങൾക്ക് അനുവാദമില്ല (Only Admin/SFRO(M))!'
            : 'മുൻപുള്ള ദിവസങ്ങളിലെ എൻട്രികൾ ചേർക്കാനോ തിരുത്താനോ നിങ്ങൾക്ക് അനുവാദമില്ല (Only Admin/SFRO(M))!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg, textAlign: TextAlign.center), backgroundColor: Colors.red),
        );
        return;
      }
    }

    if (!_isDateSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ദയവായി ഒരു തീയതി (Date) തിരഞ്ഞെടുക്കുക!', textAlign: TextAlign.center), backgroundColor: Colors.red),
      );
      return;
    }
    if (_formKey.currentState!.validate()) {
      if (_selectedActionType == 'Onward Journey' || _selectedActionType == 'Return Journey') {
        int newDepMins = _timeToDutyMinutes(_depTimeController.text);
        int newArrMins = _timeToDutyMinutes(_arrTimeController.text);

        if (newArrMins <= newDepMins) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('അവസാനിക്കുന്ന സമയം (Arrival Time) തുടങ്ങുന്ന സമയത്തേക്കാൾ (Departure Time) വലുതായിരിക്കണം!', textAlign: TextAlign.center), backgroundColor: Colors.red),
          );
          return;
        }

        final logbookProvider = context.read<LogbookProvider>();
        final entries = logbookProvider.entries;

        LogbookEntry? prevEntry;
        LogbookEntry? nextEntry;

        final dateEntries = entries.where((e) {
          if (widget.entryToEdit != null && e.id == widget.entryToEdit!.id) return false;
          return e.date.year == _date.year && e.date.month == _date.month && e.date.day == _date.day;
        }).toList();

        for (var e in dateEntries) {
          String eTime = e.departureTime.isNotEmpty ? e.departureTime : (e.pumpStartTime.isNotEmpty ? e.pumpStartTime : (e.vehicleCheckTime.isNotEmpty ? e.vehicleCheckTime : '23:59'));
          int eMins = _timeToDutyMinutes(eTime);
          if (eMins <= newDepMins) {
            prevEntry = e;
          } else {
            nextEntry ??= e;
          }
        }

        if (prevEntry != null && _selectedActionType != 'Fuel Drain/Decanting') {
           String prevEndTimeStr = prevEntry.arrivalTime.isNotEmpty ? prevEntry.arrivalTime : (prevEntry.pumpEndTime.isNotEmpty ? prevEntry.pumpEndTime : (prevEntry.vehicleCheckTime.isNotEmpty ? prevEntry.vehicleCheckTime : ''));
           if (prevEndTimeStr.isNotEmpty) {
             int prevEndMins = _timeToDutyMinutes(prevEndTimeStr);
             if (newDepMins < prevEndMins) {
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('തുടക്ക സമയം മുമ്പത്തെ യാത്ര അവസാനിച്ച സമയത്തിന് ($prevEndTimeStr) ശേഷമായിരിക്കണം!', textAlign: TextAlign.center), backgroundColor: Colors.red),
               );
               return;
             }
           }

           if (widget.entryToEdit == null) {
              double prevEndOdo = prevEntry.previousKms + prevEntry.travelledDistance + prevEntry.pumpKm;
              double newStartOdo = double.tryParse(_prevKmsController.text) ?? 0.0;
              if (newStartOdo < prevEndOdo) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('തുടക്കത്തിലെ Odometer റീഡിങ് മുമ്പത്തെ റീഡിങ്ങിനേക്കാൾ ($prevEndOdo) കുറവാകാൻ പാടില്ല!', textAlign: TextAlign.center), backgroundColor: Colors.red),
                );
                return;
              }
           }
        }

        if (nextEntry != null && _selectedActionType != 'Fuel Drain/Decanting') {
           String nextStartTimeStr = nextEntry.departureTime.isNotEmpty ? nextEntry.departureTime : (nextEntry.pumpStartTime.isNotEmpty ? nextEntry.pumpStartTime : (nextEntry.vehicleCheckTime.isNotEmpty ? nextEntry.vehicleCheckTime : ''));
           if (nextStartTimeStr.isNotEmpty) {
             int nextStartMins = _timeToDutyMinutes(nextStartTimeStr);
             int ourEndMins = newArrMins > 0 ? newArrMins : newDepMins;
             if (ourEndMins > nextStartMins) {
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('അവസാനിക്കുന്ന സമയം അടുത്ത യാത്രയുടെ തുടക്ക സമയത്തിന് () മുൻപായിരിക്കണം!', textAlign: TextAlign.center), backgroundColor: Colors.red),
               );
               return;
             }
           }
        }

        if (nextEntry != null) {
           String nextStartTimeStr = nextEntry.departureTime.isNotEmpty ? nextEntry.departureTime : (nextEntry.pumpStartTime.isNotEmpty ? nextEntry.pumpStartTime : (nextEntry.vehicleCheckTime.isNotEmpty ? nextEntry.vehicleCheckTime : ''));
           if (nextStartTimeStr.isNotEmpty) {
              int nextStartMins = _timeToDutyMinutes(nextStartTimeStr);
              if (newArrMins > nextStartMins) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text('അവസാനിക്കുന്ന സമയം അടുത്ത യാത്ര തുടങ്ങിയ സമയത്തേക്കാൾ ($nextStartTimeStr) മുന്നിലായിരിക്കണം!', textAlign: TextAlign.center), backgroundColor: Colors.red),
                 );
                 return;
              }
           }
        }
      }

      if (widget.entryToEdit == null &&
          _selectedActionType != 'Taking on Charge' &&
          _selectedActionType != 'Emergency Taking on Charge' &&
          _selectedActionType != 'Fuel Receipt') {

        DateTime? entryTime;
        String timeStr = _depTimeController.text.isNotEmpty ? _depTimeController.text : _checkTimeController.text;
        // Wait, let's just make a dummy LogbookEntry to get its dutyDate.
        final dummyEntry = LogbookEntry(
          id: '', vehicleId: '', date: _date, operatorName: '',
          departureTime: _depTimeController.text,
          vehicleCheckTime: _checkTimeController.text,
          pumpStartTime: '',
          previousKms: 0,
          remainingFuelInTank: 0,
          suppliedFuel: 0,
          oil: 0, grease: 0, dWater: 0, adBlue: 0,
          fromPlace: '', toPlace: '', arrivalTime: '',
          pumpEndTime: '', pumpDuration: '',
          fuelConsumedForJourney: 0,
          fuelConsumedForPump: 0,
          travelledDistance: 0,
          remarks: '',
          actionType: _selectedActionType ?? '',
        );
        final entryDutyDate = dummyEntry.dutyDate;

        final logbookProvider = context.read<LogbookProvider>();
        final hasTOC = logbookProvider.entries.any((e) {
          return e.dutyDate.year == entryDutyDate.year &&
                 e.dutyDate.month == entryDutyDate.month &&
                 e.dutyDate.day == entryDutyDate.day &&
                 e.vehicleId == widget.vehicle.id &&
                 (e.actionType == 'Taking on Charge' || e.actionType == 'Emergency Taking on Charge');
        });

        if (!hasTOC) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('Warning', style: TextStyle(color: Colors.amber)),
              content: const Text(
                'ഇന്നത്തെ Taking on Charge ലോഗ്ബുക്കിൽ ചേർത്തിട്ടില്ല. ഇത് ചേർക്കാതെ നിങ്ങൾക്ക് മുന്നോട്ട് പോകണമെന്നുണ്ടോ?',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('No', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Yes', style: TextStyle(color: Colors.amber)),
                ),
              ],
            ),
          );
          if (confirm != true) return;
        }
      }

      final assignedVehicles = AccessControl.getAssignedVehicles(context, _date);
      bool isAssignedDriver = false;
      if (assignedVehicles.isNotEmpty) {
        final cleanReg = widget.vehicle.regNumber.replaceAll('-', '').replaceAll(' ', '').toLowerCase();
        final cleanType = widget.vehicle.type.replaceAll('-', '').replaceAll(' ', '').toLowerCase();
        isAssignedDriver = assignedVehicles.any((assignedId) {
          final nameLower = assignedId.replaceAll('-', '').replaceAll(' ', '').toLowerCase();
          return (cleanReg.isNotEmpty && nameLower.contains(cleanReg)) ||
                 (cleanType.isNotEmpty && nameLower.contains(cleanType));
        });
      }
      final isSfroM = AccessControl.isSfroM(context);
      final isAdmin = AccessControl.isAdmin(context);

      if (!isAssignedDriver && !isSfroM && !isAdmin && !widget.isEmergencyOnly && widget.canEdit) {
        final emTime = _getEmergencyTakingTime();
        if (emTime != null) {
          DateTime? entryTime;
          if (_depTimeController.text.isNotEmpty) {
            final p = _depTimeController.text.split(':');
            entryTime = DateTime(_date.year, _date.month, _date.day, int.parse(p[0]), int.parse(p[1]));
          } else if (_checkTimeController.text.isNotEmpty) {
            final p = _checkTimeController.text.split(':');
            entryTime = DateTime(_date.year, _date.month, _date.day, int.parse(p[0]), int.parse(p[1]));
          }

          if (entryTime != null && entryTime.isBefore(emTime)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('നിങ്ങൾ വാഹനം എമർജൻസി ചാർജ് എടുത്ത സമയത്തിന് മുൻപുള്ള വിവരങ്ങൾ രേഖപ്പെടുത്താൻ നിങ്ങൾക്ക് അനുമതിയില്ല', textAlign: TextAlign.center),
                backgroundColor: Colors.redAccent,
                duration: Duration(seconds: 4),
              ),
            );
            return;
          }
        }
      }

      if (_selectedActionType == 'Fuel Drain/Decanting') {
        double drainedQty = double.tryParse(_drainedFuelController.text) ?? 0;
        double originalFuel = 0;
        if (widget.entryToEdit != null) {
          originalFuel = widget.entryToEdit!.remainingFuelInTank;
        } else {
          final logbookProvider = context.read<LogbookProvider>();
          if (logbookProvider.entries.isNotEmpty) {
            final last = logbookProvider.entries.last;
            originalFuel = (last.remainingFuelInTank + last.suppliedFuel - last.fuelConsumedForJourney - last.fuelConsumedForPump).clamp(0.0, 99999.0);
          } else {
            originalFuel = widget.vehicle.currentFuelInTank;
          }
        }

        if (drainedQty > originalFuel) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot drain more fuel than available in tank!', textAlign: TextAlign.center), backgroundColor: Colors.red),
          );
          return;
        }
      }

      final provider = context.read<LogbookProvider>();

      bool isTakingOnCharge = _selectedActionType == 'Taking on Charge' || _selectedActionType == 'Emergency Taking on Charge';

      if (isTakingOnCharge && widget.entryToEdit == null) {
        final entriesForDate = provider.entries.where((e) => e.date.year == _date.year && e.date.month == _date.month && e.date.day == _date.day).toList();

        // Duplicate taking on charge check
        bool alreadyTaken = entriesForDate.any((e) =>
          (e.actionType == 'Taking on Charge' || e.actionType == 'Emergency Taking on Charge') &&
          e.operatorName == _operatorController.text
        );

        if (alreadyTaken) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('താങ്കൾ ഇതിനകം വാഹനം ചാർജിൽ എടുത്തിട്ടുണ്ട്', textAlign: TextAlign.center), backgroundColor: Colors.red),
          );
          return;
        }
      }



      if (_selectedActionType == 'Fuel Drain/Decanting' && widget.entryToEdit == null) {
        double drainedQty = double.tryParse(_drainedFuelController.text) ?? 0;
        if (drainedQty > 0) {
          final fuelProvider = context.read<FuelProvider>();
          String? ledgerId;
          try {
            final txSnapshot = await FirebaseFirestore.instance
                .collection('fuel_transactions')
                .where('party', isEqualTo: '${widget.vehicle.type} (${widget.vehicle.regNumber})')
                .where('type', isEqualTo: 'ISSUE')
                .orderBy('date', descending: true)
                .limit(1)
                .get();
            if (txSnapshot.docs.isNotEmpty) {
              ledgerId = txSnapshot.docs.first.data()['ledgerId'];
            }
          } catch (e) {
            debugPrint("Error finding previous fuel transaction: $e");
          }

          if (ledgerId == null) {
            String? selectedType = await showDialog<String>(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF1E1E1E),
                title: const Text('Select Fuel Type', style: TextStyle(color: Colors.white)),
                content: const Text('Could not determine fuel type for this vehicle. What type of fuel was drained?', style: TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, 'Petrol'), child: const Text('Petrol', style: TextStyle(color: Colors.blueAccent))),
                  TextButton(onPressed: () => Navigator.pop(context, 'Diesel'), child: const Text('Diesel', style: TextStyle(color: Colors.blueAccent))),
                ],
              ),
            );
            if (selectedType != null) {
               final ledgers = fuelProvider.fuelLedgers.where((l) => l.name.toLowerCase().contains(selectedType.toLowerCase())).toList();
               if (ledgers.isNotEmpty) {
                 ledgerId = ledgers.first.id;
               } else if (fuelProvider.fuelLedgers.isNotEmpty) {
                 ledgerId = fuelProvider.fuelLedgers.first.id;
               }
            }
          }

          if (ledgerId != null) {
            String dateStr = '${_date.day.toString().padLeft(2, '0')}${_date.month.toString().padLeft(2, '0')}${_date.year}';
            String vNo = '${widget.vehicle.regNumber}/$dateStr';
            await fuelProvider.addTransaction(
              ledgerId: ledgerId,
              date: _date,
              party: '${widget.vehicle.type} (${widget.vehicle.regNumber})',
              type: 'RECEIPT',
              quantity: drainedQty,
              remarks: 'Fuel Drain / Decanting',
              customVoucherNumber: vNo,
            );

            _remarksController.text = '${drainedQty % 1 == 0 ? drainedQty.toInt() : drainedQty} ltr fuel (drained from vehicle) and deposited to store. Voucher No: $vNo';
          }
        }
      }

      final entry = LogbookEntry(
        id: widget.entryToEdit?.id ?? '',
        vehicleId: widget.vehicle.id,
        date: _date,
        previousKms: double.tryParse(_prevKmsController.text) ?? 0,
        remainingFuelInTank: double.tryParse(_remFuelController.text) ?? 0,
        suppliedFuel: (_selectedActionType == 'Fuel Drain/Decanting')
            ? -(double.tryParse(_drainedFuelController.text) ?? 0)
            : (double.tryParse(_supFuelController.text) ?? 0),
        oil: double.tryParse(_oilController.text) ?? 0,
        grease: double.tryParse(_greaseController.text) ?? 0,
        dWater: double.tryParse(_dWaterController.text) ?? 0,
        departureTime: _depTimeController.text,
        fromPlace: _fromPlaceController.text,
        toPlace: _toPlaceController.text,
        arrivalTime: _arrTimeController.text,
        travelledDistance: double.tryParse(_distController.text) ?? 0,
        pumpStartTime: _pumpStartController.text,
        pumpEndTime: _pumpEndController.text,
        pumpDuration: _pumpDurController.text,
        pumpKm: double.tryParse(_pumpKmController.text) ?? 0,
        fuelConsumedForJourney: double.tryParse(_fuelJrnController.text) ?? 0,
        fuelConsumedForPump: double.tryParse(_fuelPumpController.text) ?? 0,
        remarks: _remarksController.text,
        vehicleCheckTime: _checkTimeController.text,
        operatorName: _operatorController.text,
        actionType: _selectedActionType ?? '',
      );

      bool success;
      if (widget.entryToEdit != null) {
        success = await provider.updateEntry(entry);
      } else {
        success = await provider.addEntry(entry);
      }

      if (success && mounted) {
        await provider.cascadeUpdates(widget.vehicle.id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry saved successfully', textAlign: TextAlign.center), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${provider.errorMessage}', textAlign: TextAlign.center), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDecimal(double val, {int maxDecimals = 3}) {
    if (val % 1 == 0) return val.toInt().toString();
    return val.toStringAsFixed(maxDecimals).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  void _checkSaturdayDS() {
    if ((_selectedActionType == 'Taking on Charge' || _selectedActionType == 'Emergency Taking on Charge') &&
        _date.weekday == DateTime.saturday) {
      final double weeklyDS = widget.vehicle.fixedDSConsumption;
      if (weeklyDS > 0) {
        _fuelPumpController.text = _formatDecimal(weeklyDS);
      }
    } else if (_selectedActionType == 'Taking on Charge' || _selectedActionType == 'Emergency Taking on Charge') {
      _fuelPumpController.text = '0';
    }
  }

  void _onActionTypeChanged(String type) {
    final logbookProvider = context.read<LogbookProvider>();
    final lastEntry = logbookProvider.entries.isNotEmpty ? logbookProvider.entries.last : null;

    if (type == 'Taking on Charge' || type == 'Emergency Taking on Charge') {
      if (_checkTimeController.text.isEmpty) _checkTimeController.text = '09:00';
      if (_remarksController.text.isEmpty) {
        _remarksController.text = type == 'Emergency Taking on Charge'
            ? 'വാഹനം എമർജൻസി ചാർജിൽ എടുത്തു'
            : 'വാഹനം ചാർജിൽ എടുത്തു';
      }
      _checkSaturdayDS();
    } else if (type == 'Onward Journey') {
      if (_fromPlaceController.text.isEmpty) {
        if (lastEntry != null && lastEntry.toPlace.isNotEmpty && lastEntry.toPlace != 'Routine Check / Charge') {
          _fromPlaceController.text = lastEntry.toPlace;
        } else {
          _fromPlaceController.text = 'FRS കൊയിലാണ്ടി';
        }
      }
    } else if (type == 'Return Journey') {
      if (lastEntry != null && lastEntry.toPlace.isNotEmpty) {
        _fromPlaceController.text = lastEntry.toPlace;
      } else {
        if (_fromPlaceController.text.isEmpty) _fromPlaceController.text = 'Station / Outpost';
      }
      _toPlaceController.text = 'FRS കൊയിലാണ്ടി';
    } else if (type == 'Fuel Drain/Decanting') {
      if (_remarksController.text.isEmpty) _remarksController.text = 'Fuel Drain / Decanting';
    }
  }

  void _calculatePumpDuration() {
    if (_pumpStartController.text.isNotEmpty && _pumpEndController.text.isNotEmpty) {
      try {
        final startParts = _pumpStartController.text.split(':');
        final endParts = _pumpEndController.text.split(':');
        if (startParts.length == 2 && endParts.length == 2) {
          int startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
          int endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
          int diff = endMin - startMin;
          if (diff < 0) diff += 24 * 60;
          int hrs = diff ~/ 60;
          int mins = diff % 60;
          _pumpDurController.text = '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
        }
      } catch (_) {}
    }
  }

  void _onDistanceChanged() {
    if (_isUpdatingOdo) return;
    _isUpdatingOdo = true;

    double prevKms = double.tryParse(_prevKmsController.text) ?? 0.0;
    double dist = double.tryParse(_distController.text) ?? 0.0;
    double pumpKm = double.tryParse(_pumpKmController.text) ?? 0.0;

    if (_distController.text.isNotEmpty || pumpKm > 0) {
      double currOdo = prevKms + dist + pumpKm;
      _currOdoController.text = currOdo > 0 ? _formatDecimal(currOdo) : '';
    } else {
      _currOdoController.text = '';
    }

    _isUpdatingOdo = false;
    _autoCalculateFuelConsumption();
  }

  void _onCurrentOdoChanged() {
    if (_isUpdatingOdo) return;
    _isUpdatingOdo = true;

    double prevKms = double.tryParse(_prevKmsController.text) ?? 0.0;
    double currOdo = double.tryParse(_currOdoController.text) ?? 0.0;
    double pumpKm = double.tryParse(_pumpKmController.text) ?? 0.0;

    if (currOdo >= prevKms && currOdo > 0) {
      double dist = currOdo - prevKms - pumpKm;
      if (dist < 0) dist = 0;
      _distController.text = _formatDecimal(dist);
    } else if (_currOdoController.text.isEmpty) {
      _distController.text = '';
    }

    _isUpdatingOdo = false;
    _autoCalculateFuelConsumption();
  }

  void _autoCalculateFuelConsumption() {
    if (_isInitializing) return;

    double dist = double.tryParse(_distController.text) ?? 0.0;
    if (widget.vehicle.mileageOnRoad > 0 && dist > 0) {
      double jrnFuel = dist / widget.vehicle.mileageOnRoad;
      _fuelJrnController.text = _formatDecimal(jrnFuel);
    } else if (_distController.text.isEmpty) {
      _fuelJrnController.text = '';
    }

    double pumpKm = double.tryParse(_pumpKmController.text) ?? 0.0;
    if (widget.vehicle.hasFirePump && widget.vehicle.mileageOnPumping > 0 && pumpKm > 0) {
      double pumpFuel = pumpKm / widget.vehicle.mileageOnPumping;
      _fuelPumpController.text = _formatDecimal(pumpFuel);
    } else if (_pumpKmController.text.isEmpty) {
      _fuelPumpController.text = '';
    }

    _recalculateRemainingFuel();
  }

  void _recalculateRemainingFuel() {
    double prevFuel = 0.0;
    if (widget.entryToEdit != null) {
      prevFuel = widget.entryToEdit!.remainingFuelInTank;
    } else {
      final logbookProvider = context.read<LogbookProvider>();
      if (logbookProvider.entries.isNotEmpty) {
        final last = logbookProvider.entries.last;
        prevFuel = (last.remainingFuelInTank + last.suppliedFuel - last.fuelConsumedForJourney - last.fuelConsumedForPump).clamp(0.0, 99999.0);
      } else {
        prevFuel = widget.vehicle.currentFuelInTank;
      }
    }

    double supFuel = double.tryParse(_supFuelController.text) ?? 0.0;
    double drainedFuel = double.tryParse(_drainedFuelController.text) ?? 0.0;
    if (_selectedActionType == 'Fuel Drain/Decanting') {
      supFuel = -drainedFuel;
    }

    double totalRem = prevFuel + supFuel;
    if (totalRem < 0) totalRem = 0;

    _remFuelController.text = _formatDecimal(totalRem);
  }

  Future<void> _fetchFuelLedgerData() async {
    if (widget.entryToEdit != null && widget.entryToEdit!.suppliedFuel > 0) return;

    final startOfDay = DateTime(_date.year, _date.month, _date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final cleanReg = widget.vehicle.regNumber.replaceAll('-', '').replaceAll(' ', '').toLowerCase();
    final cleanType = widget.vehicle.type.replaceAll('-', '').replaceAll(' ', '').toLowerCase();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('fuel_transactions')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .where('type', isEqualTo: 'ISSUE')
          .get();

      double suppliedFuel = 0.0;
      double suppliedOil = 0.0;
      double suppliedGrease = 0.0;
      double suppliedDWater = 0.0;

      final fuelProvider = context.read<FuelProvider>();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final party = (data['party'] ?? '').toString().replaceAll('-', '').replaceAll(' ', '').toLowerCase();
        final qty = (data['quantity'] ?? 0).toDouble();
        final ledgerId = data['ledgerId'] ?? '';

        final isForVehicle = (cleanReg.isNotEmpty && party.contains(cleanReg)) ||
                            (cleanType.isNotEmpty && party.contains(cleanType));

        if (isForVehicle) {
          final ledger = fuelProvider.ledgers.firstWhere(
            (l) => l.id == ledgerId,
            orElse: () => FuelLedger(id: '', ledgerNumber: 0, name: '', type: 'Fuel'),
          );

          final nameLower = ledger.name.toLowerCase();
          if (ledger.type == 'Fuel' || nameLower.contains('petrol') || nameLower.contains('diesel')) {
            suppliedFuel += qty;
          } else if (nameLower.contains('oil') || nameLower.contains('engine')) {
            suppliedOil += qty;
          } else if (nameLower.contains('grease')) {
            suppliedGrease += qty;
          } else if (nameLower.contains('water')) {
            suppliedDWater += qty;
          } else {
            suppliedFuel += qty;
          }
        }
      }

      if (mounted) {
        setState(() {
          _supFuelController.text = suppliedFuel > 0 ? suppliedFuel.toString() : '0';
          _oilController.text = suppliedOil > 0 ? suppliedOil.toString() : '0';
          _greaseController.text = suppliedGrease > 0 ? suppliedGrease.toString() : '0';
          _dWaterController.text = suppliedDWater > 0 ? suppliedDWater.toString() : '0';
          _recalculateRemainingFuel();
        });
      }
    } catch (e) {
      debugPrint('Error fetching fuel transactions for logbook: $e');
    }
  }

  Future<void> _fetchAbsoluteLatestLogbookEntry() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('logbooks')
          .where('vehicleId', isEqualTo: widget.vehicle.id)
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final lastEntry = LogbookEntry.fromFirestore(snapshot.docs.first);
        double lastEndingOdo = lastEntry.previousKms + lastEntry.travelledDistance + lastEntry.pumpKm;
        double lastEndingFuel = (lastEntry.remainingFuelInTank + lastEntry.suppliedFuel - lastEntry.fuelConsumedForJourney - lastEntry.fuelConsumedForPump).clamp(0.0, 99999.0);

        if (mounted) {
          setState(() {
            if (lastEndingOdo > 0) {
              _prevKmsController.text = lastEndingOdo % 1 == 0 ? lastEndingOdo.toInt().toString() : lastEndingOdo.toString();
            }
            _remFuelController.text = _formatDecimal(lastEndingFuel);
            _recalculateRemainingFuel();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching absolute latest entry: $e');
    }
  }

  void _autoFillDriverFromDutyRegister() {
    if (widget.entryToEdit != null && widget.entryToEdit!.operatorName.isNotEmpty) {
      return;
    }

    final dutyProvider = context.read<DutyProvider>();
    final manpowerProvider = context.read<ManpowerProvider>();

    DateTime targetDate = DateTime(_date.year, _date.month, _date.day);
    if (_depTimeController.text.isNotEmpty) {
      final parts = _depTimeController.text.split(':');
      if (parts.isNotEmpty) {
        int hour = int.tryParse(parts[0]) ?? 0;
        if (hour < 9) {
          targetDate = targetDate.subtract(const Duration(days: 1));
        }
      }
    }

    final register = dutyProvider.registers.firstWhere(
      (r) {
        final d = DateTime(r.date.year, r.date.month, r.date.day);
        return d.isAtSameMomentAs(targetDate);
      },
      orElse: () => DutyRegisterModel(id: '', date: _date, rollCallTime: '', shift: '', staffSummaries: [], homeGuardSummaries: [], trainingSummaries: [], vehicleAssignments: [], phoneDutyIds: [], messengerIds: [], sentryDutyIds: []),
    );

    if (register.vehicleAssignments.isEmpty) return;

    final cleanReg = widget.vehicle.regNumber.replaceAll('-', '').replaceAll(' ', '').toLowerCase();
    final cleanType = widget.vehicle.type.replaceAll('-', '').replaceAll(' ', '').toLowerCase();

    final assignment = register.vehicleAssignments.firstWhere(
      (v) {
        final name = v.vehicleName.replaceAll('-', '').replaceAll(' ', '').toLowerCase();
        return (cleanReg.isNotEmpty && name.contains(cleanReg)) ||
               (cleanType.isNotEmpty && name.contains(cleanType));
      },
      orElse: () => DutyVehicleAssignment(vehicleName: ''),
    );

    final vehicleType = widget.vehicle.type.toLowerCase();
    final isLightVehicle = vehicleType.contains('bullet') ||
                           vehicleType.contains('frv') ||
                           vehicleType.contains('icv') ||
                           vehicleType.contains('jeep') ||
                           vehicleType.contains('amb') ||
                           vehicleType.contains('qrv') ||
                           vehicleType.contains('tc');

    final froD = assignment.froD.trim();
    final khgList = assignment.khg.split(',').map((e) => e.trim()).toList();

    final linkedPersonId = context.read<AuthProvider>().linkedPersonId;
    String idNumber = linkedPersonId ?? '';
    bool isLoggedUserKhg = false;
    Manpower? loggedInPerson;

    if (linkedPersonId != null && linkedPersonId.isNotEmpty) {
      try {
        loggedInPerson = manpowerProvider.personnelList.firstWhere((p) => p.id == linkedPersonId);
        idNumber = loggedInPerson.idNumber;
        final desig = loggedInPerson.designation.toUpperCase();
        isLoggedUserKhg = desig.contains('HG') || desig.contains('KHG');
      } catch (_) {}
    }

    final isAdminOrSfroM = AccessControl.isAdmin(context) || AccessControl.isSfroM(context);

    if (loggedInPerson != null && !isAdminOrSfroM) {
      if (isLoggedUserKhg && !isLightVehicle) {
        _operatorController.text = '';
      } else {
        _operatorController.text = '${loggedInPerson.name} (${loggedInPerson.idNumber})';
      }
      return;
    }

    if (loggedInPerson != null &&
       (froD == linkedPersonId || froD == idNumber || khgList.contains(linkedPersonId) || khgList.contains(idNumber))) {
      if (isLoggedUserKhg && !isLightVehicle) {
        // HG cannot drive heavy vehicles
      } else {
        _operatorController.text = '${loggedInPerson.name} (${loggedInPerson.idNumber})';
        return;
      }
    }

    // Fallback if Admin/SFRO(M) or not logged in
    if (froD.isNotEmpty) {
      final driver = manpowerProvider.personnelList.firstWhere(
        (m) => m.idNumber.trim() == froD || m.id.trim() == froD,
        orElse: () => Manpower(
          id: '',
          idNumber: froD,
          name: froD,
          designation: '',
          mobileNumber: '',
          isDriver: true,
        ),
      );

      if (driver.name.isNotEmpty && driver.name != froD) {
        _operatorController.text = '${driver.name} (${driver.idNumber})';
      } else {
        _operatorController.text = froD;
      }
    } else if (khgList.isNotEmpty && khgList.first.isNotEmpty) {
      final khgId = khgList.first;
      final driver = manpowerProvider.personnelList.firstWhere(
        (m) => m.idNumber.trim() == khgId || m.id.trim() == khgId,
        orElse: () => Manpower(
          id: '',
          idNumber: khgId,
          name: khgId,
          designation: '',
          mobileNumber: '',
          isDriver: true,
        ),
      );
      if (driver.name.isNotEmpty && driver.name != khgId) {
        _operatorController.text = '${driver.name} (${driver.idNumber})';
      } else {
        _operatorController.text = khgId;
      }
    }
  }

  void _showDriverPickerModal() {
    final dutyProvider = context.read<DutyProvider>();
    final manpowerProvider = context.read<ManpowerProvider>();
    final allPersonnel = manpowerProvider.personnelList;

    final targetDateToday = DateTime(_date.year, _date.month, _date.day);
    final targetDateYesterday = targetDateToday.subtract(const Duration(days: 1));

    final registerToday = dutyProvider.registers.firstWhere(
      (r) {
        final d = DateTime(r.date.year, r.date.month, r.date.day);
        return d.isAtSameMomentAs(targetDateToday);
      },
      orElse: () => DutyRegisterModel(id: '', date: _date, rollCallTime: '', shift: '', staffSummaries: [], homeGuardSummaries: [], trainingSummaries: [], vehicleAssignments: [], phoneDutyIds: [], messengerIds: [], sentryDutyIds: []),
    );

    final registerYesterday = dutyProvider.registers.firstWhere(
      (r) {
        final d = DateTime(r.date.year, r.date.month, r.date.day);
        return d.isAtSameMomentAs(targetDateYesterday);
      },
      orElse: () => DutyRegisterModel(id: '', date: targetDateYesterday, rollCallTime: '', shift: '', staffSummaries: [], homeGuardSummaries: [], trainingSummaries: [], vehicleAssignments: [], phoneDutyIds: [], messengerIds: [], sentryDutyIds: []),
    );

    final registersToProcess = [registerToday, registerYesterday];

    final Map<String, DateTime> presentIdsOnDate = {};
    for (var register in registersToProcess) {
      if (register.id.isNotEmpty || register.vehicleAssignments.isNotEmpty) {
        void addId(String id) {
          final cleanId = id.trim();
          if (cleanId.isNotEmpty && !presentIdsOnDate.containsKey(cleanId)) {
            presentIdsOnDate[cleanId] = register.date;
          }
        }
        for (var v in register.vehicleAssignments) {
          addId(v.froD);
          for (var id in v.khg.split(',')) {
            addId(id);
          }
          for (var id in v.fro.split(',')) {
            addId(id);
          }
          addId(v.sfro);
        }

        for (var id in register.specialDutyIds) {
          addId(id);
        }
        for (var id in register.phoneDutyIds) {
          addId(id);
        }
        for (var id in register.messengerIds) {
          addId(id);
        }
        for (var id in register.sentryDutyIds) {
          addId(id);
        }
        for (var id in register.controlRoomIds) {
          addId(id);
        }
        for (var id in register.stationWriterIds) {
          addId(id);
        }

        for (var s in [...register.staffSummaries, ...register.homeGuardSummaries]) {
          final cat = s.category.toLowerCase();
          if (!cat.contains('off') && !cat.contains('leave') && !cat.contains('absent')) {
            for (var id in s.personnelIds) {
              addId(id);
            }
          }
        }
      }
    }

    List<Manpower> drivers = allPersonnel.where((m) {
      final desig = m.designation.toUpperCase();
      final isFroD = desig.contains('FRO (D)') || desig.contains('FRO(D)') || desig.contains('SFRO (D)') || desig.contains('SFRO(D)');
      final isKhgDriver = (desig.contains('KHG') || desig.contains('HG')) && m.isDriver;
      final isDriverRole = isFroD || isKhgDriver || (m.isDriver && !desig.contains('(M)'));

      if (!isDriverRole) return false;

      if (presentIdsOnDate.isNotEmpty) {
        final cleanId = m.idNumber.trim();
        final cleanIdStr = m.id.trim();
        final cleanName = m.name.trim();

        return presentIdsOnDate.containsKey(cleanId) ||
               presentIdsOnDate.containsKey(cleanIdStr) ||
               presentIdsOnDate.keys.any((p) => p == cleanId || p == cleanIdStr || cleanName.contains(p));
      }

      return true;
    }).toList();

    if (drivers.isEmpty) {
      drivers = allPersonnel.where((m) {
        final desig = m.designation.toUpperCase();
        final isFroD = desig.contains('FRO (D)') || desig.contains('FRO(D)') || desig.contains('SFRO (D)') || desig.contains('SFRO(D)');
        final isKhgDriver = (desig.contains('KHG') || desig.contains('HG')) && m.isDriver;
        return isFroD || isKhgDriver || (m.isDriver && !desig.contains('(M)'));
      }).toList();
    }

    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = drivers.where((d) {
              final query = searchQuery.toLowerCase();
              return d.name.toLowerCase().contains(query) ||
                     d.idNumber.toLowerCase().contains(query) ||
                     d.designation.toLowerCase().contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Select Operator / Driver', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search Driver / PEN / Number...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.search, color: Colors.amber),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No drivers found.', style: TextStyle(color: Colors.white54)))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const Divider(color: Colors.white10),
                            itemBuilder: (context, index) {
                              final driver = filtered[index];
                              final isSelected = _operatorController.text.contains(driver.idNumber) || _operatorController.text.contains(driver.name);
                              
                              DateTime? driverDate;
                              final cleanId = driver.idNumber.trim();
                              final cleanIdStr = driver.id.trim();
                              if (presentIdsOnDate.containsKey(cleanId)) {
                                driverDate = presentIdsOnDate[cleanId];
                              } else if (presentIdsOnDate.containsKey(cleanIdStr)) {
                                driverDate = presentIdsOnDate[cleanIdStr];
                              } else {
                                for (var entry in presentIdsOnDate.entries) {
                                  if (entry.key == cleanId || entry.key == cleanIdStr || driver.name.trim().contains(entry.key)) {
                                    driverDate = entry.value;
                                    break;
                                  }
                                }
                              }

                              Widget? trailingWidget;
                              if (driverDate != null || isSelected) {
                                trailingWidget = Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (driverDate != null)
                                      Container(
                                        margin: EdgeInsets.only(right: isSelected ? 8 : 0),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.amber.withOpacity(0.5)),
                                        ),
                                        child: Text(
                                          DateFormat('dd/MM/yyyy').format(driverDate),
                                          style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle, color: Colors.amber),
                                  ],
                                );
                              }

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: driver.isDriver ? Colors.amber.withOpacity(0.2) : Colors.white10,
                                  child: Icon(Icons.person, color: driver.isDriver ? Colors.amber : Colors.white70),
                                ),
                                title: Text(driver.name, style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                subtitle: Text('${driver.designation} | PEN/No: ${driver.idNumber}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                trailing: trailingWidget,
                                onTap: () {
                                  setState(() {
                                    _operatorController.text = '${driver.name} (${driver.idNumber})';
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    bool isTime = false,
    bool readOnly = false,
    int maxLines = 1,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    bool effectiveReadOnly = readOnly || !widget.canEdit;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        maxLines: maxLines,
        readOnly: isTime || onTap != null || effectiveReadOnly,
        onTap: (isTime && widget.canEdit) ? () => _selectTime(controller) : (widget.canEdit ? onTap : null),
        style: TextStyle(color: effectiveReadOnly ? Colors.amberAccent : Colors.white, fontWeight: effectiveReadOnly ? FontWeight.bold : FontWeight.normal),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE53935)),
          ),
          filled: true,
          fillColor: effectiveReadOnly ? Colors.amber.withOpacity(0.08) : Colors.white.withOpacity(0.05),
          suffixIcon: suffixIcon ?? (isTime ? const Icon(Icons.access_time, color: Colors.white70) : (effectiveReadOnly ? const Icon(Icons.lock_outline, color: Colors.amber, size: 18) : null)),
        ),
        validator: (value) {
          if (!isTime && !isNumber && value != null && value.isEmpty && label.contains('Operator')) {
             return 'Required';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.entryToEdit != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.vehicle.type.isNotEmpty ? widget.vehicle.type : widget.vehicle.regNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isEdit && widget.canEdit)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                if (widget.entryToEdit!.actionType == 'Fuel Receipt') {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ഈ എൻട്രി ഫ്യുവൽ ലെഡ്ജറിൽ നിന്നും സ്വയമേവ വന്നതാണ്. ഇത് ലോഗ്ബുക്കിൽ നിന്നും തിരുത്താനോ ഡിലീറ്റ് ചെയ്യാനോ സാധിക്കില്ല, അതിനായി ഫ്യുവൽ ലെഡ്ജറിൽ പോകുക.', textAlign: TextAlign.center), backgroundColor: Colors.red));
                  return;
                }
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1E1E),
                    title: const Text('Delete Entry?', style: TextStyle(color: Colors.white)),
                    content: const Text('Are you sure you want to delete this logbook entry?', style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  final provider = context.read<LogbookProvider>();
                  final entryToDelete = widget.entryToEdit!;
                  final allEntries = provider.entries;
                  final success = await provider.deleteEntry(entryToDelete.id, widget.vehicle.id);
                  if (success && mounted) {
                    Navigator.pop(context);
                  }
                }
              },
            ),
        ],
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
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!widget.canEdit) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.visibility, color: Colors.redAccent),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'View-Only Mode: You do not have permission to edit this entry.',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Type of Action Selection
                DropdownButtonFormField<String>(
                  initialValue: _selectedActionType,
                  hint: const Text('Select Type of Action', style: TextStyle(color: Colors.white60)),
                  dropdownColor: const Color(0xFF1E1E1E),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Type of Action *',
                    labelStyle: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
                    prefixIcon: const Icon(Icons.alt_route, color: Colors.amber),
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
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE53935)),
                    ),
                  ),
                  items: _currentAvailableActions.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type, style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: widget.canEdit ? (val) {
                    if (val != null) {
                      setState(() {
                        _selectedActionType = val;
                        _onActionTypeChanged(val);
                      });
                    }
                  } : null,
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please select Type of Action';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Date Selection
                ListTile(
                  tileColor: Colors.white.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white.withOpacity(0.1))),
                  leading: const Icon(Icons.calendar_today, color: Colors.amber),
                  title: const Text('Date', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  subtitle: Text(_isDateSelected ? DateFormat('dd/MM/yyyy').format(_date) : 'Select Date', style: TextStyle(color: _isDateSelected ? Colors.white : Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                  onTap: widget.canEdit ? _selectDate : null,
                ),
                const SizedBox(height: 24),

                const Text('Basic Info', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Previous Kms', _prevKmsController, isNumber: true, readOnly: true)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField('Current Fuel in Tank (L)', _remFuelController, isNumber: true, readOnly: true)),
                  ],
                ),
                Builder(
                  builder: (context) {
                    final canChangeOperator = AccessControl.isSfroM(context) || AccessControl.isAdmin(context);
                    return _buildTextField(
                      'Operator / Driver Name',
                      _operatorController,
                      readOnly: !canChangeOperator,
                      onTap: canChangeOperator ? _showDriverPickerModal : null,
                      suffixIcon: canChangeOperator
                          ? const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.amber)
                          : null,
                    );
                  }
                ),

                if (_selectedActionType == 'Fuel Drain/Decanting') ...[
                  const SizedBox(height: 24),
                  const Text('Draining Details', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  _buildTextField('Drained Fuel (Liters)', _drainedFuelController, isNumber: true),
                ],

                if (_selectedActionType == 'Onward Journey' || _selectedActionType == 'Return Journey') ...[
                  const SizedBox(height: 24),
                  const Text('Journey Details', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('From Place', _fromPlaceController)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('To Place', _toPlaceController)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Departure Time', _depTimeController, isTime: true)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Arrival Time', _arrTimeController, isTime: true)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Travelled Dist. (Km)', _distController, isNumber: true)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Current Odometer (Km)', _currOdoController, isNumber: true)),
                    ],
                  ),
                ],

                if (_selectedActionType == 'Onward Journey' && widget.vehicle.hasFirePump) ...[
                  const SizedBox(height: 24),
                  const Text('Pump Operation', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Start Time', _pumpStartController, isTime: true)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('End Time', _pumpEndController, isTime: true)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Duration (HH:mm)', _pumpDurController, readOnly: true)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Pump KM', _pumpKmController, isNumber: true)),
                    ],
                  ),
                ],

                if (_selectedActionType == 'Onward Journey' || _selectedActionType == 'Return Journey') ...[
                  const SizedBox(height: 24),
                  const Text('Fuel Consumption', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('For Journey (Ltr)', _fuelJrnController, isNumber: true, readOnly: true)),
                      if (_selectedActionType == 'Onward Journey' && widget.vehicle.hasFirePump) ...[
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField('For Pump (Ltr)', _fuelPumpController, isNumber: true, readOnly: true)),
                      ],
                    ],
                  ),
                ],

                const SizedBox(height: 24),
                const Text('Additional Details', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                if (_selectedActionType == 'Taking on Charge' || _selectedActionType == 'Emergency Taking on Charge') ...[
                  if (_date.weekday == DateTime.saturday) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.amber),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Saturday DS (Daily Start): Fixed DS Consumption (${_formatDecimal(widget.vehicle.fixedDSConsumption)} L) applied & deducted from fuel tank.',
                              style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  _buildTextField('Vehicle Check Time', _checkTimeController, isTime: true),
                ],
                _buildTextField('Remarks (Special Usage/Reasons)', _remarksController, maxLines: 3),

                if (widget.canEdit) ...[
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _saveEntry,
                    child: const Text('SAVE ENTRY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
