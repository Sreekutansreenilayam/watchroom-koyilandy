import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/fuel_model.dart';
import '../services/fuel_pdf_service.dart';

class FuelPdfPreviewScreen extends StatelessWidget {
  final FuelLedger ledger;
  final List<FuelTransaction> transactions;

  const FuelPdfPreviewScreen({super.key, required this.ledger, required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fuel Ledger PDF')),
      body: PdfPreview(
        allowSharing: true,
        allowPrinting: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        build: (format) => FuelPdfService.generateStockRegister(ledger, transactions),
      ),
    );
  }
}
