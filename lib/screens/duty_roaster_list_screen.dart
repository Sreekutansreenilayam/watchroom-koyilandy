import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/duty_provider.dart';
import 'duty_roaster_pdf_preview_screen.dart';

class DutyRoasterListScreen extends StatefulWidget {
  const DutyRoasterListScreen({super.key});

  @override
  State<DutyRoasterListScreen> createState() => _DutyRoasterListScreenState();
}

class _DutyRoasterListScreenState extends State<DutyRoasterListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DutyProvider>().fetchDutyRegisters();
    });
  }

  List<Map<String, dynamic>> _getAvailableMonths(DutyProvider provider) {
    // Extract unique year-month combinations from actual registers
    final Set<String> uniqueMonths = {};
    final DateTime cutoffDate = DateTime(2026, 7, 1);

    for (var reg in provider.registers) {
      if (reg.date.isBefore(cutoffDate)) continue; // Skip test records before July 2026

      final monthStr = DateFormat('yyyy-MM').format(reg.date);
      uniqueMonths.add(monthStr);
    }

    // Sort descending (newest first)
    final sortedMonths = uniqueMonths.toList()..sort((a, b) => b.compareTo(a));

    List<Map<String, dynamic>> intervals = [];
    for (var mStr in sortedMonths) {
      final parts = mStr.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      DateTime firstDay = DateTime(year, month, 1);
      int lastDay = DateTime(year, month + 1, 0).day;
      DateTime endDay = DateTime(year, month, lastDay);

      intervals.add({
        'title': DateFormat('MMM yyyy').format(firstDay),
        'startDate': firstDay,
        'endDate': endDay,
      });
    }

    return intervals;
  }

  @override
  Widget build(BuildContext context) {
    final dutyProvider = context.watch<DutyProvider>();
    final intervals = _getAvailableMonths(dutyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Duty Roaster (Month-Wise)', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.5,
            colors: [Color(0xFF2C0B0B), Color(0xFF0A0A0A)],
          ),
        ),
        child: SafeArea(
          child: dutyProvider.isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
              : intervals.isEmpty
                  ? const Center(child: Text('No duty registers found.', style: TextStyle(color: Colors.white70)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: intervals.length,
                      itemBuilder: (context, index) {
                        final interval = intervals[index];
                        return Card(
                          color: const Color(0xFF1E1E1E),
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.amber.withOpacity(0.2),
                              child: const Icon(Icons.date_range, color: Colors.amber),
                            ),
                            title: Text(interval['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            trailing: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DutyRoasterPdfPreviewScreen(
                                    startDate: interval['startDate'],
                                    endDate: interval['endDate'],
                                    title: interval['title'],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
