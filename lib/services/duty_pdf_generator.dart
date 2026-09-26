import 'dart:typed_data';
import 'package:flutter/material.dart' as material;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/duty_register_model.dart';
import '../models/attendance_model.dart';
import '../models/manpower_model.dart';
import 'text_to_image_service.dart';
import '../config/app_config.dart';

class PdfPreRenderedTexts {
  final pw.MemoryImage dutyReg;
  final pw.MemoryImage rollCall;
  final pw.MemoryImage offDuty;
  final pw.MemoryImage onDuty;
  final pw.MemoryImage leave;
  final pw.MemoryImage total;
  final pw.MemoryImage signature;
  final pw.MemoryImage homeGuards;
  final pw.MemoryImage leaveOD;
  final pw.MemoryImage stationTraining;
  
  // Top-most table fields
  final pw.MemoryImage stationWriter;
  final pw.MemoryImage weeklyLeave;
  final pw.MemoryImage casualLeave;
  final pw.MemoryImage specialDuty;
  final pw.MemoryImage medicalLeave;
  final pw.MemoryImage outDuty;
  final pw.MemoryImage training;
  final pw.MemoryImage vacancies;
  final pw.MemoryImage subStationHead;
  final pw.MemoryImage stationHead;
  
  // Dynamic header fields
  final pw.MemoryImage headerImage;
  final pw.MemoryImage offDutyColon;

  PdfPreRenderedTexts({
    required this.dutyReg,
    required this.rollCall,
    required this.offDuty,
    required this.onDuty,
    required this.leave,
    required this.total,
    required this.signature,
    required this.homeGuards,
    required this.leaveOD,
    required this.stationTraining,
    required this.stationWriter,
    required this.weeklyLeave,
    required this.casualLeave,
    required this.specialDuty,
    required this.medicalLeave,
    required this.outDuty,
    required this.training,
    required this.vacancies,
    required this.subStationHead,
    required this.stationHead,
    required this.headerImage,
    required this.offDutyColon,
  });
}

class DutyPdfGenerator {
  static double _dynamicPadding = 2.5;
  static double _dynamicSummaryHeight = 14.0;
  static double _fontScale = 1.0;
  static Future<Uint8List> generateDutyRegisterPdf(
    DutyRegisterModel register, {
    Map<String, MonthlyAttendance>? attendanceMap,
    List<Manpower>? personnelList,
  }) async {
    final pdf = pw.Document();

    int vehicleCount = register.vehicleAssignments.length;
    if (vehicleCount <= 10) {
      _dynamicPadding = 6.0;
      _dynamicSummaryHeight = 17.0;
      _fontScale = 1.3;
    } else if (vehicleCount <= 14) {
      _dynamicPadding = 4.0;
      _dynamicSummaryHeight = 15.0;
      _fontScale = 1.15;
    } else {
      _dynamicPadding = 2.5;
      _dynamicSummaryHeight = 14.0;
      _fontScale = 1.0;
    }

    final weekDays = ['തിങ്കളാഴ്ച', 'ചൊവ്വാഴ്ച', 'ബുധനാഴ്ച', 'വ്യാഴാഴ്ച', 'വെള്ളിയാഴ്ച', 'ശനിയാഴ്ച', 'ഞായറാഴ്ച'];
    final dayName = weekDays[register.date.weekday - 1];
    
    // As per user request, this text is fixed on the PDF
    final rollCallStr = 'രാവിലെ 8.45 മണിയുടെ റോൾകോൾ';

    // Calculate dynamic data
    List<String> offDutyIdNumbers = [];
    List<String> offDutyDrIdNumbers = [];
    List<String> sfroIds = [];
    List<String> sfroMIds = [];
    List<String> froDIds = [];
    List<String> froIds = [];
    List<String> weeklyLeaveIds = [];
    List<String> casualLeaveIds = [];
    List<String> otherLeaveIds = [];
    List<String> medicalLeaveIds = [];
    List<String> outDutyIds = [];
    List<String> trainingIds = [];
    List<String> subStationHeadIds = [];
    List<String> stationHeadIds = [];

    // Station Training dynamic data
    List<String> trainingOffDutyIds = [];
    List<String> trainingOffDutyDrIds = [];
    List<String> trainingOnDutyIds = [];
    List<String> trainingLeaveIds = [];

    // Home Guards dynamic data
    List<String> hgOffDutyIds = [];
    List<String> hgOffDutyDrIds = [];
    List<String> hgOnDutyIds = [];
    List<String> hgLeaveOdIds = [];
    List<String> hgSpecialDutyIds = [];

    // Other Stations dynamic data
    Map<String, List<String>> otherStationsOffDutyIds = {};
    Map<String, List<String>> otherStationsOffDutyDrIds = {};
    Map<String, List<String>> otherStationsOnDutyIds = {};
    Map<String, List<String>> otherStationsLeaveIds = {};
    Map<String, List<String>> otherStationsSpecialDutyIds = {};

    // Filtered manual assignments based on daily status
    List<String> actualStationWriterIds = [];
    List<String> actualSpecialDutyIds = [];

    if (personnelList != null) {
      for (var person in personnelList) {
        final attendance = attendanceMap != null ? attendanceMap[person.id] : null;
        final status = attendance?.dailyStatus[register.date.day];
        
        bool isStationWriter = register.stationWriterIds.contains(person.idNumber);

        if (isStationWriter && (status == 'X' || status?.toUpperCase() == 'X/R' || status == null || status.isEmpty)) {
          actualStationWriterIds.add(person.idNumber);
          continue; // Deduplicate from all general lists
        }
        
        bool isTrainee = person.designation.toLowerCase() == 'trainees';
        bool isStationTraining = person.isTempAttachedForTraining || 
                                 (isTrainee && status != 'T' && status != 'Trg' && status?.toUpperCase() != 'TRG');

        if (isStationTraining) {
          if (status == 'R') {
            trainingOffDutyIds.add(person.idNumber);
          } else if (status == 'DR') {
            trainingOffDutyDrIds.add(person.idNumber);
          } else if (status == 'X' || status?.toUpperCase() == 'X/R' || status == null || status.isEmpty) {
            trainingOnDutyIds.add(person.idNumber);
          } else {
            trainingLeaveIds.add(person.idNumber);
          }
          continue; // Skip from all other calculations!
        }
        
        if (isTrainee) {
          // If trainee and not in station training, they are in Academy training
          trainingIds.add(person.idNumber);
          continue;
        }

        bool isHomeStation = person.currentStation.trim().isEmpty || 
                             person.currentStation.trim().toLowerCase() == AppConfig.stationNameShort.toLowerCase();

        if (!isHomeStation) {
          final station = person.currentStation;
          otherStationsOffDutyIds.putIfAbsent(station, () => []);
          otherStationsOffDutyDrIds.putIfAbsent(station, () => []);
          otherStationsOnDutyIds.putIfAbsent(station, () => []);
          otherStationsLeaveIds.putIfAbsent(station, () => []);
          otherStationsSpecialDutyIds.putIfAbsent(station, () => []);
          
          if (status == 'R') {
            otherStationsOffDutyIds[station]!.add(person.idNumber);
          } else if (status == 'DR') {
            otherStationsOffDutyDrIds[station]!.add(person.idNumber);
          } else if (status == 'OD' || status == 'SD' || status == 'WA') {
            otherStationsSpecialDutyIds[station]!.add(person.idNumber);
          } else if (status == 'X' || status?.toUpperCase() == 'X/R' || status == null || status.isEmpty) {
            otherStationsOnDutyIds[station]!.add(person.idNumber);
          } else if (status.isNotEmpty) {
            otherStationsLeaveIds[station]!.add('${person.idNumber} ($status)');
          }
          continue; // Skip these personnel from other station counts
        }

        if (attendance != null) {
          if (person.designation == 'KHG') {
            if (status == 'R') {
              hgOffDutyIds.add(person.idNumber);
            } else if (status == 'DR') {
              hgOffDutyDrIds.add(person.idNumber);
            } else if (status == 'X' || status?.toUpperCase() == 'X/R' || status == null || status.isEmpty) {
              hgOnDutyIds.add(person.idNumber);
            } else if (status == 'OD' || status == 'SD' || status == 'WA') {
              hgSpecialDutyIds.add(person.idNumber);
            } else if (status == 'LWP' || (status.isNotEmpty)) {
              hgLeaveOdIds.add(person.idNumber);
            }
          } else {
            if (status == 'R') {
              offDutyIdNumbers.add(person.idNumber);
            } else if (status == 'DR') {
              offDutyDrIdNumbers.add(person.idNumber);
            } else if (status == 'OFF') {
              weeklyLeaveIds.add(person.idNumber);
            } else if (status == 'CL') {
              casualLeaveIds.add(person.idNumber);
            } else if (['BH', 'HP', 'RH', 'CML', 'EL', 'HPL', 'SPCL', 'SpCL', 'PL'].contains(status)) {
              otherLeaveIds.add(person.idNumber);
            } else if (status == 'ML' || status == 'A') {
              medicalLeaveIds.add(person.idNumber);
            } else if (status == 'OD') {
              outDutyIds.add(person.idNumber);
            } else if (status == 'SD' || status == 'WA') {
              actualSpecialDutyIds.add(person.idNumber);
            } else if (status == 'T' || status == 'Trg') {
              trainingIds.add(person.idNumber);
            } else if (status == 'X' || status?.toUpperCase() == 'X/R' || status == null || status.isEmpty) {
              if (person.designation == 'STO') {
                stationHeadIds.add(person.idNumber);
              } else if (person.designation == 'ASTO') {
                subStationHeadIds.add(person.idNumber);
              } else if (person.designation == 'SFRO') {
                sfroIds.add(person.idNumber);
              } else if (person.designation == 'SFRO (M)') {
                sfroMIds.add(person.idNumber);
              } else if (person.designation == 'FRO (D)') {
                froDIds.add(person.idNumber);
              } else if (person.designation == 'FRO') {
                froIds.add(person.idNumber);
              }
            }
          }
        }
      }
    }
    
    bool isSfroInCharge = sfroIds.isEmpty && sfroMIds.isEmpty;
    if (isSfroInCharge && froIds.isNotEmpty && personnelList != null) {
      final presentFros = personnelList.where((p) => froIds.contains(p.idNumber)).toList();
      if (presentFros.isNotEmpty) {
        presentFros.sort((a, b) {
          if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
          int rankA = 999999;
          final matchA = RegExp(r'\d+').firstMatch(a.idNumber);
          if (matchA != null) rankA = int.parse(matchA.group(0)!);
          int rankB = 999999;
          final matchB = RegExp(r'\d+').firstMatch(b.idNumber);
          if (matchB != null) rankB = int.parse(matchB.group(0)!);
          return rankA.compareTo(rankB);
        });
        final actingSfro = presentFros.first;
        froIds.remove(actingSfro.idNumber);
        sfroIds.add(actingSfro.idNumber);
      }
    }
    
    int _getSeniorityRank(String idNumber) {
      final match = RegExp(r'\d+').firstMatch(idNumber);
      if (match != null) {
        String digits = match.group(0)!;
        int num = int.parse(digits);
        if (num < 100) return num + 200000;
        if (num < 1000) return num + 100000;
        if (digits.startsWith('10')) return num + 50000;
        return num;
      }
      return 999999;
    }

    // Helper function to format ID numbers by grouping consecutive identical prefixes
    String formatIdNumbers(List<String> ids) {
      if (ids.isEmpty) return '';
      ids = List.from(ids)..sort((a, b) => _getSeniorityRank(a).compareTo(_getSeniorityRank(b)));
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

    String formatIdNumbersCombined(List<String> rIds, List<String> drIds) {
      String rStr = formatIdNumbers(rIds);
      String drStr = formatIdNumbers(drIds);
      if (rStr.isEmpty && drStr.isEmpty) return '';
      if (rStr.isEmpty) return 'D/R- $drStr';
      if (drStr.isEmpty) return rStr;
      return '$rStr. D/R- $drStr';
    }

    final offDutyCountStr = (offDutyIdNumbers.length + offDutyDrIdNumbers.length) > 0 ? (offDutyIdNumbers.length + offDutyDrIdNumbers.length).toString() : '';
    final offDutyDetailsStr = formatIdNumbersCombined(offDutyIdNumbers, offDutyDrIdNumbers);
    
    final sfroCountStr = sfroIds.isNotEmpty ? sfroIds.length.toString() : '';
    final sfroDetailsStr = formatIdNumbers(sfroIds);
    final sfroMCountStr = sfroMIds.isNotEmpty ? sfroMIds.length.toString() : '';
    final sfroMDetailsStr = formatIdNumbers(sfroMIds);
    final froDCountStr = froDIds.isNotEmpty ? froDIds.length.toString() : '';
    final froDDetailsStr = formatIdNumbers(froDIds);
    final froCountStr = froIds.isNotEmpty ? froIds.length.toString() : '';
    final froDetailsStr = formatIdNumbers(froIds);

    final weeklyLeaveCountStr = weeklyLeaveIds.isNotEmpty ? weeklyLeaveIds.length.toString() : '';
    final weeklyLeaveDetailsStr = formatIdNumbers(weeklyLeaveIds);
    final casualLeaveCountStr = casualLeaveIds.isNotEmpty ? casualLeaveIds.length.toString() : '';
    final casualLeaveDetailsStr = formatIdNumbers(casualLeaveIds);
    final otherLeaveCountStr = otherLeaveIds.isNotEmpty ? otherLeaveIds.length.toString() : '';
    final otherLeaveDetailsStr = formatIdNumbers(otherLeaveIds);
    final medicalLeaveCountStr = medicalLeaveIds.isNotEmpty ? medicalLeaveIds.length.toString() : '';
    final medicalLeaveDetailsStr = formatIdNumbers(medicalLeaveIds);
    final outDutyCountStr = outDutyIds.isNotEmpty ? outDutyIds.length.toString() : '';
    final outDutyDetailsStr = formatIdNumbers(outDutyIds);
    final trainingCountStr = trainingIds.isNotEmpty ? trainingIds.length.toString() : '';
    final trainingDetailsStr = formatIdNumbers(trainingIds);
    final subStationHeadCountStr = subStationHeadIds.isNotEmpty ? subStationHeadIds.length.toString() : '';
    final subStationHeadDetailsStr = formatIdNumbers(subStationHeadIds);
    final stationHeadCountStr = stationHeadIds.isNotEmpty ? stationHeadIds.length.toString() : '';
    final stationHeadDetailsStr = formatIdNumbers(stationHeadIds);

    final hgOffDutyCountStr = (hgOffDutyIds.length + hgOffDutyDrIds.length) > 0 ? (hgOffDutyIds.length + hgOffDutyDrIds.length).toString() : '';
    final hgOffDutyDetailsStr = formatIdNumbersCombined(hgOffDutyIds, hgOffDutyDrIds);
    final hgOnDutyCountStr = hgOnDutyIds.isNotEmpty ? hgOnDutyIds.length.toString() : '';
    final hgOnDutyDetailsStr = formatIdNumbers(hgOnDutyIds);
    final hgSpecialDutyCountStr = hgSpecialDutyIds.isNotEmpty ? hgSpecialDutyIds.length.toString() : '';
    final hgSpecialDutyDetailsStr = formatIdNumbers(hgSpecialDutyIds);
    final hgLeaveOdCountStr = hgLeaveOdIds.isNotEmpty ? hgLeaveOdIds.length.toString() : '';
    final hgLeaveOdDetailsStr = formatIdNumbers(hgLeaveOdIds);

    final trainingOffDutyCountStr = (trainingOffDutyIds.length + trainingOffDutyDrIds.length) > 0 ? (trainingOffDutyIds.length + trainingOffDutyDrIds.length).toString() : '';
    final trainingOffDutyDetailsStr = formatIdNumbersCombined(trainingOffDutyIds, trainingOffDutyDrIds);
    final trainingOnDutyCountStr = trainingOnDutyIds.isNotEmpty ? trainingOnDutyIds.length.toString() : '';
    final trainingOnDutyDetailsStr = formatIdNumbers(trainingOnDutyIds);
    final trainingLeaveCountStr = trainingLeaveIds.isNotEmpty ? trainingLeaveIds.length.toString() : '';
    final trainingLeaveDetailsStr = formatIdNumbers(trainingLeaveIds);
    final int trainingTotal = trainingOffDutyIds.length + trainingOffDutyDrIds.length + trainingOnDutyIds.length + trainingLeaveIds.length;
    final trainingTotalStr = trainingTotal > 0 ? trainingTotal.toString() : '';

    Map<String, Map<String, String>> otherStationsData = {};
    for (String station in otherStationsOffDutyIds.keys) {
      final offIds = otherStationsOffDutyIds[station]!;
      final drIds = otherStationsOffDutyDrIds[station] ?? [];
      final onIds = otherStationsOnDutyIds[station]!;
      final leaveIds = otherStationsLeaveIds[station]!;
      final specialIds = otherStationsSpecialDutyIds[station]!;

      final total = offIds.length + drIds.length + onIds.length + leaveIds.length + specialIds.length;
      
      otherStationsData[station] = {
        'offCount': (offIds.length + drIds.length) > 0 ? (offIds.length + drIds.length).toString() : '',
        'offDetails': formatIdNumbersCombined(offIds, drIds),
        'onCount': onIds.isNotEmpty ? onIds.length.toString() : '',
        'onDetails': formatIdNumbers(onIds),
        'leaveCount': leaveIds.isNotEmpty ? leaveIds.length.toString() : '',
        'leaveDetails': formatIdNumbers(leaveIds),
        'specialCount': specialIds.isNotEmpty ? specialIds.length.toString() : '',
        'specialDetails': formatIdNumbers(specialIds),
        'total': total > 0 ? total.toString() : '',
      };
    }

    final stationWriterCountStr = actualStationWriterIds.isNotEmpty ? actualStationWriterIds.length.toString() : '';
    final stationWriterDetailsStr = formatIdNumbers(actualStationWriterIds);

    final specialDutyCountStr = actualSpecialDutyIds.isNotEmpty ? actualSpecialDutyIds.length.toString() : '';
    final specialDutyDetailsStr = formatIdNumbers(actualSpecialDutyIds);

    final int parsedVacancyCount = int.tryParse(register.vacancyCount.trim()) ?? 0;
    final int stationStaffTotal = offDutyIdNumbers.length + offDutyDrIdNumbers.length +
        sfroIds.length + sfroMIds.length + froDIds.length + froIds.length +
        weeklyLeaveIds.length + casualLeaveIds.length + otherLeaveIds.length +
        medicalLeaveIds.length + outDutyIds.length + trainingIds.length +
        actualStationWriterIds.length + actualSpecialDutyIds.length +
        subStationHeadIds.length + stationHeadIds.length + parsedVacancyCount;
    final stationStaffTotalStr = stationStaffTotal > 0 ? stationStaffTotal.toString() : '';

    final int hgTotal = hgOffDutyIds.length + hgOffDutyDrIds.length + hgOnDutyIds.length + hgLeaveOdIds.length + hgSpecialDutyIds.length;
    final hgTotalStr = hgTotal > 0 ? hgTotal.toString() : '';

    Map<String, pw.MemoryImage> otherStationImages = {};
    for (String station in otherStationsOffDutyIds.keys) {
      otherStationImages[station] = pw.MemoryImage(await TextToImageService.convertTextToImage(station, fontSize: (32).toDouble(), fontWeight: material.FontWeight.bold));
    }

    // Pre-render Malayalam text as high-resolution images
    final texts = PdfPreRenderedTexts(
      dutyReg: pw.MemoryImage(await TextToImageService.convertTextToImage('ഡ്യൂട്ടി രജിസ്റ്റർ (DUTY REGISTER)', fontSize: 40, fontWeight: material.FontWeight.bold)),
      rollCall: pw.MemoryImage(await TextToImageService.convertTextToImage('റോൾകോൾ: ${register.rollCallTime}', fontSize: 36, fontWeight: material.FontWeight.bold)),
      offDuty: pw.MemoryImage(await TextToImageService.convertTextToImage('വിശ്രമത്തിന് പോകുന്നവർ', fontSize: (26).toDouble())),
      onDuty: pw.MemoryImage(await TextToImageService.convertTextToImage('ജോലി ഏൽക്കുന്നവർ', fontSize: (26).toDouble())),
      leave: pw.MemoryImage(await TextToImageService.convertTextToImage('ആഴ്ച/ആകസ്മിക അവധി', fontSize: (26).toDouble())),
      total: pw.MemoryImage(await TextToImageService.convertTextToImage('ആകെ', fontSize: (26).toDouble(), fontWeight: material.FontWeight.bold)),
      signature: pw.MemoryImage(await TextToImageService.convertTextToImage('ഒപ്പ് / Signature', fontSize: (32).toDouble(), fontWeight: material.FontWeight.bold)),
      homeGuards: pw.MemoryImage(await TextToImageService.convertTextToImage('ഹോം ഗാർഡ്സ്', fontSize: (32).toDouble(), fontWeight: material.FontWeight.bold)),
      leaveOD: pw.MemoryImage(await TextToImageService.convertTextToImage('ശൂന്യവേതന അവധി/LWP', fontSize: (26).toDouble())),
      stationTraining: pw.MemoryImage(await TextToImageService.convertTextToImage('നിലയ പരിശീലനം', fontSize: (32).toDouble(), fontWeight: material.FontWeight.bold)),
      
      stationWriter: pw.MemoryImage(await TextToImageService.convertTextToImage('നിലയം എഴുത്തുകാരൻ', fontSize: (26).toDouble())),
      weeklyLeave: pw.MemoryImage(await TextToImageService.convertTextToImage('ആഴ്ച അവധി', fontSize: (26).toDouble())),
      casualLeave: pw.MemoryImage(await TextToImageService.convertTextToImage('ആകസ്മിക അവധി', fontSize: (26).toDouble())),
      specialDuty: pw.MemoryImage(await TextToImageService.convertTextToImage('പ്രവർത്തനക്രമീകരണം/\nസ്പെഷ്യൽ ഡ്യൂട്ടി', fontSize: (26).toDouble())),
      medicalLeave: pw.MemoryImage(await TextToImageService.convertTextToImage('മെഡിക്കൽ അവധി/\nആബ്സെൻ്റ്', fontSize: (26).toDouble())),
      outDuty: pw.MemoryImage(await TextToImageService.convertTextToImage('ഔട്ട് ഡ്യൂട്ടി', fontSize: (26).toDouble())),
      training: pw.MemoryImage(await TextToImageService.convertTextToImage('പരിശീലനം', fontSize: (26).toDouble())),
      vacancies: pw.MemoryImage(await TextToImageService.convertTextToImage('ഒഴിവുകൾ', fontSize: (26).toDouble())),
      subStationHead: pw.MemoryImage(await TextToImageService.convertTextToImage('ഉപനിലയത്തലവൻ', fontSize: (26).toDouble())),
      stationHead: pw.MemoryImage(await TextToImageService.convertTextToImage('നിലയത്തലവൻ', fontSize: (26).toDouble())),
      
      headerImage: pw.MemoryImage(await TextToImageService.convertTextToImage('${DateFormat('dd-MM-yyyy').format(register.date)}   $dayName   $rollCallStr', fontSize: (32).toDouble(), fontWeight: material.FontWeight.bold)),
      offDutyColon: pw.MemoryImage(await TextToImageService.convertTextToImage('വിശ്രമത്തിന് പോകുന്നവർ:', fontSize: (26).toDouble())),
    );

    pdf.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.only(left: 75, right: 15, top: 15, bottom: 25),
          buildBackground: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Stack(
                children: [
                  pw.Positioned(
                    left: 5,
                    top: (15.1 * 72.0 / 2.54) - 0.5, // 15.1 cm from the top (moved 1mm down)
                    child: pw.Container(
                      width: 15,
                      height: 1,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        build: (pw.Context context) {
          return pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            child: pw.Container(
              width: PdfPageFormat.a4.width - 45 - 25,
              child: pw.Column(
                children: [
                  _buildHeader(register, texts),
                  _buildTopSummaries(
                    isSfroInCharge: isSfroInCharge,
                    texts: texts, 
                    offDutyCount: offDutyCountStr, offDutyDetails: offDutyDetailsStr,
                    sfroCount: sfroCountStr, sfroDetails: sfroDetailsStr,
                    sfroMCount: sfroMCountStr, sfroMDetails: sfroMDetailsStr,
                    froDCount: froDCountStr, froDDetails: froDDetailsStr,
                    froCount: froCountStr, froDetails: froDetailsStr,
                    weeklyLeaveCount: weeklyLeaveCountStr, weeklyLeaveDetails: weeklyLeaveDetailsStr,
                    casualLeaveCount: casualLeaveCountStr, casualLeaveDetails: casualLeaveDetailsStr,
                    otherLeaveCount: otherLeaveCountStr, otherLeaveDetails: otherLeaveDetailsStr,
                    medicalLeaveCount: medicalLeaveCountStr, medicalLeaveDetails: medicalLeaveDetailsStr,
                    outDutyCount: outDutyCountStr, outDutyDetails: outDutyDetailsStr,
                    trainingCount: trainingCountStr, trainingDetails: trainingDetailsStr,
                    stationWriterCount: stationWriterCountStr, stationWriterDetails: stationWriterDetailsStr,
                    specialDutyCount: specialDutyCountStr, specialDutyDetails: specialDutyDetailsStr,
                    subStationHeadCount: subStationHeadCountStr, subStationHeadDetails: subStationHeadDetailsStr,
                    stationHeadCount: stationHeadCountStr, stationHeadDetails: stationHeadDetailsStr,
                    hgOffDutyCount: hgOffDutyCountStr, hgOffDutyDetails: hgOffDutyDetailsStr,
                    hgOnDutyCount: hgOnDutyCountStr, hgOnDutyDetails: hgOnDutyDetailsStr,
                    hgSpecialDutyCount: hgSpecialDutyCountStr, hgSpecialDutyDetails: hgSpecialDutyDetailsStr,
                    hgLeaveOdCount: hgLeaveOdCountStr, hgLeaveOdDetails: hgLeaveOdDetailsStr,
                    trainingOffDutyCount: trainingOffDutyCountStr, trainingOffDutyDetails: trainingOffDutyDetailsStr,
                    trainingOnDutyCount: trainingOnDutyCountStr, trainingOnDutyDetails: trainingOnDutyDetailsStr,
                    trainingLeaveCount: trainingLeaveCountStr, trainingLeaveDetails: trainingLeaveDetailsStr,
                    trainingTotal: trainingTotalStr,
                    otherStationsData: otherStationsData,
                    otherStationImages: otherStationImages,
                    vacancyCount: register.vacancyCount,
                    vacancyDetails: register.vacancyDetails,
                    stationStaffTotal: stationStaffTotalStr,
                    hgTotal: hgTotalStr,
                  ),
                  pw.SizedBox(height: 2),
                  _buildVehicleTable(
                    register, 
                    personnelList,
                    phoneDuty: formatIdNumbers(register.phoneDutyIds),
                    messenger: formatIdNumbers(register.messengerIds),
                    sentryDuty: formatIdNumbers(register.sentryDutyIds),
                    controlRoom: formatIdNumbers(register.controlRoomIds),
                    isSfroInCharge: isSfroInCharge,
                  ),
                  pw.SizedBox(height: 3),
                  _buildFooter(register),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(DutyRegisterModel register, PdfPreRenderedTexts texts) {
    return pw.Column(
      children: [
        pw.Center(
          child: pw.Image(texts.headerImage, height: 12),
        ),
        pw.SizedBox(height: 2),
        pw.Divider(thickness: 1, color: PdfColors.black, height: 1),
        pw.SizedBox(height: 1.5),
        pw.Divider(thickness: 1, color: PdfColors.black, height: 1),
      ]
    );
  }

  static pw.Widget _buildTopSummaries({
    required bool isSfroInCharge,
    required PdfPreRenderedTexts texts, 
    required String offDutyCount, required String offDutyDetails,
    required String sfroCount, required String sfroDetails,
    required String sfroMCount, required String sfroMDetails,
    required String froDCount, required String froDDetails,
    required String froCount, required String froDetails,
    required String weeklyLeaveCount, required String weeklyLeaveDetails,
    required String casualLeaveCount, required String casualLeaveDetails,
    required String otherLeaveCount, required String otherLeaveDetails,
    required String medicalLeaveCount, required String medicalLeaveDetails,
    required String outDutyCount, required String outDutyDetails,
    required String trainingCount, required String trainingDetails,
    required String stationWriterCount, required String stationWriterDetails,
    required String specialDutyCount, required String specialDutyDetails,
    required String subStationHeadCount, required String subStationHeadDetails,
    required String stationHeadCount, required String stationHeadDetails,
    required String hgOffDutyCount, required String hgOffDutyDetails,
    required String hgOnDutyCount, required String hgOnDutyDetails,
    required String hgSpecialDutyCount, required String hgSpecialDutyDetails,
    required String hgLeaveOdCount, required String hgLeaveOdDetails,
    required String trainingOffDutyCount, required String trainingOffDutyDetails,
    required String trainingOnDutyCount, required String trainingOnDutyDetails,
    required String trainingLeaveCount, required String trainingLeaveDetails,
    required String trainingTotal,
    required Map<String, Map<String, String>> otherStationsData,
    required Map<String, pw.MemoryImage> otherStationImages,
    required String vacancyCount, required String vacancyDetails,
    required String stationStaffTotal,
    required String hgTotal,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Off Duty Row (Top of the Huge Table)
        pw.Table(
          border: const pw.TableBorder(
            top: pw.BorderSide(width: 1, color: PdfColors.black),
            bottom: pw.BorderSide(width: 1, color: PdfColors.black),
            left: pw.BorderSide(width: 1, color: PdfColors.black),
            right: pw.BorderSide(width: 1, color: PdfColors.black),
            verticalInside: pw.BorderSide(width: 1, color: PdfColors.black),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(4.5),
            1: const pw.FlexColumnWidth(0.8),
            2: const pw.FlexColumnWidth(8),
          },
          children: [
            _buildSummaryRow(_img(texts.offDutyColon), count: offDutyCount, details: offDutyDetails),
          ],
        ),

        // Header row for Taking Charge (No Borders)
        pw.SizedBox(height: 2),
        pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Image(texts.onDuty, height: 12)
        ),
        pw.SizedBox(height: 1),

        // Rest of the Station Staff Section
        pw.Table(
          border: const pw.TableBorder(
            top: pw.BorderSide(width: 1, color: PdfColors.black),
            bottom: pw.BorderSide(width: 1, color: PdfColors.black),
            left: pw.BorderSide(width: 1, color: PdfColors.black),
            right: pw.BorderSide(width: 1, color: PdfColors.black),
            verticalInside: pw.BorderSide(width: 1, color: PdfColors.black),
            horizontalInside: pw.BorderSide(width: 1, color: PdfColors.black),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(4.5),
            1: const pw.FlexColumnWidth(0.8),
            2: const pw.FlexColumnWidth(8),
          },
          children: [
            _buildSummaryRow(_txt(isSfroInCharge ? 'SFRO (In Charge)' : 'SFRO'), count: sfroCount, details: sfroDetails),
            _buildSummaryRow(_txt('SFRO (M)'), count: sfroMCount, details: sfroMDetails),
            _buildSummaryRow(_txt('FRO (D)'), count: froDCount, details: froDDetails),
            _buildSummaryRow(_txt('FRO'), count: froCount, details: froDetails),
            _buildSummaryRow(_img(texts.stationWriter), count: stationWriterCount, details: stationWriterDetails),
            _buildSummaryRow(_img(texts.weeklyLeave), count: weeklyLeaveCount, details: weeklyLeaveDetails),
            _buildSummaryRow(_img(texts.casualLeave), count: casualLeaveCount, details: casualLeaveDetails),
            _buildSummaryRow(_txt('BH/HP/RH/CML/EL/HPL/SpCL/PL'), count: otherLeaveCount, details: otherLeaveDetails),
            _buildSummaryRow(_img(texts.specialDuty, height: 20), count: specialDutyCount, details: specialDutyDetails),
            _buildSummaryRow(_img(texts.medicalLeave, height: 20), count: medicalLeaveCount, details: medicalLeaveDetails),
            _buildSummaryRow(_img(texts.outDuty), count: outDutyCount, details: outDutyDetails),
            _buildSummaryRow(_img(texts.training), count: trainingCount, details: trainingDetails),
            _buildSummaryRow(_img(texts.vacancies), count: vacancyCount, details: vacancyDetails),
            _buildSummaryRow(_img(texts.subStationHead), count: subStationHeadCount, details: subStationHeadDetails),
            _buildSummaryRow(_img(texts.stationHead), count: stationHeadCount, details: stationHeadDetails),
            _buildSummaryRow(_img(texts.total), count: stationStaffTotal, details: 'PTS - 01', isTotal: true),
          ],
        ),

        pw.SizedBox(height: 3),

        // Home Guards Section
        pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Image(texts.homeGuards, height: 12)
        ),
        pw.SizedBox(height: 1),
        pw.Table(
          border: const pw.TableBorder(
            top: pw.BorderSide(width: 1, color: PdfColors.black),
            bottom: pw.BorderSide(width: 1, color: PdfColors.black),
            left: pw.BorderSide(width: 1, color: PdfColors.black),
            right: pw.BorderSide(width: 1, color: PdfColors.black),
            verticalInside: pw.BorderSide(width: 1, color: PdfColors.black),
            horizontalInside: pw.BorderSide(width: 1, color: PdfColors.black),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(4.5),
            1: const pw.FlexColumnWidth(0.8),
            2: const pw.FlexColumnWidth(8),
          },
          children: [
            _buildSummaryRow(_img(texts.offDuty), count: hgOffDutyCount, details: hgOffDutyDetails),
            _buildSummaryRow(_img(texts.onDuty), count: hgOnDutyCount, details: hgOnDutyDetails),
            _buildSummaryRow(_img(texts.specialDuty, height: 20), count: hgSpecialDutyCount, details: hgSpecialDutyDetails),
            _buildSummaryRow(_img(texts.leaveOD), count: hgLeaveOdCount, details: hgLeaveOdDetails),
            _buildSummaryRow(_img(texts.total), count: hgTotal, isTotal: true),
          ],
        ),

        // Station Training Table
        if (trainingTotal.isNotEmpty)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 3),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Image(texts.stationTraining, height: 12)
              ),
              pw.SizedBox(height: 1),
              pw.Table(
                border: const pw.TableBorder(
                  top: pw.BorderSide(width: 1, color: PdfColors.black),
                  bottom: pw.BorderSide(width: 1, color: PdfColors.black),
                  left: pw.BorderSide(width: 1, color: PdfColors.black),
                  right: pw.BorderSide(width: 1, color: PdfColors.black),
                  verticalInside: pw.BorderSide(width: 1, color: PdfColors.black),
                  horizontalInside: pw.BorderSide(width: 1, color: PdfColors.black),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4.5),
                  1: const pw.FlexColumnWidth(0.8),
                  2: const pw.FlexColumnWidth(8),
                },
                children: [
                  _buildSummaryRow(_img(texts.offDuty), count: trainingOffDutyCount, details: trainingOffDutyDetails),
                  _buildSummaryRow(_img(texts.onDuty), count: trainingOnDutyCount, details: trainingOnDutyDetails),
                  _buildSummaryRow(_img(texts.leave), count: trainingLeaveCount, details: trainingLeaveDetails),
                  _buildSummaryRow(_img(texts.total), count: trainingTotal, isTotal: true),
                ],
              ),
            ]
          ),

        // Other Stations
        for (String station in otherStationsData.keys)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 3),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Image(otherStationImages[station]!, height: 12)
              ),
              pw.SizedBox(height: 1),
              pw.Table(
                border: const pw.TableBorder(
                  top: pw.BorderSide(width: 1, color: PdfColors.black),
                  bottom: pw.BorderSide(width: 1, color: PdfColors.black),
                  left: pw.BorderSide(width: 1, color: PdfColors.black),
                  right: pw.BorderSide(width: 1, color: PdfColors.black),
                  verticalInside: pw.BorderSide(width: 1, color: PdfColors.black),
                  horizontalInside: pw.BorderSide(width: 1, color: PdfColors.black),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4.5),
                  1: const pw.FlexColumnWidth(0.8),
                  2: const pw.FlexColumnWidth(8),
                },
                children: [
                  _buildSummaryRow(_img(texts.offDuty), count: otherStationsData[station]!['offCount']!, details: otherStationsData[station]!['offDetails']!),
                  _buildSummaryRow(_img(texts.onDuty), count: otherStationsData[station]!['onCount']!, details: otherStationsData[station]!['onDetails']!),
                  _buildSummaryRow(_img(texts.specialDuty, height: 20), count: otherStationsData[station]!['specialCount']!, details: otherStationsData[station]!['specialDetails']!),
                  _buildSummaryRow(_img(texts.leave), count: otherStationsData[station]!['leaveCount']!, details: otherStationsData[station]!['leaveDetails']!),
                  _buildSummaryRow(_img(texts.total), count: otherStationsData[station]!['total']!, isTotal: true),
                ],
              ),
            ]
          ),
      ],
    );
  }

  static pw.Widget _img(pw.MemoryImage img, {double height = 12.5}) => pw.FittedBox(
    fit: pw.BoxFit.scaleDown,
    alignment: pw.Alignment.centerLeft,
    child: pw.Image(img, height: height),
  );
  static pw.Widget _txt(String text) => pw.Text(text, style: pw.TextStyle(fontSize: 9));

  static String _formatCount(String count) {
    final parsed = int.tryParse(count.trim());
    if (parsed != null) {
      return parsed.toString().padLeft(2, '0');
    }
    if (count.trim().isEmpty) return '00';
    return count;
  }

  static pw.TableRow _buildSummaryRow(pw.Widget titleWidget, {String count = '', String details = '', bool isTotal = false}) {
    final formattedCount = _formatCount(count);
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(vertical: _dynamicPadding, horizontal: 4),
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: titleWidget,
          )
        ),
        // Cell for Count
        pw.Container(
          padding: pw.EdgeInsets.symmetric(vertical: _dynamicPadding),
          alignment: pw.Alignment.center,
          child: pw.Text(
            formattedCount, 
            style: pw.TextStyle(fontSize: 10, fontWeight: isTotal ? pw.FontWeight.bold : null),
            textAlign: pw.TextAlign.center,
          ),
        ),
        // Cell for Details/Remarks
        pw.Container(
          padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: _dynamicPadding),
          alignment: isTotal ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          child: pw.Text(
            details, 
            style: pw.TextStyle(fontSize: 10, fontWeight: isTotal ? pw.FontWeight.bold : null),
            textAlign: isTotal ? pw.TextAlign.right : pw.TextAlign.left,
          ),
        ),
      ],
    );
  }

  static int _getSeniorityRank(String idNumber) {
    final match = RegExp(r'\d+').firstMatch(idNumber);
    if (match != null) {
      int num = int.parse(match.group(0)!);
      if (num < 100) return num + 200000; // 1 or 2-digit numbers are most junior
      if (num < 1000) return num + 100000; // 3-digit numbers are junior
      return num;
    }
    return 999999;
  }

  static String _extractNumbers(String text, [List<Manpower>? personnelList]) {
    if (text.isEmpty) return '';
    
    final parts = text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    List<String> processed = [];
    
    for (var part in parts) {
      String num = part.replaceAll(RegExp(r'[^0-9]'), '');
      
      if (num.isNotEmpty) {
        processed.add(num);
      }
    }
    
    processed.sort((a, b) => _getSeniorityRank(a).compareTo(_getSeniorityRank(b)));
    return processed.join(', ');
  }

  static String _extractAndSortNumbers(String text, List<Manpower>? personnelList) {
    if (text.isEmpty) return '';
    final ids = text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    
    ids.sort((a, b) {
       Manpower? pA;
       Manpower? pB;
       if (personnelList != null) {
         try { 
           pA = personnelList.firstWhere((p) {
             String pNum = RegExp(r'\d+').firstMatch(p.idNumber)?.group(0) ?? '';
             String aNum = RegExp(r'\d+').firstMatch(a)?.group(0) ?? '';
             return p.idNumber == a || (pNum.isNotEmpty && aNum.isNotEmpty && int.tryParse(pNum) == int.tryParse(aNum));
           }); 
         } catch (_) {}
         try { 
           pB = personnelList.firstWhere((p) {
             String pNum = RegExp(r'\d+').firstMatch(p.idNumber)?.group(0) ?? '';
             String bNum = RegExp(r'\d+').firstMatch(b)?.group(0) ?? '';
             return p.idNumber == b || (pNum.isNotEmpty && bNum.isNotEmpty && int.tryParse(pNum) == int.tryParse(bNum));
           }); 
         } catch (_) {}
       }
       
       int genderA = (pA?.gender == 'Female') ? 1 : 0;
       int genderB = (pB?.gender == 'Female') ? 1 : 0;
       if (genderA != genderB) return genderA.compareTo(genderB);
       
       int orderA = pA?.sortOrder ?? 999;
       int orderB = pB?.sortOrder ?? 999;
       if (orderA != orderB) return orderA.compareTo(orderB);
       
       return _getSeniorityRank(a).compareTo(_getSeniorityRank(b));
    });

    List<String> result = [];
    for (var id in ids) {
      final m = RegExp(r'\d+').firstMatch(id);
      
      if (m != null) {
        result.add(m.group(0)!);
      }
    }
    return result.join(', ');
  }

  static pw.Widget _buildVehicleTable(
    DutyRegisterModel register, 
    List<Manpower>? personnelList, {
    required String phoneDuty,
    required String messenger,
    required String sentryDuty,
    required String controlRoom,
    bool isSfroInCharge = false,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 1, color: PdfColors.black)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Top Table Title
          pw.Container(
            padding: const pw.EdgeInsets.all(3),
            child: pw.Text(
              'PERFORMA DUTY DETAILING OF PERSONNEL - ${AppConfig.stationNamePdfHeader}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
          ),
          _hDivider(),

          // Complex Header
          pw.Container(
            height: 42,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Expanded(flex: 7, child: _headerCell('SL\nNo.', size: 7, rightBorder: true)),
                
                pw.Expanded(flex: 27, child: _headerCell('VEHICLE & EQUIPMENTS', size: 7, rightBorder: true)),

                // POSTED PERSONNEL Group
                pw.Expanded(
                  flex: 7 + 24 + 7 + 7, // SFRO + FRO + KHG + FRO(D)
                  child: pw.Container(
                    decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 1, color: PdfColors.black))),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        _headerCell('POSTED PERSONNEL', size: 8),
                        _hDivider(),
                        pw.Expanded(
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                            children: [
                              pw.Expanded(flex: 7, child: _headerCell(isSfroInCharge ? 'SFRO\n(I/C)' : 'SFRO', size: 7.5, rightBorder: true)),
                              pw.Expanded(flex: 24, child: _headerCell('FRO', size: 7.5, rightBorder: true)),
                              pw.Expanded(flex: 7, child: _headerCell('KHG', size: 7.5, rightBorder: true)),
                              pw.Expanded(flex: 7, child: _headerCell('FRO(D)', size: 6.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // CONDITION Group
                pw.Expanded(
                  flex: 9 + 9, // MORNING + EVENING
                  child: pw.Container(
                    decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 1, color: PdfColors.black))),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        _headerCell('CONDITION OF VEHICLE\n& EQUIPMENT', size: 6.5),
                        _hDivider(),
                        pw.Expanded(
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                            children: [
                              pw.Expanded(flex: 9, child: _headerCell('MORNING\nROLLCALL', size: 7, rightBorder: true)),
                              pw.Expanded(flex: 9, child: _headerCell('EVENING\nROLLCALL', size: 7)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                pw.Expanded(flex: 9, child: _headerCell('Remarks', size: 8)),
              ],
            ),
          ),
          _hDivider(),

          () {
              List<pw.Widget> tableRows = [];
              List<pw.TableRow> currentNormalRows = [];

              void flushNormalRows() {
                if (currentNormalRows.isNotEmpty) {
                  tableRows.add(
                    pw.Table(
                      border: const pw.TableBorder(
                        verticalInside: pw.BorderSide(width: 1, color: PdfColors.black),
                        horizontalInside: pw.BorderSide(width: 1, color: PdfColors.black),
                      ),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(7),
                        1: const pw.FlexColumnWidth(27),
                        2: const pw.FlexColumnWidth(7),
                        3: const pw.FlexColumnWidth(24),
                        4: const pw.FlexColumnWidth(7),
                        5: const pw.FlexColumnWidth(7),
                        6: const pw.FlexColumnWidth(9),
                        7: const pw.FlexColumnWidth(9),
                        8: const pw.FlexColumnWidth(9),
                      },
                      children: List.from(currentNormalRows),
                    )
                  );
                  currentNormalRows.clear();
                }
              }

              for (var i = 0; i < register.vehicleAssignments.length; i++) {
                final v = register.vehicleAssignments[i];
                
                // Migrate old vehicle names for display
                String displayVName = v.vehicleName;
                final isNewRule = !register.date.isBefore(DateTime(2026, 7, 23));
                if (displayVName == 'C/S: 1/15, 3/15, 6/15, ASKA-III & Hy.Eq-I (I-MTU)' || displayVName == 'C/S - 1, 7, 8, 13, Aska-III (I-MTU)' || displayVName == 'C/S - 1, 7, 8, 13, Aska-III (I-F/T)') {
                  displayVName = isNewRule ? 'C/S - 1, 7, 8, 13, Aska-III (I-F/T)' : 'C/S - 1, 7, 8, 13, Aska-III (I-MTU)';
                } else if (displayVName == 'C/S: 1, 2, 3, 4, 5, Hy.Eq. II & A/J (II-MTU)' || displayVName == 'C/S - 4, 5, 6, 11, Fanergy, Float Pump, Hydraulic Lukas (F/T)' || displayVName == 'C/S - 4, 5, 6, 11, Fanergy, Float Pump, Hydraulic Lukas (II-W/B)') {
                  displayVName = isNewRule ? 'C/S - 4, 5, 6, 11, Fanergy, Float Pump, Hydraulic Lukas (II-W/B)' : 'C/S - 4, 5, 6, 11, Fanergy, Float Pump, Hydraulic Lukas (F/T)';
                } else if (displayVName == 'C/S: 1/22, F/P, P/S, Gen-I & II, PTEL, Portable Pump, OB Engine (QRV)' || 
                           displayVName == 'C/S: 1/22, F/P, P/S, Gen-I & II & PTEL (QRV)' || 
                           displayVName == 'C/S: 1/22, F/P, P/S, Gen-I & II, PTEL, Portable Pump, Outboard Engine (QRV)' ||
                           displayVName == 'C/S-10, Gen EU-65, EXK-2800, OBM, Mini Moon Light') {
                  displayVName = 'C/S-2, 3, 9, 10, 12, Gen EU-65, EXK-2800, OBM, Mini Moon Light (QRV)';
                } else if (displayVName == 'BA Set' || displayVName == 'BA Set/Gas Detector') {
                  displayVName = 'BA Set, Gas Detector';
                }

                if (v.isOffRoad || v.isAttached) {
                  flushNormalRows();

                  String mergedText = v.isOffRoad 
                      ? 'Off The Road'
                      : 'Attached @ ${v.remarks}';

                  tableRows.add(
                    pw.Table(
                      border: const pw.TableBorder(
                        verticalInside: pw.BorderSide(width: 1, color: PdfColors.black),
                      ),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(7),
                        1: const pw.FlexColumnWidth(27),
                        2: const pw.FlexColumnWidth(7),
                        3: const pw.FlexColumnWidth(24),
                        4: const pw.FlexColumnWidth(7),
                        5: const pw.FlexColumnWidth(7),
                        6: const pw.FlexColumnWidth(27), // 9 + 9 + 9
                      },
                      children: [
                        pw.TableRow(
                          children: [
                            _dataCell(_toRoman(v.seniority, fallbackIndex: i + 1), align: pw.TextAlign.center),
                            _dataCell(displayVName),
                            _dataCell(_extractNumbers(v.sfro), align: pw.TextAlign.center),
                            _dataCell(_extractAndSortNumbers(v.fro, personnelList), align: pw.TextAlign.center),
                            _dataCell(_extractNumbers(v.khg), align: pw.TextAlign.center),
                            _dataCell(_extractNumbers(v.froD), align: pw.TextAlign.center),
                            _dataCell(mergedText, align: pw.TextAlign.center, size: v.isAttached ? (6.5) : (8)),
                          ]
                        )
                      ]
                    )
                  );
                } else {
                  currentNormalRows.add(
                    pw.TableRow(
                      children: [
                        _dataCell(_toRoman(v.seniority, fallbackIndex: i + 1), align: pw.TextAlign.center),
                        _dataCell(displayVName),
                        _dataCell(_extractNumbers(v.sfro), align: pw.TextAlign.center),
                        _dataCell(_extractAndSortNumbers(v.fro, personnelList), align: pw.TextAlign.center),
                        _dataCell(_extractNumbers(v.khg), align: pw.TextAlign.center),
                        _dataCell(_extractNumbers(v.froD), align: pw.TextAlign.center),
                        _dataCell('', align: pw.TextAlign.center), // Morning
                        _dataCell('', align: pw.TextAlign.center), // Evening
                        _dataCell(v.remarks), // Remarks
                      ]
                    )
                  );
                }
              }
              flushNormalRows();

              List<pw.Widget> finalTableRows = [];
              for (int i = 0; i < tableRows.length; i++) {
                finalTableRows.add(tableRows[i]);
                if (i < tableRows.length - 1) {
                  finalTableRows.add(_hDivider());
                }
              }

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  ...finalTableRows,
                  _hDivider(),
                  pw.Table(
                    border: const pw.TableBorder(
                      verticalInside: pw.BorderSide(width: 1, color: PdfColors.black),
                    ),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(79),
                      1: const pw.FlexColumnWidth(9),
                      2: const pw.FlexColumnWidth(9),
                      3: const pw.FlexColumnWidth(9),
                    },
                    children: [
                      pw.TableRow(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
                            child: pw.Wrap(
                              spacing: 15,
                              runSpacing: 4,
                              children: [
                                pw.Text('Phone Duty: $phoneDuty', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                pw.Text('Messenger: $messenger', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                pw.Text('Sentry Duty: $sentryDuty', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                pw.Text('Watch Room/Wireless: $controlRoom', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(width: 2),
                              ]
                            )
                          ),
                          pw.Align(
                            alignment: pw.Alignment.centerLeft, 
                            child: pw.Padding(padding: const pw.EdgeInsets.only(left: 4), child: pw.Text('Sign', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 8)))
                          ),
                          pw.Align(
                            alignment: pw.Alignment.centerLeft, 
                            child: pw.Padding(padding: const pw.EdgeInsets.only(left: 4), child: pw.Text('Sign', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 8)))
                          ),
                          pw.Container(),
                        ]
                      )
                    ]
                  )
                ]
              );
            }(),
        ],
      ),
    );
  }

  static pw.Widget _vDivider() => pw.Container(width: 1, color: PdfColors.black);
  static pw.Widget _hDivider() => pw.Container(height: 1, color: PdfColors.black);

  static pw.Widget _headerCell(String text, {double size = 9, bool rightBorder = false}) {
    return pw.Container(
      decoration: rightBorder ? const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 1, color: PdfColors.black))) : null,
      padding: const pw.EdgeInsets.symmetric(vertical: 2.0, horizontal: 1),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _dataCell(String text, {pw.TextAlign align = pw.TextAlign.left, double size = 10}) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(vertical: _dynamicPadding, horizontal: 2),
      alignment: align == pw.TextAlign.center ? pw.Alignment.center : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: size),
        textAlign: align,
      ),
    );
  }

  static String _toRoman(int number, {int? fallbackIndex}) {
    if (number > 30 && fallbackIndex != null) {
      number = fallbackIndex;
    }
    if (number < 1 || number > 30) return number.toString();
    const numerals = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII', 'XIII', 'XIV', 'XV', 'XVI', 'XVII', 'XVIII', 'XIX', 'XX', 'XXI', 'XXII', 'XXIII', 'XXIV', 'XXV', 'XXVI', 'XXVII', 'XXVIII', 'XXIX', 'XXX'];
    return numerals[number - 1];
  }

  static pw.Widget _buildFooter(DutyRegisterModel register) {
    pw.Widget pageNumberWidget = pw.Container();
    final current = DateTime.utc(register.date.year, register.date.month, register.date.day);
    int pageNum = 0;
    
    if (current.year == 2026) {
      final start = DateTime.utc(2026, 6, 29);
      if (!current.isBefore(start)) {
        pageNum = current.difference(start).inDays + 1;
      }
    } else if (current.year > 2026) {
      final start = DateTime.utc(current.year, 1, 1);
      pageNum = current.difference(start).inDays + 1;
    }

    if (pageNum > 0) {
      pageNumberWidget = pw.Container(
        width: 25,
        alignment: pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.only(top: 2, right: 2, left: 4),
        child: pw.Text(
          pageNum.toString().padLeft(2, '0'), 
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)
        )
      );
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  height: 25,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  alignment: pw.Alignment.centerLeft,
                  padding: const pw.EdgeInsets.only(left: 10),
                  child: pw.Text('Signature (with date)', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.bold)),
                )
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Container(
                  height: 25,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  alignment: pw.Alignment.centerLeft,
                  padding: const pw.EdgeInsets.only(left: 10),
                  child: pw.Text('Signature (with date)', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.bold)),
                )
              ),
            ]
          )
        ),
        pageNumberWidget
      ]
    );
  }
}
