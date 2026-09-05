import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../providers/manpower_provider.dart';
import '../providers/attendance_provider.dart';
import 'package:provider/provider.dart';
import '../providers/duty_provider.dart';

class AccessControl {
  /// Converts a given DateTime into the corresponding Duty Date.
  /// Duty is 9 AM to 9 AM (with 1 hr grace period: 8 AM to 10 AM).
  /// For simplicity, if the time is before 9 AM, it belongs to the previous calendar day's duty.
  static DateTime getDutyDate(DateTime time) {
    if (time.hour < 9) {
      return DateTime(time.year, time.month, time.day).subtract(const Duration(days: 1));
    }
    return DateTime(time.year, time.month, time.day);
  }

  static int timeToDutyMinutes(String timeStr) {
    if (timeStr.isEmpty) return 0;
    final parts = timeStr.split(':');
    if (parts.length != 2) return 0;
    int h = int.tryParse(parts[0]) ?? 0;
    int m = int.tryParse(parts[1]) ?? 0;
    int totalMins = h * 60 + m;
    int dutyStartMins = 9 * 60;
    if (totalMins >= dutyStartMins) {
      return totalMins - dutyStartMins;
    } else {
      return (24 * 60 - dutyStartMins) + totalMins;
    }
  }

  static bool isAdmin(BuildContext context) {
    return context.read<AuthProvider>().isAdmin;
  }

  static bool isSfro(BuildContext context) {
    if (isAdmin(context)) return true;
    
    final linkedPersonId = context.read<AuthProvider>().linkedPersonId;
    if (linkedPersonId == null || linkedPersonId.isEmpty) return false;

    final manpowerList = context.read<ManpowerProvider>().personnelList;
    try {
      final person = manpowerList.firstWhere((p) => p.id == linkedPersonId);
      return person.designation == 'SFRO';
    } catch (e) {
      return false;
    }
  }

  static DateTime getActiveDutyDate() {
    final now = DateTime.now();
    // Shift is 09:00 AM to 09:00 AM next day.
    // So if time is before 09:00 AM, the active duty date is yesterday.
    if (now.hour < 9) {
      return now.subtract(const Duration(days: 1));
    }
    return now;
  }

  static List<DateTime> getActiveDutyDates() {
    final now = DateTime.now();
    List<DateTime> datesToCheck = [];
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (now.hour < 8) {
      // Before 8 AM: strictly yesterday's shift
      datesToCheck.add(yesterday);
    } else if (now.hour >= 8 && now.hour < 10) {
      // Overlap period: 8 AM to 10 AM (both shifts have access)
      datesToCheck.add(yesterday);
      datesToCheck.add(today);
    } else {
      // After 10 AM: strictly today's shift
      datesToCheck.add(today);
    }
    return datesToCheck;
  }

  static bool isOnDuty(BuildContext context) {
    if (isAdmin(context)) return true;
    
    if (!isSfro(context)) return false;

    final linkedPersonId = context.read<AuthProvider>().linkedPersonId;
    if (linkedPersonId == null || linkedPersonId.isEmpty) return false;

    final attendanceProvider = context.read<AttendanceProvider>();
    final now = DateTime.now();

    List<DateTime> datesToCheck = [];
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (now.hour < 8) {
      // Before 8 AM: strictly yesterday's shift
      datesToCheck.add(yesterday);
    } else if (now.hour >= 8 && now.hour < 10) {
      // Overlap period: 8 AM to 10 AM (both shifts have access)
      datesToCheck.add(yesterday);
      datesToCheck.add(today);
    } else {
      // After 10 AM: strictly today's shift
      datesToCheck.add(today);
    }

    for (var date in datesToCheck) {
      final yearMonth = "${date.year}-${date.month.toString().padLeft(2, '0')}";
      final attendanceData = attendanceProvider.attendanceMap[linkedPersonId];
      
      if (attendanceData != null && attendanceData.yearMonth == yearMonth) {
        final status = attendanceData.dailyStatus[date.day];
        // 'X', 'P' or null/empty means present/on-duty
        if (status == null || status.isEmpty || status == 'X' || status == 'P' || status.toUpperCase() == 'X/R') {
          return true;
        }
      } else {
        // Default to true if we don't have attendance data yet (blank means on-duty)
        return true;
      }
    }
    
    return false;
  }

  static String getOnDutySfroNames(BuildContext context) {
    final manpowerList = context.read<ManpowerProvider>().personnelList;
    final attendanceProvider = context.read<AttendanceProvider>();
    final now = DateTime.now();

    List<DateTime> datesToCheck = [];
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (now.hour < 8) {
      datesToCheck.add(yesterday);
    } else if (now.hour >= 8 && now.hour < 10) {
      datesToCheck.add(yesterday);
      datesToCheck.add(today);
    } else {
      datesToCheck.add(today);
    }

    Set<String> onDutySfroNumbers = {};

    for (var person in manpowerList) {
      if (person.designation == 'SFRO') {
        for (var date in datesToCheck) {
          final yearMonth = "${date.year}-${date.month.toString().padLeft(2, '0')}";
          final attendanceData = attendanceProvider.attendanceMap[person.id];
          bool isPresent = true;
          
          if (attendanceData != null && attendanceData.yearMonth == yearMonth) {
            final status = attendanceData.dailyStatus[date.day];
            if (status != null && status.isNotEmpty && status != 'X' && status != 'P' && status.toUpperCase() != 'X/R') {
              isPresent = false;
            }
          }
          
          if (isPresent) {
            onDutySfroNumbers.add(person.idNumber);
            break; // Found present on one of the valid dates, skip other dates for this person
          }
        }
      }
    }

    if (onDutySfroNumbers.isEmpty) {
      return "the On-Duty SFRO";
    }
    return "SFRO ${onDutySfroNumbers.join(', ')}";
  }

  static bool isDateLocked(BuildContext context, DateTime date) {
    if (isAdmin(context)) return false; // Admin bypass

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    
    // User requested "01 days before and onwards only".
    // So if today is 27th, 1 day before is 26th. 26th is allowed. 25th is locked.
    final allowedDate = today.subtract(const Duration(days: 1));

    if (targetDate.isBefore(allowedDate)) {
      return true; // Locked
    }
    return false;
  }

  static bool isDriver(BuildContext context) {
    final linkedPersonId = context.read<AuthProvider>().linkedPersonId;
    if (linkedPersonId == null || linkedPersonId.isEmpty) return false;

    final manpowerList = context.read<ManpowerProvider>().personnelList;
    try {
      final person = manpowerList.firstWhere((p) => p.id == linkedPersonId);
      final desig = person.designation.toUpperCase();
      return person.isDriver || desig == 'FRO (D)' || desig == 'SFRO (M)'; // Ensuring explicit drivers are covered
    } catch (e) {
      return false;
    }
  }

  static bool isSfroM(BuildContext context) {
    final linkedPersonId = context.read<AuthProvider>().linkedPersonId;
    if (linkedPersonId == null || linkedPersonId.isEmpty) return false;

    final manpowerList = context.read<ManpowerProvider>().personnelList;
    try {
      final person = manpowerList.firstWhere((p) => p.id == linkedPersonId);
      return person.designation.toUpperCase() == 'SFRO (M)';
    } catch (e) {
      return false;
    }
  }

  static bool isPresentOnDuty(BuildContext context, DateTime targetDate) {
    if (isAdmin(context)) return true;

    final linkedPersonId = context.read<AuthProvider>().linkedPersonId;
    if (linkedPersonId == null || linkedPersonId.isEmpty) return false;

    // Check Duty Register for explicit absence
    final dutyProvider = context.read<DutyProvider>();
    final manpowerList = context.read<ManpowerProvider>().personnelList;
    String idNumber = linkedPersonId;
    try {
      final person = manpowerList.firstWhere((p) => p.id == linkedPersonId);
      idNumber = person.idNumber;
    } catch (_) {}

    try {
      final register = dutyProvider.registers.firstWhere((r) => 
        r.date.year == targetDate.year &&
        r.date.month == targetDate.month &&
        r.date.day == targetDate.day
      );

      if (register.id.isNotEmpty || register.vehicleAssignments.isNotEmpty) {
        final Set<String> presentIds = {};
        for (var v in register.vehicleAssignments) {
          if (v.froD.trim().isNotEmpty) presentIds.add(v.froD.trim());
          if (v.khg.trim().isNotEmpty) {
            for (var id in v.khg.split(',')) {
              if (id.trim().isNotEmpty) presentIds.add(id.trim());
            }
          }
          if (v.fro.trim().isNotEmpty) {
            for (var id in v.fro.split(',')) {
              if (id.trim().isNotEmpty) presentIds.add(id.trim());
            }
          }
          if (v.sfro.trim().isNotEmpty) presentIds.add(v.sfro.trim());
        }

        for (var id in register.specialDutyIds) { if (id.trim().isNotEmpty) presentIds.add(id.trim()); }
        for (var id in register.phoneDutyIds) { if (id.trim().isNotEmpty) presentIds.add(id.trim()); }
        for (var id in register.messengerIds) { if (id.trim().isNotEmpty) presentIds.add(id.trim()); }
        for (var id in register.sentryDutyIds) { if (id.trim().isNotEmpty) presentIds.add(id.trim()); }
        for (var id in register.controlRoomIds) { if (id.trim().isNotEmpty) presentIds.add(id.trim()); }
        for (var id in register.stationWriterIds) { if (id.trim().isNotEmpty) presentIds.add(id.trim()); }

        for (var s in [...register.staffSummaries, ...register.homeGuardSummaries]) {
          final cat = s.category.toLowerCase();
          if (!cat.contains('off') && !cat.contains('leave') && !cat.contains('absent') && 
              !cat.contains('c/l') && !cat.contains('e/l') && !cat.contains('r/l') &&
              !cat.contains('അവധി') && !cat.contains('ലീവ്')) {
            for (var id in s.personnelIds) {
              if (id.trim().isNotEmpty) presentIds.add(id.trim());
            }
          }
        }

        if (!presentIds.contains(linkedPersonId) && !presentIds.contains(idNumber)) {
          return false; // Not found in any duty/present list in Duty Register
        }
      }
    } catch (_) {}

    final attendanceProvider = context.read<AttendanceProvider>();
    final yearMonth = "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}";
    final attendanceData = attendanceProvider.attendanceMap[linkedPersonId];

    if (attendanceData != null && attendanceData.yearMonth == yearMonth) {
      final status = attendanceData.dailyStatus[targetDate.day];
      if (status == null || status.isEmpty || status == 'X' || status == 'P' || status.toUpperCase() == 'X/R') {
        return true;
      }
      return false; // Explicitly marked absent in Attendance
    } else {
      // Default to true if we don't have attendance data yet (blank means on-duty)
      return true;
    }
  }

  static List<String> getAssignedVehicles(BuildContext context, DateTime targetDate) {
    final linkedPersonId = context.read<AuthProvider>().linkedPersonId;
    if (linkedPersonId == null || linkedPersonId.isEmpty) return [];

    final manpowerList = context.read<ManpowerProvider>().personnelList;
    String idNumber = linkedPersonId;
    try {
      final person = manpowerList.firstWhere((p) => p.id == linkedPersonId);
      idNumber = person.idNumber;
    } catch (_) {}

    final dutyProvider = context.read<DutyProvider>();
    List<String> assignedVehicles = [];
    
    for (var register in dutyProvider.registers) {
      if (register.date.year == targetDate.year &&
          register.date.month == targetDate.month &&
          register.date.day == targetDate.day) {
        
        for (var assignment in register.vehicleAssignments) {
          if (assignment.froD.trim() == linkedPersonId || assignment.froD.trim() == idNumber) {
            assignedVehicles.add(assignment.vehicleName);
            continue;
          }
          final khgList = assignment.khg.split(',').map((e) => e.trim()).toList();
          if (khgList.contains(linkedPersonId) || khgList.contains(idNumber)) {
            assignedVehicles.add(assignment.vehicleName);
          }
        }
      }
    }
    return assignedVehicles;
  }

  static String? getAssignedVehicleId(BuildContext context, DateTime targetDate) {
    final vehicles = getAssignedVehicles(context, targetDate);
    if (vehicles.isNotEmpty) {
      return vehicles.first;
    }
    return null;
  }
}
