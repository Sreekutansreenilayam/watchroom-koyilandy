import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/manpower_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/duty_provider.dart';
import '../services/dosr_generator.dart';

class DosrScreen extends StatefulWidget {
  const DosrScreen({super.key});

  @override
  State<DosrScreen> createState() => _DosrScreenState();
}

class _DosrScreenState extends State<DosrScreen> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _majorFireController = TextEditingController(text: '000');
  final TextEditingController _incidentController = TextEditingController(text: '000');
  final TextEditingController _totalCallController = TextEditingController(text: '000');
  final TextEditingController _asstCallController = TextEditingController(text: '000');

  String _generatedReport = '';
  String _whatsappReport = '';
  bool _isGenerating = false;

  int _lastMajorFire = 0;
  int _lastIncident = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedData();

    // Preload data if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().loadAttendanceForMonth(_selectedDate);
      context.read<DutyProvider>().fetchDutyRegisters();
    });
  }

  Future<void> _loadSavedData() async {
    final firestore = FirebaseFirestore.instance;
    final currentDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final yearStr = _selectedDate.year.toString();

    _majorFireController.removeListener(_onMajorFireChanged);
    _incidentController.removeListener(_onIncidentChanged);

    try {
      final dailyDoc = await firestore.collection('dosr_stats').doc('daily_$currentDateStr').get();
      if (dailyDoc.exists) {
        _majorFireController.text = dailyDoc.data()?['major_fire'] ?? '000';
        _incidentController.text = dailyDoc.data()?['incident'] ?? '000';
      } else {
        final prefs = await SharedPreferences.getInstance();
        final savedDate = prefs.getString('dosr_date') ?? '';
        if (savedDate == currentDateStr) {
          _majorFireController.text = prefs.getString('dosr_major_fire') ?? '000';
          _incidentController.text = prefs.getString('dosr_incident') ?? '000';
        } else {
          _majorFireController.text = '000';
          _incidentController.text = '000';
        }
      }

      final yearlyDoc = await firestore.collection('dosr_stats').doc('yearly_$yearStr').get();
      if (yearlyDoc.exists) {
        _totalCallController.text = yearlyDoc.data()?['total_call'] ?? '000';
        _asstCallController.text = yearlyDoc.data()?['asst_call'] ?? '000';
      } else {
        final prefs = await SharedPreferences.getInstance();
        _totalCallController.text = prefs.getString('dosr_total_call') ?? '000';
        _asstCallController.text = prefs.getString('dosr_asst_call') ?? '000';
      }
    } catch (e) {
      debugPrint("Error loading DOSR stats: $e");
    }

    _lastMajorFire = int.tryParse(_majorFireController.text) ?? 0;
    _lastIncident = int.tryParse(_incidentController.text) ?? 0;

    _majorFireController.addListener(_onMajorFireChanged);
    _incidentController.addListener(_onIncidentChanged);
  }

  @override
  void dispose() {
    _majorFireController.removeListener(_onMajorFireChanged);
    _incidentController.removeListener(_onIncidentChanged);
    _majorFireController.dispose();
    _incidentController.dispose();
    _totalCallController.dispose();
    _asstCallController.dispose();
    super.dispose();
  }

  void _onMajorFireChanged() {
    int current = int.tryParse(_majorFireController.text) ?? 0;
    int diff = current - _lastMajorFire;
    if (diff != 0) {
      int total = int.tryParse(_totalCallController.text) ?? 0;
      total += diff;
      if (total < 0) total = 0;
      _totalCallController.text = total.toString().padLeft(3, '0');
      _lastMajorFire = current;
    }
  }

  void _onIncidentChanged() {
    int current = int.tryParse(_incidentController.text) ?? 0;
    int diff = current - _lastIncident;
    if (diff != 0) {
      int total = int.tryParse(_totalCallController.text) ?? 0;
      total += diff;
      if (total < 0) total = 0;
      _totalCallController.text = total.toString().padLeft(3, '0');
      _lastIncident = current;
    }
  }

  Future<void> _generateReport() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final currentDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final yearStr = _selectedDate.year.toString();

      await firestore.collection('dosr_stats').doc('daily_$currentDateStr').set({
        'major_fire': _majorFireController.text.trim(),
        'incident': _incidentController.text.trim(),
      });

      await firestore.collection('dosr_stats').doc('yearly_$yearStr').set({
        'total_call': _totalCallController.text.trim(),
        'asst_call': _asstCallController.text.trim(),
      });

      final manpowerProvider = context.read<ManpowerProvider>();
      final attendanceProvider = context.read<AttendanceProvider>();
      final dutyProvider = context.read<DutyProvider>();

      // Wait a moment for UI to show loading if needed
      await Future.delayed(const Duration(milliseconds: 300));

      final generator = DosrGenerator(
        manpowerProvider: manpowerProvider,
        attendanceProvider: attendanceProvider,
        dutyProvider: dutyProvider,
      );

      final report = generator.generateReport(
        date: _selectedDate,
        majorFire: _majorFireController.text.trim(),
        incident: _incidentController.text.trim(),
        totalCall: _totalCallController.text.trim(),
        asstCall: _asstCallController.text.trim(),
        forWhatsApp: false,
      );

      final waReport = generator.generateReport(
        date: _selectedDate,
        majorFire: _majorFireController.text.trim(),
        incident: _incidentController.text.trim(),
        totalCall: _totalCallController.text.trim(),
        asstCall: _asstCallController.text.trim(),
        forWhatsApp: true,
      );

      setState(() {
        _generatedReport = report;
        _whatsappReport = waReport;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating report: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _shareReport() {
    if (_whatsappReport.isNotEmpty) {
      final formattedReport = '```\n$_whatsappReport\n```';
      Share.share(formattedReport);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _generatedReport = ''; // Clear preview on date change
        _whatsappReport = '';
      });
      await _loadSavedData();
      if (mounted) {
        context.read<AttendanceProvider>().loadAttendanceForMonth(_selectedDate);
      }
    }
  }

  Widget _buildCounterField(String label, TextEditingController controller, {bool showButtons = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blueAccent),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          prefixIcon: showButtons
              ? IconButton(
                  icon: const Icon(Icons.remove, color: Colors.white54),
                  onPressed: () {
                    int val = int.tryParse(controller.text) ?? 0;
                    if (val > 0) {
                      controller.text = (val - 1).toString().padLeft(3, '0');
                    }
                  },
                )
              : null,
          suffixIcon: showButtons
              ? IconButton(
                  icon: const Icon(Icons.add, color: Colors.white54),
                  onPressed: () {
                    int val = int.tryParse(controller.text) ?? 0;
                    controller.text = (val + 1).toString().padLeft(3, '0');
                  },
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('DOSR Generator', style: TextStyle(fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 20),

            // Incident Inputs
            Row(
              children: [
                Expanded(child: _buildCounterField('Major Fire', _majorFireController)),
                const SizedBox(width: 12),
                Expanded(child: _buildCounterField('Incident (e.g. 01 accident)', _incidentController)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildCounterField('Total Call (${_selectedDate.year})', _totalCallController, showButtons: false)),
                const SizedBox(width: 12),
                Expanded(child: _buildCounterField('Asst Call', _asstCallController)),
              ],
            ),
            const SizedBox(height: 8),

            // Generate Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateReport,
                icon: _isGenerating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.article, color: Colors.white),
                label: Text(
                  _isGenerating ? 'Generating...' : 'Generate DOSR Report',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Preview Box
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: _generatedReport.isEmpty
                    ? const Center(
                        child: Text(
                          'Report preview will appear here',
                          style: TextStyle(color: Colors.white38),
                        ),
                      )
                    : SingleChildScrollView(
                        child: SelectableText(
                          _generatedReport,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _generatedReport.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _shareReport,
              backgroundColor: Colors.green,
              icon: const Icon(Icons.share, color: Colors.white),
              label: const Text('Share to WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}
