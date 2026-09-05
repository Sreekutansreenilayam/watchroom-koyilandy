import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/fire_report_model.dart';
import '../services/fire_report_pdf_generator.dart';
import 'package:provider/provider.dart';
import '../providers/manpower_provider.dart';

class FireReportPdfPreviewScreen extends StatelessWidget {
  final FireReportModel report;

  const FireReportPdfPreviewScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final manProvider = context.read<ManpowerProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Fire Report PDF')),
      body: PdfPreview(
        build: (format) => FireReportPdfGenerator.generatePdf(
          context,
          report,
          manProvider.personnelList,
        ),
      ),
    );
  }
}
