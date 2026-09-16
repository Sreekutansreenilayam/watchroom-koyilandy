import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/vehicle_model.dart';
import '../models/logbook_model.dart';
import '../providers/logbook_provider.dart';
import '../services/logbook_pdf_generator.dart';
import '../services/access_control.dart';
import '../providers/auth_provider.dart';
import '../providers/manpower_provider.dart';
import 'logbook_form_screen.dart';

class LogbookDetailScreen extends StatefulWidget {
  final VehicleModel vehicle;

  const LogbookDetailScreen({super.key, required this.vehicle});

  @override
  State<LogbookDetailScreen> createState() => _LogbookDetailScreenState();
}

class _LogbookDetailScreenState extends State<LogbookDetailScreen> {
  DateTime _selectedMonth = DateTime.now();
  int? _currentPage;
  final int _itemsPerPage = 15;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  void _fetchData() {
    setState(() {
      _currentPage = null;
    });
    context.read<LogbookProvider>().fetchEntries(widget.vehicle.id, _selectedMonth);
  }

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE53935),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && (picked.month != _selectedMonth.month || picked.year != _selectedMonth.year)) {
      setState(() {
        _selectedMonth = picked;
      });
      _fetchData();
    }
  }

  bool _hasEmergencyCharge(DateTime date, List<LogbookEntry> entries) {
    final linkedPersonId = context.read<AuthProvider>().linkedPersonId;
    if (linkedPersonId == null || linkedPersonId.isEmpty) return false;

    final manpowerList = context.read<ManpowerProvider>().personnelList;
    try {
      final person = manpowerList.firstWhere((p) => p.id == linkedPersonId);
      final hasEmergency = entries.any((e) =>
          e.date.year == date.year &&
          e.date.month == date.month &&
          e.date.day == date.day &&
          e.actionType == 'Emergency Taking on Charge' &&
          (e.operatorName.contains(person.name) || e.operatorName.contains(person.idNumber)));
      return hasEmergency;
    } catch (_) {
      return false;
    }
  }

  bool _canEditFull(DateTime dutyDate, List<LogbookEntry> entries) {
    if (AccessControl.isAdmin(context)) return true;
    if (AccessControl.isSfroM(context) && AccessControl.isPresentOnDuty(context, DateTime.now())) return true;

    final activeDates = AccessControl.getActiveDutyDates();
    bool isDutyDateActive = activeDates.any((d) => dutyDate.year == d.year && dutyDate.month == d.month && dutyDate.day == d.day);
    if (!isDutyDateActive) {
      return false; // Driver cannot edit past days
    }

    if (AccessControl.isDriver(context) && AccessControl.isPresentOnDuty(context, dutyDate)) {
      final assignedId = AccessControl.getAssignedVehicleId(context, dutyDate);
      if (assignedId != null) {
        final nameLower = assignedId.replaceAll('-', '').replaceAll(' ', '').toLowerCase();
        final cleanReg = widget.vehicle.regNumber.replaceAll('-', '').replaceAll(' ', '').toLowerCase();
        final cleanType = widget.vehicle.type.replaceAll('-', '').replaceAll(' ', '').toLowerCase();

        if ((cleanReg.isNotEmpty && nameLower.contains(cleanReg)) ||
            (cleanType.isNotEmpty && nameLower.contains(cleanType))) {
          return true;
        }
      }
      if (_hasEmergencyCharge(dutyDate, entries)) {
        return true;
      }
    }
    return false;
  }

  bool _canAddEmergency(DateTime dutyDate) {
    if (AccessControl.isAdmin(context)) return true;

    final activeDates = AccessControl.getActiveDutyDates();
    bool isDutyDateActive = activeDates.any((d) => dutyDate.year == d.year && dutyDate.month == d.month && dutyDate.day == d.day);
    if (!isDutyDateActive) {
      return false; // Driver cannot add emergency for past days
    }

    if (AccessControl.isDriver(context) && AccessControl.isPresentOnDuty(context, dutyDate)) {
      return true;
    }
    return false;
  }

  void _showEditSelectionSheet(BuildContext context, List<LogbookEntry> entries) {
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No entries available to edit this month.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Select Entry to Edit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return ListTile(
                      title: Text(DateFormat('dd/MM/yyyy').format(entry.date), style: const TextStyle(color: Colors.white)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (entry.actionType.isNotEmpty)
                            Text('Action: ${entry.actionType}', style: const TextStyle(color: Colors.amberAccent, fontSize: 13)),
                          if (entry.fromPlace.isNotEmpty || entry.toPlace.isNotEmpty)
                            Text('Route: ${entry.fromPlace.isEmpty ? 'N/A' : entry.fromPlace} -> ${entry.toPlace.isEmpty ? 'N/A' : entry.toPlace}', style: const TextStyle(color: Colors.white70)),
                          if (entry.departureTime.isNotEmpty || entry.arrivalTime.isNotEmpty)
                            Text('Time: ${entry.departureTime.isEmpty ? 'N/A' : entry.departureTime} - ${entry.arrivalTime.isEmpty ? 'N/A' : entry.arrivalTime}', style: const TextStyle(color: Colors.white70)),
                          Text('Distance: ${entry.travelledDistance} km', style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                      trailing: const Icon(Icons.edit, color: Colors.amber),
                      onTap: () async {
                        if (entry.actionType == 'Fuel Receipt') {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'ഈ എൻട്രി ഫ്യുവൽ ലെഡ്ജറിൽ നിന്നും സ്വയമേവ വന്നതാണ്. ഇത് ലോഗ്ബുക്കിൽ നിന്നും തിരുത്താനോ ഡിലീറ്റ് ചെയ്യാനോ സാധിക്കില്ല, അതിനായി ഫ്യുവൽ ലെഡ്ജറിൽ പോകുക.',
                                textAlign: TextAlign.center,
                              ),
                              backgroundColor: Colors.redAccent,
                              duration: Duration(seconds: 4),
                            ),
                          );
                          return;
                        }

                        final canEdit = _canEditFull(entry.dutyDate, entries);
                        final isPresentForEntry = AccessControl.isPresentOnDuty(context, entry.dutyDate);
                        final isAdmin = AccessControl.isAdmin(context);

                        if (!canEdit) {
                          Navigator.pop(context);
                          if (!isPresentForEntry && !isAdmin) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'താങ്കൾ ഇന്ന് ഡ്യൂട്ടിയിൽ ഇല്ലാത്തതിനാൽ എൻട്രികൾ ചേർക്കാൻ അനുമതിയില്ല',
                                  textAlign: TextAlign.center,
                                ),
                                backgroundColor: Colors.redAccent,
                                duration: Duration(seconds: 4),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'You are not authorized to add/edit previous entries for this vehicle today. Please contact SFRO(M) for any assistance.',
                                  textAlign: TextAlign.center,
                                ),
                                backgroundColor: Colors.redAccent,
                                duration: Duration(seconds: 4),
                              ),
                            );
                          }
                          return;
                        }

                        Navigator.pop(context);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LogbookFormScreen(
                              vehicle: widget.vehicle,
                              entryToEdit: entry,
                              selectedDate: entry.date, // keep original date for form
                              canEdit: canEdit,
                              isEmergencyOnly: false,
                            ),
                          ),
                        );
                        _fetchData();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('${widget.vehicle.regNumber} Logbook', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('PDF Preview (Full)')),
                    body: PdfPreview(
                      allowSharing: true,
                      allowPrinting: true,
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      canDebug: false,
                      build: (format) async {
                        return await LogbookPdfGenerator.generatePdf(
                          context,
                          widget.vehicle,
                          context.read<LogbookProvider>().entries,
                          _selectedMonth,
                          pageIndex: -1 // Generates full PDF
                        );
                      },
                    ),
                  ),
                ),
              );
            },
            tooltip: 'View Full PDF',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _selectMonth(context),
            tooltip: 'Select Month',
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.5,
            colors: [
              Color(0xFF2C0B0B),
              Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer<LogbookProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
              }

              int totalPages = (provider.entries.length / _itemsPerPage).ceil();
              if (totalPages == 0) totalPages = 1;

              int displayPage = _currentPage ?? (totalPages - 1);
              if (displayPage >= totalPages) displayPage = totalPages - 1;
              if (displayPage < 0) displayPage = 0;

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: Colors.black26,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('MMMM yyyy').format(_selectedMonth),
                          style: const TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    color: Colors.black12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
                          onPressed: displayPage > 0 ? () {
                            setState(() {
                              _currentPage = displayPage - 1;
                            });
                          } : null,
                        ),
                        Text(
                          'Page ${displayPage + 1} of $totalPages',
                          style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: Colors.white, size: 32),
                          onPressed: displayPage < totalPages - 1 ? () {
                            setState(() {
                              _currentPage = displayPage + 1;
                            });
                          } : null,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: provider.entries.isEmpty
                        ? const Center(
                            child: Text(
                              'ഈ മാസം എൻട്രികൾ ഒന്നും ലഭ്യമല്ല',
                              style: TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                          )
                        : PdfPreview(
                            allowSharing: false,
                            allowPrinting: false,
                            canChangePageFormat: false,
                            canChangeOrientation: false,
                            canDebug: false,
                            useActions: false, // hide default actions
                            maxPageWidth: MediaQuery.of(context).size.width,
                            build: (format) async {
                              return await LogbookPdfGenerator.generatePdf(
                                context,
                                widget.vehicle,
                                provider.entries,
                                _selectedMonth,
                                pageIndex: displayPage,
                                itemsPerPage: _itemsPerPage,
                              );
                            },
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            onPressed: () => _showEditSelectionSheet(context, provider.entries),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            onPressed: () async {
                              final activeDates = AccessControl.getActiveDutyDates();
                              DateTime? allowedDate;
                              bool canFull = false;
                              bool canEmerg = false;

                              for (var d in activeDates) {
                                if (_canEditFull(d, provider.entries)) {
                                  allowedDate = d;
                                  canFull = true;
                                  break;
                                }
                              }

                              if (!canFull) {
                                for (var d in activeDates) {
                                  if (_canAddEmergency(d)) {
                                    allowedDate = d;
                                    canEmerg = true;
                                    break;
                                  }
                                }
                              }

                              if (!canFull && !canEmerg) {
                                final now = DateTime.now();
                                final currentDutyDate = AccessControl.getDutyDate(now);
                                final isPresentToday = AccessControl.isPresentOnDuty(context, currentDutyDate);
                                final isAdmin = AccessControl.isAdmin(context);

                                if (!isPresentToday && !isAdmin) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'താങ്കൾ ഇന്ന് ഡ്യൂട്ടിയിൽ ഇല്ലാത്തതിനാൽ എൻട്രികൾ ചേർക്കാൻ അനുമതിയില്ല',
                                        textAlign: TextAlign.center,
                                      ),
                                      backgroundColor: Colors.redAccent,
                                      duration: Duration(seconds: 4),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'You are not authorized to add/edit previous entries for this vehicle today. Please contact SFRO(M) for any assistance.',
                                        textAlign: TextAlign.center,
                                      ),
                                      backgroundColor: Colors.redAccent,
                                      duration: Duration(seconds: 4),
                                    ),
                                  );
                                }
                                return;
                              }

                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LogbookFormScreen(
                                    vehicle: widget.vehicle,
                                    selectedDate: allowedDate ?? AccessControl.getDutyDate(DateTime.now()), // Default form date to allowed active duty date
                                    canEdit: true,
                                    isEmergencyOnly: !canFull,
                                  ),
                                ),
                              );
                              _fetchData();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
