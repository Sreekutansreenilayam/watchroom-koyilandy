import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/manpower_model.dart';
import '../providers/manpower_provider.dart';
import '../providers/attendance_provider.dart';
import '../services/access_control.dart';
import 'attendance_screen.dart';
import '../config/app_config.dart';

class ManpowerScreen extends StatefulWidget {
  const ManpowerScreen({super.key});

  @override
  State<ManpowerScreen> createState() => _ManpowerScreenState();
}

class _ManpowerScreenState extends State<ManpowerScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _idNumberController = TextEditingController();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _currentStationController = TextEditingController(text: AppConfig.stationNameShort);

  String? _selectedDesignation;
  String _selectedGender = 'Male';
  DateTime? _stationInDate;
  DateTime? _stationOutDate;
  bool _isDriver = false;
  bool _isTempAttachedForTraining = false;

  final List<String> _designations = [
    'STO', 'ASTO',
    'SFRO', 'SFRO (M)', 'FRO', 'FRO (D)',
    'KHG', 'Trainees'
  ];

  @override
  void dispose() {
    _idNumberController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _currentStationController.dispose();
    super.dispose();
  }

  void _promptMigrationAndSave(
    BuildContext context,
    String oldId,
    String newId,
    Manpower manpower,
    ManpowerProvider provider
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('ID Number Changed', style: TextStyle(color: Colors.orangeAccent)),
          content: Text(
            'You have changed the ID Number from "$oldId" to "$newId".\n\n'
            'Do you also want to update all past records (Duty Registers, Logbooks, etc.) with this new ID?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
                provider.updateManpower(manpower); // Just update manpower
                Navigator.pop(context); // Close bottom sheet
              },
              child: const Text('No, just save profile', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx); // Close dialog
                await _runIndividualMigration(context, oldId, newId, manpower, provider);
              },
              child: const Text('Yes, Update All Records'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runIndividualMigration(
    BuildContext context,
    String oldId,
    String newId,
    Manpower manpower,
    ManpowerProvider provider
  ) async {
    showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()), barrierDismissible: false);

    int totalUpdates = 0;

    Future<void> processCollection(String collectionName) async {
      try {
        final snap = await FirebaseFirestore.instance.collection(collectionName).get();
        for (var doc in snap.docs) {
          final originalData = doc.data();
          bool changed = false;

          dynamic replaceRecursively(dynamic obj) {
            if (obj is String) {
              String result = obj;
              final regex = RegExp(r'\b' + oldId + r'\b');
              if (regex.hasMatch(result)) {
                result = result.replaceAll(regex, newId);
                changed = true;
              }
              return result;
            } else if (obj is List) {
              return obj.map((e) => replaceRecursively(e)).toList();
            } else if (obj is Map<String, dynamic>) {
              final newMap = <String, dynamic>{};
              obj.forEach((key, value) {
                newMap[key] = replaceRecursively(value);
              });
              return newMap;
            }
            return obj;
          }

          final newData = replaceRecursively(originalData);
          if (changed) {
            await doc.reference.update(newData);
            totalUpdates++;
          }
        }
      } catch (e) {
        debugPrint("Error migrating $collectionName: $e");
      }
    }

    try {
      await processCollection('duty_registers');
      await processCollection('sentry_registers');
      await processCollection('attendance');
      await processCollection('logbooks');
      await processCollection('fire_reports');
      await processCollection('incident_reports');

      // Update the manpower profile itself
      await provider.updateManpower(manpower);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.pop(context); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile and $totalUpdates past records updated successfully.')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Migration failed: $e')));
      }
    }
  }

  void _showFormDialog(BuildContext context, [Manpower? existingManpower]) async {
    await context.read<AttendanceProvider>().loadAttendanceForMonth(AccessControl.getActiveDutyDate());
    if (!context.mounted) return;

    if (!AccessControl.isOnDuty(context)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are not on duty this time. You may ask ${AccessControl.getOnDutySfroNames(context)} for the same.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (existingManpower != null) {
      _idNumberController.text = existingManpower.idNumber;
      _nameController.text = existingManpower.name;
      _mobileController.text = existingManpower.mobileNumber;
      _currentStationController.text = existingManpower.currentStation;
      _selectedDesignation = existingManpower.designation;
      _selectedGender = existingManpower.gender;
      _stationInDate = existingManpower.stationIn;
      _stationOutDate = existingManpower.stationOut;
      _isDriver = existingManpower.isDriver;
      _isTempAttachedForTraining = existingManpower.isTempAttachedForTraining;
    } else {
      _idNumberController.clear();
      _nameController.clear();
      _mobileController.clear();
      _currentStationController.text = AppConfig.stationNameShort;
      _selectedDesignation = null;
      _selectedGender = 'Male';
      _stationInDate = null;
      _stationOutDate = null;
      _isDriver = false;
      _isTempAttachedForTraining = false;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildGlassForm(context, existingManpower),
    );
  }

  void _showDeleteDialog(BuildContext context, ManpowerProvider provider, Manpower person) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Remove Personnel', style: TextStyle(color: Colors.white)),
          content: const Text('Why are you removing this personnel?', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _promptForDate(context, provider, person, 'Transfer');
              },
              child: const Text('Transfer', style: TextStyle(color: Colors.blueAccent)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _promptForDate(context, provider, person, 'Pension');
              },
              child: const Text('Pension', style: TextStyle(color: Colors.blueAccent)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmWrongEntry(context, provider, person);
              },
              child: const Text('Wrong Entry', style: TextStyle(color: Colors.redAccent)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );
  }

  void _promptForDate(BuildContext context, ManpowerProvider provider, Manpower person, String reason) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selectedDate != null) {
      provider.archiveManpower(person.id, reason, selectedDate);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Station Out date is mandatory for removal (ഒഴിവാക്കാൻ Station Out തീയതി നിർബന്ധമാണ്).', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _confirmWrongEntry(BuildContext context, ManpowerProvider provider, Manpower person) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Permanent Delete', style: TextStyle(color: Colors.redAccent)),
          content: const Text('Are you sure you want to permanently delete this record? This action cannot be undone.', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                provider.deleteManpower(person.id);
                Navigator.pop(context);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlassForm(BuildContext context, Manpower? existingManpower) {
    final bool isEditing = existingManpower != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: 24 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E).withOpacity(0.85),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Edit Personnel' : 'Add New Personnel',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ID Number & Mobile Number
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _idNumberController,
                            label: 'ID Number',
                            icon: Icons.badge,
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _mobileController,
                            label: 'Mobile',
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Name
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Current Station
                    _buildTextField(
                      controller: _currentStationController,
                      label: 'Current Station Posted',
                      icon: Icons.location_city,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Designation Dropdown
                    StatefulBuilder(
                      builder: (context, setStateSB) {
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedDesignation,
                          decoration: InputDecoration(
                            labelText: 'Designation',
                            labelStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(Icons.work, color: Colors.blueAccent),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          dropdownColor: const Color(0xFF1E1E1E),
                          items: _designations.map((String desig) {
                            return DropdownMenuItem(value: desig, child: Text(desig, style: const TextStyle(color: Colors.white)));
                          }).toList(),
                          onChanged: (val) {
                            setStateSB(() {
                              _selectedDesignation = val;
                            });
                          },
                          validator: (v) => v == null ? 'Required' : null,
                        );
                      }
                    ),
                    const SizedBox(height: 16),

                    // Gender Dropdown
                    StatefulBuilder(
                      builder: (context, setStateSB) {
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedGender,
                          decoration: InputDecoration(
                            labelText: 'Gender',
                            labelStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: Icon(_selectedGender == 'Male' ? Icons.male : Icons.female, color: Colors.blueAccent),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          dropdownColor: const Color(0xFF1E1E1E),
                          items: const [
                            DropdownMenuItem(value: 'Male', child: Text('Male', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'Female', child: Text('Female', style: TextStyle(color: Colors.white))),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setStateSB(() => _selectedGender = val);
                            }
                          },
                        );
                      }
                    ),
                    const SizedBox(height: 16),

                    // Station In / Out
                    StatefulBuilder(
                      builder: (context, setStateSB) {
                        return Row(
                          children: [
                            Expanded(
                              child: _buildDateSelector(
                                label: 'Station In',
                                date: _stationInDate,
                                onSelect: () async {
                                  final selected = await showDatePicker(
                                    context: context,
                                    initialDate: _stationInDate ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (selected != null) {
                                    setStateSB(() => _stationInDate = selected);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildDateSelector(
                                label: 'Station Out',
                                date: _stationOutDate,
                                onSelect: () async {
                                  final selected = await showDatePicker(
                                    context: context,
                                    initialDate: _stationOutDate ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (selected != null) {
                                    setStateSB(() => _stationOutDate = selected);
                                  }
                                },
                              ),
                            ),
                          ],
                        );
                      }
                    ),
                    const SizedBox(height: 16),

                    // Driver Toggle
                    StatefulBuilder(
                      builder: (context, setStateSB) {
                        return Column(
                          children: [
                            SwitchListTile(
                              title: const Text('Is Driver?', style: TextStyle(color: Colors.white)),
                              value: _isDriver,
                              activeThumbColor: Colors.blueAccent,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                setStateSB(() => _isDriver = val);
                              },
                            ),
                            SwitchListTile(
                              title: const Text('Temp attachment for Station Training', style: TextStyle(color: Colors.white)),
                              value: _isTempAttachedForTraining,
                              activeThumbColor: Colors.blueAccent,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                setStateSB(() => _isTempAttachedForTraining = val);
                              },
                            ),
                          ],
                        );
                      }
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: Icon(isEditing ? Icons.update : Icons.save),
                        label: Text(
                          isEditing ? 'Update Data' : 'Save',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            if (_stationInDate == null) {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E1E1E),
                                  title: const Text('Error', style: TextStyle(color: Colors.redAccent)),
                                  content: const Text('Station In date is mandatory (Station In തീയതി നിർബന്ധമാണ്).', style: TextStyle(color: Colors.white)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('OK', style: TextStyle(color: Colors.blueAccent)),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }
                            final inputId = _idNumberController.text.trim();
                            final provider = context.read<ManpowerProvider>();

                            // Check for duplicate ID
                            bool isDuplicate = false;
                            bool inPastList = false;

                            for (var p in provider.personnelList) {
                              // Compare ID numbers (case-insensitive)
                              if (p.idNumber.toLowerCase() == inputId.toLowerCase() &&
                                  (!isEditing || p.id != existingManpower!.id)) {
                                isDuplicate = true;
                                if (!p.isActive) {
                                  inPastList = true;
                                }
                                break;
                              }
                            }

                            if (isDuplicate) {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E1E1E),
                                  title: const Text('Error', style: TextStyle(color: Colors.redAccent)),
                                  content: Text(
                                    inPastList
                                      ? 'This ID Number already exists in the Past Personnel list (ഈ ഐഡി നമ്പർ Past Personnel ലിസ്റ്റിൽ നിലവിലുണ്ട്)'
                                      : 'This ID Number already exists (ഈ ഐഡി നമ്പർ ഇതിനകം നിലവിലുണ്ട്)',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('OK', style: TextStyle(color: Colors.blueAccent)),
                                    ),
                                  ],
                                ),
                              );
                              return; // Stop saving
                            }

                            final manpower = Manpower(
                              id: isEditing ? existingManpower!.id : DateTime.now().millisecondsSinceEpoch.toString(),
                              idNumber: inputId,
                              name: _nameController.text.trim(),
                              designation: _selectedDesignation!,
                              mobileNumber: _mobileController.text.trim(),
                              currentStation: _currentStationController.text.trim(),
                              stationIn: _stationInDate,
                              stationOut: _stationOutDate,
                              isDriver: _isDriver,
                              isTempAttachedForTraining: _isTempAttachedForTraining,
                              gender: _selectedGender,
                            );

                            if (isEditing) {
                              if (existingManpower!.idNumber != inputId) {
                                _promptMigrationAndSave(context, existingManpower!.idNumber, inputId, manpower, provider);
                                return;
                              } else {
                                provider.updateManpower(manpower);
                              }
                            } else {
                              provider.addManpower(manpower);
                            }

                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        filled: true,
        fillColor: Colors.black.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDateSelector({required String label, required DateTime? date, required VoidCallback onSelect}) {
    return InkWell(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.blueAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    date != null ? DateFormat('dd MMM yyyy').format(date) : 'Not Set',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Manpower Hub', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF0A0A0A),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Colors.blueAccent,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Active Personnel'),
              Tab(text: 'Past Personnel'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPersonnelList(context, isActive: true),
            _buildPersonnelList(context, isActive: false),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AttendanceScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.how_to_reg, color: Colors.white),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Attendance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => _showFormDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Add Personnel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonnelList(BuildContext context, {required bool isActive}) {
    return Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.5,
            colors: [Color(0xFF0E1E2C), Color(0xFF0A0A0A)],
          ),
        ),
        child: SafeArea(
          child: Consumer<ManpowerProvider>(
            builder: (context, provider, child) {
              final list = isActive ? provider.activePersonnelList : provider.pastPersonnelList;
              if (list.isEmpty) {
                return const Center(
                  child: Text('No personnel added yet.', style: TextStyle(color: Colors.white54)),
                );
              }
              // Group personnel by designation while preserving the sorted rank order
              Map<String, List<Manpower>> grouped = {};
              List<String> sortedKeys = [];
              for (var p in list) {
                String groupName = p.displayGroup;
                if (!sortedKeys.contains(groupName)) {
                  sortedKeys.add(groupName);
                }
                grouped.putIfAbsent(groupName, () => []).add(p);
              }

              return ListView.builder(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 88),
                itemCount: sortedKeys.length,
                itemBuilder: (context, index) {
                  String desig = sortedKeys[index];
                  List<Manpower> subList = grouped[desig]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8, left: 8),
                        child: Row(
                          children: [
                            Text(
                              desig,
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Divider(
                                color: Colors.blueAccent.withOpacity(0.3),
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: subList.length,
                        onReorder: (oldIndex, newIndex) {
                          provider.reorderManpower(List.from(subList), oldIndex, newIndex);
                        },
                        itemBuilder: (context, subIndex) {
                          final person = subList[subIndex];
                          return Card(
                            key: ValueKey(person.id),
                            color: Colors.white.withOpacity(0.05),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: Colors.blueAccent.withOpacity(0.2),
                                child: const Icon(Icons.drag_indicator, color: Colors.blueAccent),
                              ),
                              title: Text(person.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('${person.designation} • ID: ${person.idNumber} • ${person.gender}', style: const TextStyle(color: Colors.white70)),
                                  if (person.isDriver)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Text('Driver', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  if (person.isTempAttachedForTraining)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Text('Station Training', style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  if (!person.isActive)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text('${person.exitReason} on ${person.exitDate != null ? DateFormat('dd MMM yyyy').format(person.exitDate!) : ''}',
                                        style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isActive)
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.white54),
                                      onPressed: () => _showFormDialog(context, person),
                                    ),
                                  if (isActive)
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                                      onPressed: () async {
                                        await context.read<AttendanceProvider>().loadAttendanceForMonth(AccessControl.getActiveDutyDate());
                                        if (!context.mounted) return;
                                        if (!AccessControl.isOnDuty(context)) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('You are not on duty this time. You may ask ${AccessControl.getOnDutySfroNames(context)} for the same.'),
                                              backgroundColor: Colors.redAccent,
                                            ),
                                          );
                                          return;
                                        }
                                        _showDeleteDialog(context, provider, person);
                                      },
                                    )
                                  else
                                    IconButton(
                                      icon: const Icon(Icons.restore, color: Colors.greenAccent),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return AlertDialog(
                                              backgroundColor: const Color(0xFF1E1E1E),
                                              title: const Text('Undo Action', style: TextStyle(color: Colors.greenAccent)),
                                              content: const Text('Are you sure you want to restore this personnel to the active list?', style: TextStyle(color: Colors.white70)),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    provider.restoreManpower(person.id);
                                                    Navigator.pop(context);
                                                  },
                                                  child: const Text('Restore', style: TextStyle(color: Colors.greenAccent)),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
    );
  }
}
