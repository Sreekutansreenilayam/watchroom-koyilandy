import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:screenshot/screenshot.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../models/logbook_model.dart';
import '../models/vehicle_model.dart';

class LogbookPdfGenerator {
  static Future<Uint8List> generatePdf(
      BuildContext context, 
      VehicleModel vehicle, 
      List<LogbookEntry> entries, 
      DateTime monthYear,
      {int pageIndex = -1, int itemsPerPage = 15}
  ) async {
    final pdf = pw.Document();
    final screenshotController = ScreenshotController();

    // Calculate dynamic bottom section data
    double openingFuel = 0; 
    if (entries.isNotEmpty) {
      openingFuel = entries.first.remainingFuelInTank;
      if (openingFuel < 0) openingFuel = 0;
    }

    double totalSupplied = entries.fold(0, (sum, item) => sum + item.suppliedFuel);
    double totalFuel = openingFuel + totalSupplied;

    double fuelConsumedJourneyTotal = entries.fold(0, (sum, item) => sum + item.fuelConsumedForJourney);
    double fuelConsumedPumpTotalAll = entries.fold(0, (sum, item) => sum + item.fuelConsumedForPump);
    double totalConsumed = fuelConsumedJourneyTotal + fuelConsumedPumpTotalAll;

    double closingFuel = totalFuel - totalConsumed;
    if (closingFuel < 0) closingFuel = 0;
    
    // total km
    double totalKm = entries.fold(0, (sum, item) => sum + item.travelledDistance);

    double totalPumpKm = 0;
    double fuelConsumedPumpTotal = 0;
    double totalDSFuel = 0;
    
    Set<String> processedDSSaturdays = {};

    for (var e in entries) {
      bool isTakingOnCharge = e.actionType == 'Taking on Charge' || e.actionType == 'Emergency Taking on Charge';
      bool isSaturday = e.date.weekday == DateTime.saturday;
      String dateKey = "${e.date.year}-${e.date.month}-${e.date.day}";
      
      bool isFirstSaturdayDS = isTakingOnCharge && isSaturday && !processedDSSaturdays.contains(dateKey);

      if (isFirstSaturdayDS) {
        totalDSFuel += e.fuelConsumedForPump;
        processedDSSaturdays.add(dateKey);
      } else {
        fuelConsumedPumpTotal += e.fuelConsumedForPump;
        
        double effectiveKm = e.pumpKm;
        if (effectiveKm == 0 && e.fuelConsumedForPump > 0 && vehicle.mileageOnPumping > 0) {
          effectiveKm = e.fuelConsumedForPump * vehicle.mileageOnPumping;
        }
        totalPumpKm += effectiveKm;
      }
    }

    String _formatDecimal(double val, {int maxDecimals = 3}) {
      if (val % 1 == 0) return val.toInt().toString();
      return val.toStringAsFixed(maxDecimals).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
    }

    String pumpKmStr = _formatDecimal(totalPumpKm);
    String pumpSummaryLabel = '(2) തൻമാസം $pumpKmStr കി.മീ പമ്പ് പ്രവർത്തിച്ചതിന് ചെലവ്';

    double averageMileage = 0;
    if (fuelConsumedJourneyTotal > 0) {
      averageMileage = totalKm / fuelConsumedJourneyTotal;
    }

    Widget tableCell(String text, {bool isHeader = false, bool isVertical = false, double fontSize = 9, int? maxLines, TextAlign textAlign = TextAlign.center, Alignment alignment = Alignment.center}) {
      Widget textWidget = Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
        style: TextStyle(
          fontSize: fontSize, 
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal, 
          height: 1.2
        ),
      );
      
      return Container(
        padding: const EdgeInsets.all(2.0),
        alignment: alignment,
        child: isVertical ? RotatedBox(quarterTurns: 3, child: textWidget) : textWidget,
      );
    }

    Widget tableHeaderCell(String text, {bool isVertical = true, String? unit, double fontSize = 8.5, bool isFirst = false}) {
      Widget textWidget = Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize, 
          fontWeight: FontWeight.bold, 
          height: 1.2
        ),
      );

      return Container(
        padding: const EdgeInsets.all(2.0),
        alignment: Alignment.bottomCenter,
        decoration: BoxDecoration(
          border: Border(
            left: isFirst ? const BorderSide(color: Colors.black, width: 1.0) : BorderSide.none,
            right: const BorderSide(color: Colors.black, width: 1.0),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: isVertical ? RotatedBox(quarterTurns: 3, child: textWidget) : textWidget,
              ),
            ),
            if (unit != null)
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text(
                  unit,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, height: 1.2),
                  softWrap: false,
                  maxLines: 1,
                ),
              ),
          ],
        ),
      );
    }

    Widget verticalText(String text) {
      return RotatedBox(
        quarterTurns: 3,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, height: 1.2),
        ),
      );
    }

    String formatNumOrDash(double val) {
      if (val == 0) return '-';
      return _formatDecimal(val);
    }

    String formatFuel(double val) {
      if (val == 0) return '-';
      return val.toStringAsFixed(2);
    }

    String formatTextOrDash(String? val) {
      if (val == null || val.trim().isEmpty) return '-';
      return val.trim();
    }

    Widget buildPumpDurationAndKmCell(LogbookEntry e) {
      final hasDuration = e.pumpDuration.isNotEmpty && e.pumpDuration.trim() != '-';
      double effectiveKm = e.pumpKm;
      if (effectiveKm == 0 && e.fuelConsumedForPump > 0 && vehicle.mileageOnPumping > 0 && e.actionType != 'Taking on Charge' && e.actionType != 'Emergency Taking on Charge') {
        effectiveKm = e.fuelConsumedForPump * vehicle.mileageOnPumping;
      }
      final hasKm = effectiveKm > 0;

      if (hasDuration && hasKm) {
        String kmStr = _formatDecimal(effectiveKm);
        String durStr = e.pumpDuration.trim();
        if (durStr.contains(':')) {
          final parts = durStr.split(':');
          final int hrs = int.tryParse(parts[0]) ?? 0;
          final int mins = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
          if (mins > 0) {
            durStr = '$hrs hr $mins min';
          } else {
            durStr = '$hrs Hr';
          }
        }
        return Container(
          padding: const EdgeInsets.all(2.0),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.black, width: 0.5)),
                ),
                child: Text('$kmStr Km', style: const TextStyle(fontSize: 9, height: 1.2)),
              ),
              const SizedBox(height: 1),
              Text(durStr, style: const TextStyle(fontSize: 9, height: 1.2)),
            ],
          ),
        );
      } else if (hasDuration) {
        String durStr = e.pumpDuration.trim();
        if (durStr.contains(':')) {
          final parts = durStr.split(':');
          final int hrs = int.tryParse(parts[0]) ?? 0;
          final int mins = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
          if (mins > 0) {
            durStr = '$hrs hr $mins min';
          } else {
            durStr = '$hrs Hr';
          }
        }
        return tableCell(durStr);
      } else if (hasKm) {
        String kmStr = _formatDecimal(effectiveKm);
        return tableCell('$kmStr Km');
      }
      return tableCell('-');
    }

    Future<Uint8List> captureWidget(Widget child) async {
      return await screenshotController.captureFromWidget(
        FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 1059,
            child: Directionality(
              textDirection: ui.TextDirection.ltr,
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.black, fontFamily: 'NotoSansMalayalam', height: 1.2),
                child: Container(
                  color: Colors.white,
                  child: child,
                ),
              ),
            ),
          ),
        ),
        delay: const Duration(milliseconds: 100),
        pixelRatio: 6.0,
      );
    }

    Widget headerRowWidget = Container(
      height: 115,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.black, width: 1.0),
          bottom: BorderSide(color: Colors.black, width: 1.0),
        )
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            SizedBox(width: 55, child: tableHeaderCell('തിയ്യതി', isFirst: true)),
            SizedBox(width: 40, child: tableHeaderCell('മുൻ യാത്ര\nചെയ്ത', unit: 'കി. മീ.')),
            SizedBox(
              width: 73,
              child: Column(
                children: [
                  Container(
                    height: 26, 
                    alignment: Alignment.center, 
                    decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1.0), bottom: BorderSide(color: Colors.black, width: 1.0))),
                    child: const Text('ഇന്ധനം', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 38, child: tableHeaderCell('ടാങ്കിൽ\nശേഷിക്കുന്നത്')),
                        SizedBox(width: 35, child: tableHeaderCell('നൽകിയത്')),
                      ],
                    ),
                  )
                ],
              ),
            ),
            SizedBox(
              width: 100,
              child: Column(
                children: [
                  Container(
                    height: 26, 
                    alignment: Alignment.center, 
                    decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1.0), bottom: BorderSide(color: Colors.black, width: 1.0))),
                    child: const Text('ലൂബ്രിക്കൻ്റ്സ്', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 25, child: tableHeaderCell('ഓയിൽ')),
                        SizedBox(width: 25, child: tableHeaderCell('ഗ്രീസ്/\nബ്രേക്ക് ഫ്ലൂയിഡ്')),
                        SizedBox(width: 25, child: tableHeaderCell('ഡി. വാട്ടർ')),
                        SizedBox(width: 25, child: tableHeaderCell('ആഡ് ബ്ലൂ')),
                      ],
                    ),
                  )
                ],
              ),
            ),
            SizedBox(width: 35, child: tableHeaderCell('പുറപ്പെടുന്ന\nസമയം', unit: 'മ. മി.')),
            Expanded(
              flex: 20,
              child: Column(
                children: [
                  Container(
                    height: 26, 
                    alignment: Alignment.center, 
                    decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1.0), bottom: BorderSide(color: Colors.black, width: 1.0))),
                    child: const Text('യാത്ര ചെയ്ത സ്ഥലം', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: tableHeaderCell('മുതൽ', isVertical: false)),
                        Expanded(child: tableHeaderCell('വരെ', isVertical: false)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            SizedBox(width: 35, child: tableHeaderCell('എത്തിച്ചേരുന്ന\nസമയം', unit: 'മ. മി.')),
            SizedBox(width: 35, child: tableHeaderCell('യാത്ര ചെയ്ത\nദൂരം', unit: 'കി. മീ.')),
            SizedBox(
              width: 126,
              child: Column(
                children: [
                  Container(
                    height: 26, 
                    alignment: Alignment.center, 
                    decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1.0), bottom: BorderSide(color: Colors.black, width: 1.0))),
                    child: const Text('പമ്പിന്റെ പ്രവർത്തനം', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 35, child: tableHeaderCell('ആരംഭിച്ചത്', unit: 'മ. മി.')),
                        SizedBox(width: 35, child: tableHeaderCell('അവസാനിച്ചത്', unit: 'മ. മി.')),
                        SizedBox(
                          width: 56,
                          child: Container(
                            padding: const EdgeInsets.all(2.0),
                            alignment: Alignment.bottomCenter,
                            decoration: const BoxDecoration(
                              border: Border(right: BorderSide(color: Colors.black, width: 1.0)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: verticalText('പ്രവർത്തിച്ച\nസമയം'),
                                  ),
                                ),
                                const Text(
                                  'കി.മീ.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            SizedBox(
              width: 90,
              child: Column(
                children: [
                  Container(
                    height: 26,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1.0), bottom: BorderSide(color: Colors.black, width: 1.0))),
                    child: const Text('ഇന്ധനം ചെലവായത്', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 30, child: tableHeaderCell('യാത്ര', unit: 'ലി.')),
                        SizedBox(width: 30, child: tableHeaderCell('പമ്പ്', unit: 'ലി.')),
                        SizedBox(width: 30, child: tableHeaderCell('ഡി. എസ്.', unit: 'ലി.')),
                      ],
                    ),
                  )
                ],
              ),
            ),
            Expanded(
              flex: 18,
              child: Container(
                padding: const EdgeInsets.all(2.0),
                alignment: Alignment.center,
                decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1.0))),
                child: verticalText('യാത്രയുടെ കാരണം/\nപമ്പ് പ്രവർത്തന\nകാരണം/ടെസ്റ്റിംഗ്/\nസ്റ്റാൻഡ്‌ബൈ/വാഹന\nത്തിന് ഉണ്ടാകുന്ന\nതകരാർ'),
              ),
            ),
            SizedBox(width: 35, child: tableHeaderCell('വാഹനം ചാർജ്ജ്\nഎടുക്കുന്ന സമയം', unit: 'മ. മി.')),
            Expanded(
              flex: 12,
              child: Container(
                padding: const EdgeInsets.all(2.0),
                alignment: Alignment.center,
                decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black, width: 1.0))),
                child: verticalText('ഓപ്പറേറ്ററുടെ ഒപ്പ്/\nചുമതലപ്പെട്ട\nഉദ്യോഗസ്ഥന്റെ\nകൈയ്യൊപ്പ്/നമ്പർ'),
              ),
            ),
          ],
        ),
    );

    Widget _wrapCellWithBorder(Widget cell, {bool isFirst = false}) {
      return Container(
        decoration: BoxDecoration(
          border: Border(
            left: isFirst ? const BorderSide(color: Colors.black, width: 1.0) : BorderSide.none,
            right: const BorderSide(color: Colors.black, width: 1.0),
          ),
        ),
        child: cell,
      );
    }

    Widget buildDataRow(List<Widget> cells, {bool isBottomBorder = true}) {
      return Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: isBottomBorder ? const BorderSide(color: Colors.black, width: 1.0) : BorderSide.none,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 55, child: _wrapCellWithBorder(cells[0], isFirst: true)),
              SizedBox(width: 40, child: _wrapCellWithBorder(cells[1])),
              SizedBox(width: 38, child: _wrapCellWithBorder(cells[2])),
              SizedBox(width: 35, child: _wrapCellWithBorder(cells[3])),
              SizedBox(width: 25, child: _wrapCellWithBorder(cells[4])),
              SizedBox(width: 25, child: _wrapCellWithBorder(cells[5])),
              SizedBox(width: 25, child: _wrapCellWithBorder(cells[6])),
              SizedBox(width: 25, child: _wrapCellWithBorder(cells[7])),
              SizedBox(width: 35, child: _wrapCellWithBorder(cells[8])),
              Expanded(flex: 10, child: _wrapCellWithBorder(cells[9])),
              Expanded(flex: 10, child: _wrapCellWithBorder(cells[10])),
              SizedBox(width: 35, child: _wrapCellWithBorder(cells[11])),
              SizedBox(width: 35, child: _wrapCellWithBorder(cells[12])),
              SizedBox(width: 35, child: _wrapCellWithBorder(cells[13])),
              SizedBox(width: 35, child: _wrapCellWithBorder(cells[14])),
              SizedBox(width: 56, child: _wrapCellWithBorder(cells[15])),
              SizedBox(width: 30, child: _wrapCellWithBorder(cells[16])),
              SizedBox(width: 30, child: _wrapCellWithBorder(cells[17])),
              SizedBox(width: 30, child: _wrapCellWithBorder(cells[18])),
              Expanded(flex: 18, child: _wrapCellWithBorder(cells[19])),
              SizedBox(width: 35, child: _wrapCellWithBorder(cells[20])),
              Expanded(flex: 12, child: _wrapCellWithBorder(cells[21])),
            ],
          ),
        ),
      );
    }

    Widget buildBoldRow(DateTime dt, double rowStartKm, double rowStartFuel) {
      return buildDataRow([
              tableCell(DateFormat('dd/MM/yy').format(dt), isHeader: true),
              tableCell(rowStartKm.toInt().toString(), isHeader: true),
              tableCell(formatFuel(rowStartFuel), isHeader: true),
              tableCell('', isHeader: true),
              tableCell('', isHeader: true),
              tableCell('', isHeader: true),
              tableCell('', isHeader: true),
              tableCell('', isHeader: true),
              tableCell('', isHeader: true),
              tableCell('', isHeader: true),
              tableCell('', isHeader: true),
              tableCell('', isHeader: true),
              tableCell('', isHeader: true),
              tableCell('', isHeader: true),
              tableCell('', isHeader: true),
              tableCell('', isHeader: true),
              tableCell('', isHeader: true),
              tableCell('', isHeader: true),
              tableCell('', isHeader: true),
              tableCell('', isHeader: true),
              tableCell('', isHeader: true),
              tableCell('', isHeader: true),
      ]);
    }

    List<Widget> dataRowWidgets = [];
    
    double startKm = entries.isNotEmpty ? entries.first.previousKms : 0.0;
    
    double runningKm = startKm;
    double runningFuel = openingFuel;
    final Set<String> tableProcessedDSSaturdays = {};

    int startIndex = 0;
    int endIndex = entries.length;

    if (pageIndex >= 0) {
      startIndex = pageIndex * itemsPerPage;
      endIndex = startIndex + itemsPerPage;
      if (endIndex > entries.length) endIndex = entries.length;
    }

    for (int index = 0; index < entries.length; index++) {
      final e = entries[index];
      
      bool isTakingOnCharge = e.actionType == 'Taking on Charge' || e.actionType == 'Emergency Taking on Charge';

      bool isSaturdayDS = isTakingOnCharge && e.date.weekday == DateTime.saturday;
      if (isSaturdayDS) {
        final dateStr = DateFormat('yyyy-MM-dd').format(e.date);
        if (!tableProcessedDSSaturdays.contains(dateStr)) {
          tableProcessedDSSaturdays.add(dateStr);
        } else {
          isSaturdayDS = false;
        }
      }

      if (index >= startIndex && index < endIndex) {
        dataRowWidgets.add(buildDataRow([
          tableCell(DateFormat('dd/MM/yy').format(e.date)),
          tableCell(runningKm.toInt().toString()),
          tableCell(formatFuel(runningFuel)),
          tableCell(formatFuel(e.suppliedFuel)),
          tableCell(formatFuel(e.oil)),
          tableCell(formatFuel(e.grease)),
          tableCell(formatFuel(e.dWater)),
          tableCell(formatFuel(e.adBlue)),
          tableCell(formatTextOrDash(e.departureTime)),
          tableCell(isTakingOnCharge ? '-' : formatTextOrDash(e.fromPlace)),
          tableCell(isTakingOnCharge ? '-' : formatTextOrDash(e.toPlace)),
          tableCell(formatTextOrDash(e.arrivalTime)),
          tableCell(formatNumOrDash(e.travelledDistance)),
          tableCell(formatTextOrDash(e.pumpStartTime)),
          tableCell(formatTextOrDash(e.pumpEndTime)),
          buildPumpDurationAndKmCell(e),
          tableCell(formatFuel(e.fuelConsumedForJourney)),
          tableCell(formatFuel(isSaturdayDS ? 0 : e.fuelConsumedForPump)),
          tableCell(isSaturdayDS ? formatFuel(e.fuelConsumedForPump) : '-'),
          tableCell(formatTextOrDash(e.remarks), maxLines: null, textAlign: TextAlign.left, alignment: Alignment.centerLeft), 
          tableCell(isTakingOnCharge ? formatTextOrDash(e.vehicleCheckTime) : '-'),
          tableCell(formatTextOrDash(e.operatorName).replaceFirst(RegExp(r'\s*\('), '\n(')),
        ]));
      }
      
      runningKm += e.travelledDistance + e.pumpKm;
      runningFuel = runningFuel + e.suppliedFuel - e.fuelConsumedForJourney - e.fuelConsumedForPump;
    }

    int totalPages = (entries.length / itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;
    
    if (pageIndex == -1 || pageIndex == totalPages - 1 || entries.isEmpty) {
      DateTime closingDate = entries.isNotEmpty ? entries.last.date : DateTime(monthYear.year, monthYear.month, 1);
      dataRowWidgets.add(buildBoldRow(closingDate, runningKm, runningFuel));
    }

    Widget buildSummaryRow(String text, String value, {String unit = 'ലിറ്റർ', bool isPlus = false, bool isMinus = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 10.5)),
            ),
            SizedBox(
              width: 50,
              child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5)),
            ),
            SizedBox(
              width: 40,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(unit, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5)),
              ),
            ),
            SizedBox(
              width: 20,
              child: Text(isPlus ? '+' : (isMinus ? '-' : ''), style: const TextStyle(fontSize: 10.5)),
            ),
          ],
        ),
      );
    }

    String totalKmStr = _formatDecimal(totalKm);

    Widget bottomSection = Container(
      width: 1059,
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Align(
                  alignment: Alignment.center,
                  child: Text('ആകെ    വരവ്', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(height: 10),
                buildSummaryRow('(1) മാസത്തിന്റെ തുടക്കത്തിൽ ടാങ്കിൽ ഉണ്ടായിരുന്ന ഇന്ധനം', openingFuel.toStringAsFixed(2), isPlus: true),
                buildSummaryRow('(2) നടപ്പുമാസത്തിൽ നൽകിയത്', totalSupplied.toStringAsFixed(2), unit: '"'),
                buildSummaryRow('(3) ആകെ ഇന്ധനം', totalFuel.toStringAsFixed(2), unit: '"', isMinus: true),
                buildSummaryRow('(4) മാസാവസാനം ടാങ്കിൽ ശേഷിച്ച ഇന്ധനം', closingFuel.toStringAsFixed(2), unit: '"'),
                buildSummaryRow('(5) തൻമാസം വാഹനത്തിന് ആകെ ചെലവായ ഇന്ധനം', totalConsumed.toStringAsFixed(2), unit: '"'),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Align(
                  alignment: Alignment.center,
                  child: Text('തരം തിരിച്ച ചെലവ്', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(height: 10),
                buildSummaryRow('(1) ആകെ തൻമാസം ചെലവായ ഇന്ധനം', totalConsumed.toStringAsFixed(2), isMinus: true),
                buildSummaryRow(pumpSummaryLabel, fuelConsumedPumpTotal.toStringAsFixed(2), unit: '"', isMinus: true),
                buildSummaryRow('(3) തൻമാസം ദിനംപ്രതി പ്രവർത്തനത്തിനുള്ള ചെലവ്', totalDSFuel.toStringAsFixed(2), unit: '"', isMinus: true),
                buildSummaryRow('(4) തൻമാസം $totalKmStr കി. മീ. യാത്ര ചെയ്തതിന് ചെലവായ ഇന്ധനം', fuelConsumedJourneyTotal.toStringAsFixed(2), unit: '"', isMinus: true),
                buildSummaryRow('(5) ശരാശരി ചെലവ്', averageMileage.toStringAsFixed(2), unit: 'കി.മീ / ലിറ്റർ'),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.only(right: 32),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ചാർജ്ജ് ഉദ്യോഗസ്ഥന്റെ ഒപ്പ് : .............................', style: TextStyle(fontSize: 10.5)),
                        SizedBox(height: 6),
                        Text('തിയ്യതി : .............................', style: TextStyle(fontSize: 10.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget titleBlock = Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('കെ. എഫ്. എഫ്. 14', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const Text('ദിനംപ്രതിയുള്ള യാത്രാവിവരണം/പമ്പിന്റെ പ്രവർത്തനം', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 80),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('ഡിവിഷൻ : കോഴിക്കോട്', style: TextStyle(fontSize: 12)),
            const Text('സ്റ്റേഷൻ : മീഞ്ചന്ത', style: TextStyle(fontSize: 12)),
            Text('രജിസ്റ്റർ നമ്പർ : ${vehicle.regNumber}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 16),
      ]
    );

    // Capture images
    final Uint8List titleImage = await captureWidget(titleBlock);
    final Uint8List headerImageBytes = await captureWidget(headerRowWidget);
    final Uint8List footerImage = await captureWidget(bottomSection);
    
    List<Uint8List> capturedRowImages = [];
    for (var widget in dataRowWidgets) {
      capturedRowImages.add(await captureWidget(widget));
    }

    final double availableWidth = PdfPageFormat.a4.landscape.width - 64;

    pw.Widget buildPdfImage(Uint8List bytes, String name) {
      final img = pw.MemoryImage(bytes);
      final double aspectRatio = img.width! / img.height!;
      final double height = availableWidth / aspectRatio;

      return pw.Container(
        width: availableWidth,
        height: height,
        child: pw.Image(img, fit: pw.BoxFit.fill),
      );
    }

    if (pageIndex == -1) {
      for (int p = 0; p < totalPages; p++) {
        int start = p * itemsPerPage;
        int end = start + itemsPerPage;
        
        bool isLastPage = p == totalPages - 1;
        if (isLastPage) {
          end = capturedRowImages.length;
        } else if (end > capturedRowImages.length) {
          end = capturedRowImages.length;
        }

        List<Uint8List> pageRowImages = capturedRowImages.sublist(start, end);
        
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              return pw.Center(
                child: pw.FittedBox(
                  fit: pw.BoxFit.contain,
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      buildPdfImage(titleImage, 'Title'),
                      buildPdfImage(headerImageBytes, 'Header'),
                      for (int i = 0; i < pageRowImages.length; i++)
                        buildPdfImage(pageRowImages[i], 'Row $i'),
                      if (isLastPage || entries.isEmpty)
                        buildPdfImage(footerImage, 'Footer'),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }
    } else {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.FittedBox(
                fit: pw.BoxFit.contain,
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    buildPdfImage(titleImage, 'Title'),
                    buildPdfImage(headerImageBytes, 'Header'),
                    for (int i = 0; i < capturedRowImages.length; i++)
                      buildPdfImage(capturedRowImages[i], 'Row $i'),
                    if (pageIndex == totalPages - 1 || entries.isEmpty)
                      buildPdfImage(footerImage, 'Footer'),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return pdf.save();
  }
}
