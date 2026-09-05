import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/duty_provider.dart';
import '../models/duty_register_model.dart';
import 'duty_register_screen.dart';
import 'duty_pdf_preview_screen.dart';
import 'sentry_register_screen.dart';
import 'duty_history_screen.dart';
import '../providers/manpower_provider.dart';
import '../providers/attendance_provider.dart';
import '../services/access_control.dart';
import '../models/manpower_model.dart';

class DutyScreen extends StatefulWidget {
  const DutyScreen({super.key});

  @override
  State<DutyScreen> createState() => _DutyScreenState();
}

class _DutyScreenState extends State<DutyScreen> {
  DateTime _selectedDate = DateTime.now();
  DutyRegisterModel? _localOverrideRegister;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DutyProvider>().fetchDutyRegisters();
    });
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16.0)}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                _localOverrideRegister = null;
              });
              context.read<AttendanceProvider>().loadAttendanceForMonth(_selectedDate);
            },
          ),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2101),
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                  _localOverrideRegister = null;
                });
                if (mounted) context.read<AttendanceProvider>().loadAttendanceForMonth(_selectedDate);
              }
            },
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd MMM yyyy').format(_selectedDate),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
                _localOverrideRegister = null;
              });
              context.read<AttendanceProvider>().loadAttendanceForMonth(_selectedDate);
            },
          ),
        ],
      ),
    );
  }

  String _getShortVehicleName(String fullName) {
    if (fullName.contains(' KL-')) {
      return fullName.substring(0, fullName.indexOf(' KL-')).trim();
    } else if (fullName.contains(' KL ')) {
      return fullName.substring(0, fullName.indexOf(' KL ')).trim();
    }
    return fullName;
  }

  double _calculateRowHeight(DutyVehicleAssignment assignment) {
    int maxLines = 1;
    final allCells = [assignment.sfro, assignment.fro, assignment.khg, assignment.froD];
    for (var cellText in allCells) {
      if (cellText.isEmpty) continue;
      // Estimate lines by counting commas
      int items = cellText.split(',').length;
      if (items > maxLines) {
        maxLines = items;
      }
    }
    // Base height 56. If more lines, add height.
    double calcHeight = (maxLines * 20.0) + 24.0;
    return calcHeight < 56.0 ? 56.0 : calcHeight;
  }

  Future<void> _editPersonnelFromViewer(
      DutyRegisterModel register, String vehicleName, String category, String currentAssigned) async {
    // Only allow editing for admins or on-duty personnel
    if (!AccessControl.isOnDuty(context)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are not on duty. Please ask ${AccessControl.getOnDutySfroNames(context)}.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Load attendance to make sure we have the latest
    await context.read<AttendanceProvider>().loadAttendanceForMonth(_selectedDate);
    if (!mounted) return;

    final personnelList = context.read<ManpowerProvider>().getActivePersonnelForDate(_selectedDate);
    final attendanceMap = context.read<AttendanceProvider>().attendanceMap;
    final day = _selectedDate.day;

    List<Manpower> availablePersonnel = personnelList.where((p) {
      if (register.stationWriterIds.contains(p.idNumber)) return false; // Exclude Station Writers
      final attendance = attendanceMap[p.id];
      final status = attendance?.dailyStatus[day];
      if (status == 'X' || status == null || status.trim().isEmpty || status.toUpperCase() == 'X/R') {
        if (category == 'SFRO') {
          return ['SFRO', 'SFRO (M)', 'STO', 'ASTO'].contains(p.designation);
        } else if (category == 'FRO') {
          return p.designation == 'FRO';
        } else if (category == 'KHG') {
          return p.designation == 'KHG';
        } else if (category == 'FRO(D)') {
          return p.designation == 'FRO (D)';
        }
      }
      return false;
    }).toList();

    List<String> tempSelected = currentAssigned
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    List<String> initialSelected = List.from(tempSelected);

    Offset dialogPosition = Offset.zero;

    bool saved = false;

    await showDialog(
      context: context,
      barrierColor: Colors.black45, // Lighter to see background
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (stateContext, setStateDialog) {
            return Transform.translate(
              offset: dialogPosition,
              child: AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: GestureDetector(
                onPanUpdate: (details) {
                  setStateDialog(() {
                    dialogPosition += details.delta;
                  });
                },
                child: Row(
                  children: [
                    const Icon(Icons.drag_indicator, color: Colors.white54, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Edit $category for $vehicleName', style: const TextStyle(color: Colors.white, fontSize: 16))),
                  ],
                ),
              ),
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
                    final isSelected = tempSelected.any((s) => s.contains(person.idNumber));

                    // Check if assigned elsewhere
                    List<String> assignedVehicles = [];
                    for (var v in register.vehicleAssignments) {
                      if (v.vehicleName == vehicleName) continue;
                      String otherText = '';
                      if (category == 'SFRO') {
                        otherText = v.sfro;
                      } else if (category == 'FRO') otherText = v.fro;
                      else if (category == 'KHG') otherText = v.khg;
                      else if (category == 'FRO(D)') otherText = v.froD;

                      if (otherText.contains(person.idNumber)) {
                        assignedVehicles.add(v.vehicleName);
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
                          if (category == 'FRO(D)' && tempSelected.isNotEmpty && !tempSelected.any((s) => s.contains(person.idNumber))) {
                            ScaffoldMessenger.of(stateContext).showSnackBar(
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
                            tempSelected.removeWhere((s) => s.contains(person.idNumber));
                          });
                        }

                        // Instant background update
                        List<DutyVehicleAssignment> updatedAssignments = [];

                        final isNewRule = !register.date.isBefore(DateTime(2026, 7, 23));
                        String? getVehName(bool Function(String) test) {
                          try {
                            return register.vehicleAssignments.firstWhere((v) => test(v.vehicleName)).vehicleName;
                          } catch (_) {
                            return null;
                          }
                        }

                        String? v1 = getVehName((n) => n.contains('F/T') && !n.contains('C/S'));
                        String? v2 = getVehName((n) => n.contains('W/B') && !n.contains('C/S'));
                        String? qrv = getVehName((n) => n.contains('QRV') && !n.contains('C/S'));

                        String? acc1 = getVehName((n) => n.contains(isNewRule ? 'I-F/T' : 'I-MTU'));
                        String? acc2 = getVehName((n) => n.contains(isNewRule ? 'II-W/B' : 'Hydraulic Lukas') || n.contains('II-MTU'));
                        String? accQrv = getVehName((n) => n.contains('C/S-2') || n.contains('C/S-10') || (n.contains('(QRV)') && n.contains('C/S')));

                        String? targetAcc;
                        if (vehicleName == v1) targetAcc = acc1;
                        else if (vehicleName == v2) targetAcc = acc2;
                        else if (vehicleName == qrv) targetAcc = accQrv;

                        for (var v in register.vehicleAssignments) {
                          if (v.vehicleName == vehicleName || v.vehicleName == targetAcc) {
                            String newAssigned = tempSelected.join(', ');
                            List<String> newManualIds = List.from(v.manuallyEditedIds);
                            for (var id in tempSelected) {
                              if (!initialSelected.any((s) => s.contains(id))) {
                                if (!newManualIds.contains(id)) newManualIds.add(id);
                              }
                            }
                            updatedAssignments.add(DutyVehicleAssignment(
                              vehicleName: v.vehicleName,
                              seniority: v.seniority,
                              sfro: category == 'SFRO' ? newAssigned : v.sfro,
                              fro: category == 'FRO' ? newAssigned : v.fro,
                              khg: category == 'KHG' ? newAssigned : v.khg,
                              froD: category == 'FRO(D)' ? newAssigned : v.froD,
                              remarks: v.remarks,
                              isOffRoad: v.isOffRoad,
                              isAttached: v.isAttached,
                              manuallyEditedIds: newManualIds,
                            ));
                          } else {
                            updatedAssignments.add(v);
                          }
                        }

                        setState(() {
                          _localOverrideRegister = DutyRegisterModel(
                            id: register.id,
                            date: register.date,
                            rollCallTime: register.rollCallTime,
                            shift: register.shift,
                            vacancyCount: register.vacancyCount,
                            vacancyDetails: register.vacancyDetails,
                            staffSummaries: register.staffSummaries,
                            homeGuardSummaries: register.homeGuardSummaries,
                            trainingSummaries: register.trainingSummaries,
                            stationWriterIds: register.stationWriterIds,
                            specialDutyIds: register.specialDutyIds,
                            trainingOverrideIds: register.trainingOverrideIds,
                            vehicleAssignments: updatedAssignments,
                            phoneDutyIds: register.phoneDutyIds,
                            messengerIds: register.messengerIds,
                            sentryDutyIds: register.sentryDutyIds,
                            controlRoomIds: register.controlRoomIds,
                          );
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(stateContext);
                  },
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                TextButton(
                  onPressed: () async {
                    saved = true;
                    if (_localOverrideRegister == null) {
                       Navigator.pop(stateContext);
                       return;
                    }

                    final toSave = _localOverrideRegister!;
                    Navigator.pop(stateContext);
                    await context.read<DutyProvider>().saveDutyRegister(toSave);
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.blueAccent)),
                ),
              ],
            ));
          },
        );
      },
    ).then((_) {
      if (!saved && _localOverrideRegister != null) {
        // Discard local changes if cancelled or dismissed
        setState(() {
          _localOverrideRegister = null;
        });
      } else if (saved) {
        setState(() {
           _localOverrideRegister = null;
        });
      }
    });
  }

  Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    required double height,
    double? width,
    Alignment align = Alignment.centerLeft,
    VoidCallback? onTap,
    List<String> manuallyEditedIds = const [],
  }) {
    Widget content;
    if (isHeader || manuallyEditedIds.isEmpty || text == 'OF THE ROAD' || text.startsWith('OF THE ROAD -')) {
      content = Text(
        text,
        style: TextStyle(
          color: isHeader ? Colors.white : Colors.white70,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: isHeader ? 12 : 13,
        ),
        softWrap: true,
        overflow: TextOverflow.visible,
      );
    } else {
      List<TextSpan> spans = [];
      final parts = text.split(',');
      for (int i = 0; i < parts.length; i++) {
        final part = parts[i].trim();
        if (part.isEmpty) continue;

        bool isManual = manuallyEditedIds.any((id) => part.contains(id));

        spans.add(TextSpan(
          text: part + (i < parts.length - 1 ? ', ' : ''),
          style: TextStyle(
            color: isManual ? Colors.greenAccent : Colors.white70,
            fontWeight: isManual ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ));
      }
      content = RichText(
        text: TextSpan(children: spans),
        softWrap: true,
        overflow: TextOverflow.visible,
      );
    }

    Widget cell = Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      alignment: align,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
        color: isHeader ? Colors.white.withOpacity(0.05) : Colors.transparent,
      ),
      child: content,
    );

    if (onTap != null) {
      cell = InkWell(
        onTap: onTap,
        child: cell,
      );
    }

    return cell;
  }

  Widget _buildVehicleDetailmentTable(DutyRegisterModel register) {
    return Container(
      margin: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 80.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sticky Left Column
              Container(
              width: 110, // Reduced width since no numbers
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E).withOpacity(0.8),
                border: Border(right: BorderSide(color: Colors.white.withOpacity(0.2))),
              ),
              child: Column(
                children: [
                  _buildTableCell('VEHICLE', isHeader: true, height: 56),
                  ...register.vehicleAssignments.map((assignment) {
                    double h = _calculateRowHeight(assignment);
                    return _buildTableCell(_getShortVehicleName(assignment.vehicleName), height: h);
                  }),
                ],
              ),
            ),
            // Scrollable Right Columns
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildTableCell('SFRO', isHeader: true, height: 56, width: 80),
                        _buildTableCell('FRO', isHeader: true, height: 56, width: 130),
                        _buildTableCell('KHG', isHeader: true, height: 56, width: 80),
                        _buildTableCell('FRO(D)', isHeader: true, height: 56, width: 80),
                      ],
                    ),
                    ...register.vehicleAssignments.map((assignment) {
                      double h = _calculateRowHeight(assignment);
                      return Row(
                        children: assignment.isOffRoad
                            ? [
                                _buildTableCell(
                                  'OF THE ROAD${assignment.remarks.isNotEmpty ? ' - ${assignment.remarks}' : ''}',
                                  height: h,
                                  width: 370,
                                  align: Alignment.center,
                                )
                              ]
                            : [
                                _buildTableCell(
                                  assignment.sfro,
                                  height: h,
                                  width: 80,
                                  manuallyEditedIds: assignment.manuallyEditedIds,
                                  onTap: () => _editPersonnelFromViewer(register, assignment.vehicleName, 'SFRO', assignment.sfro),
                                ),
                                _buildTableCell(
                                  assignment.fro,
                                  height: h,
                                  width: 130,
                                  manuallyEditedIds: assignment.manuallyEditedIds,
                                  onTap: () => _editPersonnelFromViewer(register, assignment.vehicleName, 'FRO', assignment.fro),
                                ),
                                _buildTableCell(
                                  assignment.khg,
                                  height: h,
                                  width: 80,
                                  manuallyEditedIds: assignment.manuallyEditedIds,
                                  onTap: () => _editPersonnelFromViewer(register, assignment.vehicleName, 'KHG', assignment.khg),
                                ),
                                _buildTableCell(
                                  assignment.froD,
                                  height: h,
                                  width: 80,
                                  manuallyEditedIds: assignment.manuallyEditedIds,
                                  onTap: () => _editPersonnelFromViewer(register, assignment.vehicleName, 'FRO(D)', assignment.froD),
                                ),
                              ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  @override
  Widget build(BuildContext context) {
    final bool shouldShowControls = AccessControl.isAdmin(context) || AccessControl.isSfro(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Duty Roster'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (shouldShowControls)
            IconButton(
              icon: const Icon(Icons.history, color: Colors.orange),
            tooltip: 'View Duty History',
            onPressed: () {
              final dutyProvider = context.read<DutyProvider>();
              final manpowerProvider = context.read<ManpowerProvider>();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DutyHistoryScreen(
                    allRegisters: dutyProvider.registers,
                    personnelList: manpowerProvider.personnelList,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.blueAccent),
            tooltip: 'View Duty Register PDF',
            onPressed: () async {
              final provider = context.read<DutyProvider>();
              try {
                final register = provider.registers.firstWhere((r) {
                  return r.date.year == _selectedDate.year &&
                         r.date.month == _selectedDate.month &&
                         r.date.day == _selectedDate.day;
                });

                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DutyPdfPreviewScreen(register: register),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No Duty Register found for ${DateFormat('dd-MMM-yyyy').format(_selectedDate)}')),
                  );
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
            center: Alignment(0, -0.8),
            radius: 1.5,
            colors: [
              Color(0xFF2C0B0B),
              Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer<DutyProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && _localOverrideRegister == null) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFE53935)),
                );
              }

              DutyRegisterModel? register = provider.registers.where((r) {
                return r.date.year == _selectedDate.year &&
                       r.date.month == _selectedDate.month &&
                       r.date.day == _selectedDate.day;
              }).firstOrNull;

              if (_localOverrideRegister != null && register != null && _localOverrideRegister!.id == register.id) {
                register = _localOverrideRegister;
              }

              return Column(
                children: [
                  _buildDateSelector(),
                  Expanded(
                    child: register == null
                        ? Center(
                            child: Text(
                              'No duty register found for ${DateFormat('dd MMM yyyy').format(_selectedDate)}.\nPlease create one using Duty Register.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withOpacity(0.6)),
                            ),
                          )
                        : _buildVehicleDetailmentTable(register),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: shouldShowControls
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DutyRegisterScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.assignment, color: Colors.white),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Duty Register', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SentryRegisterScreen(initialDate: _selectedDate)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.security, color: Colors.white),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Sentry Register', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        : null,
    );
  }
}
