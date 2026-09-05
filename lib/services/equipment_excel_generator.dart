import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/equipment_model.dart';

class EquipmentExcelGenerator {
  static Future<void> generateAndShareExcel({
    required List<String> categories,
    required bool includeDetails,
    required bool showCategoryColumn,
    bool groupByCategory = false,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final headSnapshot = await firestore.collection('equipment_heads').get();
    
    var heads = headSnapshot.docs.map((doc) => EquipmentHead.fromMap(doc.data(), doc.id)).toList();
    
    heads = heads.where((head) => categories.contains(head.category)).toList();

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Equipment Report'];
    excel.setDefaultSheet('Equipment Report');

    if (!groupByCategory) {
      // Header
      List<CellValue> headerRow = [
        TextCellValue('SI No'),
        TextCellValue('Equipment Name'),
      ];
      if (showCategoryColumn) headerRow.add(TextCellValue('Category'));
      headerRow.addAll([
        TextCellValue('Total Qty'),
        TextCellValue('Serviceable'),
        TextCellValue('Unserviceable'),
      ]);
      sheetObject.appendRow(headerRow);

      for (int i = 0; i < heads.length; i++) {
        var head = heads[i];
        List<CellValue> dataRow = [
          IntCellValue(i + 1),
          TextCellValue(head.name),
        ];
        if (showCategoryColumn) dataRow.add(TextCellValue(head.category.split(' (')[0]));
        dataRow.addAll([
          IntCellValue(head.totalQty),
          IntCellValue(head.serviceableQty),
          IntCellValue(head.unserviceableQty),
        ]);
        sheetObject.appendRow(dataRow);
      }
    } else {
      Map<String, List<EquipmentHead>> grouped = {};
      for (var head in heads) {
        grouped.putIfAbsent(head.category, () => []).add(head);
      }
      grouped.forEach((category, items) {
        sheetObject.appendRow([TextCellValue(category.split(' (')[0])]);
        List<CellValue> headerRow = [
          TextCellValue('SI No'),
          TextCellValue('Equipment Name'),
          TextCellValue('Total Qty'),
          TextCellValue('Serviceable'),
          TextCellValue('Unserviceable'),
        ];
        sheetObject.appendRow(headerRow);
        for (int i = 0; i < items.length; i++) {
          var head = items[i];
          sheetObject.appendRow([
            IntCellValue(i + 1),
            TextCellValue(head.name),
            IntCellValue(head.totalQty),
            IntCellValue(head.serviceableQty),
            IntCellValue(head.unserviceableQty),
          ]);
        }
        sheetObject.appendRow([]); // empty row for spacing
      });
    }

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

        Sheet detailSheet = excel['Detailed Stock & History'];
        
        if (!groupByCategory) {
          detailSheet.appendRow([TextCellValue('DETAILED STOCK & HISTORY REPORT')]);
          
          List<CellValue> detailHeader = [
            TextCellValue('Date'),
            TextCellValue('Equipment Name'),
          ];
          if (showCategoryColumn) detailHeader.add(TextCellValue('Category'));
          detailHeader.addAll([
            TextCellValue('Entry Type'),
            TextCellValue('Invoice/Voucher'),
            TextCellValue('Qty'),
            TextCellValue('Brand/Make'),
            TextCellValue('Assigned To'),
            TextCellValue('Remarks'),
          ]);
          detailSheet.appendRow(detailHeader);

          for (var r in allRows) {
            List<CellValue> detailRow = [
              TextCellValue(DateFormat('dd/MM/yyyy').format(r['date'] as DateTime)),
              TextCellValue(r['name'] as String),
            ];
            if (showCategoryColumn) detailRow.add(TextCellValue((r['category'] as String).split(' (')[0]));
            detailRow.addAll([
              TextCellValue(r['type'] as String),
              TextCellValue(r['invoice'] as String),
              IntCellValue(r['qty'] as int),
              TextCellValue(r['brand'] as String),
              TextCellValue(r['assigned'] as String),
              TextCellValue(r['remarks'] as String),
            ]);
            detailSheet.appendRow(detailRow);
          }
        } else {
          Map<String, List<Map<String, dynamic>>> grouped = {};
          for (var r in allRows) {
            grouped.putIfAbsent(r['category'] as String, () => []).add(r);
          }
          grouped.forEach((category, items) {
            detailSheet.appendRow([TextCellValue(category.split(' (')[0])]);
            List<CellValue> detailHeader = [
              TextCellValue('Date'),
              TextCellValue('Equipment Name'),
              TextCellValue('Entry Type'),
              TextCellValue('Invoice/Voucher'),
              TextCellValue('Qty'),
              TextCellValue('Brand/Make'),
              TextCellValue('Assigned To'),
              TextCellValue('Remarks'),
            ];
            detailSheet.appendRow(detailHeader);
            
            for (var r in items) {
              detailSheet.appendRow([
                TextCellValue(DateFormat('dd/MM/yyyy').format(r['date'] as DateTime)),
                TextCellValue(r['name'] as String),
                TextCellValue(r['type'] as String),
                TextCellValue(r['invoice'] as String),
                IntCellValue(r['qty'] as int),
                TextCellValue(r['brand'] as String),
                TextCellValue(r['assigned'] as String),
                TextCellValue(r['remarks'] as String),
              ]);
            }
            detailSheet.appendRow([]); // empty row for spacing
          });
        }
      }
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/Equipment_Report_${DateTime.now().toIso8601String().split('T')[0]}.xlsx';
      final file = File(path);
      await file.writeAsBytes(fileBytes);
      
      await Share.shareXFiles([XFile(path)], text: 'Equipment Report');
    }
  }
}
