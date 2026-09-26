import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/vehicle_provider.dart';
import '../models/vehicle_model.dart';

class VehicleMasterRegistryScreen extends StatefulWidget {
  final VehicleModel? vehicle; // If null, we are in "Add Vehicle" mode
  const VehicleMasterRegistryScreen({super.key, this.vehicle});

  @override
  State<VehicleMasterRegistryScreen> createState() => _VehicleMasterRegistryScreenState();
}

class _VehicleMasterRegistryScreenState extends State<VehicleMasterRegistryScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text controllers for form inputs
  late TextEditingController _regNumberController;
  late TextEditingController _typeController;
  late TextEditingController _shortNameController;
  late TextEditingController _callSignController;
  late TextEditingController _chassisNumberController;
  late TextEditingController _engineNumberController;
  late TextEditingController _makeModelController;
  late TextEditingController _yearOfInductionController;
  late TextEditingController _currentOdometerController;
  late TextEditingController _fuelConsumedThisFYController;
  late TextEditingController _fuelTankCapacityController;
  late TextEditingController _currentFuelInTankController;
  late TextEditingController _mileageOnRoadController;
  late TextEditingController _mileageOnPumpingController;
  late TextEditingController _fixedDSConsumptionController;
  late TextEditingController _nextServiceAtKMController;

  // Status & Toggles
  late String _status; // READY, OFF ROAD, MAINTENANCE
  late bool _hasFirePump;

  // Dates
  DateTime? _insuranceDate;
  DateTime? _insuranceExpiry;
  DateTime? _fcDate;
  DateTime? _fcExpiry;
  DateTime? _taxDate;
  DateTime? _taxExpiry;
  DateTime? _pucDate;
  DateTime? _pucExpiry;
  DateTime? _adBlueDate;
  DateTime? _adBlueExpiry;
  DateTime? _mileageReviewDate;
  DateTime? _lastServiceDate;
  DateTime? _nextServiceDate;
  DateTime? _lastPumpServiceDate;
  DateTime? _nextPumpServiceDate;

  // Lists for dynamic sections
  List<BreakdownRecord> _breakdowns = [];
  List<RepairHistoryRecord> _repairHistory = [];
  List<TempIssueHistoryRecord> _tempIssueHistory = [];
  List<InventoryItem> _inventory = [];
  List<CompartmentModel> _compartments = [];

  // Delete option
  bool _confirmDelete = false;

  bool _hasLogbookEntries = false;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;

    _regNumberController = TextEditingController(text: v?.regNumber ?? '');
    _typeController = TextEditingController(text: v?.type ?? '');
    _shortNameController = TextEditingController(text: v?.shortName ?? '');
    _callSignController = TextEditingController(text: v?.callSign ?? '');
    _chassisNumberController = TextEditingController(text: v?.chassisNumber ?? '');
    _engineNumberController = TextEditingController(text: v?.engineNumber ?? '');
    _makeModelController = TextEditingController(text: v?.makeModel ?? '');
    _yearOfInductionController = TextEditingController(text: v?.yearOfInduction ?? '');
    _currentOdometerController = TextEditingController(text: v != null ? (v.currentOdometer % 1 == 0 ? v.currentOdometer.toInt().toString() : v.currentOdometer.toString()) : '');
    _fuelConsumedThisFYController = TextEditingController(text: v != null ? v.fuelConsumedThisFY.toString() : '');
    _fuelTankCapacityController = TextEditingController(text: v != null ? v.fuelTankCapacity.toString() : '');
    _currentFuelInTankController = TextEditingController(text: v != null ? v.currentFuelInTank.toString() : '');
    _mileageOnRoadController = TextEditingController(text: v != null ? v.mileageOnRoad.toString() : '');
    _mileageOnPumpingController = TextEditingController(text: v != null ? v.mileageOnPumping.toString() : '');
    _fixedDSConsumptionController = TextEditingController(text: v != null ? v.fixedDSConsumption.toString() : '');
    _nextServiceAtKMController = TextEditingController(text: v != null ? v.nextServiceAtKM.toString() : '');

    _status = v?.status ?? 'READY';
    _hasFirePump = v?.hasFirePump ?? false;

    _insuranceDate = v?.insuranceDate;
    _insuranceExpiry = v?.insuranceExpiry;
    _fcDate = v?.fcDate;
    _fcExpiry = v?.fcExpiry;
    _taxDate = v?.taxDate;
    _taxExpiry = v?.taxExpiry;
    _pucDate = v?.pucDate;
    _pucExpiry = v?.pucExpiry;
    _adBlueDate = v?.adBlueDate;
    _adBlueExpiry = v?.adBlueExpiry;
    _mileageReviewDate = v?.mileageReviewDate;
    _lastServiceDate = v?.lastServiceDate;
    _nextServiceDate = v?.nextServiceDate;
    _lastPumpServiceDate = v?.lastPumpServiceDate;
    _nextPumpServiceDate = v?.nextPumpServiceDate;

    _breakdowns = v != null ? List.from(v.breakdowns) : [];
    _repairHistory = v != null ? List.from(v.repairHistory) : [];
    _tempIssueHistory = v != null ? List.from(v.tempIssueHistory) : [];
    _inventory = v != null ? List.from(v.inventory) : [];
    _compartments = v != null ? List.from(v.compartments) : [];

    if (v != null) {
      FirebaseFirestore.instance
          .collection('logbooks')
          .where('vehicleId', isEqualTo: v.id)
          .limit(1)
          .get()
          .then((snapshot) {
        if (mounted && snapshot.docs.isNotEmpty) {
          setState(() {
            _hasLogbookEntries = true;
          });
        }
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _regNumberController.dispose();
    _typeController.dispose();
    _callSignController.dispose();
    _chassisNumberController.dispose();
    _engineNumberController.dispose();
    _makeModelController.dispose();
    _yearOfInductionController.dispose();
    _currentOdometerController.dispose();
    _fuelConsumedThisFYController.dispose();
    _fuelTankCapacityController.dispose();
    _currentFuelInTankController.dispose();
    _mileageOnRoadController.dispose();
    _mileageOnPumpingController.dispose();
    _fixedDSConsumptionController.dispose();
    _nextServiceAtKMController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, String fieldName, DateTime? initialDate, Function(DateTime) onSelected) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.amber,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        onSelected(picked);
      });
    }
  }

  Widget _buildGlassCard({required Widget child, Color? borderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor ?? Colors.amber.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.amber,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            readOnly: readOnly,
            style: TextStyle(color: readOnly ? Colors.amberAccent : Colors.white, fontSize: 14, fontWeight: readOnly ? FontWeight.bold : FontWeight.normal),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: readOnly ? Colors.amber.withOpacity(0.08) : Colors.white.withOpacity(0.05),
              suffixIcon: suffixIcon,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Colors.amber),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime? selectedDate,
    required VoidCallback onTap,
  }) {
    final dateStr = selectedDate != null ? DateFormat('dd/MM/yyyy').format(selectedDate) : 'Select Date';
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 4),
            InkWell(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        dateStr,
                        style: TextStyle(
                          color: selectedDate != null ? Colors.white : Colors.white38,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.calendar_month, color: Colors.amber, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addBreakdownDialog() {
    final descController = TextEditingController();
    DateTime breakdownDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Add Breakdown Record', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    'Date: ${DateFormat('dd/MM/yyyy').format(breakdownDate)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(Icons.calendar_month, color: Colors.amber),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: breakdownDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        breakdownDate = picked;
                      });
                    }
                  },
                ),
                TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Breakdown Details',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (descController.text.isNotEmpty) {
                    setState(() {
                      _breakdowns.add(BreakdownRecord(
                        date: breakdownDate,
                        details: descController.text.trim(),
                      ));
                    });
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                child: const Text('Add'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _addRepairHistoryRow() {
    setState(() {
      _repairHistory.add(RepairHistoryRecord(
        sl: (_repairHistory.length + 1).toString(),
        offRoad: '',
        onRoad: '',
        duration: '',
        mechanicalRemarks: '',
      ));
    });
  }

  void _addTempIssueRow() {
    setState(() {
      _tempIssueHistory.add(TempIssueHistoryRecord(
        sl: (_tempIssueHistory.length + 1).toString(),
        issued: '',
        returned: '',
        heldPeriod: '',
        stationUnitDetails: '',
      ));
    });
  }

  void _addInventoryRow() {
    setState(() {
      _inventory.add(InventoryItem(
        slNo: _inventory.length + 1,
        equipName: '',
        qty: 0,
        remarks: '',
      ));
    });
  }

  void _addCompartmentRow() {
    setState(() {
      _compartments.add(CompartmentModel(
        id: 'L${_compartments.where((c) => c.side == 'left').length + 1}',
        label: '',
        side: 'left',
      ));
    });
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields'), backgroundColor: Colors.orange),
      );
      return;
    }

    final double water = widget.vehicle?.waterLevel ?? 0.0;
    final double fuel = widget.vehicle?.fuelLevel ?? 0.0;

    final updatedVehicle = VehicleModel(
      id: widget.vehicle?.id ?? '',
      regNumber: _regNumberController.text.trim(),
      type: _typeController.text.trim().isEmpty ? _callSignController.text.trim() : _typeController.text.trim(),
      shortName: _shortNameController.text.trim(),
      status: _status,
      waterLevel: water,
      fuelLevel: fuel,
      callSign: _callSignController.text.trim(),
      chassisNumber: _chassisNumberController.text.trim(),
      engineNumber: _engineNumberController.text.trim(),
      makeModel: _makeModelController.text.trim(),
      yearOfInduction: _yearOfInductionController.text.trim(),
      hasFirePump: _hasFirePump,
      insuranceDate: _insuranceDate,
      insuranceExpiry: _insuranceExpiry,
      fcDate: _fcDate,
      fcExpiry: _fcExpiry,
      taxDate: _taxDate,
      taxExpiry: _taxExpiry,
      pucDate: _pucDate,
      pucExpiry: _pucExpiry,
      adBlueDate: _adBlueDate,
      adBlueExpiry: _adBlueExpiry,
      currentOdometer: double.tryParse(_currentOdometerController.text) ?? 0.0,
      fuelConsumedThisFY: double.tryParse(_fuelConsumedThisFYController.text) ?? 0.0,
      prevFYHistory: widget.vehicle?.prevFYHistory ?? [],
      fuelTankCapacity: double.tryParse(_fuelTankCapacityController.text) ?? 0.0,
      currentFuelInTank: double.tryParse(_currentFuelInTankController.text) ?? 0.0,
      mileageReviewDate: _mileageReviewDate,
      mileageOnRoad: double.tryParse(_mileageOnRoadController.text) ?? 0.0,
      mileageOnPumping: _hasFirePump ? (double.tryParse(_mileageOnPumpingController.text) ?? 0.0) : 0.0,
      fixedDSConsumption: double.tryParse(_fixedDSConsumptionController.text) ?? 0.0,
      lastServiceDate: _lastServiceDate,
      nextServiceAtKM: double.tryParse(_nextServiceAtKMController.text) ?? 0.0,
      nextServiceDate: _nextServiceDate,
      lastPumpServiceDate: _lastPumpServiceDate,
      nextPumpServiceDate: _nextPumpServiceDate,
      breakdowns: _breakdowns,
      repairHistory: _repairHistory,
      tempIssueHistory: _tempIssueHistory,
      inventory: _inventory,
      compartments: _compartments,
    );

    final provider = context.read<VehicleProvider>();
    if (widget.vehicle != null) {
      await provider.updateVehicle(updatedVehicle);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle Master updated successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } else {
      await provider.addVehicle(updatedVehicle);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle added successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _deleteVehicle() async {
    if (!_confirmDelete || widget.vehicle == null) return;
    final provider = context.read<VehicleProvider>();
    await provider.deleteVehicle(widget.vehicle!.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle deleted successfully'), backgroundColor: Colors.redAccent),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Vehicle Master Registry', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.5,
            colors: [
              Color(0xFF2C0B0B),
              Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // --- SECTION 1: IDENTIFICATION ---
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('1. Identification'),
                        _buildTextField(controller: _callSignController, label: 'Vehicle ID / Call Sign', validator: (val) => val == null || val.isEmpty ? 'Required' : null),
                        _buildTextField(controller: _regNumberController, label: 'Registration Number', validator: (val) => val == null || val.isEmpty ? 'Required' : null),
                        _buildTextField(controller: _typeController, label: 'Vehicle Type (e.g. FOAM TENDER)'),
                        _buildTextField(controller: _shortNameController, label: 'Short Name (e.g. F/T, MIST)'),
                        _buildTextField(controller: _chassisNumberController, label: 'Chassis Number'),
                        _buildTextField(controller: _engineNumberController, label: 'Engine Number'),
                        _buildTextField(controller: _makeModelController, label: 'Make / Model'),
                        _buildTextField(controller: _yearOfInductionController, label: 'Year of Induction'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- SECTION 2: OPERATION STATUS & TYPE ---
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('2. Operation Status & Vehicle Type'),
                        Row(
                          children: [
                            // Status selector
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    if (_status == 'READY') {
                                      _status = 'OFF ROAD';
                                    } else if (_status == 'OFF ROAD') {
                                      _status = 'MAINTENANCE';
                                    } else {
                                      _status = 'READY';
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _status == 'READY'
                                        ? Colors.green.withOpacity(0.3)
                                        : (_status == 'OFF ROAD' ? Colors.red.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: _status == 'READY'
                                          ? Colors.greenAccent
                                          : (_status == 'OFF ROAD' ? Colors.redAccent : Colors.orangeAccent),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Status: $_status',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Fire pump toggle
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _hasFirePump = !_hasFirePump;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _hasFirePump ? Colors.blue.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: _hasFirePump ? Colors.blueAccent : Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'FIRE PUMP: ${_hasFirePump ? "YES" : "NO"}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- SECTION 3: COMPLIANCE EXPIRIES ---
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('3. Compliance Expiries'),
                        Row(
                          children: [
                            _buildDatePickerField(
                              label: 'Insurance Date',
                              selectedDate: _insuranceDate,
                              onTap: () => _selectDate(context, 'insuranceDate', _insuranceDate, (d) => _insuranceDate = d),
                            ),
                            const SizedBox(width: 12),
                            _buildDatePickerField(
                              label: 'Insurance Expiry',
                              selectedDate: _insuranceExpiry,
                              onTap: () => _selectDate(context, 'insuranceExpiry', _insuranceExpiry, (d) => _insuranceExpiry = d),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _buildDatePickerField(
                              label: 'FC Date',
                              selectedDate: _fcDate,
                              onTap: () => _selectDate(context, 'fcDate', _fcDate, (d) => _fcDate = d),
                            ),
                            const SizedBox(width: 12),
                            _buildDatePickerField(
                              label: 'FC Expiry',
                              selectedDate: _fcExpiry,
                              onTap: () => _selectDate(context, 'fcExpiry', _fcExpiry, (d) => _fcExpiry = d),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _buildDatePickerField(
                              label: 'Tax Date',
                              selectedDate: _taxDate,
                              onTap: () => _selectDate(context, 'taxDate', _taxDate, (d) => _taxDate = d),
                            ),
                            const SizedBox(width: 12),
                            _buildDatePickerField(
                              label: 'Tax Expiry',
                              selectedDate: _taxExpiry,
                              onTap: () => _selectDate(context, 'taxExpiry', _taxExpiry, (d) => _taxExpiry = d),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _buildDatePickerField(
                              label: 'PUC Date',
                              selectedDate: _pucDate,
                              onTap: () => _selectDate(context, 'pucDate', _pucDate, (d) => _pucDate = d),
                            ),
                            const SizedBox(width: 12),
                            _buildDatePickerField(
                              label: 'PUC Expiry',
                              selectedDate: _pucExpiry,
                              onTap: () => _selectDate(context, 'pucExpiry', _pucExpiry, (d) => _pucExpiry = d),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _buildDatePickerField(
                              label: 'AdBlue Date',
                              selectedDate: _adBlueDate,
                              onTap: () => _selectDate(context, 'adBlueDate', _adBlueDate, (d) => _adBlueDate = d),
                            ),
                            const SizedBox(width: 12),
                            _buildDatePickerField(
                              label: 'AdBlue Expiry',
                              selectedDate: _adBlueExpiry,
                              onTap: () => _selectDate(context, 'adBlueExpiry', _adBlueExpiry, (d) => _adBlueExpiry = d),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- SECTION 4: UTILIZATION DATA ---
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('4. Utilization Data'),
                        _buildTextField(
                          controller: _currentOdometerController,
                          label: 'Current Odometer (KM)',
                          keyboardType: TextInputType.number,
                          readOnly: _hasLogbookEntries,
                          suffixIcon: _hasLogbookEntries ? const Icon(Icons.lock, color: Colors.amber, size: 18) : null,
                        ),
                        _buildTextField(
                          controller: _fuelConsumedThisFYController,
                          label: 'Total Fuel Consumed this FY (L)',
                          keyboardType: TextInputType.number,
                          readOnly: _hasLogbookEntries,
                          suffixIcon: _hasLogbookEntries ? const Icon(Icons.lock, color: Colors.amber, size: 18) : null,
                        ),
                        // Pre-FY History selector
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Previous FY History', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      widget.vehicle != null && widget.vehicle!.prevFYHistory.isNotEmpty
                                          ? '${widget.vehicle!.prevFYHistory.length} records found'
                                          : 'No Previous FY History',
                                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                                    ),
                                    const Icon(Icons.arrow_drop_down, color: Colors.amber),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildTextField(controller: _fuelTankCapacityController, label: 'Fuel Tank Capacity (L)', keyboardType: TextInputType.number),
                        _buildTextField(
                          controller: _currentFuelInTankController,
                          label: 'Current Fuel in Tank (L)',
                          keyboardType: TextInputType.number,
                          readOnly: _hasLogbookEntries,
                          suffixIcon: _hasLogbookEntries ? const Icon(Icons.lock, color: Colors.amber, size: 18) : null,
                          validator: (value) {
                            if (value == null || value.isEmpty) return null;
                            final fuel = double.tryParse(value);
                            if (fuel == null) return 'Invalid number';
                            final capacityStr = _fuelTankCapacityController.text;
                            if (capacityStr.isNotEmpty) {
                              final capacity = double.tryParse(capacityStr);
                              if (capacity != null && fuel > capacity) {
                                return 'Cannot exceed tank capacity ($capacity)';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- SECTION 5: MILEAGE REVIEW ---
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('5. Mileage Review'),
                        Row(
                          children: [
                            _buildDatePickerField(
                              label: 'Effective Date of Review',
                              selectedDate: _mileageReviewDate,
                              onTap: () => _selectDate(context, 'mileageReviewDate', _mileageReviewDate, (d) => _mileageReviewDate = d),
                            ),
                          ],
                        ),
                        _buildTextField(controller: _mileageOnRoadController, label: 'Mileage On Road (km/l)', keyboardType: TextInputType.number),
                        if (_hasFirePump)
                          _buildTextField(controller: _mileageOnPumpingController, label: 'Mileage On Pumping (km/l)', keyboardType: TextInputType.number),
                        _buildTextField(controller: _fixedDSConsumptionController, label: 'Fixed DS Consumption (L) - Saturday Only', keyboardType: TextInputType.number),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- SECTION 6: MAINTENANCE & BREAKDOWN ---
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('6. Maintenance & Breakdown History'),
                        Row(
                          children: [
                            _buildDatePickerField(
                              label: 'Last Service Date',
                              selectedDate: _lastServiceDate,
                              onTap: () => _selectDate(context, 'lastServiceDate', _lastServiceDate, (d) => _lastServiceDate = d),
                            ),
                          ],
                        ),
                        _buildTextField(controller: _nextServiceAtKMController, label: 'Next Service @ KM', keyboardType: TextInputType.number),
                        Row(
                          children: [
                            _buildDatePickerField(
                              label: 'Next Service Date',
                              selectedDate: _nextServiceDate,
                              onTap: () => _selectDate(context, 'nextServiceDate', _nextServiceDate, (d) => _nextServiceDate = d),
                            ),
                          ],
                        ),
                        if (_hasFirePump) ...[
                          Row(
                            children: [
                              _buildDatePickerField(
                                label: 'Last Pump Service Date',
                                selectedDate: _lastPumpServiceDate,
                                onTap: () => _selectDate(context, 'lastPumpServiceDate', _lastPumpServiceDate, (d) => _lastPumpServiceDate = d),
                              ),
                              const SizedBox(width: 12),
                              _buildDatePickerField(
                                label: 'Next Pump Service Date',
                                selectedDate: _nextPumpServiceDate,
                                onTap: () => _selectDate(context, 'nextPumpServiceDate', _nextPumpServiceDate, (d) => _nextPumpServiceDate = d),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        const Text('Breakdowns:', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        if (_breakdowns.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('No breakdown records', style: TextStyle(color: Colors.white30, fontSize: 13)),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _breakdowns.length,
                            itemBuilder: (context, idx) {
                              final b = _breakdowns[idx];
                              return Card(
                                color: Colors.white.withOpacity(0.02),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  title: Text(b.details, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  subtitle: Text(
                                    b.date != null ? DateFormat('dd/MM/yyyy').format(b.date!) : '',
                                    style: const TextStyle(color: Colors.white30, fontSize: 11),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _breakdowns.removeAt(idx);
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _addBreakdownDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('ADD BREAKDOWN RECORD'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.08),
                              foregroundColor: Colors.amber,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- SECTION 7: VEHICLE HISTORY TABLES ---
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('7. Vehicle History'),
                        const Text('Repair & Maintenance History', style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Table(
                            defaultColumnWidth: const FixedColumnWidth(100),
                            border: TableBorder.all(color: Colors.white.withOpacity(0.1)),
                            children: [
                              TableRow(
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05)),
                                children: const [
                                  TableCell(child: Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text('SI', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))),
                                  TableCell(child: Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text('Off Road', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))),
                                  TableCell(child: Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text('On Road', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))),
                                  TableCell(child: Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text('Duration', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))),
                                  TableCell(child: Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text('Mechanical Remarks', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))),
                                ],
                              ),
                              for (int i = 0; i < _repairHistory.length; i++)
                                TableRow(
                                  children: [
                                    TableCell(child: Center(child: Padding(padding: const EdgeInsets.all(4.0), child: Text(_repairHistory[i].sl, style: const TextStyle(color: Colors.white, fontSize: 12))))),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(2.0),
                                        child: TextFormField(
                                          initialValue: _repairHistory[i].offRoad,
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.all(4)),
                                          onChanged: (val) {
                                            _repairHistory[i] = RepairHistoryRecord(
                                              sl: _repairHistory[i].sl,
                                              offRoad: val,
                                              onRoad: _repairHistory[i].onRoad,
                                              duration: _repairHistory[i].duration,
                                              mechanicalRemarks: _repairHistory[i].mechanicalRemarks,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(2.0),
                                        child: TextFormField(
                                          initialValue: _repairHistory[i].onRoad,
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.all(4)),
                                          onChanged: (val) {
                                            _repairHistory[i] = RepairHistoryRecord(
                                              sl: _repairHistory[i].sl,
                                              offRoad: _repairHistory[i].offRoad,
                                              onRoad: val,
                                              duration: _repairHistory[i].duration,
                                              mechanicalRemarks: _repairHistory[i].mechanicalRemarks,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(2.0),
                                        child: TextFormField(
                                          initialValue: _repairHistory[i].duration,
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.all(4)),
                                          onChanged: (val) {
                                            _repairHistory[i] = RepairHistoryRecord(
                                              sl: _repairHistory[i].sl,
                                              offRoad: _repairHistory[i].offRoad,
                                              onRoad: _repairHistory[i].onRoad,
                                              duration: val,
                                              mechanicalRemarks: _repairHistory[i].mechanicalRemarks,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(2.0),
                                        child: TextFormField(
                                          initialValue: _repairHistory[i].mechanicalRemarks,
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.all(4)),
                                          onChanged: (val) {
                                            _repairHistory[i] = RepairHistoryRecord(
                                              sl: _repairHistory[i].sl,
                                              offRoad: _repairHistory[i].offRoad,
                                              onRoad: _repairHistory[i].onRoad,
                                              duration: _repairHistory[i].duration,
                                              mechanicalRemarks: val,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _addRepairHistoryRow,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Repair Row', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(foregroundColor: Colors.amber),
                        ),
                        const Divider(color: Colors.white24, height: 24),
                        const Text('Temporary Issue Period History', style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Table(
                            defaultColumnWidth: const FixedColumnWidth(100),
                            border: TableBorder.all(color: Colors.white.withOpacity(0.1)),
                            children: [
                              TableRow(
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05)),
                                children: const [
                                  TableCell(child: Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text('SI', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))),
                                  TableCell(child: Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text('Issued', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))),
                                  TableCell(child: Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text('Returned', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))),
                                  TableCell(child: Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text('Held Period', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))),
                                  TableCell(child: Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text('Station/Unit Details', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))))),
                                ],
                              ),
                              for (int i = 0; i < _tempIssueHistory.length; i++)
                                TableRow(
                                  children: [
                                    TableCell(child: Center(child: Padding(padding: const EdgeInsets.all(4.0), child: Text(_tempIssueHistory[i].sl, style: const TextStyle(color: Colors.white, fontSize: 12))))),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(2.0),
                                        child: TextFormField(
                                          initialValue: _tempIssueHistory[i].issued,
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.all(4)),
                                          onChanged: (val) {
                                            _tempIssueHistory[i] = TempIssueHistoryRecord(
                                              sl: _tempIssueHistory[i].sl,
                                              issued: val,
                                              returned: _tempIssueHistory[i].returned,
                                              heldPeriod: _tempIssueHistory[i].heldPeriod,
                                              stationUnitDetails: _tempIssueHistory[i].stationUnitDetails,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(2.0),
                                        child: TextFormField(
                                          initialValue: _tempIssueHistory[i].returned,
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.all(4)),
                                          onChanged: (val) {
                                            _tempIssueHistory[i] = TempIssueHistoryRecord(
                                              sl: _tempIssueHistory[i].sl,
                                              issued: _tempIssueHistory[i].issued,
                                              returned: val,
                                              heldPeriod: _tempIssueHistory[i].heldPeriod,
                                              stationUnitDetails: _tempIssueHistory[i].stationUnitDetails,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(2.0),
                                        child: TextFormField(
                                          initialValue: _tempIssueHistory[i].heldPeriod,
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.all(4)),
                                          onChanged: (val) {
                                            _tempIssueHistory[i] = TempIssueHistoryRecord(
                                              sl: _tempIssueHistory[i].sl,
                                              issued: _tempIssueHistory[i].issued,
                                              returned: _tempIssueHistory[i].returned,
                                              heldPeriod: val,
                                              stationUnitDetails: _tempIssueHistory[i].stationUnitDetails,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(2.0),
                                        child: TextFormField(
                                          initialValue: _tempIssueHistory[i].stationUnitDetails,
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.all(4)),
                                          onChanged: (val) {
                                            _tempIssueHistory[i] = TempIssueHistoryRecord(
                                              sl: _tempIssueHistory[i].sl,
                                              issued: _tempIssueHistory[i].issued,
                                              returned: _tempIssueHistory[i].returned,
                                              heldPeriod: _tempIssueHistory[i].heldPeriod,
                                              stationUnitDetails: val,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _addTempIssueRow,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Temp Issue Row', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(foregroundColor: Colors.amber),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- SECTION 9: LOCKER CONFIGURATION ---
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('9. Locker / Compartment Configuration'),
                        if (_compartments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('No custom lockers configured. Defaulting to L1, L2, R1, R2.', style: TextStyle(color: Colors.white30, fontSize: 13)),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _compartments.length,
                            itemBuilder: (context, idx) {
                              final comp = _compartments[idx];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    // Locker ID Input (e.g. L1)
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        initialValue: comp.id,
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText: 'Locker ID (e.g. L1)',
                                          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(0.02),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        ),
                                        onChanged: (val) {
                                          _compartments[idx] = CompartmentModel(
                                            id: val,
                                            label: comp.label,
                                            side: comp.side,
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    // Locker Side Selection (Left / Right / Rear)
                                    Expanded(
                                      flex: 2,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: comp.side,
                                        dropdownColor: const Color(0xFF1E1E1E),
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(0.02),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                        ),
                                        items: const [
                                          DropdownMenuItem(value: 'left', child: Text('Left', style: TextStyle(fontSize: 12))),
                                          DropdownMenuItem(value: 'right', child: Text('Right', style: TextStyle(fontSize: 12))),
                                          DropdownMenuItem(value: 'rear', child: Text('Rear', style: TextStyle(fontSize: 12))),
                                          DropdownMenuItem(value: 'front', child: Text('Front', style: TextStyle(fontSize: 12))),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _compartments[idx] = CompartmentModel(
                                                id: comp.id,
                                                label: comp.label,
                                                side: val,
                                              );
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _compartments.removeAt(idx);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _addCompartmentRow,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('ADD LOCKER / COMPARTMENT'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.08),
                              foregroundColor: Colors.amber,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- DELETE VEHICLE SECTION ---
                  if (widget.vehicle != null)
                    _buildGlassCard(
                      borderColor: Colors.redAccent.withOpacity(0.3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _confirmDelete,
                                activeColor: Colors.redAccent,
                                onChanged: (val) {
                                  setState(() {
                                    _confirmDelete = val ?? false;
                                  });
                                },
                              ),
                              const Expanded(
                                child: Text(
                                  'Confirm incorrect entry to activate delete icon',
                                  style: TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_forever,
                                  color: _confirmDelete ? Colors.redAccent : Colors.white24,
                                ),
                                onPressed: _confirmDelete ? _deleteVehicle : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // --- BOTTOM UPDATE BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 4,
                      ),
                      child: Text(
                        widget.vehicle != null ? 'UPDATE VEHICLE MASTER' : 'CREATE VEHICLE MASTER',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
