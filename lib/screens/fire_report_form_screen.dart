import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/fire_report_model.dart';
import '../models/vehicle_model.dart';
import '../providers/fire_report_provider.dart';
import '../providers/manpower_provider.dart';
import '../providers/vehicle_provider.dart';
import '../providers/duty_provider.dart';
import '../models/manpower_model.dart';
import '../providers/equipment_provider.dart';
import '../config/app_config.dart';

class FireReportFormScreen extends StatefulWidget {
  final FireReportModel? existingReport;
  const FireReportFormScreen({super.key, this.existingReport});

  @override
  State<FireReportFormScreen> createState() => _FireReportFormScreenState();
}

class _FireReportFormScreenState extends State<FireReportFormScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // General Info
  final _stationCtrl = TextEditingController(text: 'കൊയിലാണ്ടി');
  final _locationCtrl = TextEditingController();
  String? _selectedOfficerInChargeId;
  final _reportNumberCtrl = TextEditingController();
  DateTime _date = DateTime.now();

  // Call Details
  final _callerNameCtrl = TextEditingController();
  final _callerPhoneCtrl = TextEditingController();
  final _buildingsInvolvedCtrl = TextEditingController();
  final _occupantNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();

  TimeOfDay? _firstTurnoutTime;
  TimeOfDay? _callTime;
  TimeOfDay? _reachedTime;
  final _distanceCtrl = TextEditingController();
  TimeOfDay? _actualFireTime;

  // Fire Details
  final _propertiesInvolvedCtrl = TextEditingController();
  String _typeOfFire = 'ചെറുത്'; // Small by default
  final _extentOfFireCtrl = TextEditingController();
  final _confirmedCauseCtrl = TextEditingController();
  final _damageDescriptionCtrl = TextEditingController();

  // Estimates
  final _estPropCtrl = TextEditingController(text: '0');
  final _estCouldHaveCtrl = TextEditingController(text: '0');
  final _estBldgCtrl = TextEditingController(text: '0');
  final _estContentsCtrl = TextEditingController(text: '0');

  // Assessment
  String? _selectedAssessingOfficerId;
  DateTime? _assessmentDate;
  TimeOfDay? _assessmentTime;

  String _to24HourString(String timeStr) {
    if (timeStr.isEmpty) return timeStr;
    try {
      if (timeStr.toLowerCase().contains('am') || timeStr.toLowerCase().contains('pm')) {
        final dt = DateFormat('h:mm a').parse(timeStr.toUpperCase());
        return DateFormat('HH:mm').format(dt);
      }
      return timeStr;
    } catch (e) {
      return timeStr;
    }
  }

  String _formatTime24(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
  final _workingHoursCtrl = TextEditingController(text: '0');
  final _workingMinsCtrl = TextEditingController(text: '0');

  // Rescues
  final _rescNoFfMaleCtrl = TextEditingController(text: '0');
  final _rescNoFfFemaleCtrl = TextEditingController(text: '0');
  final _rescFfNoEqMaleCtrl = TextEditingController(text: '0');
  final _rescFfNoEqFemaleCtrl = TextEditingController(text: '0');
  final _rescFfEqMaleCtrl = TextEditingController(text: '0');
  final _rescFfEqFemaleCtrl = TextEditingController(text: '0');

  // Casualties
  final _casFfMaleCtrl = TextEditingController(text: '0');
  final _casFfFemaleCtrl = TextEditingController(text: '0');
  final _casFfNamesCtrl = TextEditingController();
  final _casFfAddressCtrl = TextEditingController();

  final _casOthMaleCtrl = TextEditingController(text: '0');
  final _casOthFemaleCtrl = TextEditingController(text: '0');
  final _casOthNamesCtrl = TextEditingController();
  final _casOthAddressCtrl = TextEditingController();
  final _natureOfDeathCtrl = TextEditingController();

  // Vehicles
  List<FireReportVehicleDetail> _vehicleDetails = [];

  // Personnel
  List<String> _attendingOfficersIds = [];
  List<String> _attendingPersonnelIds = [];

  // Remarks
  final _hoseNoCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<DutyProvider>(context, listen: false).fetchDutyRegisters();
    });
    if (widget.existingReport != null) {
      _loadExistingData(widget.existingReport!);
    }
  }

  void _loadExistingData(FireReportModel report) {
    _stationCtrl.text = report.station;
    _locationCtrl.text = report.location;
    _selectedOfficerInChargeId = report.officerInChargeId;
    _reportNumberCtrl.text = report.reportNumber;
    _date = report.date;

    _callerNameCtrl.text = report.callerName;
    _callerPhoneCtrl.text = report.callerPhone;
    _buildingsInvolvedCtrl.text = report.buildingsInvolved;
    _occupantNameCtrl.text = report.occupantName;
    _ownerNameCtrl.text = report.ownerNameAndAddress;
    _occupationCtrl.text = report.occupation;

    _firstTurnoutTime = report.firstTurnoutTime != null ? TimeOfDay.fromDateTime(report.firstTurnoutTime!) : null;
    _callTime = report.callTime != null ? TimeOfDay.fromDateTime(report.callTime!) : null;
    _reachedTime = report.reachedTime != null ? TimeOfDay.fromDateTime(report.reachedTime!) : null;
    _distanceCtrl.text = report.distanceFromStationKm;
    _actualFireTime = report.actualFireTime != null ? TimeOfDay.fromDateTime(report.actualFireTime!) : null;

    _propertiesInvolvedCtrl.text = report.propertiesInvolved;
    _typeOfFire = report.typeOfFire.isNotEmpty ? report.typeOfFire : 'ചെറുത്';
    _extentOfFireCtrl.text = report.extentOfFire;
    _confirmedCauseCtrl.text = report.confirmedCause;
    _damageDescriptionCtrl.text = report.damageDescription;

    _estPropCtrl.text = report.estValuePropertiesInvolved.toInt().toString();
    _estCouldHaveCtrl.text = report.estValueCouldHaveCaught.toInt().toString();
    _estBldgCtrl.text = report.estValueBuildingDamage.toInt().toString();
    _estContentsCtrl.text = report.estValueContentsDamage.toInt().toString();

    _selectedAssessingOfficerId = report.assessingOfficerId;
    _assessmentDate = report.assessmentDate;
    _assessmentTime = report.assessmentDate != null ? TimeOfDay.fromDateTime(report.assessmentDate!) : null;
    _workingHoursCtrl.text = report.totalWorkingHours.toString();
    _workingMinsCtrl.text = report.totalWorkingMinutes.toString();

    _rescNoFfMaleCtrl.text = report.rescuedWithoutFireForceMale.toString();
    _rescNoFfFemaleCtrl.text = report.rescuedWithoutFireForceFemale.toString();
    _rescFfNoEqMaleCtrl.text = report.rescuedWithFireForceNoEqMale.toString();
    _rescFfNoEqFemaleCtrl.text = report.rescuedWithFireForceNoEqFemale.toString();
    _rescFfEqMaleCtrl.text = report.rescuedWithFireForceEqMale.toString();
    _rescFfEqFemaleCtrl.text = report.rescuedWithFireForceEqFemale.toString();

    _casFfMaleCtrl.text = report.casualtiesFireForceMale.toString();
    _casFfFemaleCtrl.text = report.casualtiesFireForceFemale.toString();
    _casFfNamesCtrl.text = report.casualtiesFireForceNames;
    _casFfAddressCtrl.text = report.casualtiesFireForceAddress;

    _casOthMaleCtrl.text = report.casualtiesOthersMale.toString();
    _casOthFemaleCtrl.text = report.casualtiesOthersFemale.toString();
    _casOthNamesCtrl.text = report.casualtiesOthersNames;
    _casOthAddressCtrl.text = report.casualtiesOthersAddress;
    _natureOfDeathCtrl.text = report.natureOfDeath;

    _vehicleDetails = List.from(report.vehicleDetails);
    _attendingOfficersIds = List.from(report.attendingOfficersIds);
    _attendingPersonnelIds = List.from(report.attendingPersonnelIds);

    _hoseNoCtrl.text = report.hoseNo;
    _remarksCtrl.text = report.remarks;
  }

  DateTime? _combineDateTime(DateTime baseDate, TimeOfDay? time) {
    if (time == null) return null;
    return DateTime(baseDate.year, baseDate.month, baseDate.day, time.hour, time.minute);
  }

  void _saveReport() async {
    if (!_formKey.currentState!.validate()) return;

    final report = FireReportModel(
      id: widget.existingReport?.id ?? '',
      station: _stationCtrl.text,
      location: _locationCtrl.text,
      officerInChargeId: _selectedOfficerInChargeId ?? '',
      reportNumber: _reportNumberCtrl.text,
      date: _date,
      callerName: _callerNameCtrl.text,
      callerPhone: _callerPhoneCtrl.text,
      buildingsInvolved: _buildingsInvolvedCtrl.text,
      occupantName: _occupantNameCtrl.text,
      ownerNameAndAddress: _ownerNameCtrl.text,
      occupation: _occupationCtrl.text,
      firstTurnoutTime: _combineDateTime(_date, _firstTurnoutTime),
      callTime: _combineDateTime(_date, _callTime),
      reachedTime: _combineDateTime(_date, _reachedTime),
      distanceFromStationKm: _distanceCtrl.text,
      actualFireTime: _combineDateTime(_date, _actualFireTime),
      propertiesInvolved: _propertiesInvolvedCtrl.text,
      typeOfFire: _typeOfFire,
      extentOfFire: _extentOfFireCtrl.text,
      confirmedCause: _confirmedCauseCtrl.text,
      damageDescription: _damageDescriptionCtrl.text,
      estValuePropertiesInvolved: double.tryParse(_estPropCtrl.text) ?? 0.0,
      estValueCouldHaveCaught: double.tryParse(_estCouldHaveCtrl.text) ?? 0.0,
      estValueBuildingDamage: double.tryParse(_estBldgCtrl.text) ?? 0.0,
      estValueContentsDamage: double.tryParse(_estContentsCtrl.text) ?? 0.0,
      assessingOfficerId: _selectedAssessingOfficerId ?? '',
      assessmentDate: _assessmentDate != null ? _combineDateTime(_assessmentDate!, _assessmentTime ?? TimeOfDay.now()) : null,
      totalWorkingHours: int.tryParse(_workingHoursCtrl.text) ?? 0,
      totalWorkingMinutes: int.tryParse(_workingMinsCtrl.text) ?? 0,
      rescuedWithoutFireForceMale: int.tryParse(_rescNoFfMaleCtrl.text) ?? 0,
      rescuedWithoutFireForceFemale: int.tryParse(_rescNoFfFemaleCtrl.text) ?? 0,
      rescuedWithFireForceNoEqMale: int.tryParse(_rescFfNoEqMaleCtrl.text) ?? 0,
      rescuedWithFireForceNoEqFemale: int.tryParse(_rescFfNoEqFemaleCtrl.text) ?? 0,
      rescuedWithFireForceEqMale: int.tryParse(_rescFfEqMaleCtrl.text) ?? 0,
      rescuedWithFireForceEqFemale: int.tryParse(_rescFfEqFemaleCtrl.text) ?? 0,
      casualtiesFireForceMale: int.tryParse(_casFfMaleCtrl.text) ?? 0,
      casualtiesFireForceFemale: int.tryParse(_casFfFemaleCtrl.text) ?? 0,
      casualtiesFireForceNames: _casFfNamesCtrl.text,
      casualtiesFireForceAddress: _casFfAddressCtrl.text,
      casualtiesOthersMale: int.tryParse(_casOthMaleCtrl.text) ?? 0,
      casualtiesOthersFemale: int.tryParse(_casOthFemaleCtrl.text) ?? 0,
      casualtiesOthersNames: _casOthNamesCtrl.text,
      casualtiesOthersAddress: _casOthAddressCtrl.text,
      natureOfDeath: _natureOfDeathCtrl.text,
      vehicleDetails: _vehicleDetails,
      attendingOfficersIds: _attendingOfficersIds,
      attendingPersonnelIds: _attendingPersonnelIds,
      hoseNo: _hoseNoCtrl.text,
      remarks: _remarksCtrl.text,
    );

    try {
      if (widget.existingReport == null) {
        await context.read<FireReportProvider>().addReport(report);
      } else {
        await context.read<FireReportProvider>().updateReport(report);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving report: $e')));
      }
    }
  }

  // A helper method for building standard text fields
  Widget _buildTextField(String label, TextEditingController controller, {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.redAccent), borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: const Color(0xFF2C2C2C),
        ),
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, TimeOfDay? initialTime, Function(TimeOfDay) onSelected) async {
    final TimeOfDay? picked = await _showRollingTimePicker(
      context,
      initialTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  Widget _buildTimeSelector(String label, TimeOfDay? time, Function(TimeOfDay) onSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.white24),
        ),
        tileColor: const Color(0xFF2C2C2C),
        title: Text(label, style: const TextStyle(color: Colors.white70)),
        trailing: Text(
          time != null ? _formatTime24(time) : 'Select Time',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onTap: () => _selectTime(context, time, (picked) => setState(() => onSelected(picked))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manpowerList = context.watch<ManpowerProvider>().getActivePersonnelForDate(_date);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.existingReport == null ? 'New Fire Report' : 'Edit Fire Report'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveReport),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Theme(
          data: Theme.of(context).copyWith(
            canvasColor: const Color(0xFF1A1A1A),
            colorScheme: const ColorScheme.dark(primary: Colors.redAccent),
          ),
          child: Stepper(
            currentStep: _currentStep,
            onStepContinue: () {
              if (_currentStep < 5) {
                setState(() => _currentStep += 1);
              } else {
                _saveReport();
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() => _currentStep -= 1);
              }
            },
            onStepTapped: (step) => setState(() => _currentStep = step),
            physics: const ClampingScrollPhysics(),
            steps: [
              Step(
                title: const Text('പൊതുവിവരങ്ങൾ', style: TextStyle(color: Colors.white)),
                content: Column(
                  children: [
                    _buildTextField('റിപ്പോർട്ട് നമ്പർ', _reportNumberCtrl),
                    _buildTextField('സ്ഥലം', _locationCtrl),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedOfficerInChargeId,
                      dropdownColor: const Color(0xFF2C2C2C),
                      decoration: InputDecoration(
                        labelText: 'ചുമതല വഹിച്ച ഉദ്യോഗസ്ഥൻ',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: const Color(0xFF2C2C2C),
                      ),
                      items: manpowerList.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (${p.designation})', style: const TextStyle(color: Colors.white)))).toList(),
                      onChanged: (v) => setState(() => _selectedOfficerInChargeId = v),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.white24)),
                      tileColor: const Color(0xFF2C2C2C),
                      title: const Text('തീയതി', style: TextStyle(color: Colors.white70)),
                      trailing: Text(DateFormat('dd/MM/yyyy').format(_date), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (picked != null) setState(() => _date = picked);
                      },
                    ),
                  ],
                ),
                isActive: _currentStep >= 0,
              ),
              Step(
                title: const Text('വിളിയുടെ വിവരങ്ങൾ', style: TextStyle(color: Colors.white)),
                content: Column(
                  children: [
                    _buildTextField('വിളിച്ച ആൾ', _callerNameCtrl),
                    _buildTextField('ടെലിഫോൺ/തീപിടുത്ത അറിയിപ്പ് നമ്പർ', _callerPhoneCtrl, type: TextInputType.phone),
                    _buildTextField('ഉൾപ്പെട്ട കെട്ടിടങ്ങളുടെ വിവരങ്ങൾ', _buildingsInvolvedCtrl, maxLines: 2),
                    _buildTextField('പാർപ്പുകാരൻ്റെ പേര്', _occupantNameCtrl),
                    _buildTextField('ഉടമസ്ഥൻ്റെ പേരും വിലാസവും', _ownerNameCtrl, maxLines: 2),
                    _buildTextField('ജോലി', _occupationCtrl),
                    _buildTimeSelector('വിളിച്ച സമയം', _callTime, (t) {
                      _callTime = t;
                      _firstTurnoutTime ??= t;
                      _reachedTime ??= t;
                    }),
                    _buildTimeSelector('ആദ്യം പുറപ്പെട്ട സമയം', _firstTurnoutTime, (t) => _firstTurnoutTime = t),
                    _buildTimeSelector('എത്തിയ സമയം', _reachedTime, (t) => _reachedTime = t),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: DropdownButtonFormField<String>(
                        initialValue: _actualFireTime == null ? 'വ്യക്തമല്ല' : 'Enter time',
                        dropdownColor: const Color(0xFF2C2C2C),
                        decoration: InputDecoration(
                          labelText: 'യാഥാർത്ഥത്തിൽ തീപിടിച്ച സമയം',
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: const Color(0xFF2C2C2C),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'വ്യക്തമല്ല', child: Text('വ്യക്തമല്ല', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 'Enter time', child: Text('സമയം നൽകുക', style: TextStyle(color: Colors.white))),
                        ],
                        onChanged: (val) async {
                          if (val == 'വ്യക്തമല്ല') {
                            setState(() => _actualFireTime = null);
                          } else {
                            if (_actualFireTime == null) {
                              final picked = await _showRollingTimePicker(
                                context,
                                TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setState(() => _actualFireTime = picked);
                              }
                            }
                          }
                        },
                      ),
                    ),
                    if (_actualFireTime != null)
                      _buildTimeSelector('തിരഞ്ഞെടുത്ത സമയം', _actualFireTime, (t) => _actualFireTime = t),
                    _buildTextField('സ്റ്റേഷനിൽ നിന്ന് സംഭവസ്ഥലത്തേക്കുള്ള ദൂരം (കി. മീ)', _distanceCtrl, type: TextInputType.number),
                  ],
                ),
                isActive: _currentStep >= 1,
              ),
              Step(
                title: const Text('തീപിടുത്ത വിവരങ്ങൾ', style: TextStyle(color: Colors.white)),
                content: Column(
                  children: [
                    _buildTextField('ഉൾപ്പെട്ട വസ്തുക്കൾ', _propertiesInvolvedCtrl, maxLines: 3),
                    DropdownButtonFormField<String>(
                      initialValue: _typeOfFire,
                      dropdownColor: const Color(0xFF2C2C2C),
                      decoration: InputDecoration(
                        labelText: 'തീപിടുത്തത്തിന്റെ തരം',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: const Color(0xFF2C2C2C),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ഗുരുതരം', child: Text('ഗുരുതരം', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'മാധ്യമം', child: Text('മാധ്യമം', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'ചെറുത്', child: Text('ചെറുത്', style: TextStyle(color: Colors.white))),
                      ],
                      onChanged: (v) => setState(() => _typeOfFire = v!),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField('തീയുടെ വ്യാപ്തി', _extentOfFireCtrl),
                    _buildTextField('ഉറപ്പിക്കപ്പെടുന്ന കാരണം', _confirmedCauseCtrl),
                    _buildTextField('നാശനഷ്ടങ്ങളുടെ വിവരണം', _damageDescriptionCtrl, maxLines: 2),
                    const Divider(color: Colors.white24, height: 30),
                    const Text('അടങ്കൽ വിലകൾ (₹)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildTextField('ഉൾപ്പെട്ട വസ്തുക്കൾ', _estPropCtrl, type: TextInputType.number),
                    _buildTextField('അതുവഴി തീപിടിക്കുമായിരുന്നവ', _estCouldHaveCtrl, type: TextInputType.number),
                    _buildTextField('കെട്ടിടങ്ങളുടെ നാശനഷ്ടം', _estBldgCtrl, type: TextInputType.number),
                    _buildTextField('അകത്തെ സാധനങ്ങളുടെ നാശനഷ്ടങ്ങൾ', _estContentsCtrl, type: TextInputType.number),
                  ],
                ),
                isActive: _currentStep >= 2,
              ),
              Step(
                title: const Text('രക്ഷപ്പെടുവരും രക്ഷിക്കപ്പെട്ടവരും', style: TextStyle(color: Colors.white)),
                content: Column(
                  children: [
                    const Text('അഗ്നിശമന സേനയുടെ സഹായമില്ലാതെ രക്ഷപ്പെട്ടവർ', style: TextStyle(color: Colors.white70)),
                    Row(children: [
                      Expanded(child: _buildTextField('പുരുഷൻ', _rescNoFfMaleCtrl, type: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField('സ്ത്രീ', _rescNoFfFemaleCtrl, type: TextInputType.number)),
                    ]),
                    const Text('ഉപകരണങ്ങൾ കൂടാതെ അഗ്നിശമനസേന രക്ഷിച്ചവർ', style: TextStyle(color: Colors.white70)),
                    Row(children: [
                      Expanded(child: _buildTextField('പുരുഷൻ', _rescFfNoEqMaleCtrl, type: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField('സ്ത്രീ', _rescFfNoEqFemaleCtrl, type: TextInputType.number)),
                    ]),
                    const Text('ഉപകരണങ്ങളുപയോഗിച്ച് അഗ്നിശമനസേന രക്ഷിച്ചവർ', style: TextStyle(color: Colors.white70)),
                    Row(children: [
                      Expanded(child: _buildTextField('പുരുഷൻ', _rescFfEqMaleCtrl, type: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField('സ്ത്രീ', _rescFfEqFemaleCtrl, type: TextInputType.number)),
                    ]),
                    const Divider(color: Colors.white24, height: 30),
                    const Text('ആളപായങ്ങൾ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    const Text('അഗ്നിശമനസേന', style: TextStyle(color: Colors.white70)),
                    Row(children: [
                      Expanded(child: _buildTextField('പുരുഷൻ', _casFfMaleCtrl, type: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField('സ്ത്രീ', _casFfFemaleCtrl, type: TextInputType.number)),
                    ]),
                    _buildTextField('പേരും നമ്പറും', _casFfNamesCtrl),
                    _buildTextField('വിലാസം', _casFfAddressCtrl, maxLines: 2),
                    const Text('മറ്റുള്ളവർ', style: TextStyle(color: Colors.white70)),
                    Row(children: [
                      Expanded(child: _buildTextField('പുരുഷൻ', _casOthMaleCtrl, type: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField('സ്ത്രീ', _casOthFemaleCtrl, type: TextInputType.number)),
                    ]),
                    _buildTextField('പേര്', _casOthNamesCtrl),
                    _buildTextField('വിലാസം', _casOthAddressCtrl, maxLines: 2),
                    _buildTextField('ക്ഷതത്തിന്റെ സ്വഭാവം', _natureOfDeathCtrl),
                  ],
                ),
                isActive: _currentStep >= 3,
              ),
              Step(
                title: const Text('വാഹനങ്ങളും വിലയിരുത്തലും', style: TextStyle(color: Colors.white)),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('അവസാന സംഭവസ്ഥല വിലയിരുത്തൽ ആഫീസർ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedAssessingOfficerId,
                      dropdownColor: const Color(0xFF2C2C2C),
                      decoration: InputDecoration(
                        labelText: 'വിലയിരുത്തൽ ആഫീസർ',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: const Color(0xFF2C2C2C),
                      ),
                      items: manpowerList.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (${p.designation})', style: const TextStyle(color: Colors.white)))).toList(),
                      onChanged: (v) => setState(() => _selectedAssessingOfficerId = v),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.white24)),
                      tileColor: const Color(0xFF2C2C2C),
                      title: const Text('സംഭവസ്ഥല വിലയിരുത്തൽ തീയതി', style: TextStyle(color: Colors.white70)),
                      trailing: Text(_assessmentDate != null ? DateFormat('dd/MM/yyyy').format(_assessmentDate!) : 'Select', style: const TextStyle(color: Colors.white)),
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (picked != null) setState(() => _assessmentDate = picked);
                      },
                    ),
                    _buildTimeSelector('സംഭവസ്ഥല വിലയിരുത്തൽ സമയം', _assessmentTime, (t) => _assessmentTime = t),
                    const Text('ആകെ പണിയെടുത്ത സമയം', style: TextStyle(color: Colors.white70)),
                    Row(children: [
                      Expanded(child: _buildTextField('മണിക്കൂർ', _workingHoursCtrl, type: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField('മിനിറ്റ്', _workingMinsCtrl, type: TextInputType.number)),
                    ]),
                    const Divider(color: Colors.white24, height: 30),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: TextFormField(
                        controller: _hoseNoCtrl,
                        readOnly: true,
                        onTap: () => _showHoseSelectionDialog(context),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'ഹോസ് ഉപയോഗ വിവരണം',
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.redAccent), borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: const Color(0xFF2C2C2C),
                          suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                        ),
                      ),
                    ),
                    _buildTextField('വേറെ എന്തെങ്കിലും വിവരം', _remarksCtrl, maxLines: 4),
                  ],
                ),
                isActive: _currentStep >= 4,
              ),
              Step(
                title: const Text('വാഹനങ്ങളുടെയും സേനാംഗങ്ങളുടെയും പട്ടിക', style: TextStyle(color: Colors.white)),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(child: Text('വാഹനങ്ങൾ (Vehicles)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                        TextButton.icon(
                          onPressed: _showAddVehicleDialog,
                          icon: const Icon(Icons.add, color: Colors.redAccent),
                          label: const Text('Add', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                    if (_vehicleDetails.isEmpty)
                      const Text('വാഹനങ്ങളൊന്നും ചേർത്തിട്ടില്ല.', style: TextStyle(color: Colors.white54))
                    else
                      ..._vehicleDetails.map((v) => Card(
                        color: const Color(0xFF2C2C2C),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text('${v.vehicleType} - ${v.regNo}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('Out: ${_to24HourString(v.timeOut)} | Reached: ${_to24HourString(v.timeReached)}\nLeft: ${_to24HourString(v.timeLeft)} | In: ${_to24HourString(v.timeIn)}', style: const TextStyle(color: Colors.white70)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () {
                              setState(() {
                                _vehicleDetails.remove(v);
                              });
                            },
                          ),
                        ),
                      )),
                    const Divider(color: Colors.white24, height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(child: Text('സേനാംഗങ്ങൾ (Personnel)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                        TextButton.icon(
                          onPressed: _showAddPersonnelDialog,
                          icon: const Icon(Icons.person_add, color: Colors.redAccent),
                          label: const Text('Add', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [..._attendingOfficersIds, ..._attendingPersonnelIds].map((id) {
                        final manpowerList = Provider.of<ManpowerProvider>(context, listen: false).getActivePersonnelForDate(_date);
                        final person = manpowerList.firstWhere((p) => p.id == id, orElse: () => Manpower(id: id, idNumber: '', name: 'Unknown', designation: '', mobileNumber: '', isDriver: false));
                        return Chip(
                          backgroundColor: const Color(0xFF2C2C2C),
                          label: Text('${person.name} - ${person.idNumber} (${person.designation})', style: const TextStyle(color: Colors.white)),
                          deleteIcon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                          onDeleted: () {
                            setState(() {
                              _attendingOfficersIds.remove(id);
                              _attendingPersonnelIds.remove(id);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
                isActive: _currentStep >= 5,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHoseSelectionDialog(BuildContext context) {
    final equipmentList = Provider.of<EquipmentProvider>(context, listen: false).equipments;
    final hoseList = equipmentList.where((e) => e.name.toLowerCase().contains('hose') || e.category.toLowerCase().contains('hose')).toList();

    List<String> tempSelected = _hoseNoCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: const Text('Select Hoses', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: hoseList.length,
                  itemBuilder: (context, index) {
                    final h = hoseList[index];
                    final isSelected = tempSelected.contains(h.name);
                    return CheckboxListTile(
                      title: Text(h.name, style: const TextStyle(color: Colors.white)),
                      value: isSelected,
                      checkColor: Colors.white,
                      activeColor: Colors.redAccent,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            tempSelected.add(h.name);
                          } else {
                            tempSelected.remove(h.name);
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
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _hoseNoCtrl.text = tempSelected.join(', ');
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _showAddPersonnelDialog() {
    final manpowerList = Provider.of<ManpowerProvider>(context, listen: false).getActivePersonnelForDate(_date).where((p) => p.currentStation.trim().toLowerCase() == AppConfig.stationNameShort.toLowerCase() || p.currentStation.isEmpty).toList();
    List<String> tempSelected = [..._attendingOfficersIds, ..._attendingPersonnelIds];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: const Text('Select Personnel', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: manpowerList.length,
                  itemBuilder: (context, index) {
                    final p = manpowerList[index];
                    final isSelected = tempSelected.contains(p.id);
                    return CheckboxListTile(
                      title: Text('${p.name} - ${p.idNumber} (${p.designation})', style: const TextStyle(color: Colors.white)),
                      value: isSelected,
                      checkColor: Colors.white,
                      activeColor: Colors.redAccent,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            tempSelected.add(p.id);
                          } else {
                            tempSelected.remove(p.id);
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
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _attendingOfficersIds.clear();
                      _attendingPersonnelIds.clear();
                      for (String id in tempSelected) {
                        final person = manpowerList.firstWhere((p) => p.id == id);
                        if (person.designation.toLowerCase().contains('officer') || person.designation.toLowerCase().contains('sfro') || person.designation.toLowerCase().contains('afso') || person.designation.toLowerCase().contains('sto')) {
                          _attendingOfficersIds.add(id);
                        } else {
                          _attendingPersonnelIds.add(id);
                        }
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _showAddVehicleDialog() {
    final vehicleList = Provider.of<VehicleProvider>(context, listen: false).vehicles;
    VehicleModel? selectedVehicle;
    TimeOfDay? timeOut;
    TimeOfDay? timeReached;
    TimeOfDay? timeLeft;
    TimeOfDay? timeIn;
    final distanceCtrl = TextEditingController();
    final pumpWorkedCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: const Text('Add Vehicle', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<VehicleModel>(
                      initialValue: selectedVehicle,
                      dropdownColor: const Color(0xFF2C2C2C),
                      decoration: const InputDecoration(labelText: 'Select Vehicle', labelStyle: TextStyle(color: Colors.white70)),
                      items: vehicleList.map((v) => DropdownMenuItem(value: v, child: Text('${v.type} - ${v.regNumber}', style: const TextStyle(color: Colors.white)))).toList(),
                      onChanged: (v) => setDialogState(() => selectedVehicle = v),
                    ),
                    ListTile(
                      title: const Text('Time Out', style: TextStyle(color: Colors.white70)),
                      trailing: Text(timeOut != null ? _formatTime24(timeOut!) : 'Select', style: const TextStyle(color: Colors.white)),
                      onTap: () async {
                        final t = await _showRollingTimePicker(
                          context,
                          timeOut ?? TimeOfDay.now(),
                        );
                        if (t != null) {
                          setDialogState(() {
                            timeOut = t;
                            timeReached ??= t;
                            timeLeft ??= t;
                            timeIn ??= t;
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('Time Reached', style: TextStyle(color: Colors.white70)),
                      trailing: Text(timeReached != null ? _formatTime24(timeReached!) : 'Select', style: const TextStyle(color: Colors.white)),
                      onTap: () async {
                        final t = await _showRollingTimePicker(context, timeReached ?? TimeOfDay.now());
                        if (t != null) setDialogState(() => timeReached = t);
                      },
                    ),
                    ListTile(
                      title: const Text('Time Left', style: TextStyle(color: Colors.white70)),
                      trailing: Text(timeLeft != null ? _formatTime24(timeLeft!) : 'Select', style: const TextStyle(color: Colors.white)),
                      onTap: () async {
                        final t = await _showRollingTimePicker(context, timeLeft ?? TimeOfDay.now());
                        if (t != null) setDialogState(() => timeLeft = t);
                      },
                    ),
                    ListTile(
                      title: const Text('Time In', style: TextStyle(color: Colors.white70)),
                      trailing: Text(timeIn != null ? _formatTime24(timeIn!) : 'Select', style: const TextStyle(color: Colors.white)),
                      onTap: () async {
                        final t = await _showRollingTimePicker(context, timeIn ?? TimeOfDay.now());
                        if (t != null) setDialogState(() => timeIn = t);
                      },
                    ),
                    TextField(controller: distanceCtrl, decoration: const InputDecoration(labelText: 'Distance (KM)', labelStyle: TextStyle(color: Colors.white70)), style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number),
                    TextField(controller: pumpWorkedCtrl, decoration: const InputDecoration(labelText: 'Pump Worked Time', labelStyle: TextStyle(color: Colors.white70)), style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                TextButton(
                  onPressed: () {
                    if (selectedVehicle == null) return;
                    final newVehicle = FireReportVehicleDetail(
                      stationName: 'കൊയിലാണ്ടി',
                      vehicleType: selectedVehicle!.type,
                      regNo: selectedVehicle!.regNumber,
                      timeOut: timeOut != null ? _formatTime24(timeOut!) : '',
                      timeReached: timeReached != null ? _formatTime24(timeReached!) : '',
                      timeLeft: timeLeft != null ? _formatTime24(timeLeft!) : '',
                      timeIn: timeIn != null ? _formatTime24(timeIn!) : '',
                      distanceTripKm: distanceCtrl.text,
                      pumpWorkedTime: pumpWorkedCtrl.text,
                    );

                    setState(() {
                      _vehicleDetails.add(newVehicle);
                    });

                    // Auto-fetch posted personnel from duty register
                    final dutyProvider = Provider.of<DutyProvider>(context, listen: false);
                    final manpowerList = Provider.of<ManpowerProvider>(context, listen: false).getActivePersonnelForDate(_date);

                    final todayRegisters = dutyProvider.registers.where((r) => r.date.year == _date.year && r.date.month == _date.month && r.date.day == _date.day).toList();
                    if (todayRegisters.isNotEmpty) {
                      final register = todayRegisters.first;
                      final normalizedSelectedReg = selectedVehicle!.regNumber.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
                      final normalizedSelectedType = selectedVehicle!.type.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
                      final assignments = register.vehicleAssignments.where((a) {
                        final normalizedAssignedName = a.vehicleName.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

                        if (normalizedSelectedReg.isNotEmpty && normalizedSelectedReg.length > 4 && normalizedAssignedName.contains(normalizedSelectedReg)) {
                          return true;
                        }

                        if (normalizedSelectedType.contains('MTU') && normalizedAssignedName.contains('MTU')) return true;
                        if (normalizedSelectedType.contains('FT') && normalizedAssignedName.contains('F/T'.replaceAll('/', ''))) return true;
                        if (normalizedSelectedType.contains('WATER') && normalizedAssignedName.contains('WATER')) return true;
                        if (normalizedSelectedType.contains('AMB') && normalizedAssignedName.contains('AMB')) return true;
                        if (normalizedSelectedType.contains('SCUBA') && normalizedAssignedName.contains('SCUBA')) return true;
                        if (normalizedSelectedType.contains('JEEP') && normalizedAssignedName.contains('JEEP')) return true;
                        if (normalizedSelectedType.contains('ICV') && normalizedAssignedName.contains('ICV')) return true;
                        if (normalizedSelectedType.contains('CCV') && normalizedAssignedName.contains('CCV')) return true;

                        return false;
                      }).toList();
                      if (assignments.isNotEmpty) {
                        final a = assignments.first;
                        List<String> rawIds = [a.sfro, a.fro, a.khg, a.froD, ...a.manuallyEditedIds];
                        List<String> parsedIdNumbers = [];
                        for (String raw in rawIds) {
                           if (raw.trim().isEmpty) continue;
                           var splits = raw.split(',');
                           for (var s in splits) {
                              if (s.trim().isNotEmpty) parsedIdNumbers.add(s.trim());
                           }
                        }

                        setState(() {
                          for (String idNum in parsedIdNumbers) {
                             try {
                               final person = manpowerList.firstWhere((p) => p.idNumber == idNum);
                               String docId = person.id;
                               if (!_attendingOfficersIds.contains(docId) && !_attendingPersonnelIds.contains(docId)) {
                                 if (person.designation.toLowerCase().contains('officer') || person.designation.toLowerCase().contains('sfro') || person.designation.toLowerCase().contains('afso') || person.designation.toLowerCase().contains('sto')) {
                                   _attendingOfficersIds.add(docId);
                                 } else {
                                   _attendingPersonnelIds.add(docId);
                                 }
                               }
                             } catch(e) {
                               // Ignore if person not found
                             }
                          }
                        });

                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('അന്നത്തെ ഡ്യൂട്ടി രജിസ്റ്ററിൽ നിന്നും ഉദ്യോഗസ്ഥരെ ചേർത്തിട്ടുണ്ട്.')));
                      }
                    }

                    Navigator.pop(context);
                  },
                  child: const Text('Add', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            );
          }
        );
      }
    );
  }
}
