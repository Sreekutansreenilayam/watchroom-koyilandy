import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/vehicle_provider.dart';
import '../providers/manpower_provider.dart';
import '../models/equipment_model.dart';
import '../screens/equipment_pdf_preview_screen.dart';
import '../screens/equipment_detail_screen.dart';

class EquipmentDialogs {
  static void showAddEquipmentHeadDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    String selectedCategory = 'Others (മറ്റുള്ളവ)';
    final categories = [
      'Personal Protective Eqpt (വ്യക്തിഗത സുരക്ഷാ ഉപകരണങ്ങൾ)',
      'Hydraulic Tools (ഹൈഡ്രോളിക് ഉപകരണങ്ങൾ)',
      'Fire Suppression (അഗ്നിശമന ഉപകരണങ്ങൾ)',
      'Vehicle Tools (വാഹന ഉപകരണങ്ങൾ)',
      'Others (മറ്റുള്ളവ)'
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Add Equipment Category', style: TextStyle(color: Colors.white)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Equipment Name',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  dropdownColor: const Color(0xFF2C2C2C),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                  isExpanded: true,
                  items: categories
                      .map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedCategory = val);
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final provider = Provider.of<EquipmentProvider>(context, listen: false);
                  try {
                    final newId = await provider.addEquipmentHead(nameController.text.trim(), selectedCategory);
                    final newHead = EquipmentHead(
                      id: newId,
                      name: nameController.text.trim(),
                      category: selectedCategory,
                      totalQty: 0,
                      serviceableQty: 0,
                      unserviceableQty: 0,
                    );

                    if (context.mounted) {
                      Navigator.pop(context); // Close the Add Equipment dialog
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EquipmentDetailScreen(head: newHead),
                        ),
                      );
                      EquipmentDialogs.showAddStockEntryDialog(context, newHead);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
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

  static void showEditEquipmentHeadDialog(BuildContext context, EquipmentHead head) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: head.name);
    String selectedCategory = head.category;
    final categories = [
      'Personal Protective Eqpt (വ്യക്തിഗത സുരക്ഷാ ഉപകരണങ്ങൾ)',
      'Hydraulic Tools (ഹൈഡ്രോളിക് ഉപകരണങ്ങൾ)',
      'Fire Suppression (അഗ്നിശമന ഉപകരണങ്ങൾ)',
      'Vehicle Tools (വാഹന ഉപകരണങ്ങൾ)',
      'Others (മറ്റുള്ളവ)'
    ];
    if (!categories.contains(selectedCategory)) {
      categories.add(selectedCategory);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Edit Equipment Category', style: TextStyle(color: Colors.white)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Equipment Name',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  dropdownColor: const Color(0xFF2C2C2C),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                  isExpanded: true,
                  items: categories
                      .map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedCategory = val);
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final provider = Provider.of<EquipmentProvider>(context, listen: false);
                  Navigator.pop(context);
                  try {
                    await provider.updateEquipmentHead(head.id, nameController.text.trim(), selectedCategory);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
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

  static void showAddStockEntryDialog(BuildContext context, EquipmentHead head) {
    final formKey = GlobalKey<FormState>();
    final quantityController = TextEditingController();
    final brandController = TextEditingController();
    final serialController = TextEditingController();
    final assignedToController = TextEditingController();
    final lockerController = TextEditingController();
    final invoiceController = TextEditingController();

    DateTime selectedDate = DateTime.now();
    DateTime? warrantyDate;
    DateTime? lastServiceDate;
    DateTime? nextServiceDate;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (stateContext, setState) {
          final vehicles = Provider.of<VehicleProvider>(stateContext).vehicles.map((v) => v.regNumber).toList();
          final personnel = Provider.of<ManpowerProvider>(stateContext).activePersonnelList.map((p) => p.name).toList();
          final List<String> assignableOptions = [...vehicles, ...personnel];

          final bool isVehicleAssigned = vehicles.contains(assignedToController.text);

          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: Text('Add Stock - ${head.name}', style: const TextStyle(color: Colors.white)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDatePickerListTile(context, 'Date Taken Into Charge', selectedDate, (d) { if (d != null) setState(() => selectedDate = d); }),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: quantityController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('Quantity'),
                        validator: (value) => value == null || value.isEmpty || int.tryParse(value) == null ? 'Invalid' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: brandController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Brand/Make'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: serialController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Serial Numbers (comma separated)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: invoiceController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Invoice/Voucher/Letter No'),
                      ),
                      const SizedBox(height: 12),
                      
                      // Autocomplete for Assigned To
                      Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '') {
                            return const Iterable<String>.empty();
                          }
                          return assignableOptions.where((String option) {
                            return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        onSelected: (String selection) {
                          assignedToController.text = selection;
                          setState(() {}); // trigger rebuild for locker field
                        },
                        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                          // Sync controller
                          controller.addListener(() {
                            if (assignedToController.text != controller.text) {
                              assignedToController.text = controller.text;
                              setState(() {});
                            }
                          });
                          
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Assigned To (Vehicle/Person)'),
                            onEditingComplete: onEditingComplete,
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              color: const Color(0xFF2C2C2C),
                              elevation: 4.0,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 200, maxWidth: 250),
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
                      
                      if (isVehicleAssigned) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: lockerController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Locker Number'),
                        ),
                      ],

                      const SizedBox(height: 16),
                      const Text('Dates (Optional)', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      _buildDatePickerListTile(context, 'Warranty Expiry', warrantyDate, (d) => setState(() => warrantyDate = d)),
                      _buildDatePickerListTile(context, 'Last Service', lastServiceDate, (d) => setState(() => lastServiceDate = d)),
                      _buildDatePickerListTile(context, 'Next Service', nextServiceDate, (d) => setState(() => nextServiceDate = d)),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(stateContext),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final provider = Provider.of<EquipmentProvider>(stateContext, listen: false);
                    Navigator.pop(stateContext);
                    try {
                      await provider.addStockEntry(
                        headId: head.id,
                        dateTakenIntoCharge: selectedDate,
                        quantity: int.parse(quantityController.text.trim()),
                        brand: brandController.text.trim(),
                        serialNumbers: serialController.text.trim(),
                        warrantyExpiry: warrantyDate,
                        lastServiceDate: lastServiceDate,
                        nextServiceDate: nextServiceDate,
                        assignedTo: assignedToController.text.trim(),
                        lockerNumber: isVehicleAssigned ? lockerController.text.trim() : null,
                        invoiceNo: invoiceController.text.trim(),
                      );
                      if (provider.error != null && stateContext.mounted) {
                        ScaffoldMessenger.of(stateContext).showSnackBar(SnackBar(content: Text(provider.error!)));
                      }
                    } catch (e) {
                      if (stateContext.mounted) {
                        ScaffoldMessenger.of(stateContext).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  }
                },
                child: const Text('Add Stock', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  static void showAddHistoryDialog(BuildContext context, EquipmentHead head) {
    final formKey = GlobalKey<FormState>();
    final quantityController = TextEditingController();
    final voucherController = TextEditingController();
    final remarksController = TextEditingController();

    String selectedType = 'STATUS_CHANGE';
    String selectedStatus = 'UNSERVICEABLE';
    DateTime fromDate = DateTime.now();
    DateTime? toDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Add Log / Status Change', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      dropdownColor: const Color(0xFF2C2C2C),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Log Type'),
                      items: const [
                        DropdownMenuItem(value: 'STATUS_CHANGE', child: Text('Status Change')),
                        DropdownMenuItem(value: 'TEMP_ISSUE', child: Text('Temporary Issue')),
                        DropdownMenuItem(value: 'RETURN_TEMP_ISSUE', child: Text('Return Temp Issue')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    if (selectedType == 'STATUS_CHANGE') ...[
                      DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
                        dropdownColor: const Color(0xFF2C2C2C),
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('New Status'),
                        items: const [
                          DropdownMenuItem(value: 'UNSERVICEABLE', child: Text('Unserviceable (Off Road)')),
                          DropdownMenuItem(value: 'SERVICEABLE', child: Text('Serviceable (On Road / Repaired)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => selectedStatus = val);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextFormField(
                      controller: quantityController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Quantity Affected'),
                      validator: (value) => value == null || value.isEmpty || int.tryParse(value) == null ? 'Invalid' : null,
                    ),
                    const SizedBox(height: 12),
                    
                    _buildDatePickerListTile(context, 'From Date', fromDate, (d) => setState(() => fromDate = d!)),
                    
                    if (selectedType == 'TEMP_ISSUE' || selectedType == 'RETURN_TEMP_ISSUE') ...[
                      if (selectedType == 'TEMP_ISSUE')
                        _buildDatePickerListTile(context, 'Expected Return Date', toDate, (d) => setState(() => toDate = d)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: voucherController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Voucher Number'),
                      ),
                    ],

                    const SizedBox(height: 12),
                    TextFormField(
                      controller: remarksController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Remarks'),
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final provider = Provider.of<EquipmentProvider>(context, listen: false);
                    Navigator.pop(context);
                    try {
                      await provider.addHistoryEntry(
                        headId: head.id,
                        type: selectedType,
                        status: selectedType == 'STATUS_CHANGE' ? selectedStatus : '',
                        quantityAffected: int.parse(quantityController.text.trim()),
                        fromDate: fromDate,
                        toDate: toDate,
                        voucherNumber: voucherController.text.trim(),
                        remarks: remarksController.text.trim(),
                      );
                      if (provider.error != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.error!)));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  }
                },
                child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  static InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.orange),
      ),
    );
  }

  static Widget _buildDatePickerListTile(BuildContext context, String title, DateTime? date, Function(DateTime?) onPicked) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      subtitle: Text(
        date != null ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}' : 'Not set',
        style: TextStyle(color: date != null ? Colors.white : Colors.white38, fontSize: 16),
      ),
      trailing: const Icon(Icons.calendar_today, color: Colors.white54),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onPicked(picked);
        }
      },
    );
  }

  static void showEditStockEntryDialog(BuildContext context, EquipmentStockEntry entry) {
    final formKey = GlobalKey<FormState>();
    final quantityController = TextEditingController(text: entry.quantity.toString());
    final brandController = TextEditingController(text: entry.brand);
    final serialController = TextEditingController(text: entry.serialNumbers);
    final assignedToController = TextEditingController(text: entry.assignedTo);
    final lockerController = TextEditingController(text: entry.lockerNumber ?? '');
    final invoiceController = TextEditingController(text: entry.invoiceNo);

    DateTime selectedDate = entry.dateTakenIntoCharge;
    DateTime? warrantyDate = entry.warrantyExpiry;
    DateTime? lastServiceDate = entry.lastServiceDate;
    DateTime? nextServiceDate = entry.nextServiceDate;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (stateContext, setState) {
          final vehicles = Provider.of<VehicleProvider>(stateContext).vehicles.map((v) => v.regNumber).toList();
          final personnel = Provider.of<ManpowerProvider>(stateContext).activePersonnelList.map((p) => p.name).toList();
          final List<String> assignableOptions = [...vehicles, ...personnel];

          final bool isVehicleAssigned = vehicles.contains(assignedToController.text);
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Edit Stock Entry', style: TextStyle(color: Colors.white)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDatePickerListTile(context, 'Date Taken Into Charge', selectedDate, (d) { if (d != null) setState(() => selectedDate = d); }),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: quantityController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('Quantity'),
                        validator: (value) => value == null || value.isEmpty || int.tryParse(value) == null ? 'Invalid' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: brandController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Brand/Make'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: serialController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Serial Numbers (comma separated)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: invoiceController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Invoice/Voucher/Letter No'),
                      ),
                      const SizedBox(height: 12),
                      Autocomplete<String>(
                        initialValue: TextEditingValue(text: entry.assignedTo),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '') return const Iterable<String>.empty();
                          return assignableOptions.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                        },
                        onSelected: (String selection) {
                          assignedToController.text = selection;
                          setState(() {});
                        },
                        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                          controller.addListener(() {
                            if (assignedToController.text != controller.text) {
                              assignedToController.text = controller.text;
                              setState(() {});
                            }
                          });
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Assigned To (Vehicle/Person)'),
                            onEditingComplete: onEditingComplete,
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              color: const Color(0xFF2C2C2C),
                              elevation: 4.0,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 200, maxWidth: 250),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final option = options.elementAt(index);
                                    return InkWell(
                                      onTap: () => onSelected(option),
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
                      if (isVehicleAssigned) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: lockerController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Locker Number'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text('Dates (Optional)', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      _buildDatePickerListTile(context, 'Warranty Expiry', warrantyDate, (d) => setState(() => warrantyDate = d)),
                      _buildDatePickerListTile(context, 'Last Service', lastServiceDate, (d) => setState(() => lastServiceDate = d)),
                      _buildDatePickerListTile(context, 'Next Service', nextServiceDate, (d) => setState(() => nextServiceDate = d)),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final provider = Provider.of<EquipmentProvider>(context, listen: false);
                    Navigator.pop(context);
                    
                    final updatedEntry = EquipmentStockEntry(
                      id: entry.id,
                      headId: entry.headId,
                      dateTakenIntoCharge: selectedDate,
                      quantity: int.parse(quantityController.text.trim()),
                      brand: brandController.text.trim(),
                      serialNumbers: serialController.text.trim(),
                      warrantyExpiry: warrantyDate,
                      lastServiceDate: lastServiceDate,
                      nextServiceDate: nextServiceDate,
                      assignedTo: assignedToController.text.trim(),
                      lockerNumber: isVehicleAssigned ? lockerController.text.trim() : null,
                    );
                    
                    try {
                      await provider.updateStockEntry(entry, updatedEntry);
                    } catch (e) {
                      if (stateContext.mounted) ScaffoldMessenger.of(stateContext).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  static void showEditHistoryDialog(BuildContext context, EquipmentHistory log) {
    final formKey = GlobalKey<FormState>();
    final quantityController = TextEditingController(text: log.quantityAffected.toString());
    final voucherController = TextEditingController(text: log.voucherNumber ?? '');
    final remarksController = TextEditingController(text: log.remarks);

    DateTime fromDate = log.fromDate;
    DateTime? toDate = log.toDate;
    
    String selectedType = log.type;
    String selectedStatus = log.status;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Edit Log / Status', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      dropdownColor: const Color(0xFF2C2C2C),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Log Type'),
                      items: const [
                        DropdownMenuItem(value: 'STATUS_CHANGE', child: Text('Status Change')),
                        DropdownMenuItem(value: 'TEMP_ISSUE', child: Text('Temporary Issue')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => selectedType = val);
                      },
                    ),
                    if (selectedType == 'STATUS_CHANGE') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
                        dropdownColor: const Color(0xFF2C2C2C),
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Status'),
                        items: const [
                          DropdownMenuItem(value: 'UNSERVICEABLE', child: Text('Unserviceable / Off Road', style: TextStyle(color: Colors.redAccent))),
                          DropdownMenuItem(value: 'SERVICEABLE', child: Text('Serviceable / On Road', style: TextStyle(color: Colors.greenAccent))),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => selectedStatus = val);
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: quantityController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Quantity Affected'),
                      validator: (value) => value == null || value.isEmpty || int.tryParse(value) == null ? 'Invalid' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildDatePickerListTile(context, 'From Date', fromDate, (d) => setState(() => fromDate = d!)),
                    if (selectedType == 'TEMP_ISSUE') ...[
                      _buildDatePickerListTile(context, 'Expected Return Date', toDate, (d) => setState(() => toDate = d)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: voucherController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Voucher Number'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: remarksController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Remarks'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final provider = Provider.of<EquipmentProvider>(context, listen: false);
                    Navigator.pop(context);
                    
                    final updatedLog = EquipmentHistory(
                      id: log.id,
                      headId: log.headId,
                      type: selectedType,
                      status: selectedStatus,
                      quantityAffected: int.parse(quantityController.text.trim()),
                      fromDate: fromDate,
                      toDate: selectedType == 'TEMP_ISSUE' ? toDate : null,
                      voucherNumber: selectedType == 'TEMP_ISSUE' ? voucherController.text.trim() : null,
                      remarks: remarksController.text.trim(),
                    );
                    
                    try {
                      await provider.updateHistoryEntry(log, updatedLog);
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
  static void showEquipmentReportFilterDialog(BuildContext context) {
    bool isInitialized = false;
    List<String> selectedCategories = [];
    bool includeDetails = false;
    bool showCategoryColumn = true;
    bool groupByCategory = false;

    final provider = Provider.of<EquipmentProvider>(context, listen: false);
    final equipments = provider.equipments;

    List<String> getCategories() {
      final cats = equipments.map((e) => e.category).toSet().toList();
      cats.sort();
      return cats;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final allCategories = getCategories();
          
          if (!isInitialized) {
            selectedCategories = List.from(allCategories);
            isInitialized = true;
          }
          
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Generate Equipment Report', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: showCategoryColumn,
                            activeColor: Colors.orange,
                            checkColor: Colors.black,
                            onChanged: (val) {
                              if (val != null) setState(() => showCategoryColumn = val);
                            },
                          ),
                          const Text('Categories:', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (selectedCategories.length == allCategories.length) {
                              selectedCategories.clear();
                            } else {
                              selectedCategories = List.from(allCategories);
                            }
                          });
                        },
                        child: Text(selectedCategories.length == allCategories.length ? 'Deselect All' : 'Select All', style: const TextStyle(fontSize: 12)),
                      )
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 0,
                    children: allCategories.map((c) => FilterChip(
                      label: Text(c.split(' (')[0], style: const TextStyle(fontSize: 12)),
                      selected: selectedCategories.contains(c),
                      selectedColor: Colors.orange.withOpacity(0.3),
                      checkmarkColor: Colors.orange,
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            selectedCategories.add(c);
                          } else {
                            selectedCategories.remove(c);
                          }
                        });
                      },
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Include Detailed Stock / History', style: TextStyle(color: Colors.white)),
                    activeColor: Colors.orange,
                    checkColor: Colors.black,
                    value: includeDetails,
                    onChanged: (val) {
                      if (val != null) setState(() => includeDetails = val);
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    title: const Text('Show category wise in different tables', style: TextStyle(color: Colors.white)),
                    activeColor: Colors.orange,
                    checkColor: Colors.black,
                    value: groupByCategory,
                    onChanged: (val) {
                      if (val != null) setState(() => groupByCategory = val);
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                onPressed: () {
                  if (selectedCategories.isEmpty) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one category.')));
                     return;
                  }
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => EquipmentPdfPreviewScreen(
                      categories: selectedCategories,
                      includeDetails: includeDetails,
                      showCategoryColumn: showCategoryColumn,
                      groupByCategory: groupByCategory,
                    ),
                  ));
                },
                child: const Text('Generate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}
