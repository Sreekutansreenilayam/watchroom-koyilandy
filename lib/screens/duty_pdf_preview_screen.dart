import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/duty_register_model.dart';
import '../services/duty_pdf_generator.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/manpower_provider.dart';

class DutyPdfPreviewScreen extends StatelessWidget {
  final DutyRegisterModel register;

  const DutyPdfPreviewScreen({super.key, required this.register});

  @override
  Widget build(BuildContext context) {
    final attProvider = context.read<AttendanceProvider>();
    final manProvider = context.read<ManpowerProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Duty Register PDF')),
      body: PdfPreview(
        allowSharing: true,
        allowPrinting: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        build: (format) => DutyPdfGenerator.generateDutyRegisterPdf(
          register,
          attendanceMap: attProvider.attendanceMap,
          personnelList: manProvider.personnelList,
        ),
      ),
    );
  }
}
