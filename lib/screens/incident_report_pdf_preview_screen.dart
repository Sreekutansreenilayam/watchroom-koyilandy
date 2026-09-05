import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/incident_report_model.dart';
import '../services/incident_report_pdf_generator.dart';
import 'package:provider/provider.dart';
import '../providers/manpower_provider.dart';

class IncidentReportPdfPreviewScreen extends StatelessWidget {
  final IncidentReportModel report;

  const IncidentReportPdfPreviewScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final manProvider = context.read<ManpowerProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Incident Report PDF')),
      body: PdfPreview(
        build: (format) => IncidentReportPdfGenerator.generatePdf(
          context,
          report,
          manProvider.personnelList,
        ),
      ),
    );
  }
}
