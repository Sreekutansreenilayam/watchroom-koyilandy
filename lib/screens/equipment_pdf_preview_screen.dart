import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../services/equipment_pdf_generator.dart';

class EquipmentPdfPreviewScreen extends StatelessWidget {
  final List<String> categories;
  final bool includeDetails;
  final bool showCategoryColumn;
  final bool groupByCategory;

  const EquipmentPdfPreviewScreen({
    super.key,
    required this.categories,
    required this.includeDetails,
    required this.showCategoryColumn,
    this.groupByCategory = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equipment Report PDF')),
      body: PdfPreview(
        build: (format) => EquipmentPdfGenerator.generateEquipmentReportPdf(
          categories: categories,
          includeDetails: includeDetails,
          showCategoryColumn: showCategoryColumn,
          groupByCategory: groupByCategory,
        ),
      ),
    );
  }
}
