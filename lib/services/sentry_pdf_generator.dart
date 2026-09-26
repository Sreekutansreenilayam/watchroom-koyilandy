import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/sentry_register_model.dart';
import '../models/manpower_model.dart';
import '../config/app_config.dart';

class SentryPdfGenerator {
  static Future<Uint8List> generatePdf({
    required DateTime monthDate,
    required SentryRegisterModel dayRegister,
    required List<SentryRegisterModel> monthRegisters,
    required List<Manpower> personnelList,
    required List<SentryExemption> exemptions,
  }) async {
    final pdf = pw.Document();

    // PAGE 1: Daily Sentry Details
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(15),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                AppConfig.stationNamePdfHeader,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'SENTRY DETAILS AS ON ${DateFormat('dd-MM-yyyy').format(dayRegister.date)}',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 24),
              _buildDailySlotsTable(dayRegister, personnelList, monthRegisters),
              pw.SizedBox(height: 24),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'SPARE LIST',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              _buildSpareListTable(dayRegister, personnelList),
              pw.SizedBox(height: 40),
              pw.Align(
                alignment: pw.Alignment.bottomRight,
                child: pw.Text(
                  'STATION OFFICER',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );

    // PAGE 2: Monthly Rotation
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 10),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              if (context.pageNumber == 1)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 16),
                  child: pw.Text(
                    'SENTRY DUTY ROTATION - ${DateFormat('MMMM yyyy').format(monthDate)}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              _buildMonthlyHeaderRow(
                DateTime(monthDate.year, monthDate.month + 1, 0).day,
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return _buildMonthlyDataRows(
            monthDate,
            monthRegisters,
            personnelList,
            exemptions,
          );
        },
      ),
    );

    return pdf.save();
  }

static pw.Widget _buildDailySlotsTable(
    SentryRegisterModel reg,
    List<Manpower> personnelList,
    List<SentryRegisterModel> allRegisters,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.5),
        1: pw.FlexColumnWidth(2.5),
        2: pw.FlexColumnWidth(5.0),
        3: pw.FlexColumnWidth(3.0),
        4: pw.FlexColumnWidth(3.0),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _tableHeaderCell('Time Slot'),
            _tableHeaderCell('ID Number'),
            _tableHeaderCell('Personnel Name'),
            _tableHeaderCell('Green Duty\n(01-03 & 03-05)'),
            _tableHeaderCell('Red Duty\n(23-01 & 05-07)'),
          ],
        ),
        ...reg.slots.map((s) {
          String name = '-';
          String idNumber = '-';
          String lastGreen = '-';
          String lastRed = '-';

          if (s.personnelId.isNotEmpty) {
            final p = personnelList.where((m) => m.idNumber == s.personnelId).firstOrNull;
            name = p != null ? p.name : s.personnelId;
            idNumber = s.personnelId;

            // Find last green/red duty strictly BEFORE this register's date
            List<SentryRegisterModel> sortedHistory = List.from(allRegisters)
              ..sort((a, b) => b.date.compareTo(a.date));

            for (var historyReg in sortedHistory) {
              if (historyReg.date.isBefore(DateTime(reg.date.year, reg.date.month, reg.date.day))) {
                for (int i = 0; i < historyReg.slots.length; i++) {
                  if (historyReg.slots[i].personnelId == s.personnelId) {
                    if ((i == 8 || i == 9) && lastGreen == '-') {
                      lastGreen = DateFormat('dd/MM/yy').format(historyReg.date);
                    }
                    if ((i == 7 || i == 10) && lastRed == '-') {
                      lastRed = DateFormat('dd/MM/yy').format(historyReg.date);
                    }
                  }
                }
                if (lastGreen != '-' && lastRed != '-') break;
              }
            }
          }

          return pw.TableRow(
            children: [
              _tableDataCell(s.timeLabel),
              _tableDataCell(idNumber),
              _tableDataCell(name, alignLeft: true),
              _tableDataCell(lastGreen, textColor: PdfColors.green),
              _tableDataCell(lastRed, textColor: PdfColors.red),
            ],
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _tableHeaderCell(String text) {
    return pw.Container(
      height: 25,
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      ),
    );
  }

  static pw.Widget _tableDataCell(String text, {bool alignLeft = false, PdfColor? textColor}) {
    return pw.Container(
      height: 25,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4),
      alignment: alignLeft ? pw.Alignment.centerLeft : pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, color: textColor),
      ),
    );
  }

  static pw.Widget _buildSpareListTable(
    SentryRegisterModel reg,
    List<Manpower> personnelList,
  ) {
    if (reg.spares.isEmpty) {
      return pw.Text('No spares available today.');
    }
    return pw.TableHelper.fromTextArray(
      context: null,
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headerHeight: 25,
      cellHeight: 25,
      columnWidths: const {
        0: pw.FlexColumnWidth(1.0),
        1: pw.FlexColumnWidth(2.5),
        2: pw.FlexColumnWidth(6.5),
      },
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.center,
        2: pw.Alignment.centerLeft,
      },
      headers: ['Sl No', 'ID Number', 'Personnel Name'],
      data: List.generate(reg.spares.length, (index) {
        final id = reg.spares[index];
        final p = personnelList.where((m) => m.idNumber == id).firstOrNull;
        return [(index + 1).toString(), id, p?.name ?? id];
      }),
    );
  }

  static Map<int, pw.TableColumnWidth> _getColWidths(int daysInMonth) {
    Map<int, pw.TableColumnWidth> widths = {
      0: const pw.FlexColumnWidth(45),
    };
    for (int i = 1; i <= daysInMonth; i++) {
      widths[i] = const pw.FlexColumnWidth(10);
    }
    widths[daysInMonth + 1] = const pw.FlexColumnWidth(18);
    widths[daysInMonth + 2] = const pw.FlexColumnWidth(18);
    widths[daysInMonth + 3] = const pw.FlexColumnWidth(15);
    return widths;
  }

  static pw.Widget _buildCell(
    pw.Widget child, {
    bool isHeader = false,
    bool isTop = false,
    bool isLeft = false,
  }) {
    return pw.Container(
      constraints: const pw.BoxConstraints(minHeight: 18),
      padding: const pw.EdgeInsets.all(1),
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: isHeader ? PdfColors.grey300 : null,
        border: pw.Border(
          top: isTop
              ? const pw.BorderSide(width: 0.5, color: PdfColors.black)
              : pw.BorderSide.none,
          left: isLeft
              ? const pw.BorderSide(width: 0.5, color: PdfColors.black)
              : pw.BorderSide.none,
          bottom: const pw.BorderSide(width: 0.5, color: PdfColors.black),
          right: const pw.BorderSide(width: 0.5, color: PdfColors.black),
        ),
      ),
      child: child,
    );
  }

  static pw.Widget _buildMonthlyHeaderRow(int daysInMonth) {
    List<pw.Widget> headerCells = [
      _buildCell(
        pw.Text(
          'Name',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
        ),
        isHeader: true,
        isTop: true,
        isLeft: true,
      ),
    ];
    for (int i = 1; i <= daysInMonth; i++) {
      headerCells.add(
        _buildCell(
          pw.Text(
            '$i',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          ),
          isHeader: true,
          isTop: true,
        ),
      );
    }
    headerCells.add(
      _buildCell(
        pw.Text(
          '23-01\n05-07',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 5),
          textAlign: pw.TextAlign.center,
        ),
        isHeader: true,
        isTop: true,
      ),
    );
    headerCells.add(
      _buildCell(
        pw.Text(
          '01-03\n03-05',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 5),
          textAlign: pw.TextAlign.center,
        ),
        isHeader: true,
        isTop: true,
      ),
    );
    headerCells.add(
      _buildCell(
        pw.Text(
          'SPARE',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 5),
          textAlign: pw.TextAlign.center,
        ),
        isHeader: true,
        isTop: true,
      ),
    );

    return pw.Table(
      columnWidths: _getColWidths(daysInMonth),
      children: [
        pw.TableRow(children: headerCells),
      ],
    );
  }

  static List<pw.Widget> _buildMonthlyDataRows(
    DateTime monthDate,
    List<SentryRegisterModel> allRegisters,
    List<Manpower> personnelList,
    List<SentryExemption> exemptions,
  ) {
    Map<String, Map<int, List<String>>> memberDayDuties = {};
    Map<int, List<String>> spareDuties = {};

    for (var reg in allRegisters) {
      if (reg.date.year == monthDate.year &&
          reg.date.month == monthDate.month) {
        int day = reg.date.day;
        spareDuties[day] = List.from(reg.spares);

        for (var slot in reg.slots) {
          if (slot.segments != null && slot.segments!.isNotEmpty) {
             for (var seg in slot.segments!) {
                try {
                   final startDt = DateFormat('HH:mm').parse(seg.startTime);
                   var endDt = DateFormat('HH:mm').parse(seg.endTime);
                   if (endDt.isBefore(startDt) || endDt.isAtSameMomentAs(startDt)) {
                       endDt = endDt.add(const Duration(days: 1));
                   }
                   if (endDt.difference(startDt).inMinutes >= 30) {
                       final startStr = seg.startTime.split(':')[0];
                       final endStr = seg.endTime.split(':')[0];
                       String shortSegLabel = '$startStr-$endStr';
                       String compositeLabel = '$shortSegLabel|${slot.timeLabel}';

                       memberDayDuties.putIfAbsent(seg.personnelId, () => {});
                       memberDayDuties[seg.personnelId]!
                           .putIfAbsent(day, () => [])
                           .add(compositeLabel);
                   }
                } catch(e) {}
             }
          } else {
            bool originalGetsCredit = true;
            String originalShort = "";
            String replShort = "";
            
            if (slot.isBroken && slot.brokenTime != null) {
              int diffMins = 0;
              try {
                final parts = slot.timeLabel.split(' - ');
                final startDt = DateFormat('HH:mm').parse(parts[0].trim());
                var breakDt = DateFormat('HH:mm').parse(slot.brokenTime!);
                if (breakDt.isBefore(startDt) || breakDt.isAtSameMomentAs(startDt)) breakDt = breakDt.add(const Duration(days: 1));
                diffMins = breakDt.difference(startDt).inMinutes;
                
                originalShort = '${startDt.hour.toString().padLeft(2, '0')}-${breakDt.hour.toString().padLeft(2, '0')}';
                
                var endDt = DateFormat('HH:mm').parse(parts[1].trim());
                if (endDt.isBefore(breakDt) || endDt.isAtSameMomentAs(breakDt)) endDt = endDt.add(const Duration(days: 1));
                if (endDt.difference(breakDt).inMinutes >= 30 && slot.replacementPersonnelId != null && slot.replacementPersonnelId!.isNotEmpty) {
                   replShort = '${breakDt.hour.toString().padLeft(2, '0')}-${endDt.hour.toString().padLeft(2, '0')}';
                   memberDayDuties.putIfAbsent(slot.replacementPersonnelId!, () => {});
                   memberDayDuties[slot.replacementPersonnelId!]!
                       .putIfAbsent(day, () => [])
                       .add('$replShort|${slot.timeLabel}');
                }
              } catch (e) {}
              if (diffMins < 30) originalGetsCredit = false;
            }

            if (originalGetsCredit && slot.personnelId.isNotEmpty) {
              memberDayDuties.putIfAbsent(slot.personnelId, () => {});
              
              String labelToAdd = slot.timeLabel;
              if (originalShort.isNotEmpty) {
                 labelToAdd = '$originalShort|${slot.timeLabel}';
              } else {
                 final parts = slot.timeLabel.split(' - ');
                 if (parts.length == 2) {
                     originalShort = '${parts[0].split(':')[0]}-${parts[1].split(':')[0]}';
                     labelToAdd = '$originalShort|${slot.timeLabel}';
                 }
              }

              memberDayDuties[slot.personnelId]!
                  .putIfAbsent(day, () => [])
                  .add(labelToAdd);
            }
          }
        }
      }
    }

    int daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    var activeMembers = personnelList
        .where((p) {
           if (!['FRO', 'KHG', 'Trainees'].contains(p.designation)) return false;
           // If they are active, definitely include them
           if (p.isActive) return true;
           // If they are inactive but have duties or were a spare this month, include them!
           bool hasDuties = memberDayDuties.containsKey(p.idNumber);
           bool hasSpares = false;
           for (var spares in spareDuties.values) {
              if (spares.contains(p.idNumber)) {
                 hasSpares = true;
                 break;
              }
           }
           return hasDuties || hasSpares;
        })
        .toList();

    List<pw.Widget> rows = [];
    var colWidths = _getColWidths(daysInMonth);

    // Data Rows
    for (var p in activeMembers) {
      List<pw.Widget> rowCells = [];

      final exemption = exemptions
          .where((e) => e.personnelId == p.idNumber)
          .firstOrNull;

      rowCells.add(
        _buildCell(
          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              p.name,
              style: pw.TextStyle(
                fontSize: 8,
                color: exemption != null ? PdfColors.red800 : PdfColors.black,
                fontWeight: exemption != null ? pw.FontWeight.bold : null,
              ),
              maxLines: 1,
            ),
          ),
          isLeft: true,
        ),
      );

      if (exemption != null) {
        // Merged cell! Since we can't use colspan in pw.Table easily, 
        // we fallback to pw.Row with pw.Expanded just for this single non-stretching row.
        rows.add(pw.Row(
          children: [
            pw.Expanded(
              flex: 45,
              child: rowCells[0],
            ),
            pw.Expanded(
              flex: 10 * daysInMonth + 18 + 18 + 15,
              child: _buildCell(
                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    '(EXEMPTED: ${exemption.reason})',
                    style: pw.TextStyle(
                      color: PdfColors.red800,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ));
      } else {
        int tier2Count = 0;
        int tier1Count = 0;
        int spareCount = 0;

        for (int i = 1; i <= daysInMonth; i++) {
          var labels = memberDayDuties[p.idNumber]?[i];
          bool isSpare = spareDuties[i]?.contains(p.idNumber) ?? false;

          if (isSpare) spareCount++;

          if (labels != null) {
            for (var label in labels) {
              if (label.contains("23:00 - 01:00") ||
                  label.contains("05:00 - 07:00")) {
                tier2Count++;
              }
              if (label.contains("01:00 - 03:00") ||
                  label.contains("03:00 - 05:00")) {
                tier1Count++;
              }
            }
          }

          if (isSpare && (labels == null || labels.isEmpty)) {
            rowCells.add(
              _buildCell(
                pw.Text(
                  'SPARE',
                  style: pw.TextStyle(
                    color: PdfColors.orange700,
                    fontSize: 4.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  maxLines: 1,
                ),
              ),
            );
          } else if (labels == null || labels.isEmpty) {
            rowCells.add(
              _buildCell(
                pw.Text(
                  '-',
                  style: const pw.TextStyle(color: PdfColors.grey, fontSize: 8),
                ),
              ),
            );
          } else {
            rowCells.add(
              _buildCell(
                pw.Wrap(
                  alignment: pw.WrapAlignment.center,
                  runAlignment: pw.WrapAlignment.center,
                  crossAxisAlignment: pw.WrapCrossAlignment.center,
                  spacing: 1,
                  runSpacing: 1,
                  children: labels.map((label) {
                    PdfColor c = PdfColors.black;
                    String shortLabel = "";
                    if (label.contains("|")) {
                        final parts = label.split("|");
                        shortLabel = parts[0];
                    }

                    if (label.contains("09:00 - 11:00")) {
                      if (shortLabel.isEmpty) shortLabel = "09-11";
                    } else if (label.contains("11:00 - 13:00")) {
                      if (shortLabel.isEmpty) shortLabel = "11-13";
                    } else if (label.contains("13:00 - 15:00")) {
                      if (shortLabel.isEmpty) shortLabel = "13-15";
                    } else if (label.contains("15:00 - 17:00")) {
                      if (shortLabel.isEmpty) shortLabel = "15-17";
                    } else if (label.contains("17:00 - 19:00")) {
                      if (shortLabel.isEmpty) shortLabel = "17-19";
                    } else if (label.contains("19:00 - 21:00")) {
                      if (shortLabel.isEmpty) shortLabel = "19-21";
                    } else if (label.contains("21:00 - 23:00")) {
                      if (shortLabel.isEmpty) shortLabel = "21-23";
                    } else if (label.contains("23:00 - 01:00")) {
                      if (shortLabel.isEmpty) shortLabel = "23-01";
                      c = PdfColors.green700;
                    } else if (label.contains("01:00 - 03:00")) {
                      if (shortLabel.isEmpty) shortLabel = "01-03";
                      c = PdfColors.red700;
                    } else if (label.contains("03:00 - 05:00")) {
                      if (shortLabel.isEmpty) shortLabel = "03-05";
                      c = PdfColors.red700;
                    } else if (label.contains("05:00 - 07:00")) {
                      if (shortLabel.isEmpty) shortLabel = "05-07";
                      c = PdfColors.green700;
                    } else if (label.contains("07:00 - 09:00")) {
                      if (shortLabel.isEmpty) shortLabel = "07-09";
                    }

                    return pw.Text(
                      shortLabel,
                      maxLines: 1,
                      style: pw.TextStyle(
                        color: c,
                        fontSize: 5.5,
                        fontWeight: c != PdfColors.black
                            ? pw.FontWeight.bold
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          }
        }

        rowCells.add(
          _buildCell(
            pw.Text(
              tier2Count > 0 ? tier2Count.toString() : '-',
              style: const pw.TextStyle(fontSize: 6),
            ),
          ),
        );
        rowCells.add(
          _buildCell(
            pw.Text(
              tier1Count > 0 ? tier1Count.toString() : '-',
              style: const pw.TextStyle(fontSize: 6),
            ),
          ),
        );
        rowCells.add(
          _buildCell(
            pw.Text(
              spareCount > 0 ? spareCount.toString() : '-',
              style: const pw.TextStyle(fontSize: 6),
            ),
          ),
        );

        rows.add(pw.Table(
          columnWidths: colWidths,
          children: [
            pw.TableRow(children: rowCells),
          ],
        ));
      }
    }

    return rows;
  }
}
