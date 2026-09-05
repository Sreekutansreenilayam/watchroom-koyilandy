import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/fire_report_provider.dart';
import '../providers/manpower_provider.dart';
import 'fire_report_form_screen.dart';
import 'fire_report_pdf_preview_screen.dart';

class FireReportScreen extends StatelessWidget {
  const FireReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FireReportProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Fire Reports', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: provider.isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
        : provider.reports.isEmpty
            ? const Center(child: Text('No Fire Reports found.', style: TextStyle(color: Colors.white70)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: provider.reports.length,
                itemBuilder: (context, index) {
                  final report = provider.reports[index];
                  return Card(
                    color: const Color(0xFF1E1E1E),
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text('FR No - ${report.reportNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          '${report.location} / ${DateFormat('dd/MM/yyyy').format(report.date)}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.blueAccent),
                            onPressed: () async {
                              final manpowerList = context.read<ManpowerProvider>().getActivePersonnelForDate(report.date);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FireReportPdfPreviewScreen(report: report),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white70),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => FireReportFormScreen(existingReport: report)));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: const Color(0xFF2C2C2C),
                                  title: const Text('Delete Report?', style: TextStyle(color: Colors.white)),
                                  content: const Text('Are you sure you want to delete this fire report?', style: TextStyle(color: Colors.white70)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
                                  ],
                                )
                              );
                              if (confirm == true) {
                                provider.deleteReport(report.id);
                              }
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => FireReportFormScreen(existingReport: report)));
                      },
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const FireReportFormScreen()));
        },
      ),
    );
  }
}
