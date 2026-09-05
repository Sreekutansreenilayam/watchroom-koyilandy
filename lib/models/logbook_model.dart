import 'package:cloud_firestore/cloud_firestore.dart';

class LogbookEntry {
  final String id;
  final String vehicleId;
  final DateTime date;
  
  final double previousKms;
  
  final double remainingFuelInTank;
  final double suppliedFuel;
  
  final double oil;
  final double grease;
  final double dWater;
  final double adBlue;
  
  final String departureTime; // "HH:mm"
  final String fromPlace;
  final String toPlace;
  final String arrivalTime; // "HH:mm"
  final double travelledDistance;
  
  final String pumpStartTime; // "HH:mm"
  final String pumpEndTime; // "HH:mm"
  final String pumpDuration; // "HH:mm" or minutes
  final double pumpKm;
  
  final double fuelConsumedForJourney;
  final double fuelConsumedForPump;
  
  final String remarks;
  final String vehicleCheckTime; // "HH:mm"
  final String operatorName;
  final String actionType;

  LogbookEntry({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.previousKms,
    required this.remainingFuelInTank,
    required this.suppliedFuel,
    required this.oil,
    required this.grease,
    required this.dWater,
    this.adBlue = 0.0,
    required this.departureTime,
    required this.fromPlace,
    required this.toPlace,
    required this.arrivalTime,
    required this.travelledDistance,
    required this.pumpStartTime,
    required this.pumpEndTime,
    required this.pumpDuration,
    this.pumpKm = 0.0,
    required this.fuelConsumedForJourney,
    required this.fuelConsumedForPump,
    required this.remarks,
    required this.vehicleCheckTime,
    required this.operatorName,
    this.actionType = '',
  });

  /// Computes the duty date for this entry based on its actual time.
  DateTime get dutyDate {
    String timeStr = departureTime;
    if (timeStr.isEmpty) timeStr = vehicleCheckTime;
    if (timeStr.isEmpty) timeStr = pumpStartTime;
    if (timeStr.isEmpty) return DateTime(date.year, date.month, date.day);

    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]) ?? 0;
      if (hour < 9) {
        return DateTime(date.year, date.month, date.day).subtract(const Duration(days: 1));
      }
    }
    return DateTime(date.year, date.month, date.day);
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicleId': vehicleId,
      'date': Timestamp.fromDate(date),
      'previousKms': previousKms,
      'remainingFuelInTank': remainingFuelInTank,
      'suppliedFuel': suppliedFuel,
      'oil': oil,
      'grease': grease,
      'dWater': dWater,
      'adBlue': adBlue,
      'departureTime': departureTime,
      'fromPlace': fromPlace,
      'toPlace': toPlace,
      'arrivalTime': arrivalTime,
      'travelledDistance': travelledDistance,
      'pumpStartTime': pumpStartTime,
      'pumpEndTime': pumpEndTime,
      'pumpDuration': pumpDuration,
      'pumpKm': pumpKm,
      'fuelConsumedForJourney': fuelConsumedForJourney,
      'fuelConsumedForPump': fuelConsumedForPump,
      'remarks': remarks,
      'vehicleCheckTime': vehicleCheckTime,
      'operatorName': operatorName,
      'actionType': actionType,
    };
  }

  factory LogbookEntry.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return LogbookEntry(
      id: doc.id,
      vehicleId: data['vehicleId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      previousKms: (data['previousKms'] ?? 0).toDouble(),
      remainingFuelInTank: (data['remainingFuelInTank'] ?? 0).toDouble(),
      suppliedFuel: (data['suppliedFuel'] ?? 0).toDouble(),
      oil: (data['oil'] ?? 0).toDouble(),
      grease: (data['grease'] ?? 0).toDouble(),
      dWater: (data['dWater'] ?? 0).toDouble(),
      adBlue: (data['adBlue'] ?? 0).toDouble(),
      departureTime: data['departureTime'] ?? '',
      fromPlace: data['fromPlace'] ?? '',
      toPlace: data['toPlace'] ?? '',
      arrivalTime: data['arrivalTime'] ?? '',
      travelledDistance: (data['travelledDistance'] ?? 0).toDouble(),
      pumpStartTime: data['pumpStartTime'] ?? '',
      pumpEndTime: data['pumpEndTime'] ?? '',
      pumpDuration: data['pumpDuration'] ?? '',
      pumpKm: (data['pumpKm'] ?? 0).toDouble(),
      fuelConsumedForJourney: (data['fuelConsumedForJourney'] ?? 0).toDouble(),
      fuelConsumedForPump: (data['fuelConsumedForPump'] ?? 0).toDouble(),
      remarks: data['remarks'] ?? '',
      vehicleCheckTime: data['vehicleCheckTime'] ?? '',
      operatorName: data['operatorName'] ?? '',
      actionType: data['actionType'] ?? '',
    );
  }
}
