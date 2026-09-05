import 'package:cloud_firestore/cloud_firestore.dart';

class DutyRegisterModel {
  final String id;
  final DateTime date;
  final String rollCallTime; // e.g. "08:45 AM"
  final String shift; // Day, Night
  final String vacancyCount;
  final String vacancyDetails;
  
  // Section 2: Personnel Summaries
  final List<DutyPersonnelSummary> staffSummaries;
  final List<DutyPersonnelSummary> homeGuardSummaries;
  final List<DutyPersonnelSummary> trainingSummaries;
  final List<String> stationWriterIds;
  final List<String> specialDutyIds;
  final List<String> trainingOverrideIds;
  
  // Section 3: Vehicle Assignments
  final List<DutyVehicleAssignment> vehicleAssignments;

  // Section 4: Other Duties
  final List<String> phoneDutyIds;
  final List<String> messengerIds;
  final List<String> sentryDutyIds;
  final List<String> controlRoomIds;

  DutyRegisterModel({
    required this.id,
    required this.date,
    required this.rollCallTime,
    required this.shift,
    this.vacancyCount = '',
    this.vacancyDetails = '',
    required this.staffSummaries,
    required this.homeGuardSummaries,
    required this.trainingSummaries,
    this.stationWriterIds = const [],
    this.specialDutyIds = const [],
    this.trainingOverrideIds = const [],
    required this.vehicleAssignments,
    required this.phoneDutyIds,
    required this.messengerIds,
    required this.sentryDutyIds,
    this.controlRoomIds = const [],
  });

  factory DutyRegisterModel.fromMap(String id, Map<String, dynamic> data) {
    return DutyRegisterModel(
      id: id,
      date: (data['date'] as Timestamp).toDate(),
      rollCallTime: data['rollCallTime'] ?? '',
      shift: data['shift'] ?? 'Day',
      vacancyCount: data['vacancyCount'] ?? '',
      vacancyDetails: data['vacancyDetails'] ?? '',
      staffSummaries: (data['staffSummaries'] as List? ?? [])
          .map((e) => DutyPersonnelSummary.fromMap(e))
          .toList(),
      homeGuardSummaries: (data['homeGuardSummaries'] as List? ?? [])
          .map((e) => DutyPersonnelSummary.fromMap(e))
          .toList(),
      trainingSummaries: (data['trainingSummaries'] as List? ?? [])
          .map((e) => DutyPersonnelSummary.fromMap(e))
          .toList(),
      stationWriterIds: List<String>.from(data['stationWriterIds'] ?? []),
      specialDutyIds: List<String>.from(data['specialDutyIds'] ?? []),
      trainingOverrideIds: List<String>.from(data['trainingOverrideIds'] ?? []),
      vehicleAssignments: (data['vehicleAssignments'] as List? ?? [])
          .map((e) => DutyVehicleAssignment.fromMap(e))
          .toList(),
      phoneDutyIds: List<String>.from(data['phoneDutyIds'] ?? []),
      messengerIds: List<String>.from(data['messengerIds'] ?? []),
      sentryDutyIds: List<String>.from(data['sentryDutyIds'] ?? []),
      controlRoomIds: List<String>.from(data['controlRoomIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'rollCallTime': rollCallTime,
      'shift': shift,
      'vacancyCount': vacancyCount,
      'vacancyDetails': vacancyDetails,
      'staffSummaries': staffSummaries.map((e) => e.toMap()).toList(),
      'homeGuardSummaries': homeGuardSummaries.map((e) => e.toMap()).toList(),
      'trainingSummaries': trainingSummaries.map((e) => e.toMap()).toList(),
      'stationWriterIds': stationWriterIds,
      'specialDutyIds': specialDutyIds,
      'trainingOverrideIds': trainingOverrideIds,
      'vehicleAssignments': vehicleAssignments.map((e) => e.toMap()).toList(),
      'phoneDutyIds': phoneDutyIds,
      'messengerIds': messengerIds,
      'sentryDutyIds': sentryDutyIds,
      'controlRoomIds': controlRoomIds,
    };
  }
}

class DutyPersonnelSummary {
  final String category; // e.g. "Off Duty", "On Duty (SFRO)"
  final List<String> personnelIds;

  DutyPersonnelSummary({
    required this.category,
    required this.personnelIds,
  });

  factory DutyPersonnelSummary.fromMap(Map<String, dynamic> data) {
    return DutyPersonnelSummary(
      category: data['category'] ?? '',
      personnelIds: List<String>.from(data['personnelIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'personnelIds': personnelIds,
    };
  }
}

class DutyVehicleAssignment {
  final String vehicleName;
  final int seniority;
  // 4 columns for Posted Personnel
  final String sfro;
  final String fro;
  final String khg;
  final String froD;
  final String remarks;
  final bool isOffRoad;
  final bool isAttached;
  final List<String> manuallyEditedIds;

  DutyVehicleAssignment({
    required this.vehicleName,
    this.seniority = 99,
    this.sfro = '',
    this.fro = '',
    this.khg = '',
    this.froD = '',
    this.remarks = '',
    this.isOffRoad = false,
    this.isAttached = false,
    this.manuallyEditedIds = const [],
  });

  factory DutyVehicleAssignment.fromMap(Map<String, dynamic> data) {
    return DutyVehicleAssignment(
      vehicleName: data['vehicleName'] ?? '',
      seniority: data['seniority'] ?? 99,
      sfro: data['sfro'] ?? '',
      fro: data['fro'] ?? '',
      khg: data['khg'] ?? '',
      froD: data['froD'] ?? '',
      remarks: data['remarks'] ?? '',
      isOffRoad: data['isOffRoad'] ?? false,
      isAttached: data['isAttached'] ?? false,
      manuallyEditedIds: List<String>.from(data['manuallyEditedIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicleName': vehicleName,
      'seniority': seniority,
      'sfro': sfro,
      'fro': fro,
      'khg': khg,
      'froD': froD,
      'remarks': remarks,
      'isOffRoad': isOffRoad,
      'isAttached': isAttached,
      'manuallyEditedIds': manuallyEditedIds,
    };
  }
}
