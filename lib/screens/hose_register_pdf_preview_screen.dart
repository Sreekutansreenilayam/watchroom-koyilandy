import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../services/hose_register_pdf_generator.dart';

class HoseRegisterPdfPreviewScreen extends StatelessWidget {
  final String hoseName;

  const HoseRegisterPdfPreviewScreen({super.key, required this.hoseName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hose Register PDF')),
      body: PdfPreview(
        build: (format) => HoseRegisterPdfGenerator.generatePdf(context, hoseName),
      ),
    );
  }
}
