import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fuel_provider.dart';
import '../models/fuel_model.dart';
import '../providers/vehicle_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/manpower_provider.dart';
import '../providers/auth_provider.dart';
import '../services/access_control.dart';

class FuelDialogs {
  static void showAddLedgerDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    String selectedType = 'Fuel';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Add Ledger Head', style: TextStyle(color: Colors.white)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Ledger Name',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE53935)),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  dropdownColor: const Color(0xFF2C2C2C),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Type',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE53935)),
                    ),
                  ),
                  items: ['Fuel', 'Oil']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedType = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB300)), // Yellow button
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final provider = Provider.of<FuelProvider>(context, listen: false);
                  Navigator.pop(context); // Close dialog early for better UX
                  await provider.addLedger(nameController.text.trim(), selectedType);
                }
              },
              child: const Text('Add', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  static void showEditLedgerDialog(BuildContext context, FuelLedger ledger) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: ledger.name);
    String selectedType = ledger.type;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Edit Ledger Head', style: TextStyle(color: Colors.white)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Ledger Name',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE53935)),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  dropdownColor: const Color(0xFF2C2C2C),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Type',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE53935)),
                    ),
                  ),
                  items: ['Fuel', 'Oil']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedType = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB300)),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final provider = Provider.of<FuelProvider>(context, listen: false);
                  Navigator.pop(context);
                  await provider.editLedger(ledger.id, nameController.text.trim(), selectedType);
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  static void showDeleteConfirmDialog(BuildContext context, FuelLedger ledger) {
    final passwordController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Delete Ledger', style: TextStyle(color: Colors.redAccent)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Are you sure you want to delete "${ledger.name}"? All its transactions will also be permanently deleted.', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Enter Password to Confirm',
                  labelStyle: const TextStyle(color: Colors.white70),
                  errorText: errorText,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.redAccent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                if (passwordController.text == 'sreenath') {
                  final provider = Provider.of<FuelProvider>(context, listen: false);
                  Navigator.pop(context);
                  await provider.deleteLedger(ledger.id);
                } else {
                  setState(() {
                    errorText = 'Incorrect password';
                  });
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  static void showAddEntryDialog(BuildContext context, FuelLedger ledger) {
    final formKey = GlobalKey<FormState>();
    final partyController = TextEditingController();
    final partyFocusNode = FocusNode();
    final quantityController = TextEditingController();
    final remarksController = TextEditingController();
    String? selectedType; // Blank by default
    DateTime? selectedDate;

    final isAdminOrSfroM = AccessControl.isAdmin(context) || AccessControl.isSfroM(context);
    final activeDates = AccessControl.getActiveDutyDates();


    final List<String> vehicleNames = Provider.of<VehicleProvider>(context, listen: false).vehicles.map((v) => '${v.type} (${v.regNumber})').toList();
    final List<String> equipmentNames = Provider.of<EquipmentProvider>(context, listen: false).equipments.map((e) => e.name).toList();
    final List<String> suggestions = <String>{...vehicleNames, ...equipmentNames}.toList();

    final manpowerList = Provider.of<ManpowerProvider>(context, listen: false).personnelList;
        final sfroMList = manpowerList.where((p) => p.designation == 'SFRO (M)').toList();
    final operatorController = TextEditingController();
    final operatorFocusNode = FocusNode();
    
    final List<String> operatorNames = manpowerList.map((p) {
      String suffix = p.idNumber;
      if (suffix.isEmpty) return '${p.name} (${p.designation})';
      if (suffix.replaceAll(' ', '').toLowerCase().contains(p.designation.replaceAll(' ', '').toLowerCase())) {
        return '${p.name} ($suffix)';
      }
      return '${p.name} (${p.designation} - $suffix)';
    }).toList();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final linkedPersonId = authProvider.linkedPersonId;
    final loggedInPerson = manpowerList.firstWhere((p) => p.id == linkedPersonId, orElse: () => manpowerList.first);
    
    String loggedInPersonFormatted = '';
    String suffix = loggedInPerson.idNumber;
    if (suffix.isEmpty) {
      loggedInPersonFormatted = '${loggedInPerson.name} (${loggedInPerson.designation})';
    } else if (suffix.replaceAll(' ', '').toLowerCase().contains(loggedInPerson.designation.replaceAll(' ', '').toLowerCase())) {
      loggedInPersonFormatted = '${loggedInPerson.name} ($suffix)';
    } else {
      loggedInPersonFormatted = '${loggedInPerson.name} (${loggedInPerson.designation} - $suffix)';
    }

    operatorController.text = loggedInPersonFormatted;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text('Add Entry - ${ledger.name}', style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Date Picker
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    subtitle: Text(
                      selectedDate == null ? 'Select Date' : '${selectedDate!.day.toString().padLeft(2, '0')}/${selectedDate!.month.toString().padLeft(2, '0')}/${selectedDate!.year}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    trailing: const Icon(Icons.calendar_today, color: Colors.white54),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? AccessControl.getDutyDate(DateTime.now()),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        selectableDayPredicate: (DateTime day) {
                          if (isAdminOrSfroM) return true;
                          bool isDateActive = activeDates.any((d) => d.year == day.year && d.month == day.month && d.day == day.day);
                          if (isDateActive) {
                            return AccessControl.isPresentOnDuty(context, day);
                          }
                          return false;
                        },
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    dropdownColor: const Color(0xFF2C2C2C),
                    style: const TextStyle(color: Colors.white),
                    validator: (val) => val == null ? 'Required' : null,
                    decoration: InputDecoration(
                      labelText: 'Transaction Type',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFE53935)),
                      ),
                    ),
                    items: ['RECEIPT', 'ISSUE']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  RawAutocomplete<String>(
                    textEditingController: partyController,
                    focusNode: partyFocusNode,
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return suggestions.where((String option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: selectedType == 'RECEIPT' ? 'From whom received' : 'To whom issued',
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFE53935)),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      );
                    },
                    optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          color: const Color(0xFF2C2C2C),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 280),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final String option = options.elementAt(index);
                                return InkWell(
                                  onTap: () {
                                    onSelected(option);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(option, style: const TextStyle(color: Colors.white)),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: quantityController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Quantity (L)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFE53935)),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      final qty = double.tryParse(value);
                      if (qty == null) return 'Invalid number';
                      
                      final provider = Provider.of<FuelProvider>(context, listen: false);
                      final latestLedger = provider.ledgers.firstWhere((l) => l.id == ledger.id, orElse: () => ledger);
                      
                      if (selectedType == 'ISSUE' && qty > latestLedger.currentBalance) {
                        return 'Not enough stock (Max: ${latestLedger.currentBalance})';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: remarksController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Remarks (Optional)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFE53935)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: operatorController.text.isNotEmpty && operatorNames.contains(operatorController.text) ? operatorController.text : null,
                    hint: const Text('Select Operator', style: TextStyle(color: Colors.white54)),
                    decoration: InputDecoration(
                      labelText: 'Operator / Issued By',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFE53935)),
                      ),
                    ),
                    dropdownColor: const Color(0xFF2C2C2C),
                    style: const TextStyle(color: Colors.white),
                    isExpanded: true,
                    items: operatorNames.map((String option) {
                      return DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      );
                    }).toList(),
                    onChanged: isAdminOrSfroM ? (String? newValue) {
                      if (newValue != null) {
                        operatorController.text = newValue;
                      }
                    } : null,
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB300)),
              onPressed: () async {
                if (selectedDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a date')));
                  return;
                }
                if (formKey.currentState!.validate()) {
                  final provider = Provider.of<FuelProvider>(context, listen: false);
                  // Ensure previous errors are cleared, although addTransaction overwrites it anyway
                  await provider.addTransaction(
                    ledgerId: ledger.id,
                    date: selectedDate!,
                    party: partyController.text.trim(),
                    type: selectedType!,
                    quantity: double.parse(quantityController.text.trim()),
                    remarks: remarksController.text.trim(),
                    operatorName: operatorController.text.trim(),
                  );
                  if (provider.error != null && provider.error!.contains('negative')) {
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF1E1E1E),
                          title: const Text('Warning', style: TextStyle(color: Colors.redAccent)),
                          content: Text(provider.error!, style: const TextStyle(color: Colors.white)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('OK', style: TextStyle(color: Colors.white)),
                            )
                          ],
                        )
                      );
                    }
                  } else {
                    if (context.mounted) Navigator.pop(context);
                  }
                }
              },
              child: const Text('Add', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  static void showEditTransactionDialog(BuildContext context, FuelTransaction tx, FuelLedger ledger) {
    final isAdminOrSfroM = AccessControl.isAdmin(context) || AccessControl.isSfroM(context);
    final activeDates = AccessControl.getActiveDutyDates();
    final formKey = GlobalKey<FormState>();
    final partyController = TextEditingController(text: tx.party);
    final partyFocusNode = FocusNode();
    final quantityController = TextEditingController(text: tx.quantity.toString());
    final remarksController = TextEditingController(text: tx.remarks);
    String selectedType = tx.type;
    DateTime selectedDate = tx.date;

    final List<String> vehicleNames = Provider.of<VehicleProvider>(context, listen: false).vehicles.map((v) => '${v.type} (${v.regNumber})').toList();
    final List<String> equipmentNames = Provider.of<EquipmentProvider>(context, listen: false).equipments.map((e) => e.name).toList();
    final List<String> suggestions = <String>{...vehicleNames, ...equipmentNames}.toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Edit Entry', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    subtitle: Text(
                      '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    trailing: const Icon(Icons.calendar_today, color: Colors.white54),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        selectableDayPredicate: (DateTime day) {
                          if (isAdminOrSfroM) return true;
                          bool isDateActive = activeDates.any((d) => d.year == day.year && d.month == day.month && d.day == day.day);
                          if (isDateActive) {
                            return AccessControl.isPresentOnDuty(context, day);
                          }
                          return false;
                        },
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    dropdownColor: const Color(0xFF2C2C2C),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Transaction Type',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFE53935)),
                      ),
                    ),
                    items: ['RECEIPT', 'ISSUE']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  RawAutocomplete<String>(
                    textEditingController: partyController,
                    focusNode: partyFocusNode,
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return suggestions.where((String option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: selectedType == 'RECEIPT' ? 'From whom received' : 'To whom issued',
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFE53935)),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      );
                    },
                    optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          color: const Color(0xFF2C2C2C),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 280),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final String option = options.elementAt(index);
                                return InkWell(
                                  onTap: () {
                                    onSelected(option);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(option, style: const TextStyle(color: Colors.white)),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: quantityController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Quantity (L)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFE53935)),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      final qty = double.tryParse(value);
                      if (qty == null) return 'Invalid number';
                      
                      final provider = Provider.of<FuelProvider>(context, listen: false);
                      final latestLedger = provider.ledgers.firstWhere((l) => l.id == ledger.id, orElse: () => ledger);
                      
                      double availableStock = latestLedger.currentBalance;
                      if (tx.type == 'ISSUE') availableStock += tx.quantity;
                      if (tx.type == 'RECEIPT') availableStock -= tx.quantity;
                      
                      if (selectedType == 'ISSUE' && qty > availableStock) {
                        return 'Not enough stock (Max: $availableStock)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: remarksController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Remarks (Optional)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFE53935)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB300)),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final provider = Provider.of<FuelProvider>(context, listen: false);
                  await provider.editTransaction(
                    tx: tx,
                    date: selectedDate,
                    party: partyController.text.trim(),
                    type: selectedType,
                    quantity: double.parse(quantityController.text.trim()),
                    remarks: remarksController.text.trim(),
                  );
                  if (provider.error != null && provider.error!.contains('negative')) {
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF1E1E1E),
                          title: const Text('Warning', style: TextStyle(color: Colors.redAccent)),
                          content: Text(provider.error!, style: const TextStyle(color: Colors.white)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('OK', style: TextStyle(color: Colors.white)),
                            )
                          ],
                        )
                      );
                    }
                  } else {
                    if (context.mounted) Navigator.pop(context);
                  }
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  static void showDeleteTransactionConfirmDialog(BuildContext context, FuelTransaction tx) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Entry', style: TextStyle(color: Colors.redAccent)),
        content: const Text('Are you sure you want to delete this entry? Balances will be recalculated.', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              final provider = Provider.of<FuelProvider>(context, listen: false);
              Navigator.pop(context);
              await provider.deleteTransaction(tx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
