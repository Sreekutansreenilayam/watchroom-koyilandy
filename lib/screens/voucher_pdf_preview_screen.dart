import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/voucher_model.dart';
import '../services/voucher_pdf_generator.dart';

class VoucherPdfPreviewScreen extends StatelessWidget {
  final VoucherModel voucher;

  const VoucherPdfPreviewScreen({super.key, required this.voucher});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voucher PDF')),
      body: PdfPreview(
        allowSharing: true,
        allowPrinting: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        build: (format) => VoucherPdfGenerator.generateVoucher(voucher),
      ),
    );
  }
}
