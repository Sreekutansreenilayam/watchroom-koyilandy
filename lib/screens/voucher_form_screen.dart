import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/voucher_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/vehicle_provider.dart';
import '../providers/manpower_provider.dart';
import '../models/voucher_model.dart';
import '../models/manpower_model.dart';

class VoucherFormScreen extends StatefulWidget {
  final VoucherModel? voucher;
  final String initialType;

  const VoucherFormScreen({super.key, this.voucher, this.initialType = 'Temporary'});

  @override
  State<VoucherFormScreen> createState() => _VoucherFormScreenState();
}

class _VoucherFormScreenState extends State<VoucherFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _type;

  List<VoucherItem> _items = [];

  // Issued By
  late String _issuedByIdNo;
  late String _issuedByDesig;
  late TextEditingController _issuedByNameCtrl;
  late String _issuedByStation;
  late String _issuedByMobile;

  // Received By (Optional, minimized by default)
  late TextEditingController _receivedByIdCtrl;
  late TextEditingController _receivedByDesigCtrl;
  late TextEditingController _receivedByNameCtrl;
  late TextEditingController _receivedByStationCtrl;
  late TextEditingController _receivedByMobileCtrl;
  DateTime? _receivedByDate;

  @override
  void initState() {
    super.initState();
    final v = widget.voucher;

    _type = v?.type ?? widget.initialType;

    if (v != null && v.items.isNotEmpty) {
      _items = List.from(v.items);
    } else {
      _items = [VoucherItem(au: 'Nos')];
    }

    _issuedByIdNo = v?.issuedByIdNo ?? '';
    _issuedByDesig = v?.issuedByDesignation ?? '';
    _issuedByNameCtrl = TextEditingController(text: v?.issuedByName ?? '');
    _issuedByStation = v?.issuedByStation ?? 'Fire & Rescue Station, Meenchanda';
    _issuedByMobile = v?.issuedByMobile ?? '';

    _receivedByIdCtrl = TextEditingController(text: v?.receivedByIdNo ?? '');
    _receivedByDesigCtrl = TextEditingController(text: v?.receivedByDesignation ?? '');
    _receivedByNameCtrl = TextEditingController(text: v?.receivedByName ?? '');
    _receivedByStationCtrl = TextEditingController(text: v?.receivedByStation ?? '');
    _receivedByMobileCtrl = TextEditingController(text: v?.receivedByMobile ?? '');
    _receivedByDate = v?.receivedByDate;
  }

  @override
  void dispose() {
    _issuedByNameCtrl.dispose();
    _receivedByIdCtrl.dispose();
    _receivedByDesigCtrl.dispose();
    _receivedByNameCtrl.dispose();
    _receivedByStationCtrl.dispose();
    _receivedByMobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, DateTime? initialDate, ValueChanged<DateTime?> onSelected) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final provider = Provider.of<VoucherProvider>(context, listen: false);

      String finalIvNo = widget.voucher?.ivNo ?? '';
      DateTime? finalIssueDate = widget.voucher?.issueDate ?? DateTime.now();
      String finalIssueStation = widget.voucher?.issueStation ?? 'Fire & Rescue Station, Meenchanda';

      // Auto-detect category based on selected items
      String detectedCategory = 'Misc';
      bool hasVehicle = false;
      bool hasEquipment = false;

      final ep = Provider.of<EquipmentProvider>(context, listen: false);
      final vp = Provider.of<VehicleProvider>(context, listen: false);

      final equipmentNames = ep.equipments.map((e) => e.name).toList();
      final vehicleNames = vp.vehicles.map((v) => '${v.type} - ${v.regNumber}').toList();

      for (var item in _items) {
        if (vehicleNames.contains(item.description)) hasVehicle = true;
        if (equipmentNames.contains(item.description)) hasEquipment = true;
      }

      if (hasVehicle && !hasEquipment) {
        detectedCategory = 'Vehicle';
      } else if (hasEquipment && !hasVehicle) {
        detectedCategory = 'Equipment';
      } else {
        detectedCategory = 'Misc';
      }

      if (finalIvNo.isEmpty) {
        finalIvNo = await provider.generateIvNo(detectedCategory, _type);
      }

      final voucher = VoucherModel(
        id: widget.voucher?.id ?? '',
        type: _type,
        category: detectedCategory,
        ivNo: finalIvNo,
        issueDate: finalIssueDate,
        issueStation: finalIssueStation,
        rvNo: '', // Intentionally blank
        receiptDate: null, // Intentionally blank
        receiptStation: '', // Intentionally blank
        items: _items,
        issuedByIdNo: _issuedByIdNo,
        issuedByDesignation: _issuedByDesig,
        issuedByName: _issuedByNameCtrl.text.trim(),
        issuedByStation: _issuedByStation,
        issuedByMobile: _issuedByMobile,
        issuedByDate: finalIssueDate, // Same as issueDate
        receivedByIdNo: _receivedByIdCtrl.text.trim(),
        receivedByDesignation: _receivedByDesigCtrl.text.trim(),
        receivedByName: _receivedByNameCtrl.text.trim(),
        receivedByStation: _receivedByStationCtrl.text.trim(),
        receivedByMobile: _receivedByMobileCtrl.text.trim(),
        receivedByDate: _receivedByDate,
      );

      if (widget.voucher == null) {
        await provider.addVoucher(voucher);
      } else {
        await provider.updateVoucher(voucher);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voucher saved successfully')));
      }
    }
  }

  List<String> _getLedgerItems(BuildContext context) {
    final ep = Provider.of<EquipmentProvider>(context, listen: false);
    final vp = Provider.of<VehicleProvider>(context, listen: false);
    final equipmentNames = ep.equipments.map((e) => e.name).toList();
    final vehicleNames = vp.vehicles.map((v) => '${v.type} - ${v.regNumber}').toList();
    return [...equipmentNames, ...vehicleNames];
  }

  @override
  Widget build(BuildContext context) {
    final ledgerItems = _getLedgerItems(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.voucher == null ? 'New Voucher' : 'Edit Voucher'),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionCard(
              title: 'Voucher Info',
              children: [
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(labelText: 'Voucher Type'),
                  items: ['Temporary', 'Permanent'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _type = newValue!;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Items',
              children: [
                ..._items.asMap().entries.map((entry) {
                  int idx = entry.key;
                  VoucherItem item = entry.value;
                  return Card(
                    color: Colors.white12,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Item ${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _items.removeAt(idx);
                                  });
                                },
                              )
                            ],
                          ),
                          Autocomplete<String>(
                            initialValue: TextEditingValue(text: item.description),
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return const Iterable<String>.empty();
                              }
                              return ledgerItems.where((String option) {
                                return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                              });
                            },
                            onSelected: (String selection) {
                              _items[idx] = VoucherItem(
                                description: selection, ledgerPageNo: item.ledgerPageNo, au: item.au, qty: item.qty, remarks: item.remarks
                              );
                            },
                            fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                              // Sync controller with current item description if it was updated outside autocomplete
                              if (controller.text != item.description && !focusNode.hasFocus) {
                                controller.text = item.description;
                              }
                              return TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                onEditingComplete: onEditingComplete,
                                decoration: const InputDecoration(labelText: 'Nomenclature / Description'),
                                onChanged: (val) {
                                  _items[idx] = VoucherItem(
                                    description: val, ledgerPageNo: item.ledgerPageNo, au: item.au, qty: item.qty, remarks: item.remarks
                                  );
                                },
                              );
                            },
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: item.ledgerPageNo,
                                  decoration: const InputDecoration(labelText: 'Ledger Page No'),
                                  onChanged: (val) => _items[idx] = VoucherItem(
                                    description: item.description, ledgerPageNo: val, au: item.au, qty: item.qty, remarks: item.remarks
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue: item.au,
                                  decoration: const InputDecoration(labelText: 'A/U'),
                                  onChanged: (val) => _items[idx] = VoucherItem(
                                    description: item.description, ledgerPageNo: item.ledgerPageNo, au: val, qty: item.qty, remarks: item.remarks
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue: item.qty.toString(),
                                  decoration: const InputDecoration(labelText: 'Qty'),
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) => _items[idx] = VoucherItem(
                                    description: item.description, ledgerPageNo: item.ledgerPageNo, au: item.au, qty: int.tryParse(val) ?? 1, remarks: item.remarks
                                  ),
                                ),
                              ),
                            ],
                          ),
                          TextFormField(
                            initialValue: item.remarks,
                            decoration: const InputDecoration(labelText: 'Remarks'),
                            onChanged: (val) => _items[idx] = VoucherItem(
                              description: item.description, ledgerPageNo: item.ledgerPageNo, au: item.au, qty: item.qty, remarks: val
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                  onPressed: () {
                    setState(() {
                      _items.add(VoucherItem(au: 'Nos'));
                    });
                  },
                )
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Issued By',
              children: [
                Consumer<ManpowerProvider>(
                  builder: (context, mp, child) {
                    final names = mp.personnelList.map((m) => m.name).toList();
                    return Autocomplete<String>(
                      initialValue: TextEditingValue(text: _issuedByNameCtrl.text),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<String>.empty();
                        }
                        return names.where((String option) {
                          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (String selection) {
                        _issuedByNameCtrl.text = selection;
                        final person = mp.personnelList.firstWhere((m) => m.name == selection);
                        setState(() {
                          _issuedByIdNo = person.idNumber;
                          _issuedByDesig = person.designation;
                          _issuedByStation = person.currentStation.isNotEmpty ? person.currentStation : 'Fire & Rescue Station, Meenchanda';
                          _issuedByMobile = person.mobileNumber;
                        });
                      },
                      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          onEditingComplete: onEditingComplete,
                          decoration: const InputDecoration(labelText: 'Name (Search Personnel)'),
                          onChanged: (val) {
                            _issuedByNameCtrl.text = val;
                          },
                        );
                      },
                    );
                  }
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                title: const Text('Received By (Optional)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
                childrenPadding: const EdgeInsets.all(16),
                children: [
                  const Text('Leave blank for receiver to fill manually after printout.', style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 8),
                  TextFormField(controller: _receivedByIdCtrl, decoration: const InputDecoration(labelText: 'ID No')),
                  TextFormField(controller: _receivedByDesigCtrl, decoration: const InputDecoration(labelText: 'Designation')),
                  TextFormField(controller: _receivedByNameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                  TextFormField(controller: _receivedByStationCtrl, decoration: const InputDecoration(labelText: 'Station Name')),
                  TextFormField(controller: _receivedByMobileCtrl, decoration: const InputDecoration(labelText: 'Mobile No')),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_receivedByDate == null ? 'Select Date' : 'Date: ${DateFormat('dd/MM/yyyy').format(_receivedByDate!)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _selectDate(context, _receivedByDate, (d) => setState(() => _receivedByDate = d)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.all(16)),
              onPressed: _save,
              child: const Text('Save Voucher', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
            const Divider(color: Colors.white24),
            ...children,
          ],
        ),
      ),
    );
  }
}
