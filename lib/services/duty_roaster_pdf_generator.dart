import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/duty_register_model.dart';

class DutyRoasterPdfGenerator {
  static Future<Uint8List> generatePdf(
    DateTime startDate,
    DateTime endDate,
    List<DutyRegisterModel> allRegisters,
    String title,
  ) async {
    final pdf = pw.Document();

    final Map<int, DutyRegisterModel> dailyRegisters = {};
    DutyRegisterModel? latestReg;
    for (var reg in allRegisters) {
      if (reg.date.isAfter(startDate.subtract(const Duration(days: 1))) && 
          reg.date.isBefore(endDate.add(const Duration(days: 1)))) {
        dailyRegisters[reg.date.day] = reg;
        if (latestReg == null || reg.date.isAfter(latestReg.date)) {
          latestReg = reg;
        }
      }
    }

    // Identify the vehicles based on seniority from the latest register
    // The user specified that seniority 1 to 12 are vehicles, balance are accessories.
    final Map<String, int> vehicleSeniority = {};
    if (latestReg != null) {
      for (var v in latestReg.vehicleAssignments) {
        if (v.vehicleName.isNotEmpty && v.seniority <= 12) {
          vehicleSeniority[v.vehicleName] = v.seniority;
        }
      }
    }
    
    // Sort vehicles by seniority
    final vehicles = vehicleSeniority.keys.toList()
      ..sort((a, b) => vehicleSeniority[a]!.compareTo(vehicleSeniority[b]!));

    List<int> days = [];
    for (int i = startDate.day; i <= endDate.day; i++) {
      days.add(i);
    }

    String getPersonnelString(int day, String vehicleName) {
      final reg = dailyRegisters[day];
      if (reg == null) return '';
      
      try {
        final assignment = reg.vehicleAssignments.firstWhere((v) => v.vehicleName == vehicleName);
        List<String> names = [];
        if (assignment.sfro.isNotEmpty) names.add(assignment.sfro);
        if (assignment.fro.isNotEmpty) names.add(assignment.fro);
        if (assignment.khg.isNotEmpty) names.add(assignment.khg);
        if (assignment.froD.isNotEmpty) names.add(assignment.froD);
        
        return names.join(', ');
      } catch (e) {
        return '';
      }
    }

    pw.Widget buildTablePage(List<int> pageDays) {
      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(0.5), // Serial/Seniority (Roman)
          1: const pw.FlexColumnWidth(2), // Vehicle Name
          for (int i = 0; i < pageDays.length; i++)
            (i + 2): const pw.FlexColumnWidth(1.2),
        },
        children: [
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Center(child: pw.Text('No.', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Center(child: pw.Text('Vehicle Name', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
              ),
              for (var day in pageDays)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Center(child: pw.Text(day.toString().padLeft(2, '0'), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                ),
            ],
          ),
          for (var vehicle in vehicles)
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Center(
                    child: pw.Text(vehicleSeniority[vehicle]!.toString(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(vehicle, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ),
                for (var day in pageDays)
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      getPersonnelString(day, vehicle),
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                  ),
              ],
            ),
        ],
      );
    }

    final chunks = <List<int>>[];
    for (var i = 0; i < days.length; i += 11) {
      chunks.add(days.sublist(i, i + 11 > days.length ? days.length : i + 11));
    }

    for (int i = 0; i < chunks.length; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(12),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Stack(
                  children: [
                    pw.Center(
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'DUTY ROASTER', 
                            style: pw.TextStyle(
                              fontSize: 16, 
                              fontWeight: pw.FontWeight.bold,
                              decoration: pw.TextDecoration.underline,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(title, style: const pw.TextStyle(fontSize: 12)),
                        ]
                      )
                    ),
                    pw.Positioned(
                      right: 0,
                      bottom: 0,
                      child: pw.Text('Page ${i + 1} of ${chunks.length}', style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                buildTablePage(chunks[i]),
              ]
            );
          },
        ),
      );
    }

    if (vehicles.isEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (context) => pw.Center(child: pw.Text('No duty register data available for this period.')),
        )
      );
    }

    return pdf.save();
  }
}
