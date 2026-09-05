import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:screenshot/screenshot.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../providers/fire_report_provider.dart';

class HoseRegisterPdfGenerator {
  static Future<Uint8List> generatePdf(BuildContext context, String hoseName) async {
    final pdf = pw.Document();
    final screenshotController = ScreenshotController();

    Widget tableCell(String text, {bool isHeader = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isHeader ? 14 : 12,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              height: 1.2,
            ),
          ),
        ),
      );
    }

    final fireReportProvider = Provider.of<FireReportProvider>(context, listen: false);
    final allReports = fireReportProvider.reports;
    
    // Filter reports where hoseNo contains the selected hoseName (case-insensitive)
    final relevantReports = allReports.where((r) => r.hoseNo.toLowerCase().contains(hoseName.toLowerCase().trim())).toList();
    // Sort oldest first
    relevantReports.sort((a, b) => a.date.compareTo(b.date));

    final int rowsCount = 28;

    Widget page1 = Container(
      color: Colors.white,
      width: 794, // A4 width
      height: 1123, // Fixed A4 height
      padding: const EdgeInsets.all(48),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.black, fontFamily: 'NotoSansMalayalam', height: 1.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'STOCK REGISTER OF ${hoseName.toUpperCase()}',
              style: const TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
            const SizedBox(height: 20),
            Table(
              border: TableBorder.all(color: Colors.black),
              columnWidths: const {
                0: FlexColumnWidth(1.5),
                1: FlexColumnWidth(3),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
                4: FlexColumnWidth(1.5),
                5: FlexColumnWidth(1.5),
              },
              children: [
                TableRow(
                  children: [
                    tableCell('തീയതി', isHeader: true),
                    tableCell('ഉപയോഗിച്ച വിവരം', isHeader: true),
                    tableCell('ഉപയോഗ സമയം\n(മണിക്കൂർ മിനിറ്റ്)', isHeader: true),
                    tableCell('ന്യൂനത', isHeader: true),
                    tableCell('തിരികെ\nഎത്തിയത്', isHeader: true),
                    tableCell('ഒപ്പ്', isHeader: true),
                  ],
                ),
                for (int i = 0; i < rowsCount; i++)
                  if (i < relevantReports.length)
                    TableRow(
                      children: [
                        tableCell('${relevantReports[i].date.day.toString().padLeft(2, '0')}/${relevantReports[i].date.month.toString().padLeft(2, '0')}/${relevantReports[i].date.year}'),
                        tableCell(relevantReports[i].reportNumber),
                        tableCell('${relevantReports[i].totalWorkingHours} hr ${relevantReports[i].totalWorkingMinutes} min'),
                        tableCell('-'),
                        tableCell('-'),
                        tableCell(''),
                      ],
                    )
                  else
                    TableRow(
                      children: [
                        tableCell(''),
                        tableCell(''),
                        tableCell(''),
                        tableCell(''),
                        tableCell(''),
                        tableCell(''),
                      ],
                    ),
              ],
            ),
          ],
        ),
      ),
    );

    final Uint8List image1 = await screenshotController.captureFromWidget(
      Directionality(
        textDirection: ui.TextDirection.ltr,
        child: FittedBox(
          fit: BoxFit.contain,
          child: page1,
        ),
      ),
      context: context,
      delay: const Duration(milliseconds: 100),
      pixelRatio: 6.0,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Align(
            alignment: pw.Alignment.topCenter,
            child: pw.Image(pw.MemoryImage(image1), fit: pw.BoxFit.contain),
          );
        },
      ),
    );

    return pdf.save();
  }
}
