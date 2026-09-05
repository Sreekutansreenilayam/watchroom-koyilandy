import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' as material;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/equipment_model.dart';
import 'text_to_image_service.dart';

class EquipmentPdfGenerator {
  static Future<Uint8List> generateEquipmentReportPdf({
    required List<String> categories,
    required bool includeDetails,
    required bool showCategoryColumn,
    bool groupByCategory = false,
  }) async {
    final pdf = pw.Document();
    
    // Fetch Data
    final firestore = FirebaseFirestore.instance;
    final headSnapshot = await firestore.collection('equipment_heads').get();
    
    var heads = headSnapshot.docs.map((doc) => EquipmentHead.fromMap(doc.data(), doc.id)).toList();
    
    heads = heads.where((head) => categories.contains(head.category)).toList();
    
    // Pre-render texts
    final reportTitleImg = pw.MemoryImage(await TextToImageService.convertTextToImage(
      'ഉപകരണങ്ങളുടെ റിപ്പോർട്ട് (EQUIPMENT REPORT)',
      fontSize: 36,
      fontWeight: material.FontWeight.bold,
    ));
    
    final dateImg = pw.MemoryImage(await TextToImageService.convertTextToImage(
      'തീയതി: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}',
      fontSize: 24,
    ));

    final colNameImg = pw.MemoryImage(await TextToImageService.convertTextToImage('ഉപകരണം', fontSize: 24, fontWeight: material.FontWeight.bold));
    final colCategoryImg = pw.MemoryImage(await TextToImageService.convertTextToImage('വിഭാഗം', fontSize: 24, fontWeight: material.FontWeight.bold));
    final colTotalImg = pw.MemoryImage(await TextToImageService.convertTextToImage('ആകെ എണ്ണം', fontSize: 24, fontWeight: material.FontWeight.bold));
    final colServImg = pw.MemoryImage(await TextToImageService.convertTextToImage('ഉപയോഗപ്രദം', fontSize: 24, fontWeight: material.FontWeight.bold));
    final colUnservImg = pw.MemoryImage(await TextToImageService.convertTextToImage('കേടായത്', fontSize: 24, fontWeight: material.FontWeight.bold));

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
        ),
        build: (pw.Context context) {
          return [
            pw.Center(child: pw.Image(reportTitleImg, height: 20)),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Categories: ${categories.length > 3 ? "${categories.length} selected" : categories.map((c) => c.split(' (')[0]).join(", ")}', 
                  style: const pw.TextStyle(fontSize: 10)
                ),
                pw.Image(dateImg, height: 12),
              ],
            ),
            pw.SizedBox(height: 15),
            
            if (!groupByCategory)
              pw.Table(
                border: pw.TableBorder.all(width: 1, color: PdfColors.black),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(3),
                  if (showCategoryColumn) 2: pw.FlexColumnWidth(3),
                  if (showCategoryColumn) 3: pw.FlexColumnWidth(2) else 2: pw.FlexColumnWidth(2),
                  if (showCategoryColumn) 4: pw.FlexColumnWidth(2) else 3: pw.FlexColumnWidth(2),
                  if (showCategoryColumn) 5: pw.FlexColumnWidth(2) else 4: pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('SI No', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Image(colNameImg, height: 12))),
                      if (showCategoryColumn) pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Image(colCategoryImg, height: 12))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Image(colTotalImg, height: 12))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Image(colServImg, height: 12))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Image(colUnservImg, height: 12))),
                    ],
                  ),
                  ...heads.asMap().entries.map((entry) {
                    int idx = entry.key;
                    EquipmentHead head = entry.value;
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('${idx + 1}', style: const pw.TextStyle(fontSize: 10)))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(head.name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                        if (showCategoryColumn) pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(head.category.split(' (')[0], style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('${head.totalQty}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('${head.serviceableQty}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.green)))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('${head.unserviceableQty}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.red)))),
                      ],
                    );
                  }),
                ],
              )
            else
              ...(() {
                Map<String, List<EquipmentHead>> grouped = {};
                for (var head in heads) {
                  grouped.putIfAbsent(head.category, () => []).add(head);
                }
                List<pw.Widget> widgets = [];
                grouped.forEach((category, items) {
                  widgets.add(pw.Text(category.split(' (')[0], style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)));
                  widgets.add(pw.SizedBox(height: 5));
                  widgets.add(pw.Table(
                    border: pw.TableBorder.all(width: 1, color: PdfColors.black),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1),
                      1: const pw.FlexColumnWidth(3),
                      2: const pw.FlexColumnWidth(2),
                      3: const pw.FlexColumnWidth(2),
                      4: const pw.FlexColumnWidth(2),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('SI No', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Image(colNameImg, height: 12))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Image(colTotalImg, height: 12))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Image(colServImg, height: 12))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Image(colUnservImg, height: 12))),
                        ],
                      ),
                      ...items.asMap().entries.map((entry) {
                        int idx = entry.key;
                        EquipmentHead head = entry.value;
                        return pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('${idx + 1}', style: const pw.TextStyle(fontSize: 10)))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(head.name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('${head.totalQty}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('${head.serviceableQty}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.green)))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('${head.unserviceableQty}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.red)))),
                          ],
                        );
                      }),
                    ],
                  ));
                  widgets.add(pw.SizedBox(height: 15));
                });
                return widgets;
              })(),
          ];
        },
      ),
    );

    if (includeDetails) {
      List<Map<String, dynamic>> allRows = [];

      for (var head in heads) {
        final stockQuery = await firestore.collection('equipment_entries').where('headId', isEqualTo: head.id).get();
        final historyQuery = await firestore.collection('equipment_history').where('headId', isEqualTo: head.id).get();
        
        final stocks = stockQuery.docs.map((doc) => EquipmentStockEntry.fromMap(doc.data(), doc.id)).toList();
        final histories = historyQuery.docs.map((doc) => EquipmentHistory.fromMap(doc.data(), doc.id)).toList();

        for (var s in stocks) {
          allRows.add({
            'date': s.dateTakenIntoCharge,
            'name': head.name,
            'category': head.category,
            'type': 'STOCK ENTRY',
            'invoice': s.invoiceNo,
            'qty': s.quantity,
            'brand': s.brand,
            'assigned': s.assignedTo,
            'remarks': '',
          });
        }
        for (var h in histories) {
          allRows.add({
            'date': h.fromDate,
            'name': head.name,
            'category': head.category,
            'type': h.type == 'STATUS_CHANGE' ? h.status : 'TEMP_ISSUE',
            'invoice': h.voucherNumber ?? '',
            'qty': h.quantityAffected,
            'brand': '',
            'assigned': '',
            'remarks': h.remarks,
          });
        }
      }

      if (allRows.isNotEmpty) {
        // Sort by Item Name first, then by Date descending
        allRows.sort((a, b) {
          int nameCompare = (a['name'] as String).compareTo(b['name'] as String);
          if (nameCompare != 0) return nameCompare;
          return (b['date'] as DateTime).compareTo(a['date'] as DateTime);
        });

        pdf.addPage(
          pw.MultiPage(
            pageTheme: pw.PageTheme(
              pageFormat: PdfPageFormat.a4.landscape,
              margin: const pw.EdgeInsets.all(30),
            ),
            build: (pw.Context context) {
              return [
                pw.Text('Detailed Stock & History Report', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                if (!groupByCategory)
                  pw.Table(
                    border: pw.TableBorder.all(width: 1, color: PdfColors.black),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2),
                      1: const pw.FlexColumnWidth(3),
                      if (showCategoryColumn) 2: pw.FlexColumnWidth(2),
                      if (showCategoryColumn) 3: pw.FlexColumnWidth(2) else 2: pw.FlexColumnWidth(2),
                      if (showCategoryColumn) 4: pw.FlexColumnWidth(2) else 3: pw.FlexColumnWidth(2),
                      if (showCategoryColumn) 5: pw.FlexColumnWidth(1) else 4: pw.FlexColumnWidth(1),
                      if (showCategoryColumn) 6: pw.FlexColumnWidth(2) else 5: pw.FlexColumnWidth(2),
                      if (showCategoryColumn) 7: pw.FlexColumnWidth(2) else 6: pw.FlexColumnWidth(2),
                      if (showCategoryColumn) 8: pw.FlexColumnWidth(3) else 7: pw.FlexColumnWidth(3),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('Date', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('Equipment Name', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                          if (showCategoryColumn) pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('Category', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('Entry Type', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('Invoice/Voucher', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('Qty', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('Brand/Make', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('Assigned To', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('Remarks', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                        ],
                      ),
                      ...allRows.map((r) => pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(DateFormat('dd/MM/yyyy').format(r['date'] as DateTime), style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r['name'] as String, style: const pw.TextStyle(fontSize: 8))),
                          if (showCategoryColumn) pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text((r['category'] as String).split(' (')[0], style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r['type'] as String, style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r['invoice'] as String, style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('${r['qty']}', style: const pw.TextStyle(fontSize: 8)))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r['brand'] as String, style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r['assigned'] as String, style: const pw.TextStyle(fontSize: 8))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r['remarks'] as String, style: const pw.TextStyle(fontSize: 8))),
                        ],
                      )),
                    ],
                  )
                else
                  ...(() {
                    Map<String, List<Map<String, dynamic>>> grouped = {};
                    for (var r in allRows) {
                      grouped.putIfAbsent(r['category'] as String, () => []).add(r);
                    }
                    List<pw.Widget> widgets = [];
                    grouped.forEach((category, items) {
                      widgets.add(pw.Text(category.split(' (')[0], style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)));
                      widgets.add(pw.SizedBox(height: 5));
                      widgets.add(pw.Table(
                        border: pw.TableBorder.all(width: 1, color: PdfColors.black),
                        columnWidths: {
                          0: const pw.FlexColumnWidth(2), // Date
                          1: const pw.FlexColumnWidth(3), // Name
                          2: const pw.FlexColumnWidth(2), // Type
                          3: const pw.FlexColumnWidth(2), // Invoice
                          4: const pw.FlexColumnWidth(1), // Qty
                          5: const pw.FlexColumnWidth(2), // Brand
                          6: const pw.FlexColumnWidth(2), // Assigned
                          7: const pw.FlexColumnWidth(3), // Remarks
                        },
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('Date', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('Equipment Name', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('Entry Type', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('Invoice/Voucher', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('Qty', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('Brand/Make', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('Assigned To', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('Remarks', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                            ],
                          ),
                          ...items.map((r) => pw.TableRow(
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(DateFormat('dd/MM/yyyy').format(r['date'] as DateTime), style: const pw.TextStyle(fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r['name'] as String, style: const pw.TextStyle(fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r['type'] as String, style: const pw.TextStyle(fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r['invoice'] as String, style: const pw.TextStyle(fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('${r['qty']}', style: const pw.TextStyle(fontSize: 8)))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r['brand'] as String, style: const pw.TextStyle(fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r['assigned'] as String, style: const pw.TextStyle(fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r['remarks'] as String, style: const pw.TextStyle(fontSize: 8))),
                            ],
                          )),
                        ],
                      ));
                      widgets.add(pw.SizedBox(height: 15));
                    });
                    return widgets;
                  })(),
              ];
            },
          ),
        );
      }
    }

    return pdf.save();
  }
}
