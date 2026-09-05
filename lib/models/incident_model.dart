import 'package:cloud_firestore/cloud_firestore.dart';

class IncidentModel {
  final String id;
  final String type; // Fire, Rescue, Medical, Other
  final String address;
  final double latitude;
  final double longitude;
  final String status; // Active, Resolved
  final DateTime? reportedTime;
  final DateTime? resolvedTime;
  final List<String> assignedVehicles; // Vehicle IDs or Reg Numbers
  final double? sfroLatitude; // SFRO Mobile GPS bypass
  final double? sfroLongitude; // SFRO Mobile GPS bypass

  IncidentModel({
    required this.id,
    required this.type,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.reportedTime,
    this.resolvedTime,
    this.assignedVehicles = const [],
    this.sfroLatitude,
    this.sfroLongitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'reportedTime': reportedTime != null ? Timestamp.fromDate(reportedTime!) : null,
      'resolvedTime': resolvedTime != null ? Timestamp.fromDate(resolvedTime!) : null,
      'assignedVehicles': assignedVehicles,
      'sfroLatitude': sfroLatitude,
      'sfroLongitude': sfroLongitude,
    };
  }

  factory IncidentModel.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime? parseDateTime(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return IncidentModel(
      id: documentId,
      type: map['type'] ?? 'Other',
      address: map['address'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'Active',
      reportedTime: parseDateTime(map['reportedTime']),
      resolvedTime: parseDateTime(map['resolvedTime']),
      assignedVehicles: List<String>.from(map['assignedVehicles'] ?? []),
      sfroLatitude: map['sfroLatitude']?.toDouble(),
      sfroLongitude: map['sfroLongitude']?.toDouble(),
    );
  }
}
