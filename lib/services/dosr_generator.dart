import 'package:intl/intl.dart';
import '../models/duty_register_model.dart';
import '../models/manpower_model.dart';
import '../providers/manpower_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/duty_provider.dart';
import '../config/app_config.dart';

class DosrGenerator {
  final ManpowerProvider manpowerProvider;
  final AttendanceProvider attendanceProvider;
  final DutyProvider dutyProvider;
  
  DosrGenerator({
    required this.manpowerProvider,
    required this.attendanceProvider,
    required this.dutyProvider,
  });

  String generateReport({
    required DateTime date,
    required String majorFire,
    required String incident,
    required String totalCall,
    required String asstCall,
    bool forWhatsApp = false,
  }) {
    final StringBuffer sb = StringBuffer();
    final String dateStr = DateFormat('dd/MM/yy EEEE').format(date);
    final String timeStr = '09:00'; // Fixed as per daily duty starting time

    sb.writeln('Daily Operational Status Report (DOSR)');
    sb.writeln('""""""""""""""""""""""""""""""""""""""');
    sb.writeln('Fire & Rescue Station🚒  :  മീഞ്ചന്ത ');
    sb.writeln('Date.                 : $dateStr ');
    sb.writeln('Time.                 : $timeStr  Hrs');
    sb.writeln('');
    sb.writeln('""""""""""""""""""""""""""""""""""""""');

    String padDesig(String desig) {
      return desig.padRight(19, ' ');
    }

    // (No longer using yesterday's register for Batch Out based on user feedback)

    // Load Today's Duty Register for Batch In / On Duty
    final DutyRegisterModel? todayRegister = dutyProvider.registers.where((r) {
      return r.date.year == date.year && r.date.month == date.month && r.date.day == date.day;
    }).firstOrNull;

    final allPersonnel = manpowerProvider.getActivePersonnelForDate(date);

    // Helper: is beach
    bool isBeach(Manpower p) {
      return p.currentStation.toLowerCase().contains('kozhikode') || 
             p.currentStation.toLowerCase().contains('kkd');
    }

    String effectiveDesignation(Manpower p) {
      if (p.designation == 'FRO' && p.gender.toLowerCase() == 'female') {
        return 'WFRO';
      }
      return p.designation;
    }

    bool isTrainee(Manpower p) {
      return p.designation.toLowerCase().contains('trainee') || p.isTempAttachedForTraining;
    }

    // 1. Personnel Retiring from Duty (Batch Out)
    sb.writeln('1.  😴 Personnel Retiring from Duty');
    sb.writeln(' (Batch Out) _ മീഞ്ചന്ത\n');

    Map<String, int> retiringStation = {};
    Map<String, int> retiringBeach = {};
    int totalRetiring = 0;

    final day = date.day;
    final attMap = attendanceProvider.attendanceMap;

    for (var p in allPersonnel) {
      final status = attMap[p.id]?.dailyStatus[day]?.toUpperCase() ?? '';
      
      if (status == 'R' || status == 'D/R' || status == 'DR') {
         if (isTrainee(p)) continue; // Exclude trainees from Batch Out
         final effDesig = effectiveDesignation(p);
         if (isBeach(p)) {
           retiringBeach[effDesig] = (retiringBeach[effDesig] ?? 0) + 1;
         } else {
           retiringStation[effDesig] = (retiringStation[effDesig] ?? 0) + 1;
         }
         totalRetiring++;
      }
    }

    void writeStats(Map<String, int> stats, List<String> order, {bool skipExtras = false}) {
      for (var desig in order) {
        if (stats.containsKey(desig) && stats[desig]! > 0) {
           String formattedDesig = padDesig(desig);
           String count = stats[desig]!.toString().padLeft(2, '0');
           sb.writeln('$formattedDesig: $count');
        } else {
           String formattedDesig = padDesig(desig);
           sb.writeln('$formattedDesig: 00');
        }
      }
      if (!skipExtras) {
        for (var desig in stats.keys) {
          if (!order.contains(desig) && stats[desig]! > 0) {
             String formattedDesig = padDesig(desig);
             String count = stats[desig]!.toString().padLeft(2, '0');
             sb.writeln('$formattedDesig: $count');
          }
        }
      }
    }

    writeStats(retiringStation, ['SFRO', 'FRO (D)', 'FRO', 'WFRO', 'KHG']);
    
    sb.writeln('\nകോഴിക്കോട് ബീച്ച്');
    sb.writeln('----------------------------');
    writeStats(retiringBeach, ['FRO (D)', 'FRO', 'KHG']);
    sb.writeln('                          ');
    sb.writeln('👉   Total Batch Out #  $totalRetiring');
    sb.writeln('\n"""""""""""""""""""""""""""""');

    // 2. Officer on Duty & 3. Personnel on Duty
    sb.writeln('2. 🧑🚒 OFFICER ON DUTY ');
    sb.writeln(' Station Charge  _ മീഞ്ചന്ത\n');

    Map<String, int> onDutyStation = {};
    Map<String, int> onDutyBeach = {};
    int totalOfficers = 0;
    int totalPersonnel = 0;
    int stationWriterCount = 0;

    if (todayRegister != null) {
      for (var idNumber in todayRegister.stationWriterIds) {
        final p = allPersonnel.where((person) => person.idNumber == idNumber).firstOrNull;
        if (p != null) {
          final status = attMap[p.id]?.dailyStatus[day]?.toUpperCase() ?? '';
          if (status.isEmpty || status == 'X' || status == 'X/R') {
            stationWriterCount++;
          }
        }
      }
    }

    for (var p in allPersonnel) {
       final status = attMap[p.id]?.dailyStatus[day]?.toUpperCase() ?? '';
       final effDesig = effectiveDesignation(p);
       if (status.isEmpty || status == 'X' || status == 'X/R') {
           if (isTrainee(p)) continue; // Trainees present are handled in training section
           if (todayRegister != null && todayRegister.stationWriterIds.contains(p.idNumber)) continue;
           if (['STO', 'ASTO'].contains(effDesig)) {
             onDutyStation[effDesig] = (onDutyStation[effDesig] ?? 0) + 1;
             totalOfficers++;
           } else {
             if (isBeach(p)) {
               onDutyBeach[effDesig] = (onDutyBeach[effDesig] ?? 0) + 1;
             } else {
               onDutyStation[effDesig] = (onDutyStation[effDesig] ?? 0) + 1;
             }
             totalPersonnel++;
           }
       }
    }

    writeStats(onDutyStation, ['STO', 'ASTO'], skipExtras: true);
    sb.writeln('\n👉           TOTAL # ${totalOfficers.toString().padLeft(2, '0')}');

    sb.writeln('\n3. 🧑🚒 PERSONNAL ON DUTY ');
    sb.writeln('                (മീഞ്ചന്ത)\n');
    writeStats(onDutyStation, ['SFRO', 'SFRO (M)', 'FRO (D)', 'FRO', 'WFRO', 'KHG'], skipExtras: true);

    sb.writeln('\n(കോഴിക്കോട് ബീച്ച്)');
    sb.writeln('----------------------------');
    writeStats(onDutyBeach, ['FRO (D)', 'KHG'], skipExtras: true);

    sb.writeln('\n👉 Total Personnel on Duty # $totalPersonnel');
    sb.writeln('\n"""""""""""""""""""""""""""""""""');
    sb.writeln('STATION WRITER.: #   ${stationWriterCount.toString().padLeft(2, '0')}');
    sb.writeln('\n"""""""""""""""""""""""""""""""""');

    // 4. Personnel on Leave
    sb.writeln('\n4. 🛑 PERSONNAL ON LEAVE \n');

    Map<String, int> dayOffStation = {};
    Map<String, int> dayOffBeach = {};
    Map<String, int> clStation = {};
    int elHpCml = 0;
    int specialDuty = 0;
    int medicalLeave = 0;
    int od = 0;
    int spcl = 0;
    int trainingCount = 0;
    int lwpBeach = 0;
    int lwpStation = 0;
    int sdWaKhgBeach = 0;
    int sdWaKhgStation = 0;

    for (var p in allPersonnel) {
       final status = (attMap[p.id]?.dailyStatus[day] ?? '').toUpperCase();
       final effDesig = effectiveDesignation(p);
       
       if (status.contains('TRG') || status == 'T' || isTrainee(p)) {
          trainingCount++;
          continue;
       }

       if (status.isEmpty || status == 'X' || status == 'R' || status == 'X/R') continue; // Not on leave

       if (status == 'OFF') {
          if (isBeach(p)) {
             dayOffBeach[effDesig] = (dayOffBeach[effDesig] ?? 0) + 1;
          } else {
             dayOffStation[effDesig] = (dayOffStation[effDesig] ?? 0) + 1;
          }
       } else if (status == 'CL') {
          clStation[effDesig] = (clStation[effDesig] ?? 0) + 1;
       } else if (['BH', 'HP', 'RH', 'CML', 'EL', 'HPL'].contains(status)) {
          elHpCml++;
       } else if (status == 'SPCL') {
          spcl++;
       } else if (status == 'SD' || status == 'WA') {
          if (effDesig == 'KHG') {
             if (isBeach(p)) {
                sdWaKhgBeach++;
             } else {
                sdWaKhgStation++;
             }
          } else {
             specialDuty++;
          }
       } else if (status == 'ML' || status == 'AB' || status == 'SL' || status == 'A') {
          medicalLeave++;
       } else if (status == 'OD') {
          od++;
       } else if (status == 'LWP') {
          if (isBeach(p)) {
             lwpBeach++;
          } else {
             lwpStation++;
          }
       }
    }

    int getSectionTotal(Map<String, int> stats, List<String> order) {
      int total = 0;
      for (var desig in order) {
        total += stats[desig] ?? 0;
      }
      return total;
    }

    int totalDayOffStation = getSectionTotal(dayOffStation, ['STO', 'ASTO', 'SFRO', 'SFRO (M)', 'FRO (D)', 'FRO', 'WFRO']);
    int totalDayOffBeach = getSectionTotal(dayOffBeach, ['FRO (D)']);
    int totalCl = getSectionTotal(clStation, ['STO', 'ASTO', 'SFRO', 'SFRO (M)', 'FRO (D)', 'FRO', 'WFRO']);

    sb.writeln('DAY OFF (മീഞ്ചന്ത)');
    sb.writeln('---------------------');
    writeStats(dayOffStation, ['STO', 'ASTO', 'SFRO', 'SFRO (M)', 'FRO (D)', 'FRO', 'WFRO']);
    sb.writeln('\n👉    TOTAL #.       ${totalDayOffStation.toString().padLeft(2, '0')}');

    sb.writeln('\nDAY OFF (കോഴിക്കോട് ബീച്ച് )');
    sb.writeln('--------------------------------         ');
    writeStats(dayOffBeach, ['FRO (D)']);
    sb.writeln('\n👉    TOTAL #.       ${totalDayOffBeach.toString().padLeft(2, '0')}');

    sb.writeln('\nCASUAL LEAVE (CL) ');
    sb.writeln('-------------------------------                      ');
    writeStats(clStation, ['STO', 'ASTO', 'SFRO', 'SFRO (M)', 'FRO (D)', 'FRO', 'WFRO']);
    sb.writeln('\n👉  TOTAL #.         ${totalCl.toString().padLeft(2, '0')}');

    sb.writeln('\n--------------------------------');
    sb.writeln('${padDesig('E.L / HP / CML')}: ${elHpCml.toString().padLeft(2, '0')}');
    sb.writeln('${padDesig('SPL DUTY / W.A')}: ${specialDuty.toString().padLeft(2, '0')}');
    sb.writeln('${padDesig('ML / ABSENT')}: ${medicalLeave.toString().padLeft(2, '0')}');
    sb.writeln('${padDesig('O.D')}: ${od.toString().padLeft(2, '0')}');
    sb.writeln('${padDesig('SpCL')}: ${spcl.toString().padLeft(2, '0')}');
    
    sb.writeln('\nTRAINING :   ');
    sb.writeln('"""""""""""""”"""                               ');
    sb.writeln('${padDesig('TOTAL TRAINING')}: ${trainingCount.toString().padLeft(2, '0')}');

    int totalLeavesOthers = elHpCml + specialDuty + medicalLeave + od + spcl + trainingCount;
    sb.writeln('\n👉   TOTAL    #     ${totalLeavesOthers.toString().padLeft(2, '0')}');

    sb.writeln('\nHOME GUARDS (മീഞ്ചന്ത)');
    sb.writeln('-----------------------------------');
    sb.writeln('${padDesig('HG. (LWP)')}: ${lwpStation.toString().padLeft(2, '0')}');
    sb.writeln('${padDesig('HG. (SD/WA)')}: ${sdWaKhgStation.toString().padLeft(2, '0')}');
    sb.writeln('\n👉   TOTAL #.       ${(lwpStation + sdWaKhgStation).toString().padLeft(2, '0')}');

    sb.writeln('\nHOME GUARDS (കോഴിക്കോട് ബീച്ച്)');
    sb.writeln('------------------------------------');
    sb.writeln('${padDesig('HG. (LWP)')}: ${lwpBeach.toString().padLeft(2, '0')}');
    sb.writeln('${padDesig('HG. (SD/WA)')}: ${sdWaKhgBeach.toString().padLeft(2, '0')}');
    sb.writeln('\n👉   TOTAL   #.     ${(lwpBeach + sdWaKhgBeach).toString().padLeft(2, '0')}');

    // Vacancy
    sb.writeln('\n"""""""""""""""""""""""""""""""""""');
    sb.writeln('VACANCY');
    sb.writeln('----------------');
    
    // Calculate actual strengths
    Map<String, int> actualStrength = {};
    for (var p in allPersonnel) {
       if (isBeach(p)) continue;
       
       // Exclude personnel from other stations (like Kollam) from Station's actual strength
       if (p.currentStation.trim().isNotEmpty && p.currentStation.trim().toLowerCase() != AppConfig.stationNameShort.toLowerCase()) {
           continue;
       }
       
       String desig = effectiveDesignation(p);
       if (isTrainee(p)) {
          if (p.gender.toLowerCase() == 'female') {
             desig = 'WFRO';
          } else {
             desig = 'FRO';
          }
       }
       actualStrength[desig] = (actualStrength[desig] ?? 0) + 1;
    }

    final Map<String, int> sanctioned = {
       'STO': 1,
       'ASTO': 2,
       'SFRO': 5,
       'SFRO (M)': 1,
       'FRO (D)': 10,
       'FRO': 31,
       'WFRO': 15,
    };

    int totalVacancy = 0;
    int totalSanctioned = sanctioned.values.fold(0, (sum, val) => sum + val);

    for (var desig in sanctioned.keys) {
       int sanction = sanctioned[desig]!;
       int actual = actualStrength[desig] ?? 0;
       int vac = sanction - actual;
       if (vac < 0) vac = 0;
       totalVacancy += vac;
       String formattedDesig = padDesig(desig);
       sb.writeln('$formattedDesig: ${vac.toString().padLeft(2, '0')}');
    }

    sb.writeln('\n👉    TOTAL     #    ${totalVacancy.toString().padLeft(2, '0')}');
    sb.writeln('\n"""""""""""""""""""""""""""""""""""');
    
    int grandTotal = totalRetiring + 
                     totalOfficers + 
                     totalPersonnel + 
                     stationWriterCount + 
                     totalDayOffStation + 
                     totalDayOffBeach + 
                     totalCl + 
                     totalLeavesOthers + 
                     (lwpStation + sdWaKhgStation) + 
                     (lwpBeach + sdWaKhgBeach) + 
                     totalVacancy;

    sb.writeln('\n🧑🚒 TOTAL STATION STRENGTH  ');
    sb.writeln('\n👉    #  $grandTotal   (${totalVacancy.toString().padLeft(2, '0')} vacancy)');
    sb.writeln('\n"""""""""""""""""""""""""""""""""""');

    // Vehicle Status
    sb.writeln('\n🚒STATION VEHICLE STATUS (On the road) ');
    sb.writeln('•••••••••••••••••••••••••••••••••••\n');

    if (todayRegister != null) {
       int index = 1;
       for (var v in todayRegister.vehicleAssignments) {
          if (index > 12) break; // Only show actual vehicles (1 to 12)
          String vehName = v.vehicleName.split('\n').join(' '); // Flatten multiline names
          sb.writeln('$index. $vehName');
          
          if (v.isOffRoad) {
             sb.writeln('           🛑 OFF THE ROAD');
             if (v.remarks.trim().isNotEmpty) {
                sb.writeln('           (${v.remarks.trim()})');
             }
             sb.writeln('');
          } else if (v.isAttached) {
             String remarksText = v.remarks.trim().isNotEmpty ? v.remarks.trim() : 'ATTACHED';
             sb.writeln('           @ $remarksText');
             sb.writeln('');
          } else if (vehName.toUpperCase().contains('SCUBA') && v.remarks.trim().isNotEmpty) {
             // Fallback for legacy SCUBA entries before isAttached was consistently used
             sb.writeln('           @ ${v.remarks.trim()}');
             sb.writeln('');
          } else {
             sb.writeln('');
          }
          index++;
       }
    } else {
       sb.writeln('No vehicle data available for this date.');
    }

    sb.writeln('\n"""""""""""""""""""""""""""""""""""""""""');
    sb.writeln('\n👉 Major Incidents in Last 24 Hours ');
    sb.writeln('    (9 AM to 9 AM)\n');

    sb.writeln('> Major fire   🔥      : ${majorFire.padLeft(3, '0')}');
    sb.writeln('> Incident     🌳      : ${incident.padLeft(3, '0')}');
    sb.writeln('');
    sb.writeln('Total call (${date.year})      : ${totalCall.padLeft(3, '0')}');
    sb.writeln('Asst call.             : ${asstCall.padLeft(3, '0')}');

    sb.writeln('\n"""""""""""""""""""""""""""""""""""""""""');

    return sb.toString();
  }
}
