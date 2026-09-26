import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../providers/manpower_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/manpower_model.dart';
import '../models/attendance_model.dart';
import '../services/access_control.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  late AttendanceProvider _attendanceProvider;
  late ManpowerProvider _manpowerProvider;

  final Set<String> _selectedCells = {};
  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _bodyScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  bool _isSyncing = false;
  bool _shouldScrollToCurrentDate = true;

  final Map<int, String> _dayFilters = {};

  // Drag-to-fill state
  String? _dragFillValue;
  final Set<String> _currentlyDraggingCells = {};
  Timer? _autoScrollTimer;
  Offset? _lastDragPosition;

  @override
  void initState() {
    super.initState();
    _attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
    _manpowerProvider = Provider.of<ManpowerProvider>(context, listen: false);
    _loadData();

    _headerScrollController.addListener(() {
      if (_isSyncing) return;
      _isSyncing = true;
      _bodyScrollController.jumpTo(_headerScrollController.offset);
      _isSyncing = false;
    });

    _bodyScrollController.addListener(() {
      if (_isSyncing) return;
      _isSyncing = true;
      _headerScrollController.jumpTo(_bodyScrollController.offset);
      _isSyncing = false;
    });

    _attendanceProvider.addListener(_onProviderUpdate);
  }

  void _onProviderUpdate() {
    if (!_attendanceProvider.isLoading && _shouldScrollToCurrentDate) {
      _shouldScrollToCurrentDate = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentDate();
      });
    }
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _attendanceProvider.removeListener(_onProviderUpdate);
    _headerScrollController.dispose();
    _bodyScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _loadData() {
    _attendanceProvider.loadAttendanceForMonth(_selectedDate);
    setState(() {
      _selectedCells.clear();
    });
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + offset, 1);
      _shouldScrollToCurrentDate = true;
    });
    _loadData();
  }

  void _scrollToCurrentDate() {
    final now = DateTime.now();
    double offset = 0;

    if (_selectedDate.year == now.year && _selectedDate.month == now.month) {
      final int currentDay = now.day;
      final double cellWidth = 46.0;
      offset = (currentDay - 1) * cellWidth;
      if (offset < 0) offset = 0;
    }

    if (_headerScrollController.hasClients) {
      final maxScroll = _headerScrollController.position.maxScrollExtent;
      if (offset > maxScroll) offset = maxScroll;
      _headerScrollController.jumpTo(offset);
    }
  }

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  bool _isAfterExitDate(String personId, DateTime cellDate) {
    try {
      final person = context.read<ManpowerProvider>().personnelList.firstWhere((p) => p.id == personId);
      if (person.exitDate != null) {
        final exitDateOnly = DateTime(person.exitDate!.year, person.exitDate!.month, person.exitDate!.day);
        if (cellDate.isAfter(exitDateOnly)) {
          return true;
        }
      }
    } catch (e) {}
    return false;
  }

  bool _isBeforeJoinDate(String personId, DateTime cellDate) {
    try {
      final person = context.read<ManpowerProvider>().personnelList.firstWhere((p) => p.id == personId);
      if (person.stationIn != null) {
        final joinDateOnly = DateTime(person.stationIn!.year, person.stationIn!.month, person.stationIn!.day);
        if (cellDate.isBefore(joinDateOnly)) {
          return true;
        }
      }
    } catch (e) {}
    return false;
  }

  bool _isInvalidDate(String personId, DateTime cellDate) {
    return _isAfterExitDate(personId, cellDate) || _isBeforeJoinDate(personId, cellDate);
  }

  void _toggleCellSelection(String cellId) {
    final parsed = CellIdParts.parse(cellId, _selectedDate);
    if (parsed == null) return;

    if (!AccessControl.canEditAttendance(context, parsed.personId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You do not have permission to edit this attendance. You may ask ${AccessControl.getOnDutySfroNames(context)} for the same.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final cellDate = DateTime(parsed.year, parsed.month, parsed.day);
    if (AccessControl.isDateLocked(context, cellDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This day\'s attendance is permanently locked.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (_isInvalidDate(parsed.personId, cellDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot mark attendance on this date (ജോയിൻ ചെയ്യുന്നതിന് മുൻപോ പോയതിനു ശേഷമോ അറ്റൻഡൻസ് രേഖപ്പെടുത്താൻ സാധിക്കില്ല).'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() {
      if (_selectedCells.contains(cellId)) {
        _selectedCells.remove(cellId);
      } else {
        _selectedCells.add(cellId);
      }
    });
  }

  String? _getCellIdFromOffset(Offset localPosition, List<Manpower> manpowerList) {
    if (!mounted) return null;
    final int daysInMonth = _getDaysInMonth(_selectedDate.year, _selectedDate.month);

    final int prevMonth = _selectedDate.month == 1 ? 12 : _selectedDate.month - 1;
    final int prevYear = _selectedDate.month == 1 ? _selectedDate.year - 1 : _selectedDate.year;
    final int daysInPrevMonth = _getDaysInMonth(prevYear, prevMonth);

    final List<int> prevDaysToShow = [daysInPrevMonth - 1, daysInPrevMonth];
    final String currentYearMonth = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}";
    final String prevYearMonth = "$prevYear-${prevMonth.toString().padLeft(2, '0')}";

    final double cellWidth = 46.0;
    final double cellHeight = 56.0;
    final double headerHeight = 36.0;

    int colIndex = (localPosition.dx / cellWidth).floor();
    int totalCols = prevDaysToShow.length + daysInMonth;

    if (colIndex < 0 || colIndex >= totalCols) return null;

    String ym;
    int day;
    if (colIndex < prevDaysToShow.length) {
      ym = prevYearMonth;
      day = prevDaysToShow[colIndex];
    } else {
      ym = currentYearMonth;
      day = colIndex - prevDaysToShow.length + 1;
    }

    double currentY = 0.0;
    for (int i = 0; i < manpowerList.length; i++) {
      final person = manpowerList[i];
      bool showHeader = i == 0 || person.displayGroup != manpowerList[i - 1].displayGroup;

      if (showHeader) {
        currentY += headerHeight;
      }

      if (localPosition.dy >= currentY && localPosition.dy < currentY + cellHeight) {
        return "${person.id}_${ym}_$day";
      }

      currentY += cellHeight;
    }
    return null;
  }

  void _showAddLegendDialog() {
    final codeController = TextEditingController();
    final descController = TextEditingController();
    int selectedColor = Colors.blue.value;

    final List<Color> colorOptions = [
      Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
      Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
      Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
      Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
      Colors.brown, Colors.grey, Colors.blueGrey,
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Add New Legend', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Code (e.g., SL)',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Description (e.g., Sick Leave)',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Select Color:', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: colorOptions.map((color) {
                      final isSelected = color.value == selectedColor;
                      return InkWell(
                        onTap: () => setDialogState(() => selectedColor = color.value),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                          ),
                        ),
                      );
                    }).toList(),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (codeController.text.isNotEmpty && descController.text.isNotEmpty) {
                    _attendanceProvider.addCustomLegend(
                      codeController.text.trim(),
                      descController.text.trim(),
                      selectedColor
                    );
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showEditLegendDialog(AttendanceLegend legend) {
    if (legend.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot edit default legends. Please add a new one.')),
      );
      return;
    }

    final codeController = TextEditingController(text: legend.code);
    final descController = TextEditingController(text: legend.description);
    int selectedColor = legend.colorValue;

    final List<Color> colorOptions = [
      Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
      Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
      Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
      Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
      Colors.brown, Colors.grey, Colors.blueGrey,
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Edit Legend', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Code (e.g., SL)',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Description (e.g., Sick Leave)',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Select Color:', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: colorOptions.map((color) {
                      final isSelected = color.value == selectedColor;
                      return InkWell(
                        onTap: () => setDialogState(() => selectedColor = color.value),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                          ),
                        ),
                      );
                    }).toList(),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _attendanceProvider.deleteLegend(legend.id);
                  Navigator.pop(ctx);
                },
                child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (codeController.text.isNotEmpty && descController.text.isNotEmpty) {
                    _attendanceProvider.updateLegend(
                      legend.id,
                      codeController.text.trim(),
                      descController.text.trim(),
                      selectedColor
                    );
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: const Text('Update', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showLegendOptionsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Mark Attendance (${_selectedCells.length} Days)', style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Consumer<AttendanceProvider>(
                  builder: (context, provider, child) {
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: provider.legends.length,
                      itemBuilder: (context, index) {
                        final sortedLegends = List.of(provider.legends)..sort((a, b) => a.code.compareTo(b.code));
                        final legend = sortedLegends[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Color(legend.colorValue),
                            radius: 16,
                            child: Text(
                              legend.code,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(legend.description, style: const TextStyle(color: Colors.white)),
                          onTap: () {
                            provider.updateMultipleAttendance(_selectedCells, legend.code);
                            setState(() {
                              _selectedCells.clear();
                            });
                            Navigator.pop(ctx);
                          },
                          onLongPress: () {
                            Navigator.pop(ctx);
                            _showEditLegendDialog(legend);
                          },
                        );
                      },
                    );
                  }
                ),
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.clear, color: Colors.redAccent),
                title: const Text('Clear (Remove mark)', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  _attendanceProvider.updateMultipleAttendance(_selectedCells, '');
                  setState(() {
                    _selectedCells.clear();
                  });
                  Navigator.pop(ctx);
                },
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                title: const Text('Add New Legend', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                onTap: () {
                  _showAddLegendDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColorForCode(String code) {
    if (code.isEmpty) return Colors.transparent;
    try {
      final legend = _attendanceProvider.legends.firstWhere((l) => l.code == code);
      return Color(legend.colorValue);
    } catch (e) {
      return Colors.grey; // Fallback
    }
  }

  void _showFilterOptions(int day) {
    Map<String, int> usedLegends = {};
    for (var p in _manpowerProvider.personnelList) {
      final att = _attendanceProvider.attendanceMap[p.id];
      final status = att?.dailyStatus[day] ?? '';
      if (status.isNotEmpty) {
        usedLegends[status] = (usedLegends[status] ?? 0) + 1;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Filter Day $day', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (usedLegends.isEmpty)
                const Text('No legends used on this day.', style: TextStyle(color: Colors.white54)),
              for (var legendCode in usedLegends.keys.toList()..sort())
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _getColorForCode(legendCode).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        legendCode,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  title: Text(
                    legendCode,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      usedLegends[legendCode].toString(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _dayFilters[day] = legendCode;
                    });
                    Navigator.pop(ctx);
                  },
                ),
              if (_dayFilters.containsKey(day))
                const Divider(color: Colors.white24),
              if (_dayFilters.containsKey(day))
                ListTile(
                  leading: const Icon(Icons.clear, color: Colors.redAccent),
                  title: const Text('Clear Filter', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    setState(() {
                      _dayFilters.remove(day);
                    });
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int daysInMonth = _getDaysInMonth(_selectedDate.year, _selectedDate.month);
    final String monthName = DateFormat('MMMM yyyy').format(_selectedDate);

    final int prevMonth = _selectedDate.month == 1 ? 12 : _selectedDate.month - 1;
    final int prevYear = _selectedDate.month == 1 ? _selectedDate.year - 1 : _selectedDate.year;
    final int daysInPrevMonth = _getDaysInMonth(prevYear, prevMonth);

    final List<int> prevDaysToShow = [daysInPrevMonth - 1, daysInPrevMonth];
    final String currentYearMonth = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}";
    final String prevYearMonth = "$prevYear-${prevMonth.toString().padLeft(2, '0')}";

    final DateFormat prevMonthAbbrFormat = DateFormat('MMM');
    final String prevMonthAbbr = prevMonthAbbrFormat.format(DateTime(prevYear, prevMonth, 1));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Attendance Register', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Month Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.blueAccent),
                      onPressed: () => _changeMonth(-1),
                    ),
                    Consumer<AttendanceProvider>(
                      builder: (context, provider, child) {
                        return IconButton(
                          icon: const Icon(Icons.undo),
                          color: provider.canUndo ? Colors.orangeAccent : Colors.white24,
                          onPressed: provider.canUndo ? () => provider.undoLastAction() : null,
                          tooltip: 'Undo Last Action',
                        );
                      }
                    ),
                  ],
                ),
                Text(
                  monthName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Consumer<AttendanceProvider>(
                      builder: (context, provider, child) {
                        return IconButton(
                          icon: const Icon(Icons.redo),
                          color: provider.canRedo ? Colors.orangeAccent : Colors.white24,
                          onPressed: provider.canRedo ? () => provider.redoLastAction() : null,
                          tooltip: 'Redo Last Action',
                        );
                      }
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, color: Colors.blueAccent),
                      onPressed: () => _changeMonth(1),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Data Table
          Expanded(
            child: Consumer2<ManpowerProvider, AttendanceProvider>(
              builder: (context, manpowerProvider, attendanceProvider, child) {
                if (manpowerProvider.isLoading || attendanceProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                }

                if (manpowerProvider.personnelList.isEmpty) {
                  return const Center(
                    child: Text('No personnel found.', style: TextStyle(color: Colors.white54)),
                  );
                }

                final double cellWidth = 46.0;
                final double cellHeight = 56.0;
                final double nameWidth = 140.0;

                List<Manpower> filteredPersonnel = manpowerProvider.personnelList.where((p) {
                  if (_dayFilters.isEmpty) return true;
                  final att = attendanceProvider.attendanceMap[p.id];
                  for (var entry in _dayFilters.entries) {
                    final day = entry.key;
                    final requiredStatus = entry.value;
                    final status = att?.dailyStatus[day] ?? '';
                    if (status != requiredStatus) return false;
                  }
                  return true;
                }).toList();

                List<Manpower> activeList = filteredPersonnel.where((p) => p.isActive).toList();
                List<Manpower> pastList = filteredPersonnel.where((p) => !p.isActive).toList();
                filteredPersonnel = [...activeList, ...pastList];

                return Column(
                  children: [
                    // --- STICKY HEADER ROW ---
                    Row(
                      children: [
                        // Sticky Header Name
                        Container(
                          width: nameWidth,
                          height: cellHeight,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.2),
                            border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
                          ),
                          child: const Text('Name', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        // Scrollable Header Dates
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _headerScrollController,
                            scrollDirection: Axis.horizontal,
                            child: Container(
                              height: cellHeight,
                              color: Colors.blueAccent.withOpacity(0.2),
                              child: Row(
                                children: [
                                  for (int i in prevDaysToShow)
                                    Container(
                                      width: cellWidth,
                                      alignment: Alignment.center,
                                      color: Colors.white.withOpacity(0.05), // slightly different background
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text('$prevMonthAbbr $i', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                  for (int i = 1; i <= daysInMonth; i++)
                                    Container(
                                      width: cellWidth,
                                      alignment: Alignment.center,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(i.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                          const SizedBox(height: 2),
                                          InkWell(
                                            onTap: () => _showFilterOptions(i),
                                            child: _dayFilters.containsKey(i)
                                              ? Text(_dayFilters[i]!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold))
                                              : const Icon(Icons.filter_alt_outlined, size: 14, color: Colors.white54),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // --- SCROLLABLE BODY ---
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _verticalScrollController,
                        // Vertical scroll for the entire body
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Sticky Names Column
                            Container(
              width: nameWidth,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0A0A0A),
                                border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
                              ),
                              child: Column(
                                children: filteredPersonnel.asMap().entries.expand((entry) {
                                  final index = entry.key;
                                  final person = entry.value;
                                  String currentGroup = person.isActive ? person.displayGroup : 'Past Personnel';
                                  String prevGroup = index == 0 ? '' : (filteredPersonnel[index - 1].isActive ? filteredPersonnel[index - 1].displayGroup : 'Past Personnel');
                                  bool showHeader = index == 0 || currentGroup != prevGroup;

                                  List<Widget> widgets = [];
                                  if (showHeader) {
                                    widgets.add(
                                      Container(
                                        height: 36,
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.only(left: 16, right: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent.withOpacity(0.1),
                                          border: Border(bottom: BorderSide(color: Colors.blueAccent.withOpacity(0.3))),
                                        ),
                                        child: Text(
                                          currentGroup,
                                          style: TextStyle(
                                            color: person.isActive ? Colors.blueAccent : Colors.redAccent,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      )
                                    );
                                  }

                                  widgets.add(
                                    Container(
                                      height: cellHeight,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      decoration: BoxDecoration(
                                        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                                      ),
                                      child: Text(
                                        person.name,
                                        style: TextStyle(color: person.isActive ? Colors.white : Colors.redAccent),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  );
                                  return widgets;
                                }).toList(),
                              ),
                            ),
                            // Scrollable Dates Grid
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _bodyScrollController,
                                scrollDirection: Axis.horizontal,
                                child: GestureDetector(
                                  onLongPressStart: (details) {
                                    String? cellId = _getCellIdFromOffset(details.localPosition, filteredPersonnel);
                                    if (cellId != null) {
                                      final parsed = CellIdParts.parse(cellId, _selectedDate);
                                      if (parsed == null) return;
                                      
                                      if (!AccessControl.canEditAttendance(context, parsed.personId)) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('You do not have permission to edit this attendance. You may ask ${AccessControl.getOnDutySfroNames(context)} for the same.'),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                        return;
                                      }

                                      final cellDate = DateTime(parsed.year, parsed.month, parsed.day);
                                      if (AccessControl.isDateLocked(context, cellDate)) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('This day\'s attendance is permanently locked.'), backgroundColor: Colors.redAccent),
                                        );
                                        return;
                                      }

                                      if (_isInvalidDate(parsed.personId, cellDate)) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Cannot mark attendance on this date (ജോയിൻ ചെയ്യുന്നതിന് മുൻപോ പോയതിനു ശേഷമോ അറ്റൻഡൻസ് രേഖപ്പെടുത്താൻ സാധിക്കില്ല).'), backgroundColor: Colors.redAccent),
                                        );
                                        return;
                                      }

                                      final isCurrentMonth = parsed.month == _selectedDate.month && parsed.year == _selectedDate.year;
                                      final status = isCurrentMonth
                                          ? (_attendanceProvider.attendanceMap[parsed.personId]?.dailyStatus[parsed.day] ?? '')
                                          : (_attendanceProvider.prevAttendanceMap[parsed.personId]?.dailyStatus[parsed.day] ?? '');

                                      if (status.isNotEmpty) {
                                        setState(() {
                                          _dragFillValue = status;
                                          _currentlyDraggingCells.clear();
                                          _currentlyDraggingCells.add(cellId);
                                        });
                                      }
                                    }
                                  },
                                  onLongPressMoveUpdate: (details) {
                                    if (_dragFillValue == null) return;
                                    _lastDragPosition = details.localPosition;
                                    _startAutoScroll(filteredPersonnel);

                                    String? cellId = _getCellIdFromOffset(details.localPosition, filteredPersonnel);
                                    if (cellId != null && !_currentlyDraggingCells.contains(cellId)) {
                                      final parsed = CellIdParts.parse(cellId, _selectedDate);
                                      if (parsed != null) {
                                        final cellDate = DateTime(parsed.year, parsed.month, parsed.day);
                                        if (!AccessControl.isDateLocked(context, cellDate) && !_isInvalidDate(parsed.personId, cellDate)) {
                                          setState(() {
                                            _currentlyDraggingCells.add(cellId);
                                          });
                                        }
                                      }
                                    }
                                  },
                                  onLongPressEnd: (details) {
                                    _stopAutoScroll();
                                    _lastDragPosition = null;
                                    if (_dragFillValue != null) {
                                      if (_currentlyDraggingCells.isNotEmpty) {
                                        _attendanceProvider.updateMultipleAttendance(_currentlyDraggingCells, _dragFillValue!);
                                      }
                                      setState(() {
                                        _dragFillValue = null;
                                        _currentlyDraggingCells.clear();
                                      });
                                    }
                                  },
                                  child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: filteredPersonnel.asMap().entries.expand((entry) {
                                    final index = entry.key;
                                    final person = entry.value;
                                    String currentGroup = person.isActive ? person.displayGroup : 'Past Personnel';
                                    String prevGroup = index == 0 ? '' : (filteredPersonnel[index - 1].isActive ? filteredPersonnel[index - 1].displayGroup : 'Past Personnel');
                                    bool showHeader = index == 0 || currentGroup != prevGroup;

                                    final attendanceData = attendanceProvider.attendanceMap[person.id];
                                    final dailyStatusMap = attendanceData?.dailyStatus ?? {};

                                    List<Widget> widgets = [];
                                    if (showHeader) {
                                      widgets.add(
                                        Container(
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: Colors.blueAccent.withOpacity(0.1),
                                            border: Border(bottom: BorderSide(color: Colors.blueAccent.withOpacity(0.3))),
                                          ),
                                          child: Row(
                                            children: [
                                              for (int day in prevDaysToShow)
                                                Builder(
                                                  builder: (context) {
                                                    int xCount = 0;
                                                    for (var p in manpowerProvider.personnelList) {
                                                      String pGroup = p.isActive ? p.displayGroup : 'Past Personnel';
                                                      if (pGroup == currentGroup) {
                                                        final data = attendanceProvider.prevAttendanceMap[p.id];
                                                        if (data != null && (data.dailyStatus[day]?.toLowerCase() == 'x' || data.dailyStatus[day]?.toUpperCase() == 'X/R')) {
                                                          xCount++;
                                                        }
                                                      }
                                                    }

                                                    return Container(
                                                      width: cellWidth,
                                                      alignment: Alignment.center,
                                                      color: Colors.white.withOpacity(0.05),
                                                      child: Text(
                                                        xCount > 0 ? xCount.toString() : '-',
                                                        style: TextStyle(
                                                          color: xCount > 0 ? Colors.blueAccent : Colors.white24,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                ),
                                              for (int day = 1; day <= daysInMonth; day++)
                                                Builder(
                                                  builder: (context) {
                                                    int xCount = 0;
                                                    for (var p in manpowerProvider.personnelList) {
                                                      String pGroup = p.isActive ? p.displayGroup : 'Past Personnel';
                                                      if (pGroup == currentGroup) {
                                                        final data = attendanceProvider.attendanceMap[p.id];
                                                        if (data != null && (data.dailyStatus[day]?.toLowerCase() == 'x' || data.dailyStatus[day]?.toUpperCase() == 'X/R')) {
                                                          xCount++;
                                                        }
                                                      }
                                                    }

                                                    return Container(
                                                      width: cellWidth,
                                                      alignment: Alignment.center,
                                                      child: Text(
                                                        xCount > 0 ? xCount.toString() : '-',
                                                        style: TextStyle(
                                                          color: xCount > 0 ? Colors.blueAccent : Colors.white24,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                ),
                                            ],
                                          ),
                                        )
                                      );
                                    }

                                    widgets.add(
                                      Container(
                                        height: cellHeight,
                                        decoration: BoxDecoration(
                                          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                                        ),
                                        child: Row(
                                          children: [
                                              for (int day in prevDaysToShow)
                                                Builder(
                                                  builder: (context) {
                                                    final cellId = "${person.id}_${prevYearMonth}_$day";
                                                    final isSelected = _selectedCells.contains(cellId);
                                                    
                                                    final parsed = CellIdParts.parse(cellId, _selectedDate);
                                                    final cellDate = parsed != null ? DateTime(parsed.year, parsed.month, parsed.day) : DateTime.now();
                                                    final isInvalid = _isInvalidDate(person.id, cellDate);

                                                    final isBeingDragged = _currentlyDraggingCells.contains(cellId);
                                                    final prevData = attendanceProvider.prevAttendanceMap[person.id];
                                                    final prevDailyStatusMap = prevData?.dailyStatus ?? {};
                                                    final status = isBeingDragged ? _dragFillValue! : (prevDailyStatusMap[day] ?? '');
                                                    final cellColor = _getColorForCode(status);

                                                    return Container(
                                                      width: cellWidth,
                                                      alignment: Alignment.center,
                                                      color: Colors.white.withOpacity(0.02),
                                                      child: InkWell(
                                                        onTap: () => _toggleCellSelection(cellId),
                                                        child: Opacity(
                                                          opacity: isInvalid ? 0.2 : 1.0,
                                                          child: Container(
                                                          width: 32,
                                                          height: 32,
                                                          alignment: Alignment.center,
                                                          decoration: BoxDecoration(
                                                            color: isSelected
                                                                ? Colors.blueAccent.withOpacity(0.5)
                                                                : (status.isNotEmpty ? cellColor.withOpacity(0.8) : Colors.transparent),
                                                            borderRadius: BorderRadius.circular(6),
                                                            border: Border.all(
                                                              color: isSelected ? Colors.blueAccent : Colors.white24,
                                                              width: isSelected ? 2 : 1,
                                                            ),
                                                          ),
                                                          child: isSelected
                                                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                                                              : FittedBox(
                                                                  fit: BoxFit.scaleDown,
                                                                  child: Text(
                                                                    status,
                                                                    style: const TextStyle(
                                                                      color: Colors.white,
                                                                      fontWeight: FontWeight.bold,
                                                                      fontSize: 12,
                                                                    ),
                                                                  ),
                                                                ),
                                                        ),
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                ),
                                              for (int day = 1; day <= daysInMonth; day++)
                                                Builder(
                                                  builder: (context) {
                                                    final cellId = "${person.id}_${currentYearMonth}_$day";
                                                    final isSelected = _selectedCells.contains(cellId);
                                                    
                                                    final parsed = CellIdParts.parse(cellId, _selectedDate);
                                                    final cellDate = parsed != null ? DateTime(parsed.year, parsed.month, parsed.day) : DateTime.now();
                                                    final isInvalid = _isInvalidDate(person.id, cellDate);

                                                    final isBeingDragged = _currentlyDraggingCells.contains(cellId);
                                                    final status = isBeingDragged ? _dragFillValue! : (dailyStatusMap[day] ?? '');
                                                    final cellColor = _getColorForCode(status);

                                                    return Container(
                                                      width: cellWidth,
                                                      alignment: Alignment.center,
                                                      child: InkWell(
                                                        onTap: () => _toggleCellSelection(cellId),
                                                        child: Opacity(
                                                          opacity: isInvalid ? 0.2 : 1.0,
                                                          child: Container(
                                                          width: 32,
                                                          height: 32,
                                                          alignment: Alignment.center,
                                                          decoration: BoxDecoration(
                                                            color: isSelected
                                                                ? Colors.blueAccent.withOpacity(0.5)
                                                                : (status.isNotEmpty ? cellColor.withOpacity(0.8) : Colors.transparent),
                                                            borderRadius: BorderRadius.circular(6),
                                                            border: Border.all(
                                                              color: isSelected ? Colors.blueAccent : Colors.white24,
                                                              width: isSelected ? 2 : 1,
                                                            ),
                                                          ),
                                                          child: isSelected
                                                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                                                              : FittedBox(
                                                                  fit: BoxFit.scaleDown,
                                                                  child: Text(
                                                                    status,
                                                                    style: const TextStyle(
                                                                      color: Colors.white,
                                                                      fontWeight: FontWeight.bold,
                                                                      fontSize: 12,
                                                                    ),
                                                                  ),
                                                                ),
                                                        ),
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                ),
                                          ],
                                        ),
                                      )
                                    );
                                    return widgets;
                                  }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selectedCells.isNotEmpty
        ? Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedCells.length} Days Selected',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedCells.clear();
                          });
                        },
                        child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _showLegendOptionsDialog,
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text('Mark', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        : null,
    );
  }

  void _startAutoScroll(List<Manpower> filteredPersonnel) {
    if (_autoScrollTimer != null) return;

    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_lastDragPosition == null || _dragFillValue == null) {
        _stopAutoScroll();
        return;
      }

      bool scrolled = false;
      final localPosition = _lastDragPosition!;

      if (_bodyScrollController.hasClients) {
        final double scrollOffset = _bodyScrollController.offset;
        final double viewportWidth = _bodyScrollController.position.viewportDimension;
        final double localX = localPosition.dx - scrollOffset;

        if (localX > viewportWidth - 50) {
          final target = (scrollOffset + 15).clamp(0.0, _bodyScrollController.position.maxScrollExtent);
          if (target != scrollOffset) {
            _bodyScrollController.jumpTo(target);
            scrolled = true;
          }
        } else if (localX < 50) {
          final target = (scrollOffset - 15).clamp(0.0, _bodyScrollController.position.maxScrollExtent);
          if (target != scrollOffset) {
            _bodyScrollController.jumpTo(target);
            scrolled = true;
          }
        }
      }

      if (_verticalScrollController.hasClients) {
        final double scrollOffset = _verticalScrollController.offset;
        final double viewportHeight = _verticalScrollController.position.viewportDimension;
        final double localY = localPosition.dy - scrollOffset;

        if (localY > viewportHeight - 50) {
          final target = (scrollOffset + 15).clamp(0.0, _verticalScrollController.position.maxScrollExtent);
          if (target != scrollOffset) {
            _verticalScrollController.jumpTo(target);
            scrolled = true;
          }
        } else if (localY < 50) {
          final target = (scrollOffset - 15).clamp(0.0, _verticalScrollController.position.maxScrollExtent);
          if (target != scrollOffset) {
            _verticalScrollController.jumpTo(target);
            scrolled = true;
          }
        }
      }

      if (scrolled) {
        String? cellId = _getCellIdFromOffset(localPosition, filteredPersonnel);
        if (cellId != null && !_currentlyDraggingCells.contains(cellId)) {
          final parsed = CellIdParts.parse(cellId, _selectedDate);
          if (parsed != null) {
            final cellDate = DateTime(parsed.year, parsed.month, parsed.day);
            if (!AccessControl.isDateLocked(context, cellDate)) {
              setState(() {
                _currentlyDraggingCells.add(cellId);
              });
            }
          }
        }
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }
}

class CellIdParts {
  final String personId;
  final int year;
  final int month;
  final int day;

  CellIdParts({required this.personId, required this.year, required this.month, required this.day});

  static CellIdParts? parse(String cellId, DateTime defaultDate) {
    final parts = cellId.split('_');
    if (parts.length < 3) return null;

    final dayStr = parts.last;
    final ymStr = parts[parts.length - 2];
    final personId = parts.sublist(0, parts.length - 2).join('_');

    final ymParts = ymStr.split('-');
    final year = ymParts.isNotEmpty ? (int.tryParse(ymParts[0]) ?? defaultDate.year) : defaultDate.year;
    final month = ymParts.length > 1 ? (int.tryParse(ymParts[1]) ?? defaultDate.month) : defaultDate.month;
    final day = int.tryParse(dayStr) ?? 1;

    return CellIdParts(personId: personId, year: year, month: month, day: day);
  }
}
