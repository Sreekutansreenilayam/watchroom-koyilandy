import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:screenshot/screenshot.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../models/fire_report_model.dart';
import '../models/manpower_model.dart';

class FireReportPdfGenerator {
  static Future<Uint8List> generatePdf(BuildContext context, FireReportModel report, List<Manpower> personnelList) async {
    final pdf = pw.Document();
    final screenshotController = ScreenshotController();

    // Helper functions for Flutter Widgets
    Widget buildRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: Text(label, style: const TextStyle(fontSize: 12, height: 1.2))),
            const Text(' : ', style: TextStyle(fontSize: 12, height: 1.2)),
            Expanded(flex: 6, child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, height: 1.2))),
          ],
        ),
      );
    }
    
    Widget buildDoubleRow(String label1, String value1, String label2, String value2) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: Text(label1, style: const TextStyle(fontSize: 12, height: 1.2))),
            const Text(' : ', style: TextStyle(fontSize: 12, height: 1.2)),
            Expanded(flex: 3, child: Text(value1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, height: 1.2))),
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: RichText(
                  textAlign: TextAlign.right,
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black, fontFamily: 'NotoSansMalayalam', fontSize: 12, height: 1.2),
                    children: [
                      TextSpan(text: '$label2 : '),
                      TextSpan(text: value2, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    Widget buildSectionTitle(String title) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Center(
          child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, height: 1.2)),
        ),
      );
    }

    String formatDate(DateTime? date) => date != null ? DateFormat('dd/MM/yyyy').format(date) : '';
    String formatTime(DateTime? date) => date != null ? DateFormat('HH.mm').format(date) : '';
    
    String getFullDesignation(String shortDesig) {
      switch (shortDesig) {
        case 'STO': return 'Station Officer';
        case 'ASTO': return 'Assistant Station Officer';
        case 'SFRO': return 'Senior Fire & Rescue Officer';
        case 'SFRO (M)': return 'Senior Fire & Rescue Officer (Mechanic)';
        case 'FRO': return 'Fire & Rescue Officer';
        case 'FRO (D)': return 'Fire & Rescue Officer (Driver)';
        case 'KHG': return 'Home Guard';
        case 'HG': return 'Home Guard';
        default: return shortDesig;
      }
    }

    String getOfficerName(String id) {
      final p = personnelList.where((p) => p.id == id).firstOrNull;
      if (p != null) {
        String fullDesig = getFullDesignation(p.designation);
        String idNumOnly = p.idNumber.replaceAll(RegExp(r'[^0-9]'), '');
        String idStr = idNumOnly.isNotEmpty ? '-$idNumOnly' : '';
        return '$fullDesig$idStr ${p.name}';
      }
      return '';
    }

    Widget tableCell(String text, {bool isHeader = false}) {
      return Padding(
        padding: const EdgeInsets.all(4.0),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, fontWeight: isHeader ? FontWeight.bold : FontWeight.normal, height: 1.2),
          ),
        ),
      );
    }
    
    Widget mergedHeaderCell() {
      return IntrinsicHeight(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(4.0),
              child: Center(child: Text('സംഭവസ്ഥലത്ത്', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, height: 1.2))),
            ),
            Container(height: 1, color: Colors.black),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: Padding(padding: const EdgeInsets.all(4.0), child: Center(child: Text('എത്തിയ\nസമയം', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, height: 1.2))))),
                  Container(width: 1, color: Colors.black),
                  Expanded(child: Padding(padding: const EdgeInsets.all(4.0), child: Center(child: Text('വിട്ട\nസമയം', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, height: 1.2))))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget mergedDataCell(String text1, String text2) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: Padding(padding: const EdgeInsets.all(4.0), child: Center(child: Text(text1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, height: 1.2))))),
            Container(width: 1, color: Colors.black),
            Expanded(child: Padding(padding: const EdgeInsets.all(4.0), child: Center(child: Text(text2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, height: 1.2))))),
          ],
        ),
      );
    }

    // Page 1 Widget
    Widget page1 = Container(
      color: Colors.white,
      width: 794, // A4 width in pixels at 96 DPI
      constraints: const BoxConstraints(minHeight: 1123), // Allow expansion
      padding: const EdgeInsets.only(left: 64, right: 32, top: 48, bottom: 48),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.black, fontFamily: 'NotoSansMalayalam', height: 1.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: Text('കെ. എഫ്. എഫ്. ഫോറം നമ്പർ 4', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            const Center(child: Text('അനുബന്ധം', style: TextStyle(fontSize: 14))),
            const SizedBox(height: 8),
            const Center(child: Text('കേരള അഗ്നിശമനസേനാ തീപിടുത്ത റിപ്പോർട്ട്', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('മേഖല : കോഴിക്കോട്', style: TextStyle(fontSize: 14)),
                Text('തീപിടുത്ത റിപ്പോർട്ട് നമ്പർ: ${report.reportNumber}', style: const TextStyle(fontSize: 14)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('സ്ഥലം : കൊയിലാണ്ടി', style: TextStyle(fontSize: 14)),
                Text('സംഭവ തീയതി: ${formatDate(report.date)}', style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(
                text: 'സംഭവസ്ഥലത്ത് ചുമതല വഹിച്ച ഉദ്യോഗസ്ഥൻ: ',
                style: const TextStyle(color: Colors.black, fontFamily: 'NotoSansMalayalam', fontSize: 14, height: 1.2),
                children: [
                  TextSpan(
                    text: getOfficerName(report.officerInChargeId),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.black, height: 12),
            
            buildSectionTitle('1. അറിയിപ്പ്'),
            buildRow('വിളിച്ച ആൾ', report.callerName),
            buildRow('ടെലിഫോൺ/തീപിടുത്ത അറിയിപ്പ് നമ്പർ', report.callerPhone),
            buildDoubleRow('ഉൾപ്പെട്ട കെട്ടിടങ്ങളുടെ വിവരങ്ങൾ', report.buildingsInvolved, 'ജോലി', report.occupation),
            buildDoubleRow('പാർപ്പുകാരൻ്റെ പേര്', report.occupantName, 'ആദ്യം പുറപ്പെട്ട സമയം', formatTime(report.firstTurnoutTime)),
            buildRow('ഉടമസ്ഥൻ്റെ പേരും വിലാസവും', report.ownerNameAndAddress),
            buildRow('വിളിച്ച സമയം', formatTime(report.callTime)),
            buildRow('സംഭവസ്ഥലത്ത് എത്തിയ സമയം', formatTime(report.reachedTime)),
            buildRow('സ്റ്റേഷനിൽ നിന്ന് സംഭവസ്ഥലത്തേക്കുള്ള ദൂരം', '${report.distanceFromStationKm} കി. മി.'),
            buildRow('യാഥാർത്ഥത്തിൽ തീപിടിച്ച സമയം', formatTime(report.actualFireTime)),
            const Divider(color: Colors.black, height: 12),
            
            buildSectionTitle('2. വിവരങ്ങൾ'),
            buildRow('ഉൾപ്പെട്ട വസ്തുക്കൾ, വ്യവസായ സ്ഥാപനങ്ങൾ, സംരചനകളുടെ തരം, വിസ്തീർണ്ണം മുതലായവയുടെ വിവരണം', report.propertiesInvolved),
            buildRow('തീപിടുത്തത്തിന്റെ തരം', report.typeOfFire),
            buildRow('തീയുടെ വ്യാപ്തി', report.extentOfFire),
            buildRow('തീപിടുത്തത്തിന്റെ ഉറപ്പിക്കപ്പെടുന്ന കാരണം', report.confirmedCause),
            buildRow('നാശനഷ്ടങ്ങളുടെ വിവരണം', report.damageDescription),
            const Divider(color: Colors.black, height: 12),
            const SizedBox(height: 8),
            const Text('അടങ്കൽ വിലകൾ:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                children: [
                  buildRow('(1) ഉൾപ്പെട്ട വസ്തുക്കൾ', report.estValuePropertiesInvolved.toInt().toString()),
                  buildRow('(2) അതുവഴി തീപിടിക്കുമായിരുന്നവ', report.estValueCouldHaveCaught.toInt().toString()),
                  buildRow('(3) കെട്ടിടങ്ങളുടെ നാശനഷ്ടം', report.estValueBuildingDamage.toInt().toString()),
                  buildRow('(4) അകത്തെ സാധനങ്ങളുടെ നാശനഷ്ടങ്ങൾ', report.estValueContentsDamage.toInt().toString()),
                ]
              )
            ),
            
            const SizedBox(height: 8),
            buildRow('അവസാന സംഭവസ്ഥല വിലയിരുത്തൽ ആഫീസർ', getOfficerName(report.assessingOfficerId)),
            buildRow('സംഭവസ്ഥല വിലയിരുത്തൽ തീയതിയും സമയവും', '${formatDate(report.assessmentDate)} ; ${formatTime(report.assessmentDate)}'),
            buildRow('ആകെ പണിയെടുത്ത സമയം', '${report.totalWorkingHours} മണിക്കൂർ ${report.totalWorkingMinutes} മിനിറ്റ്'),
            const Divider(color: Colors.black, height: 12),
            
            buildSectionTitle('3. രക്ഷപ്പെടുവരും രക്ഷിക്കപ്പെട്ടവരും'),
            Table(
              border: TableBorder.all(color: Colors.black),
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  children: [
                    tableCell('അഗ്നിശമന സേനയുടെ സഹായമില്ലാതെ രക്ഷപ്പെട്ടവർ', isHeader: true),
                    tableCell('ഉപകരണങ്ങൾ കൂടാതെ അഗ്നിശമനസേന രക്ഷിച്ചവർ', isHeader: true),
                    tableCell('ഉപകരണങ്ങളുപയോഗിച്ച് അഗ്നിശമനസേന രക്ഷിച്ചവർ', isHeader: true),
                  ]
                ),
                TableRow(
                  children: [
                    Row(
                      children: [
                        Expanded(child: tableCell('പുരുഷൻ\n${report.rescuedWithoutFireForceMale}')),
                        Expanded(child: tableCell('സ്ത്രീ\n${report.rescuedWithoutFireForceFemale}')),
                      ]
                    ),
                    Row(
                      children: [
                        Expanded(child: tableCell('പുരുഷൻ\n${report.rescuedWithFireForceNoEqMale}')),
                        Expanded(child: tableCell('സ്ത്രീ\n${report.rescuedWithFireForceNoEqFemale}')),
                      ]
                    ),
                    Row(
                      children: [
                        Expanded(child: tableCell('പുരുഷൻ\n${report.rescuedWithFireForceEqMale}')),
                        Expanded(child: tableCell('സ്ത്രീ\n${report.rescuedWithFireForceEqFemale}')),
                      ]
                    ),
                  ]
                )
              ]
            ),
            const SizedBox(height: 12),
            const Text(
              'കുറിപ്പ് -തെറ്റായ വിളികൾ സംബന്ധിച്ച റിപ്പോർട്ടുകൾ റിപ്പോർട്ട് ഫാമിൻ്റെ രണ്ടാം ഭാഗത്ത് വിലങ്ങനെ " തെറ്റായ വിളി \' എന്ന് ചുവന്ന മഷി കൊണ്ട് എഴുതുക',
              style: TextStyle(fontSize: 12, height: 1.2),
            ),
          ],
        ),
      ),
    );

    final allIds = <dynamic>{...report.attendingOfficersIds, ...report.attendingPersonnelIds}.toList();
    final allAttendees = allIds
        .map((id) => personnelList.firstWhere((p) => p.id == id, orElse: () => Manpower(id: '', name: 'Unknown', designation: '', mobileNumber: '', idNumber: '', isDriver: false, sortOrder: 99)))
        .where((p) => p.id != '')
        .toList();
    
    final officers = allAttendees.where((p) => p.designation == 'STO' || p.designation == 'ASTO').toList();
    final personnel = allAttendees.where((p) => p.designation != 'STO' && p.designation != 'ASTO').toList();

    int numOfficers = officers.length;
    int numPersonnel = personnel.length;
    int maxRows = numOfficers > numPersonnel ? numOfficers : numPersonnel;
    if (maxRows < 8) maxRows = 8; // At least 8 rows

    List<TableRow> officerRows = [
      TableRow(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black))),
        children: [
          tableCell('റാങ്ക്', isHeader: true),
          tableCell('പേര്', isHeader: true),
        ]
      ),
    ];
    for (int i = 0; i < maxRows; i++) {
      if (i < numOfficers) {
        final p = officers[i];
        officerRows.add(TableRow(children: [
          Padding(padding: const EdgeInsets.all(4), child: Text(p.designation, style: const TextStyle(fontSize: 10))),
          Padding(padding: const EdgeInsets.all(4), child: Text(p.name, style: const TextStyle(fontSize: 10))),
        ]));
      } else {
        officerRows.add(TableRow(children: [
          const Padding(padding: EdgeInsets.all(4), child: Text('', style: TextStyle(fontSize: 10))),
          const Padding(padding: EdgeInsets.all(4), child: Text('', style: TextStyle(fontSize: 10))),
        ]));
      }
    }

    List<TableRow> personnelRows = [
      TableRow(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black))),
        children: [
          tableCell('റാങ്ക്', isHeader: true),
          tableCell('നമ്പർ', isHeader: true),
          tableCell('പേര്', isHeader: true),
        ]
      ),
    ];
    for (int i = 0; i < maxRows; i++) {
      if (i < numPersonnel) {
        final p = personnel[i];
        personnelRows.add(TableRow(children: [
          Padding(padding: const EdgeInsets.all(4), child: Text(p.designation, style: const TextStyle(fontSize: 10))),
          Padding(padding: const EdgeInsets.all(4), child: Text(p.idNumber, style: const TextStyle(fontSize: 10))),
          Padding(padding: const EdgeInsets.all(4), child: Text(p.name, style: const TextStyle(fontSize: 10))),
        ]));
      } else {
        personnelRows.add(TableRow(children: [
          const Padding(padding: EdgeInsets.all(4), child: Text('', style: TextStyle(fontSize: 10))),
          const Padding(padding: EdgeInsets.all(4), child: Text('', style: TextStyle(fontSize: 10))),
          const Padding(padding: EdgeInsets.all(4), child: Text('', style: TextStyle(fontSize: 10))),
        ]));
      }
    }

    // Page 2 Widget
    Widget page2 = Container(
      color: Colors.white,
      width: 794,
      constraints: const BoxConstraints(minHeight: 1123), // Allow expansion
      padding: const EdgeInsets.only(left: 64, right: 32, top: 48, bottom: 48),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.black, fontFamily: 'NotoSansMalayalam', height: 1.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildSectionTitle('4 ആളപായങ്ങൾ'),
            const Divider(color: Colors.black, thickness: 1, height: 16),
            Row(
              children: [
                Expanded(child: Text('പുരുഷൻ : ${report.casualtiesFireForceMale}        സ്ത്രീ : ${report.casualtiesFireForceFemale}', style: const TextStyle(fontSize: 12))),
                Expanded(child: Text('പുരുഷൻ : ${report.casualtiesOthersMale}        സ്ത്രീ : ${report.casualtiesOthersFemale}', style: const TextStyle(fontSize: 12))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Text('അഗ്നിശമനസേന :', style: TextStyle(fontSize: 12))),
                const Expanded(child: Text('മറ്റുള്ളവർ :', style: TextStyle(fontSize: 12))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('പേര് : ${report.casualtiesFireForceNames}', style: const TextStyle(fontSize: 12))),
                Expanded(child: Text('പേര് : ${report.casualtiesOthersNames}', style: const TextStyle(fontSize: 12))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('വിലാസം : ${report.casualtiesFireForceAddress}', style: const TextStyle(fontSize: 12))),
                Expanded(child: Text('വിലാസം : ${report.casualtiesOthersAddress}', style: const TextStyle(fontSize: 12))),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.black, thickness: 1, height: 16),
            Text('ക്ഷതത്തിൻ്റെ സ്വഭാവം : ${report.natureOfDeath}', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            const Text('കുറിപ്പ് : അഗ്നിശമനസേനയിലെ ആളാണെങ്കിൽ അയാളുടെ നമ്പർ എഴുതിയാൽ മതിയാവും.', style: TextStyle(fontSize: 10)),
            const SizedBox(height: 16),
            
            buildSectionTitle('5. സംഭവസ്ഥലത്തെ ഹാജർ'),
            Table(
              border: TableBorder.all(color: Colors.black),
              columnWidths: const {
                0: FlexColumnWidth(1.8),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(1.8), // Increased for Reg Number
                3: FlexColumnWidth(1.5),
                4: FlexColumnWidth(2.2),
                5: FlexColumnWidth(1.5),
                6: FlexColumnWidth(1.2),
                7: FlexColumnWidth(1.5),
              },
              children: [
                TableRow(
                  children: [
                    tableCell('അഗ്നിശമന സേനാ\nസ്റ്റേഷൻ്റെ പേര്', isHeader: true),
                    tableCell('ഉപകരണ\nങ്ങളുടെ തരം', isHeader: true),
                    tableCell('രജി\nനമ്പർ', isHeader: true),
                    tableCell('പുറപ്പെട്ട\nസമയം', isHeader: true),
                    mergedHeaderCell(),
                    tableCell('സ്റ്റേഷനിൽ\nമടങ്ങി\nഎത്തിയ\nസമയം', isHeader: true),
                    tableCell('ട്രിപ്പിൻ്റെ\nദൂരം\nകി. മീ', isHeader: true),
                    tableCell('പമ്പ് പ്രവർത്തിച്ച\nസമയം', isHeader: true),
                  ]
                ),
                ...report.vehicleDetails.map((v) => TableRow(
                  children: [
                    tableCell('കൊയിലാണ്ടി'),
                    tableCell(v.vehicleType),
                    tableCell(v.regNo),
                    tableCell(v.timeOut),
                    mergedDataCell(v.timeReached, v.timeLeft),
                    tableCell(v.timeIn),
                    tableCell(v.distanceTripKm),
                    tableCell(v.pumpWorkedTime),
                  ]
                )),
              ]
            ),
            
            const SizedBox(height: 16),
            const Center(
              child: Text('6. ഹാജരായ അഗ്നിശമന സേനാംഗങ്ങളുടെ വിവരം\n(റിലീഫ് പ്രവർത്തകരുടെ വിവരം ചേർക്കേണ്ടതില്ല)', 
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, height: 1.2)
              )
            ),
            const SizedBox(height: 4),
            Table(
              border: TableBorder.all(color: Colors.black),
              columnWidths: const {
                0: FlexColumnWidth(4),
                1: FlexColumnWidth(6),
              },
              children: [
                TableRow(
                  children: [
                    tableCell('ആഫീസർമാർ', isHeader: true),
                    tableCell('സേനാംഗങ്ങൾ', isHeader: true),
                  ]
                ),
                TableRow(
                  children: [
                    Table(
                      border: const TableBorder(verticalInside: BorderSide(color: Colors.black)),
                      columnWidths: const { 0: FlexColumnWidth(3), 1: FlexColumnWidth(7) },
                      children: officerRows,
                    ),
                    Table(
                      border: const TableBorder(verticalInside: BorderSide(color: Colors.black)),
                      columnWidths: const { 0: FlexColumnWidth(3), 1: FlexColumnWidth(2), 2: FlexColumnWidth(5) },
                      children: personnelRows,
                    ),
                  ]
                )
              ]
            ),
            
            const SizedBox(height: 16),
            if (report.hoseNo.isNotEmpty) ...[
              Text('ഹോസ് ഉപയോഗ വിവരണം : ${report.hoseNo}', style: const TextStyle(fontSize: 14, height: 1.2)),
              const SizedBox(height: 16),
            ],
            const Center(child: Text('വേറെ എന്തെങ്കിലും വിവരം ചേർക്കാനുണ്ടെങ്കിൽ അത് താഴെ എഴുതുക', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            Text(report.remarks, style: const TextStyle(fontSize: 14, height: 1.2)),
            
            const SizedBox(height: 48),
            Align(
              alignment: Alignment.centerRight,
              child: const Text('ചുമതലപ്പെട്ട ആഫീസറുടെ ഒപ്പ്', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    // Show loading dialog if applicable, or we can just capture silently
    // Capture Page 1
    final Uint8List image1 = await screenshotController.captureFromWidget(
      Directionality(
        textDirection: ui.TextDirection.ltr, 
        child: FittedBox(
          fit: BoxFit.contain, 
          child: page1,
        )
      ),
      context: context,
      delay: const Duration(milliseconds: 100),
      pixelRatio: 6.0,
    );
    
    // Capture Page 2
    final Uint8List image2 = await screenshotController.captureFromWidget(
      Directionality(
        textDirection: ui.TextDirection.ltr, 
        child: FittedBox(
          fit: BoxFit.contain, 
          child: page2,
        )
      ),
      context: context,
      delay: const Duration(milliseconds: 100),
      pixelRatio: 6.0,
    );

    // Create PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Align(alignment: pw.Alignment.topCenter, child: pw.Image(pw.MemoryImage(image1), fit: pw.BoxFit.contain));
        },
      ),
    );
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Align(alignment: pw.Alignment.topCenter, child: pw.Image(pw.MemoryImage(image2), fit: pw.BoxFit.contain));
        },
      ),
    );

    return pdf.save();
  }
}
