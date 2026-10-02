import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/fuel_model.dart';
import 'package:intl/intl.dart';

import 'dart:typed_data';
import '../config/app_config.dart';

class FuelPdfService {
  static Future<Uint8List> generateStockRegister(FuelLedger ledger, List<FuelTransaction> transactions) async {
    final pdf = pw.Document();
    
    // Sort transactions chronologically (oldest first for PDF logic)
    transactions.sort((a, b) {
      int dateComp = a.date.compareTo(b.date);
      if (dateComp != 0) return dateComp;
      int serialA = int.tryParse(a.voucherNumber.split('/').last) ?? 0;
      int serialB = int.tryParse(b.voucherNumber.split('/').last) ?? 0;
      return serialA.compareTo(serialB);
    });

    // Group transactions by month
    Map<String, List<FuelTransaction>> monthlyData = {};
    for (var tx in transactions) {
      String monthKey = DateFormat('MM/yyyy').format(tx.date);
      if (!monthlyData.containsKey(monthKey)) {
        monthlyData[monthKey] = [];
      }
      monthlyData[monthKey]!.add(tx);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(ledger.name),
            pw.SizedBox(height: 20),
            _buildTable(monthlyData),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(String ledgerName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text(
            'STOCK REGISTER OF ${AppConfig.stationName.toUpperCase()}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Name of Article : $ledgerName',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  static pw.Widget _buildTable(Map<String, List<FuelTransaction>> monthlyData) {
    final headers = [
      'Date',
      'No. and\ndate of\nvoucher',
      'From whom received or\nto whom issued',
      'Receipt',
      'Issued',
      'Balance after\neach\ntransaction',
      'Initials',
      'Remarks'
    ];

    List<pw.TableRow> rows = [];
    
    // Header Row
    rows.add(
      pw.TableRow(
        children: headers.map((h) => pw.Container(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
        )).toList(),
      )
    );

    double runningBalance = 0.0;

    monthlyData.forEach((monthKey, txs) {
      // If we have previous months or it's the very first, Opening Balance is the current runningBalance
      // However, if it's the very first transaction ever, running balance before it was (tx.balanceAfter - tx.qty) if receipt etc.
      // For simplicity, we calculate opening balance of the month based on the first transaction of that month.
      final firstTx = txs.first;
      double openingBalance = firstTx.type == 'RECEIPT' 
          ? firstTx.balanceAfter - firstTx.quantity 
          : firstTx.balanceAfter + firstTx.quantity;
          
      // Use runningBalance if this isn't the first month ever being printed
      if (runningBalance != 0.0) openingBalance = runningBalance;

      // Add Opening Balance Row
      String firstDateOfMonth = '01/$monthKey';
      rows.add(_buildBalanceRow(firstDateOfMonth, 'Opening Balance', openingBalance, isOpening: true));

      // Add Transaction Rows
      for (var tx in txs) {
        rows.add(_buildTransactionRow(tx));
        runningBalance = tx.balanceAfter;
      }

      // Add Closing Balance Row only if the month is completed
      DateTime now = DateTime.now();
      bool isMonthCompleted = (txs.last.date.year < now.year) || (txs.last.date.year == now.year && txs.last.date.month < now.month);
      
      if (isMonthCompleted) {
        String lastDateStr = DateFormat('dd/MM/yyyy').format(DateTime(txs.last.date.year, txs.last.date.month + 1, 0));
        rows.add(_buildBalanceRow(lastDateStr, 'Closing Balance', runningBalance, isOpening: false));
      }
    });

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.4),
        1: const pw.FlexColumnWidth(1.9),
        2: const pw.FlexColumnWidth(2.1),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.2),
        5: const pw.FlexColumnWidth(1.6),
        6: const pw.FlexColumnWidth(2.0),
        7: const pw.FlexColumnWidth(1.2),
      },
      children: rows,
    );
  }

  static pw.TableRow _buildBalanceRow(String date, String label, double balance, {required bool isOpening}) {
    final color = isOpening ? PdfColors.green800 : PdfColors.red800;
    return pw.TableRow(
      children: [
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(date, style: pw.TextStyle(color: color, fontSize: 8))),
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: const pw.TextStyle(fontSize: 8))),
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(label, style: pw.TextStyle(color: color, fontSize: 8))),
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: const pw.TextStyle(fontSize: 8))),
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: const pw.TextStyle(fontSize: 8))),
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(balance.toStringAsFixed(2), style: pw.TextStyle(color: color, fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: const pw.TextStyle(fontSize: 8))),
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: const pw.TextStyle(fontSize: 8))),
      ]
    );
  }

  static pw.TableRow _buildTransactionRow(FuelTransaction tx) {
    String date = DateFormat('dd/MM/yyyy').format(tx.date);
    String receipt = tx.type == 'RECEIPT' ? tx.quantity.toStringAsFixed(2) : '';
    String issue = tx.type == 'ISSUE' ? tx.quantity.toStringAsFixed(2) : '';

    String displayParty = tx.party;
    if (displayParty.toLowerCase() != 'opening balance' && 
        !displayParty.toLowerCase().startsWith('issued to') && 
        !displayParty.toLowerCase().startsWith('received from')) {
      if (tx.type == 'ISSUE') {
        displayParty = 'Issued to $displayParty (MTU)';
      } else if (tx.type == 'RECEIPT') {
        displayParty = 'Received from $displayParty';
      }
    }

    return pw.TableRow(
      children: [
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(date, style: const pw.TextStyle(fontSize: 8))),
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(tx.voucherNumber, style: const pw.TextStyle(fontSize: 8))),
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(displayParty, style: const pw.TextStyle(fontSize: 8))),
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(receipt, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(issue, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(tx.balanceAfter.toStringAsFixed(2), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(tx.operatorName, style: const pw.TextStyle(fontSize: 8))),
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(tx.remarks, style: const pw.TextStyle(fontSize: 8))),
      ]
    );
  }
}
