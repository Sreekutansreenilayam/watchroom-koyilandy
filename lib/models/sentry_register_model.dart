import 'package:cloud_firestore/cloud_firestore.dart';

class SentrySlot {
  final String timeLabel; // e.g., "09:00 AM - 11:00 AM"
  final String personnelId; // idNumber of the assigned person
  final bool isBroken;
  final String? brokenTime;
  final String? replacementPersonnelId;

  SentrySlot({
    required this.timeLabel,
    this.personnelId = '',
    this.isBroken = false,
    this.brokenTime,
    this.replacementPersonnelId,
  });

  Map<String, dynamic> toMap() {
    return {
      'timeLabel': timeLabel,
      'personnelId': personnelId,
      'isBroken': isBroken,
      'brokenTime': brokenTime,
      'replacementPersonnelId': replacementPersonnelId,
    };
  }

  factory SentrySlot.fromMap(Map<String, dynamic> map) {
    return SentrySlot(
      timeLabel: map['timeLabel'] ?? '',
      personnelId: map['personnelId'] ?? '',
      isBroken: map['isBroken'] ?? false,
      brokenTime: map['brokenTime'],
      replacementPersonnelId: map['replacementPersonnelId'],
    );
  }
}

class SentryExemption {
  final String personnelId;
  final String reason;

  SentryExemption({
    required this.personnelId,
    required this.reason,
  });

  Map<String, dynamic> toMap() {
    return {
      'personnelId': personnelId,
      'reason': reason,
    };
  }

  factory SentryExemption.fromMap(Map<String, dynamic> map) {
    return SentryExemption(
      personnelId: map['personnelId'] ?? '',
      reason: map['reason'] ?? '',
    );
  }
}

class SentryRegisterModel {
  final String id;
  final DateTime date;
  final List<SentrySlot> slots;
  final List<String> spares; // List of personnel idNumbers
  final List<SentryExemption> exemptions;
  final bool isConfirmed;

  SentryRegisterModel({
    required this.id,
    required this.date,
    required this.slots,
    this.spares = const [],
    this.exemptions = const [],
    this.isConfirmed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'slots': slots.map((s) => s.toMap()).toList(),
      'spares': spares,
      'exemptions': exemptions.map((e) => e.toMap()).toList(),
      'isConfirmed': isConfirmed,
    };
  }

  factory SentryRegisterModel.fromMap(String id, Map<String, dynamic> data) {
    var slotsData = data['slots'] as List? ?? [];
    var exemptionsData = data['exemptions'] as List? ?? [];
    return SentryRegisterModel(
      id: id,
      date: (data['date'] as Timestamp).toDate(),
      slots: slotsData.map((s) => SentrySlot.fromMap(s as Map<String, dynamic>)).toList(),
      spares: List<String>.from(data['spares'] ?? []),
      exemptions: exemptionsData.map((e) => SentryExemption.fromMap(e as Map<String, dynamic>)).toList(),
      isConfirmed: data['isConfirmed'] ?? false,
    );
  }
}
