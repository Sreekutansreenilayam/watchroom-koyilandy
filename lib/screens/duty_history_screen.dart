import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/duty_register_model.dart';
import '../models/manpower_model.dart';

class DutyHistoryScreen extends StatefulWidget {
  final List<DutyRegisterModel> allRegisters;
  final List<Manpower> personnelList;

  const DutyHistoryScreen({
    super.key,
    required this.allRegisters,
    required this.personnelList,
  });

  @override
  State<DutyHistoryScreen> createState() => _DutyHistoryScreenState();
}

class _DutyDayRecord {
  final DateTime date;
  final List<String> vehicles;
  final int actualVehicleCount;
  _DutyDayRecord(this.date, this.vehicles, this.actualVehicleCount);
}

class _PersonnelDutyData {
  final Manpower personnel;
  final List<_DutyDayRecord> allRecords; // sorted descending by date
  final List<_DutyDayRecord> monthRecords; // records only for selected month
  
  _PersonnelDutyData(this.personnel, this.allRecords, this.monthRecords);
}

class _DesignationGroup {
  final String designation;
  final Color borderColor;
  final List<_PersonnelDutyData> personnelData;
  _DesignationGroup(this.designation, this.borderColor, this.personnelData);
}

class _DutyHistoryScreenState extends State<DutyHistoryScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  Color _getCategoryColor(String designation) {
    if (designation.contains('SFRO')) return Colors.blueAccent;
    if (designation.contains('FRO (D)')) return Colors.cyanAccent;
    if (designation.contains('FRO')) return Colors.white70;
    if (designation.contains('KHG')) return Colors.green;
    if (designation.contains('STO')) return Colors.purpleAccent;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    // 1. Sort all registers descending
    final sortedRegisters = List<DutyRegisterModel>.from(widget.allRegisters)
      ..sort((a, b) => b.date.compareTo(a.date));

    // 2. Find the absolute latest duty date in the selected month
    DateTime? latestMonthDutyDate;
    for (var reg in sortedRegisters) {
      if (reg.date.year == _selectedMonth.year && reg.date.month == _selectedMonth.month) {
        latestMonthDutyDate = reg.date;
        break; // First one is the latest
      }
    }

    // 3. Group by designation maintaining original manpower seniority
    List<_DesignationGroup> groups = [];

    for (var person in widget.personnelList) {
      List<_DutyDayRecord> records = [];

      for (var reg in sortedRegisters) {
        List<String> assignedVehicles = [];
        int actualVehicleCount = 0;
        for (int i = 0; i < reg.vehicleAssignments.length; i++) {
          var v = reg.vehicleAssignments[i];
          bool assigned = false;
          if (v.sfro.contains(person.idNumber)) assigned = true;
          if (v.fro.contains(person.idNumber)) assigned = true;
          if (v.khg.contains(person.idNumber)) assigned = true;
          if (v.froD.contains(person.idNumber)) assigned = true;

          if (assigned) {
            if (i < 12) {
              actualVehicleCount++;
            }
            String shortName = v.vehicleName;
            if (shortName.contains(' KL-')) {
              shortName = shortName.substring(0, shortName.indexOf(' KL-')).trim();
            } else if (shortName.contains(' KL ')) {
              shortName = shortName.substring(0, shortName.indexOf(' KL ')).trim();
            }
            assignedVehicles.add('$shortName - ${person.designation}');
          }
        }
        if (assignedVehicles.isNotEmpty) {
          records.add(_DutyDayRecord(reg.date, assignedVehicles, actualVehicleCount));
        }
      }

      final monthRecords = records.where((r) => r.date.year == _selectedMonth.year && r.date.month == _selectedMonth.month).toList();

      if (monthRecords.isEmpty) continue;

      final pData = _PersonnelDutyData(person, records, monthRecords);

      _DesignationGroup? group;
      for (var g in groups) {
        if (g.designation == person.designation) {
          group = g;
          break;
        }
      }
      if (group == null) {
        group = _DesignationGroup(person.designation, _getCategoryColor(person.designation), []);
        groups.add(group);
      }
      group.personnelData.add(pData);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Duty History'),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E1E1E),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.orange),
                  onPressed: _previousMonth,
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.orange),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, gIndex) {
                final group = groups[gIndex];
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    border: Border.all(color: group.borderColor, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: group.personnelData.map((data) {
                      _DutyDayRecord? latestDuty = data.monthRecords.first;
                      
                      bool isLatestSystemDuty = false;
                      if (latestMonthDutyDate != null && 
                          latestDuty.date.year == latestMonthDutyDate!.year &&
                          latestDuty.date.month == latestMonthDutyDate!.month &&
                          latestDuty.date.day == latestMonthDutyDate!.day) {
                         isLatestSystemDuty = true;
                      }

                      bool hasRepetition = false;
                      bool hasMoreThanThree = false;
                      
                      _DutyDayRecord? previousDuty;
                      int latestIndex = data.allRecords.indexOf(latestDuty);
                      if (latestIndex + 1 < data.allRecords.length) {
                        previousDuty = data.allRecords[latestIndex + 1];
                      }

                      if (isLatestSystemDuty) {
                         if (latestDuty.actualVehicleCount > 3) {
                           hasMoreThanThree = true;
                         }
                         if (previousDuty != null) {
                            for (var v in latestDuty.vehicles) {
                               if (previousDuty.vehicles.contains(v)) {
                                  hasRepetition = true;
                                  break;
                               }
                            }
                         }
                      }
                      
                      Color nameColor = Colors.white70;
                      String subtitleText = '';
                      
                      if (isLatestSystemDuty) {
                         if (hasMoreThanThree) {
                            nameColor = Colors.redAccent;
                            subtitleText = 'Assigned more than three vehicles';
                         } else if (hasRepetition) {
                            nameColor = Colors.redAccent;
                            subtitleText = 'Vehicle repetition detected';
                         } else {
                            nameColor = Colors.green;
                         }
                      }

                      return Column(
                        children: [
                          Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: hasMoreThanThree 
                                ? _BlinkingText(
                                    text: '${data.personnel.name} (${data.personnel.designation})',
                                    style: TextStyle(color: nameColor, fontWeight: FontWeight.bold),
                                  )
                                : Text(
                                    '${data.personnel.name} (${data.personnel.designation})',
                                    style: TextStyle(color: nameColor, fontWeight: FontWeight.bold),
                                  ),
                              subtitle: subtitleText.isNotEmpty
                                  ? Text(subtitleText, style: const TextStyle(color: Colors.white54, fontSize: 12))
                                  : null,
                              iconColor: Colors.orange,
                              collapsedIconColor: Colors.white54,
                              children: data.monthRecords.map((record) {
                                 int rIndex = data.allRecords.indexOf(record);
                                 _DutyDayRecord? prevRecord = (rIndex + 1 < data.allRecords.length) ? data.allRecords[rIndex + 1] : null;

                                 bool isThisRecordLatestSystemDuty = false;
                                 if (latestMonthDutyDate != null && 
                                     record.date.year == latestMonthDutyDate!.year &&
                                     record.date.month == latestMonthDutyDate!.month &&
                                     record.date.day == latestMonthDutyDate!.day) {
                                     isThisRecordLatestSystemDuty = true;
                                 }

                                 return Container(
                                   width: double.infinity,
                                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                   color: const Color(0xFF121212),
                                   child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Text(
                                         DateFormat('dd MMM yyyy').format(record.date),
                                         style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                                       ),
                                       const SizedBox(height: 4),
                                       ...record.vehicles.map((v) {
                                          Color vehicleColor = Colors.white70;
                                          bool isRepeated = false;
                                          if (isThisRecordLatestSystemDuty) {
                                            isRepeated = prevRecord != null && prevRecord.vehicles.contains(v);
                                            vehicleColor = isRepeated ? Colors.redAccent : Colors.green;
                                          }

                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 2),
                                            child: isRepeated 
                                              ? _BlinkingText(
                                                  text: v,
                                                  style: TextStyle(color: vehicleColor, fontSize: 13),
                                                )
                                              : Text(
                                                  v,
                                                  style: TextStyle(color: vehicleColor, fontSize: 13),
                                                ),
                                          );
                                       }),
                                     ],
                                   ),
                                 );
                              }).toList(),
                            ),
                          ),
                          // Divider between personnel in the same group, except the last one
                          if (data != group.personnelData.last)
                            const Divider(color: Colors.black26, height: 1, indent: 16, endIndent: 16),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BlinkingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _BlinkingText({required this.text, required this.style});

  @override
  State<_BlinkingText> createState() => _BlinkingTextState();
}

class _BlinkingTextState extends State<_BlinkingText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Text(widget.text, style: widget.style),
    );
  }
}
