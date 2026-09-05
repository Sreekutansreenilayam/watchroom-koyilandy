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

  @override
  Widget build(BuildContext context) {
    final monthRegisters = widget.allRegisters
        .where((r) => r.date.year == _selectedMonth.year && r.date.month == _selectedMonth.month)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Duty History'),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left, color: Colors.orange), onPressed: _previousMonth),
                Text(DateFormat('MMMM yyyy').format(_selectedMonth), style: const TextStyle(color: Colors.white, fontSize: 18)),
                IconButton(icon: const Icon(Icons.chevron_right, color: Colors.orange), onPressed: _nextMonth),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: monthRegisters.length,
              itemBuilder: (context, index) {
                final reg = monthRegisters[index];
                return ListTile(
                  title: Text(DateFormat('dd-MMM-yyyy').format(reg.date), style: const TextStyle(color: Colors.white)),
                  subtitle: Text('Duties: \${reg.slots.length}', style: const TextStyle(color: Colors.white70)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
