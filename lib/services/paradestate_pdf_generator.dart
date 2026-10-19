import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/attendance_model.dart';
import '../models/manpower_model.dart';
import '../config/app_config.dart';

class ParadestatePdfGenerator {
  static Future<Uint8List> generateParadestatePdf({
    required DateTime date,
    required Map<String, MonthlyAttendance> attendanceMap,
    required Map<String, MonthlyAttendance> prevAttendanceMap,
    required List<Manpower> personnelList,
    List<String> stationWriterIds = const [],
  }) async {
    final pdf = pw.Document();

    // Grouping constants
    final ranks = [
      {'key': 'STO', 'name': 'Station Officer', 'sanctioned': 1},
      {'key': 'ASTO', 'name': 'Asst. Station Officer', 'sanctioned': 1},
      {'key': 'SFRO', 'name': 'Senior Fire&Rescue Officer', 'sanctioned': 3},
      {'key': 'SFRO (M)', 'name': 'Senior Fire&Rescue Officer(M)', 'sanctioned': 1},
      {'key': 'FRO (D)', 'name': 'Fire& rescue Officer\n(Driver)', 'sanctioned': 6},
      {'key': 'FRO', 'name': 'Fireman Fire& rescue\nOfficer', 'sanctioned': 15},
    ];

    Map<String, Map<String, int>> stats = {};
    Map<String, List<String>> presentOnParadeIds = {};
    List<String> hgOnDuty = [];
    List<String> hgOffDuty = [];
    List<String> hgLwp = [];
    List<String> hgWa = [];
    List<String> remarksList = [];

    for (var r in ranks) {
      String key = r['key'] as String;
      stats[key] = {
        'present': 0,
        'attached': 0,
        'off': 0,
        'cl': 0,
        'cml': 0,
        'wa_sd': 0,
        'sick_absent': 0,
        'vacancies': 0,
        'training': 0,
        'od_dr': 0,
        'bh_pl': 0,
        'parade': 0,
      };
      presentOnParadeIds[key] = [];
    }

    bool isTrainee(Manpower p) {
      return p.designation.toLowerCase().contains('trainee') || p.isTempAttachedForTraining;
    }

    String getEffectiveRankKey(Manpower p) {
      if (p.designation == 'KHG') return 'KHG';
      
      if (isTrainee(p)) {
        return 'FRO'; // All trainees mapped to FRO for this report
      }

      if (p.designation == 'FRO' && p.gender.toLowerCase() == 'female') return 'FRO';
      
      return p.designation; // STO, ASTO, SFRO, SFRO (M), FRO (D), FRO
    }

    String getYesterdayStatus(String mId) {
      DateTime yesterday = date.subtract(const Duration(days: 1));
      if (yesterday.month == date.month) {
        return (attendanceMap[mId]?.dailyStatus[yesterday.day] ?? '').toUpperCase().trim();
      } else {
        return (prevAttendanceMap[mId]?.dailyStatus[yesterday.day] ?? '').toUpperCase().trim();
      }
    }

    for (var p in personnelList) {
      String effRank = getEffectiveRankKey(p);
      final att = attendanceMap[p.id];
      final status = (att?.dailyStatus[date.day] ?? '').toUpperCase().trim();

      // Home Guards logic
      if (effRank == 'KHG') {
        if (status == 'LWP') {
          hgLwp.add(p.idNumber);
        } else if (status == 'WA' || status == 'SD') {
          hgWa.add(p.idNumber);
        } else if (status == 'R' || status == 'DR' || status == 'D/R' || status == 'ODR' || status == 'O/D/R' || status == 'OFF') {
          hgOffDuty.add(p.idNumber);
        } else if (status.isEmpty || status == 'X' || status == 'P' || status == 'X/R') {
          hgOnDuty.add(p.idNumber);
        }
        continue;
      }

      // Skip invalid ranks
      if (!stats.containsKey(effRank)) continue;

      // Handle Remarks for special duties from other stations
      bool isSpecialDuty = p.currentStation.trim().isNotEmpty && p.currentStation.trim().toLowerCase() != AppConfig.stationNameShort.toLowerCase();
      
      // Explicitly check for Manuprasad as requested by user
      if (p.name.toLowerCase().contains('manuprasad') || p.name.toLowerCase().contains('manu prasad')) {
        isSpecialDuty = true;
      }

      if (isSpecialDuty) {
        String stn = p.currentStation.trim();
        if (stn.isEmpty || stn.toLowerCase() == AppConfig.stationNameShort.toLowerCase()) {
           stn = 'FARSA'; // Default to FARSA for Manuprasad if not set
        }
        if (stn.toLowerCase() == 'farsa') stn = 'FARSA';
        
        remarksList.add('01 ${p.designation} Special duty from $stn');
        stats[effRank]!['attached'] = (stats[effRank]!['attached'] ?? 0) + 1;
        // Proceed normally so they are included in present strength and attendance columns
      }

      // Present strength counts everyone currently listed in personnel for the station
      stats[effRank]!['present'] = (stats[effRank]!['present'] ?? 0) + 1;

      // Determine if Present on Parade
      bool isParade = false;
      String yStatus = getYesterdayStatus(p.id);
      
      bool is12HrDutyOrWriter = p.designation == 'STO' || p.designation == 'ASTO' || p.designation == 'SFRO (M)' || stationWriterIds.contains(p.idNumber);
      bool wasPresentYesterday = !is12HrDutyOrWriter && (yStatus.isEmpty || yStatus == 'X');

      if (status.isEmpty || status == 'X' || status == 'P' || status == 'R' || status == 'X/R') {
        isParade = true;
      } else if (wasPresentYesterday) {
        // OD should NEVER go to parade, even if they were present yesterday
        if (status != 'OD' && status != 'O/D') {
          isParade = true;
        }
      }

      // Classify status
      if (isParade) {
        stats[effRank]!['parade'] = (stats[effRank]!['parade'] ?? 0) + 1;
        presentOnParadeIds[effRank]!.add(p.idNumber);
      } else if (status == 'OFF') {
        stats[effRank]!['off'] = (stats[effRank]!['off'] ?? 0) + 1;
      } else if (status == 'CL') {
        stats[effRank]!['cl'] = (stats[effRank]!['cl'] ?? 0) + 1;
      } else if (status == 'CML') {
        stats[effRank]!['cml'] = (stats[effRank]!['cml'] ?? 0) + 1;
      } else if (status == 'WA' || status == 'SD') {
        stats[effRank]!['wa_sd'] = (stats[effRank]!['wa_sd'] ?? 0) + 1;
      } else if (['ML', 'A', 'AB', 'SL', 'LWP'].contains(status)) { // Added LWP for non-KHG just in case
        stats[effRank]!['sick_absent'] = (stats[effRank]!['sick_absent'] ?? 0) + 1;
      } else if (['T', 'TRG'].contains(status) || (isTrainee(p) && status.isNotEmpty && !['X','P','OFF','R','DR','D/R','ODR','O/D/R'].contains(status))) {
        stats[effRank]!['training'] = (stats[effRank]!['training'] ?? 0) + 1;
      } else if (['OD', 'O/D', 'DR', 'D/R', 'ODR', 'O/D/R'].contains(status)) {
        stats[effRank]!['od_dr'] = (stats[effRank]!['od_dr'] ?? 0) + 1;
      } else if (['BH', 'HP', 'RH', 'EL', 'HPL', 'PL', 'SPCL'].contains(status)) {
        stats[effRank]!['bh_pl'] = (stats[effRank]!['bh_pl'] ?? 0) + 1;
      }
    }

    // Calculate vacancies
    for (var r in ranks) {
      String key = r['key'] as String;
      int sanctioned = r['sanctioned'] as int;
      int present = stats[key]!['present'] ?? 0;
      int attached = stats[key]!['attached'] ?? 0;
      
      int actualRegularPresent = present - attached;
      
      int vac = sanctioned - actualRegularPresent;
      stats[key]!['vacancies'] = vac > 0 ? vac : 0;
    }

    String dateStr = DateFormat('dd MMM yyyy, EEEE').format(date).toUpperCase();
    
    // Helper to format ID numbers by grouping
    String formatIdNumbers(List<String> ids) {
      if (ids.isEmpty) return '';
      List<String> result = [];
      String currentPrefix = '';
      
      for (String id in ids) {
        int lastNonDigitIndex = -1;
        for (int i = id.length - 1; i >= 0; i--) {
          if (!RegExp(r'[0-9]').hasMatch(id[i])) {
            lastNonDigitIndex = i;
            break;
          }
        }
        
        if (lastNonDigitIndex != -1 && lastNonDigitIndex < id.length - 1) {
          String prefix = id.substring(0, lastNonDigitIndex + 1);
          String number = id.substring(lastNonDigitIndex + 1);
          
          if (prefix == currentPrefix) {
            result.add(number);
          } else {
            result.add(id);
            currentPrefix = prefix;
          }
        } else {
          result.add(id);
          currentPrefix = '';
        }
      }
      return result.join(', ');
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape, // Proforma looks landscape or wide
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          final tableHeaders = [
            'Sl.\nNo.', 'Rank', 'Sanctioned\nStrength', 'Present\nStrength', 'Day\nOff',
            'Casual\nLeave', 'CML', 'W/A & SD', 'Sick/\nAbsent', 'Vacancies',
            'Training', 'OD, D/R', 'BH/PL/\nSpCL', 'Present on\nParade', 'Remarks'
          ];

          List<pw.TableRow> tableRows = [];
          
          // Header Row
          tableRows.add(pw.TableRow(
            children: tableHeaders.map((h) => pw.Padding(
              padding: const pw.EdgeInsets.all(2),
              child: pw.Center(
                child: pw.Text(h, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))
              )
            )).toList()
          ));

          int sumSanc = 0, sumPres = 0, sumOff = 0, sumCl = 0, sumCml = 0, sumWa = 0, sumSick = 0;
          int sumVac = 0, sumTrg = 0, sumOd = 0, sumBh = 0, sumParade = 0;

          for (int i = 0; i < ranks.length; i++) {
            var r = ranks[i];
            var key = r['key'] as String;
            var s = stats[key]!;

            int sanc = r['sanctioned'] as int;
            sumSanc += sanc;
            sumVac += s['vacancies']!;

            sumPres += s['present']!;
            sumOff += s['off']!;
            sumCl += s['cl']!;
            sumCml += s['cml']!;
            sumWa += s['wa_sd']!;
            sumSick += s['sick_absent']!;
            sumTrg += s['training']!;
            sumOd += s['od_dr']!;
            sumBh += s['bh_pl']!;
            sumParade += s['parade']!;

            String remarks = '';
            if (i == 4) {
              remarks = '1. Spl Duty from FRS KKD - FRO(D)-2525.';
            } else if (i == 5) {
              remarks = '1. Spl duty from FRS Nadapuram - FRO-6202.\n2. Spl duty from FRS Vadakara- FRO-8262.\n3. Spl duty @ RFO Office KKD - FRO-7596.\n4. Spl duty @ FARSA - FRO-8632.';
            }

            String sancStr = sanc.toString();
            String vacStr = s['vacancies'].toString();

            tableRows.add(pw.TableRow(
              children: [
                _cell('${i + 1}', center: true),
                _cell(r['name'] as String, bold: true),
                _cell(sancStr, center: true, bold: true, showZero: false),
                _cell(s['present'].toString(), center: true, bold: true, showZero: false),
                _cell(s['off'].toString(), center: true, showZero: false),
                _cell(s['cl'].toString(), center: true, showZero: false),
                _cell(s['cml'].toString(), center: true, showZero: false),
                _cell(s['wa_sd'].toString(), center: true, showZero: false),
                _cell(s['sick_absent'].toString(), center: true, showZero: false),
                _cell(vacStr, center: true, showZero: false),
                _cell(s['training'].toString(), center: true, showZero: false),
                _cell(s['od_dr'].toString(), center: true, showZero: false),
                _cell(s['bh_pl'].toString(), center: true, showZero: false),
                _cell(s['parade'].toString(), center: true, bold: true),
                _cell(remarks, fontSize: 8),
              ]
            ));
          }

          // TOTAL Row
          tableRows.add(pw.TableRow(
            children: [
              _cell(''),
              _cell('TOTAL', bold: true),
              _cell(sumSanc.toString(), center: true, bold: true),
              _cell(sumPres.toString(), center: true, bold: true),
              _cell(sumOff.toString(), center: true, bold: true, showZero: false),
              _cell(sumCl.toString(), center: true, bold: true, showZero: false),
              _cell(sumCml.toString(), center: true, bold: true, showZero: false),
              _cell(sumWa.toString(), center: true, bold: true, showZero: false),
              _cell(sumSick.toString(), center: true, bold: true, showZero: false),
              _cell(sumVac.toString(), center: true, bold: true, showZero: false),
              _cell(sumTrg.toString(), center: true, bold: true, showZero: false),
              _cell(sumOd.toString(), center: true, bold: true, showZero: false),
              _cell(sumBh.toString(), center: true, bold: true, showZero: false),
              _cell(sumParade.toString(), center: true, bold: true),
              _cell(''),
            ]
          ));

          return pw.FittedBox(
            child: pw.SizedBox(
              width: PdfPageFormat.a4.landscape.width - 60, // Total width minus margins (30 each side)
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                child: pw.FittedBox(
                  fit: pw.BoxFit.scaleDown,
                  child: pw.Text(
                    'PARADE STATEMENT OF ${AppConfig.stationName.toUpperCase()} ON $dateStr',
                    style: pw.TextStyle(
                      fontSize: 13, 
                      fontWeight: pw.FontWeight.bold, 
                      decoration: pw.TextDecoration.underline,
                    ),
                  )
                )
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(25),
                  1: const pw.FlexColumnWidth(3.5),
                  2: const pw.FlexColumnWidth(1.6),
                  3: const pw.FlexColumnWidth(1.2),
                  4: const pw.FlexColumnWidth(0.8),
                  5: const pw.FlexColumnWidth(1),
                  6: const pw.FlexColumnWidth(0.8),
                  7: const pw.FlexColumnWidth(1),
                  8: const pw.FlexColumnWidth(1.1),
                  9: const pw.FlexColumnWidth(1.3),
                  10: const pw.FlexColumnWidth(1.4),
                  11: const pw.FlexColumnWidth(1.1),
                  12: const pw.FlexColumnWidth(1.1),
                  13: const pw.FlexColumnWidth(1.4),
                  14: const pw.FlexColumnWidth(2.5),
                },
                children: tableRows,
              ),
              
              pw.SizedBox(height: 10),
              
              // Present on Parade Sub-section
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 7,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Present on Parade:-', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline, fontSize: 10)),
                        pw.SizedBox(height: 4),
                        pw.Table(
                          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                          columnWidths: {
                            0: const pw.FlexColumnWidth(2),
                            1: const pw.FlexColumnWidth(0.5),
                            2: const pw.FlexColumnWidth(5),
                          },
                          children: [
                            for (var r in ranks) 
                              pw.TableRow(
                                children: [
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4), 
                                    child: pw.Text((r['name'] as String).replaceAll('\n', ' '), style: const pw.TextStyle(fontSize: 9))
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4), 
                                    child: pw.Text(stats[r['key']]!['parade']! > 0 ? stats[r['key']]!['parade']!.toString().padLeft(2, '0') : '', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9))
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4), 
                                    child: pw.Text(formatIdNumbers(presentOnParadeIds[r['key']]!), style: const pw.TextStyle(fontSize: 9))
                                  ),
                                ]
                              ),
                            pw.TableRow(
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4), 
                                  child: pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4), 
                                  child: pw.Text(sumParade.toString(), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))
                                ),
                                pw.Padding(padding: const pw.EdgeInsets.all(0)),
                              ]
                            )
                          ]
                        ),
                        
                        pw.SizedBox(height: 15),
                        
                        pw.Text('HOME GUARDS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline, fontSize: 10)),
                        pw.SizedBox(height: 4),
                        pw.Table(
                          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                          columnWidths: {
                            0: const pw.FlexColumnWidth(2),
                            1: const pw.FlexColumnWidth(0.5),
                            2: const pw.FlexColumnWidth(5),
                          },
                          children: [
                            _hgRow('On Duty (KHG)', hgOnDuty.length, formatIdNumbers(hgOnDuty)),
                            _hgRow('Off Duty (KHG)', hgOffDuty.length, formatIdNumbers(hgOffDuty)),
                            _hgRow('LWP (KHG)', hgLwp.length, formatIdNumbers(hgLwp)),
                            _hgRow('W/A & SD (KHG)', hgWa.length, formatIdNumbers(hgWa)),
                            _hgRow('TOTAL', hgOnDuty.length + hgOffDuty.length + hgLwp.length + hgWa.length, '', isBold: true),
                          ]
                        )
                      ]
                    )
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(height: 20),
                        pw.Text('Submitted to\nStation Officer,\nFire &Rescue Station Station', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        
                        pw.SizedBox(height: 30),
                        pw.Text('Sentry:  ______________________', style: pw.TextStyle(fontSize: 10)),
                      ]
                    )
                  )
                ]
              )
                ]
              )
            )
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _cell(String text, {bool center = false, bool bold = false, bool showZero = true, double fontSize = 9}) {
    if (!showZero && text == '0') text = '';
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: pw.Text(
        text,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        )
      )
    );
  }

  static pw.TableRow _hgRow(String label, int count, String details, {bool isBold = false}) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4), 
          child: pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal))
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4), 
          child: pw.Text(count > 0 ? count.toString().padLeft(2, '0') : '', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal))
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4), 
          child: pw.Text(details, style: const pw.TextStyle(fontSize: 9))
        ),
      ]
    );
  }
}
