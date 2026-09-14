import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import '../providers/manpower_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/duty_provider.dart';
import '../services/paradestate_pdf_generator.dart';

class FridayParadestateScreen extends StatefulWidget {
  const FridayParadestateScreen({super.key});

  @override
  State<FridayParadestateScreen> createState() => _FridayParadestateScreenState();
}

class _FridayParadestateScreenState extends State<FridayParadestateScreen> {
  DateTime _selectedDate = DateTime.now();
  Uint8List? _pdfBytes;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    // Preload data if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().loadAttendanceForMonth(_selectedDate);
      context.read<DutyProvider>().fetchDutyRegisters();
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      selectableDayPredicate: (DateTime date) {
        // Optional: Ensure only Fridays are selectable
        // return date.weekday == DateTime.friday;
        return true;
      }
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _pdfBytes = null; // Clear previous preview
      });
      if (mounted) {
        context.read<AttendanceProvider>().loadAttendanceForMonth(_selectedDate);
      }
    }
  }

  Future<void> _generatePdf() async {
    if (_selectedDate.weekday != DateTime.friday) {
      final formattedDate = DateFormat('dd/MM/yyyy').format(_selectedDate);
      bool? proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Non-Parade Day', style: TextStyle(color: Colors.white)),
          content: Text(
            '$formattedDate is a non parade day or holiday, if you really want to generate this.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('OK', style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        ),
      );

      if (proceed != true) {
        return;
      }
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final manpowerProvider = context.read<ManpowerProvider>();
      final attendanceProvider = context.read<AttendanceProvider>();
      final dutyProvider = context.read<DutyProvider>();

      // Give UI a moment to show loading
      await Future.delayed(const Duration(milliseconds: 200));

      List<String> stationWriterIds = [];
      try {
        final register = dutyProvider.registers.firstWhere((r) =>
          r.date.year == _selectedDate.year &&
          r.date.month == _selectedDate.month &&
          r.date.day == _selectedDate.day
        );
        stationWriterIds = register.stationWriterIds;
      } catch (e) {
        // No register found for today, stationWriterIds remains empty
      }

      final bytes = await ParadestatePdfGenerator.generateParadestatePdf(
        date: _selectedDate,
        attendanceMap: attendanceProvider.attendanceMap,
        prevAttendanceMap: attendanceProvider.prevAttendanceMap,
        personnelList: manpowerProvider.getActivePersonnelForDate(_selectedDate),
        stationWriterIds: stationWriterIds,
      );

      setState(() {
        _pdfBytes = bytes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Friday Paradestate', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Date Selector
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.blueAccent, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'Date: ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                    const Icon(Icons.edit, color: Colors.white54, size: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Generate Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generatePdf,
                icon: _isGenerating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf, color: Colors.white),
                label: Text(
                  _isGenerating ? 'Generating...' : 'Generate Paradestate PDF',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // PDF Preview
            Expanded(
              child: _pdfBytes == null
                  ? Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF121212),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Center(
                        child: Text(
                          'Click generate to preview Paradestate PDF',
                          style: TextStyle(color: Colors.white38),
                        ),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: PdfPreview(
        allowSharing: true,
        allowPrinting: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
                        build: (format) => _pdfBytes!,
                        
                        
                        
                        
                        initialPageFormat: PdfPageFormat.a4.landscape,
                        pdfFileName: 'Paradestate_${DateFormat('dd_MM_yyyy').format(_selectedDate)}.pdf',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
