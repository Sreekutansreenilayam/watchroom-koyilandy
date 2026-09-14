import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/sentry_register_model.dart';
import '../services/sentry_pdf_generator.dart';
import 'package:provider/provider.dart';
import '../providers/manpower_provider.dart';
import '../providers/sentry_provider.dart';

class SentryPdfPreviewScreen extends StatelessWidget {
  final SentryRegisterModel dayRegister;

  const SentryPdfPreviewScreen({super.key, required this.dayRegister});

  @override
  Widget build(BuildContext context) {
    final manpowerProvider = context.read<ManpowerProvider>();
    final sentryProvider = context.read<SentryProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Sentry Register PDF')),
      body: PdfPreview(
        allowSharing: true,
        allowPrinting: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        build: (format) => SentryPdfGenerator.generatePdf(
          monthDate: dayRegister.date,
          dayRegister: dayRegister,
          monthRegisters: sentryProvider.registers,
          personnelList: manpowerProvider.personnelList,
          exemptions: sentryProvider.globalExemptions,
        ),
      ),
    );
  }
}
