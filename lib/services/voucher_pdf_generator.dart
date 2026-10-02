import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/voucher_model.dart';
import '../config/app_config.dart';


class VoucherPdfGenerator {
  static Future<Uint8List> generateVoucher(VoucherModel voucher) async {
    final pdf = pw.Document();

    final dateFormat = DateFormat('dd/MM/yyyy');
    String issueDateStr = voucher.issueDate != null ? dateFormat.format(voucher.issueDate!) : '........ / ........ / 20........';
    String receiptDateStr = voucher.receiptDate != null ? dateFormat.format(voucher.receiptDate!) : '........ / ........ / 20........';

    // Signatures formatting
    String formatSigDate(DateTime? d) => d != null ? dateFormat.format(d) : '................................';
    String s(String text) => text.isNotEmpty ? text : '................................';
    String sLong(String text) => text.isNotEmpty ? text : '..................................................'; // 50 dots

    // ... inside build:
    final doc = pw.Document();
    
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('RECEIPT/ISSUE VOUCHER', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline, fontSize: 14)),
              pw.SizedBox(height: 4),
              pw.Text(AppConfig.stationName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline, fontSize: 14)),
              pw.SizedBox(height: 16),
              
              pw.Container(
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Row 1
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(), bottom: pw.BorderSide())),
                            child: pw.Text('To be completed by issuing officer', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          )
                        ),
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide())),
                            child: pw.Text('To be completed by receiving officer'),
                          )
                        )
                      ]
                    ),
                    // Row 2
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(), bottom: pw.BorderSide())),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('IV No: ${sLong(voucher.ivNo)}'),
                                pw.SizedBox(height: 10),
                                pw.Text('Date: $issueDateStr'),
                                pw.SizedBox(height: 10),
                                pw.Text('Station: ${sLong(voucher.issueStation)}'),
                              ]
                            ),
                          )
                        ),
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide())),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('RV No: ${sLong(voucher.rvNo)}'),
                                pw.SizedBox(height: 10),
                                pw.Text('Date: $receiptDateStr'),
                                pw.SizedBox(height: 10),
                                pw.Text('Station: ${sLong(voucher.receiptStation)}'),
                              ]
                            ),
                          )
                        )
                      ]
                    ),
                    // Row 3 (Merged)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide())),
                      child: pw.Text('The articles enumerated below have been handed/taken over as per details given below:-'),
                    ),
                    // Item Table
                    pw.Table(
                      border: pw.TableBorder.symmetric(inside: const pw.BorderSide()),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(1), // Ser No
                        1: const pw.FlexColumnWidth(1.5), // Ledger Page No
                        2: const pw.FlexColumnWidth(4), // Nomenclature
                        3: const pw.FlexColumnWidth(1), // A/U
                        4: const pw.FlexColumnWidth(1), // Qty
                        5: const pw.FlexColumnWidth(2), // Remarks
                      },
                      children: [
                        pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('Ser\nNo', textAlign: pw.TextAlign.center))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Ledger\nPage\nNo')),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Nomenclature of item/\nItem Description')),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('A/U', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Remarks')),
                          ]
                        ),
                        ...voucher.items.asMap().entries.map((e) {
                          int index = e.key + 1;
                          VoucherItem item = e.value;
                          return pw.TableRow(
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('$index.', textAlign: pw.TextAlign.center))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item.ledgerPageNo)),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item.description)),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text(item.au, textAlign: pw.TextAlign.center))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text(item.qty.toString().padLeft(2, '0'), textAlign: pw.TextAlign.center))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item.remarks)),
                            ]
                          );
                        }),
                        // Add some empty rows to make it look like a form if there are no items
                        if (voucher.items.isEmpty)
                           pw.TableRow(
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('1.', textAlign: pw.TextAlign.center))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('')),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('')),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text(''))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text(''))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('')),
                            ]
                          ),
                      ]
                    )
                  ]
                )
              ),
              pw.SizedBox(height: 16),
              pw.Text('(Total item ${_numberToWords(voucher.items.length)} only)'),
              pw.SizedBox(height: 48),

              // Signatures
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _buildSignatureSection(
                      title: 'ISSUED BY',
                      data: {
                        'ID No': s(voucher.issuedByIdNo),
                        'Designation': s(voucher.issuedByDesignation),
                        'Name': s(voucher.issuedByName),
                        'Station Name': s(voucher.issuedByStation),
                        'Mobil No': s(voucher.issuedByMobile),
                        'Date': formatSigDate(voucher.issuedByDate),
                      },
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  pw.Expanded(
                    child: _buildSignatureSection(
                      title: 'RECEIVED BY',
                      data: {
                        'ID No': s(voucher.receivedByIdNo),
                        'Designation': s(voucher.receivedByDesignation),
                        'Name': s(voucher.receivedByName),
                        'Station Name': s(voucher.receivedByStation),
                        'Mobil No': s(voucher.receivedByMobile),
                        'Date': formatSigDate(voucher.receivedByDate),
                      },
                    ),
                  ),
                ]
              )
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildSignatureSection({required String title, required Map<String, String> data}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
        pw.SizedBox(height: 12),
        pw.Table(
          columnWidths: {
            0: const pw.IntrinsicColumnWidth(),
            1: const pw.FixedColumnWidth(10),
            2: const pw.FlexColumnWidth(),
          },
          children: data.entries.map((e) => pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(e.key),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(':'),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(e.value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ),
            ]
          )).toList()
        )
      ]
    );
  }

  static String _numberToWords(int number) {
    if (number == 0) return 'zero';
    const ones = ['', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen'];
    const tens = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];
    
    if (number < 20) return ones[number];
    if (number < 100) return '${tens[number ~/ 10]}${number % 10 != 0 ? ' ${ones[number % 10]}' : ''}';
    return number.toString();
  }
}
