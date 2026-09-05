import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/incident_report_model.dart';
import '../models/vehicle_model.dart';
import '../providers/incident_report_provider.dart';
import '../providers/manpower_provider.dart';
import '../providers/vehicle_provider.dart';
import '../providers/duty_provider.dart';
import '../models/manpower_model.dart';
import '../providers/equipment_provider.dart';

class IncidentReportFormScreen extends StatefulWidget {
  final IncidentReportModel? existingReport;
  const IncidentReportFormScreen({super.key, this.existingReport});

  @override
  State<IncidentReportFormScreen> createState() => _IncidentReportFormScreenState();
}

class _IncidentReportFormScreenState extends State<IncidentReportFormScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // General Info
  final _stationCtrl = TextEditingController(text: 'മീഞ്ചന്ത');
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

  TimeOfDay? _callTime;
  TimeOfDay? _turnoutTime;
  TimeOfDay? _reachedTime;
  final _distanceCtrl = TextEditingController();

  // Incident Details
  final _fullDetailsCtrl = TextEditingController();
  final _confirmedCauseCtrl = TextEditingController();
  final _serviceRenderedCtrl = TextEditingController();
  String? _selectedOfficerLeftLastId;
  DateTime? _dateLeft;
  TimeOfDay? _timeLeft;

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
  List<IncidentReportVehicleDetail> _vehicleDetails = [];

  // Personnel
  List<String> _selectedAttendingOfficers = [];
  List<String> _selectedAttendingPersonnel = [];

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
    } else {
      _generateNextReportNumber();
    }
  }

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

  Future<void> _generateNextReportNumber() async {
    final provider = context.read<IncidentReportProvider>();
    final count = provider.reports.length;
    _reportNumberCtrl.text = '${count + 1}';
  }

  void _loadExistingData(IncidentReportModel r) {
    _stationCtrl.text = r.station;
    _locationCtrl.text = r.location;
    _selectedOfficerInChargeId = r.officerInChargeId;
    _reportNumberCtrl.text = r.reportNumber;
    _date = r.date;

    _callerNameCtrl.text = r.callerName;
    _callerPhoneCtrl.text = r.callerPhone;
    _buildingsInvolvedCtrl.text = r.buildingsInvolved;
    _occupantNameCtrl.text = r.occupantName;
    _occupationCtrl.text = r.occupation;
    _ownerNameCtrl.text = r.ownerNameAndAddress;

    _callTime = r.callTime != null ? TimeOfDay.fromDateTime(r.callTime!) : null;
    _turnoutTime = r.turnoutTime != null ? TimeOfDay.fromDateTime(r.turnoutTime!) : null;
    _reachedTime = r.reachedTime != null ? TimeOfDay.fromDateTime(r.reachedTime!) : null;
    _distanceCtrl.text = r.distanceFromStationKm;

    _fullDetailsCtrl.text = r.fullDetails;
    _confirmedCauseCtrl.text = r.confirmedCause;
    _serviceRenderedCtrl.text = r.serviceRendered;
    _selectedOfficerLeftLastId = r.officerLeftLastId;
    if (r.dateAndTimeLeft != null) {
      _dateLeft = r.dateAndTimeLeft;
      _timeLeft = TimeOfDay.fromDateTime(r.dateAndTimeLeft!);
    }

    _workingHoursCtrl.text = r.totalWorkingHours.toString();
    _workingMinsCtrl.text = r.totalWorkingMinutes.toString();

    _rescNoFfMaleCtrl.text = r.rescuedWithoutFireForceMale.toString();
    _rescNoFfFemaleCtrl.text = r.rescuedWithoutFireForceFemale.toString();
    _rescFfNoEqMaleCtrl.text = r.rescuedWithFireForceNoEqMale.toString();
    _rescFfNoEqFemaleCtrl.text = r.rescuedWithFireForceNoEqFemale.toString();
    _rescFfEqMaleCtrl.text = r.rescuedWithFireForceEqMale.toString();
    _rescFfEqFemaleCtrl.text = r.rescuedWithFireForceEqFemale.toString();

    _casFfMaleCtrl.text = r.casualtiesFireForceMale.toString();
    _casFfFemaleCtrl.text = r.casualtiesFireForceFemale.toString();
    _casFfNamesCtrl.text = r.casualtiesFireForceNames;
    _casFfAddressCtrl.text = r.casualtiesFireForceAddress;

    _casOthMaleCtrl.text = r.casualtiesOthersMale.toString();
    _casOthFemaleCtrl.text = r.casualtiesOthersFemale.toString();
    _casOthNamesCtrl.text = r.casualtiesOthersNames;
    _casOthAddressCtrl.text = r.casualtiesOthersAddress;
    _natureOfDeathCtrl.text = r.natureOfDeath;

    _vehicleDetails = List.from(r.vehicleDetails);
    _selectedAttendingOfficers = List.from(r.attendingOfficersIds);
    _selectedAttendingPersonnel = List.from(r.attendingPersonnelIds);
    _hoseNoCtrl.text = r.hoseNo;
    _remarksCtrl.text = r.remarks;
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
                    child: const Text('റദ്ദാക്കുക', style: TextStyle(color: Colors.redAccent)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(builderContext).pop(pickedTime),
                    child: const Text('പൂർത്തിയായി', style: TextStyle(color: Colors.blueAccent)),
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

  String _formatTime24(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _saveReport() {
    if (!_formKey.currentState!.validate()) return;

    DateTime combine(DateTime baseD, TimeOfDay? t) {
      if (t == null) return baseD;
      return DateTime(baseD.year, baseD.month, baseD.day, t.hour, t.minute);
    }

    DateTime? dateLeft;
    if (_dateLeft != null && _timeLeft != null) {
      dateLeft = combine(_dateLeft!, _timeLeft);
    } else if (_dateLeft != null) {
      dateLeft = _dateLeft;
    } else if (_date != null && _timeLeft != null) {
      dateLeft = combine(_date, _timeLeft);
    }

    final newReport = IncidentReportModel(
      id: widget.existingReport?.id ?? '',
      station: _stationCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
      officerInChargeId: _selectedOfficerInChargeId ?? '',
      reportNumber: _reportNumberCtrl.text.trim(),
      date: _date,
      callerName: _callerNameCtrl.text.trim(),
      callerPhone: _callerPhoneCtrl.text.trim(),
      buildingsInvolved: _buildingsInvolvedCtrl.text.trim(),
      occupantName: _occupantNameCtrl.text.trim(),
      occupation: _occupationCtrl.text.trim(),
      ownerNameAndAddress: _ownerNameCtrl.text.trim(),
      callTime: _callTime != null ? combine(_date, _callTime) : null,
      turnoutTime: _turnoutTime != null ? combine(_date, _turnoutTime) : null,
      reachedTime: _reachedTime != null ? combine(_date, _reachedTime) : null,
      distanceFromStationKm: _distanceCtrl.text.trim(),
      fullDetails: _fullDetailsCtrl.text.trim(),
      confirmedCause: _confirmedCauseCtrl.text.trim(),
      serviceRendered: _serviceRenderedCtrl.text.trim(),
      officerLeftLastId: _selectedOfficerLeftLastId ?? '',
      dateAndTimeLeft: dateLeft,
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
      casualtiesFireForceNames: _casFfNamesCtrl.text.trim(),
      casualtiesFireForceAddress: _casFfAddressCtrl.text.trim(),
      casualtiesOthersMale: int.tryParse(_casOthMaleCtrl.text) ?? 0,
      casualtiesOthersFemale: int.tryParse(_casOthFemaleCtrl.text) ?? 0,
      casualtiesOthersNames: _casOthNamesCtrl.text.trim(),
      casualtiesOthersAddress: _casOthAddressCtrl.text.trim(),
      natureOfDeath: _natureOfDeathCtrl.text.trim(),
      vehicleDetails: _vehicleDetails,
      attendingOfficersIds: _selectedAttendingOfficers,
      attendingPersonnelIds: _selectedAttendingPersonnel,
      hoseNo: _hoseNoCtrl.text.trim(),
      remarks: _remarksCtrl.text.trim(),
    );

    final provider = context.read<IncidentReportProvider>();
    if (widget.existingReport == null) {
      provider.addReport(newReport);
    } else {
      provider.updateReport(newReport);
    }

    Navigator.pop(context);
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildTimeSelector(String label, TimeOfDay? time, Function(TimeOfDay?) onSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final t = await _showRollingTimePicker(context, time ?? TimeOfDay.now());
          if (t != null) setState(() => onSelected(t));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70)),
              Text(time != null ? _formatTime24(time) : 'സമയം തിരഞ്ഞെടുക്കുക', style: const TextStyle(color: Colors.blueAccent)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfficerDropdown(String label, String? selectedId, Function(String?) onChanged) {
    final manpowerList = context.watch<ManpowerProvider>().getActivePersonnelForDate(_date);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: selectedId,
        decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white70), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
        dropdownColor: const Color(0xFF1E1E1E),
        items: manpowerList.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(color: Colors.white)))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildMultiSelect(String label, List<String> selectedIds, Function(List<String>) onChanged) {
    final manpowerList = context.watch<ManpowerProvider>().getActivePersonnelForDate(_date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: manpowerList.map((p) {
            final isSelected = selectedIds.contains(p.id);
            return FilterChip(
              label: Text(p.name),
              selected: isSelected,
              onSelected: (val) {
                setState(() {
                  if (val) {
                    selectedIds.add(p.id);
                  } else {
                    selectedIds.remove(p.id);
                  }
                  onChanged(selectedIds);
                });
              },
              selectedColor: Colors.blueAccent.withOpacity(0.3),
              checkmarkColor: Colors.blueAccent,
              backgroundColor: Colors.white.withOpacity(0.05),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.existingReport == null ? "പുതിയ സംഭവ റിപ്പോർട്ട്" : "സംഭവ റിപ്പോർട്ട് എഡിറ്റ് ചെയ്യുക", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 7) {
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
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    child: Text(_currentStep == 7 ? "സേവ് ചെയ്യുക" : "അടുത്തത്", style: const TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text("പുറകോട്ട്", style: TextStyle(color: Colors.white70)),
                    )
                ],
              ),
            );
          },
          steps: [
              Step(
                title: const Text("പൊതുവിവരങ്ങൾ", style: TextStyle(color: Colors.white)),
                content: Column(
                  children: [
                    _buildTextField("സംഭവ റിപ്പോർട്ട് നമ്പർ", _reportNumberCtrl),
                    _buildTextField("സ്ഥലം", _locationCtrl),
                    _buildOfficerDropdown("സംഭവസ്ഥലത്ത് ചുമതല വഹിച്ച ആഫീസർ", _selectedOfficerInChargeId, (val) => setState(() => _selectedOfficerInChargeId = val)),
                    const SizedBox(height: 12),
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.white24)),
                      tileColor: Colors.white.withOpacity(0.05),
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
              title: const Text("അറിയിപ്പ്", style: TextStyle(color: Colors.white)),
              content: Column(
                children: [
                  _buildTextField("വിളിച്ച ആൾ", _callerNameCtrl),
                  _buildTextField("ടെലിഫോൺ/തീപിടുത്ത അറിയിപ്പ് നമ്പർ", _callerPhoneCtrl, isNumber: true),
                  _buildTextField("ഉൾപ്പെട്ട കെട്ടിടങ്ങളുടെ വിവരങ്ങൾ", _buildingsInvolvedCtrl, maxLines: 2),
                  _buildTextField("പാർപ്പുകാരൻ്റെ പേര്", _occupantNameCtrl),
                  _buildTextField("ജോലി", _occupationCtrl),
                  _buildTextField("ഉടമസ്ഥൻ്റെ പേരും വിലാസവും", _ownerNameCtrl, maxLines: 2),
                  _buildTimeSelector("വിളിച്ച സമയം", _callTime, (t) {
                    _callTime = t;
                    _turnoutTime ??= t;
                    _reachedTime ??= t;
                  }),
                  _buildTimeSelector("ആദ്യം പുറപ്പെട്ട സമയം", _turnoutTime, (t) => _turnoutTime = t),
                  _buildTimeSelector("സംഭവസ്ഥലത്ത് എത്തിയ സമയം", _reachedTime, (t) => _reachedTime = t),
                  _buildTextField("സ്റ്റേഷനിൽ നിന്ന് സംഭവസ്ഥലത്തേക്കുള്ള ദൂരം (കി. മി.)", _distanceCtrl, isNumber: true),
                ],
              ),
              isActive: _currentStep >= 1,
            ),
            Step(
              title: const Text("വിവരങ്ങൾ", style: TextStyle(color: Colors.white)),
              content: Column(
                children: [
                  _buildTextField("സംഭവത്തിന്റെ പൂർണ്ണ വിശദാംശങ്ങൾ", _fullDetailsCtrl, maxLines: 4),
                  _buildTextField("ഉറപ്പിക്കപ്പെടുന്ന കാരണം", _confirmedCauseCtrl),
                  _buildTextField("നൽകിയ സേവനം", _serviceRenderedCtrl, maxLines: 2),
                  _buildOfficerDropdown("അവസാനം സംഭവസ്ഥലത്തുനിന്ന് പോയ ആഫീസർ", _selectedOfficerLeftLastId, (val) => setState(() => _selectedOfficerLeftLastId = val)),
                  _buildTimeSelector("സംഭവസ്ഥലം വിട്ടുപോയ സമയം", _timeLeft, (t) => _timeLeft = t),
                  Row(
                    children: [
                      Expanded(child: _buildTextField("ആകെ പണിയെടുത്ത സമയം (മണിക്കൂർ)", _workingHoursCtrl, isNumber: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField("ആകെ പണിയെടുത്ത സമയം (മിനിറ്റ്)", _workingMinsCtrl, isNumber: true)),
                    ],
                  ),
                ],
              ),
              isActive: _currentStep >= 2,
            ),
            Step(
              title: const Text("രക്ഷപ്പെട്ടവരും രക്ഷിക്കപ്പെട്ടവരും", style: TextStyle(color: Colors.white)),
              content: Column(
                children: [
                  const Text("അഗ്നിശമന സേനയുടെ സഹായമില്ലാതെ രക്ഷപ്പെട്ടവർ", style: TextStyle(color: Colors.white70)),
                  Row(
                    children: [
                      Expanded(child: _buildTextField("പുരുഷൻ", _rescNoFfMaleCtrl, isNumber: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField("സ്ത്രീ", _rescNoFfFemaleCtrl, isNumber: true)),
                    ],
                  ),
                  const Text("ഉപകരണങ്ങൾ കൂടാതെ അഗ്നിശമനസേന രക്ഷിച്ചവർ", style: TextStyle(color: Colors.white70)),
                  Row(
                    children: [
                      Expanded(child: _buildTextField("പുരുഷൻ", _rescFfNoEqMaleCtrl, isNumber: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField("സ്ത്രീ", _rescFfNoEqFemaleCtrl, isNumber: true)),
                    ],
                  ),
                  const Text("ഉപകരണങ്ങളുപയോഗിച്ച് അഗ്നിശമനസേന രക്ഷിച്ചവർ", style: TextStyle(color: Colors.white70)),
                  Row(
                    children: [
                      Expanded(child: _buildTextField("പുരുഷൻ", _rescFfEqMaleCtrl, isNumber: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField("സ്ത്രീ", _rescFfEqFemaleCtrl, isNumber: true)),
                    ],
                  ),
                ],
              ),
              isActive: _currentStep >= 3,
            ),
            Step(
              title: const Text("ആളപായങ്ങൾ", style: TextStyle(color: Colors.white)),
              content: Column(
                children: [
                  const Text("അഗ്നിശമനസേന", style: TextStyle(color: Colors.white70)),
                  Row(
                    children: [
                      Expanded(child: _buildTextField("പുരുഷൻ", _casFfMaleCtrl, isNumber: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField("സ്ത്രീ", _casFfFemaleCtrl, isNumber: true)),
                    ],
                  ),
                  _buildTextField("പേര്", _casFfNamesCtrl),
                  _buildTextField("വിലാസം", _casFfAddressCtrl),
                  const Divider(color: Colors.white24),
                  const Text("മറ്റുള്ളവർ", style: TextStyle(color: Colors.white70)),
                  Row(
                    children: [
                      Expanded(child: _buildTextField("പുരുഷൻ", _casOthMaleCtrl, isNumber: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTextField("സ്ത്രീ", _casOthFemaleCtrl, isNumber: true)),
                    ],
                  ),
                  _buildTextField("പേര്", _casOthNamesCtrl),
                  _buildTextField("വിലാസം", _casOthAddressCtrl),
                  _buildTextField("ക്ഷതത്തിന്റെ സ്വഭാവം", _natureOfDeathCtrl),
                ],
              ),
              isActive: _currentStep >= 4,
            ),
              Step(
                title: const Text("സംഭവസ്ഥലത്തെ ഹാജർ", style: TextStyle(color: Colors.white)),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(child: Text('വാഹനങ്ങൾ (Vehicles)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                        TextButton.icon(
                          onPressed: _showAddVehicleDialog,
                          icon: const Icon(Icons.add, color: Colors.blueAccent),
                          label: const Text('Add', style: TextStyle(color: Colors.blueAccent)),
                        ),
                      ],
                    ),
                    if (_vehicleDetails.isEmpty)
                      const Text('വാഹനങ്ങളൊന്നും ചേർത്തിട്ടില്ല.', style: TextStyle(color: Colors.white54))
                    else
                      ..._vehicleDetails.map((v) => Card(
                        color: const Color(0xFF1E1E1E),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text('${v.vehicleType} (${v.regNo})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  ],
                ),
                isActive: _currentStep >= 5,
              ),
            Step(
              title: const Text("ഹാജരായ അഗ്നിശമന സേനാംഗങ്ങൾ", style: TextStyle(color: Colors.white)),
              content: Column(
                children: [
                  _buildMultiSelect("ആഫീസർമാർ", _selectedAttendingOfficers, (v) => _selectedAttendingOfficers = v),
                  _buildMultiSelect("സേനാംഗങ്ങൾ", _selectedAttendingPersonnel, (v) => _selectedAttendingPersonnel = v),
                ],
              ),
              isActive: _currentStep >= 6,
            ),
            Step(
              title: const Text("മറ്റ് റിമാർക്കുകൾ", style: TextStyle(color: Colors.white)),
              content: _buildTextField("വേറെ എന്തെങ്കിലും വിവരം ചേർക്കാനുണ്ടെങ്കിൽ അത് താഴെ എഴുതുക", _remarksCtrl, maxLines: 3),
              isActive: _currentStep >= 7,
            ),
          ],
        ),
      ),
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
                    final newVehicle = IncidentReportVehicleDetail(
                      stationName: 'മീഞ്ചന്ത',
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
                               if (!_selectedAttendingOfficers.contains(docId) && !_selectedAttendingPersonnel.contains(docId)) {
                                 if (person.designation.toLowerCase().contains('officer') || person.designation.toLowerCase().contains('sfro') || person.designation.toLowerCase().contains('afso') || person.designation.toLowerCase().contains('sto')) {
                                   _selectedAttendingOfficers.add(docId);
                                 } else {
                                   _selectedAttendingPersonnel.add(docId);
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
                  child: const Text('Add', style: TextStyle(color: Colors.blueAccent)),
                ),
              ],
            );
          }
        );
      }
    );
  }
}
