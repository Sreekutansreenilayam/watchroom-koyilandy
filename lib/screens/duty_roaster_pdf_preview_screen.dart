import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../services/duty_roaster_pdf_generator.dart';
import '../models/duty_register_model.dart';

class DutyRoasterPdfPreviewScreen extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final List<DutyRegisterModel> allRegisters;
  final String title;

  const DutyRoasterPdfPreviewScreen({
    super.key, 
    required this.startDate, 
    required this.endDate, 
    required this.allRegisters, 
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Duty Roaster PDF')),
      body: PdfPreview(
        allowSharing: true,
        allowPrinting: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        build: (format) => DutyRoasterPdfGenerator.generatePdf(
          startDate,
          endDate,
          allRegisters,
          title,
        ),
      ),
    );
  }
}
