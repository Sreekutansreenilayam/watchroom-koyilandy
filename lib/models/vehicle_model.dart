import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleModel {
  final String id;
  final String regNumber; // e.g. KL01CS2707
  final String type; // e.g. AMBULANCE
  final String shortName; // e.g. F/T, W/B
  final String status; // READY, OFF ROAD, etc.
  final double waterLevel; // 0.0 to 1.0 (used in interactive hub)
  final double fuelLevel; // 0.0 to 1.0 (used in interactive hub)

  // Section 1: Identification
  final String callSign;
  final String chassisNumber;
  final String engineNumber;
  final String makeModel;
  final String yearOfInduction;

  // Section 2: Operation Status & Vehicle Type
  final bool hasFirePump;

  // Section 3: Compliance Expiries
  final DateTime? insuranceDate;
  final DateTime? insuranceExpiry;
  final DateTime? fcDate;
  final DateTime? fcExpiry;
  final DateTime? taxDate;
  final DateTime? taxExpiry;
  final DateTime? pucDate;
  final DateTime? pucExpiry;
  final DateTime? adBlueDate;
  final DateTime? adBlueExpiry;

  // Section 4: Utilization Data
  final double currentOdometer;
  final double fuelConsumedThisFY;
  final List<dynamic> prevFYHistory; // List of history logs (strings or maps)
  final double fuelTankCapacity;
  final double currentFuelInTank;

  // Section 5: Mileage Review
  final DateTime? mileageReviewDate;
  final double mileageOnRoad;
  final double mileageOnPumping;
  final double fixedDSConsumption; // Fixed DS Consumption (L) - Saturday Only

  // Section 6: Maintenance & Breakdown History
  final DateTime? lastServiceDate;
  final double nextServiceAtKM;
  final DateTime? nextServiceDate;
  final DateTime? lastPumpServiceDate; // Only when hasFirePump is true
  final DateTime? nextPumpServiceDate; // Only when hasFirePump is true
  final List<BreakdownRecord> breakdowns;

  // Section 7: Vehicle History
  final List<RepairHistoryRecord> repairHistory;
  final List<TempIssueHistoryRecord> tempIssueHistory;

  // Section 8: Vehicle Inventory
  final List<InventoryItem> inventory;

  // Section 9: Locker Configuration
  final List<CompartmentModel> compartments;

  VehicleModel({
    required this.id,
    required this.regNumber,
    required this.type,
    this.shortName = '',
    required this.status,
    required this.waterLevel,
    required this.fuelLevel,
    this.callSign = '',
    this.chassisNumber = '',
    this.engineNumber = '',
    this.makeModel = '',
    this.yearOfInduction = '',
    this.hasFirePump = false,
    this.insuranceDate,
    this.insuranceExpiry,
    this.fcDate,
    this.fcExpiry,
    this.taxDate,
    this.taxExpiry,
    this.pucDate,
    this.pucExpiry,
    this.adBlueDate,
    this.adBlueExpiry,
    this.currentOdometer = 0.0,
    this.fuelConsumedThisFY = 0.0,
    this.prevFYHistory = const [],
    this.fuelTankCapacity = 0.0,
    this.currentFuelInTank = 0.0,
    this.mileageReviewDate,
    this.mileageOnRoad = 0.0,
    this.mileageOnPumping = 0.0,
    this.fixedDSConsumption = 0.0,
    this.lastServiceDate,
    this.nextServiceAtKM = 0.0,
    this.nextServiceDate,
    this.lastPumpServiceDate,
    this.nextPumpServiceDate,
    this.breakdowns = const [],
    this.repairHistory = const [],
    this.tempIssueHistory = const [],
    this.inventory = const [],
    this.compartments = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'regNumber': regNumber,
      'type': type,
      'shortName': shortName,
      'status': status,
      'waterLevel': waterLevel,
      'fuelLevel': fuelLevel,
      'callSign': callSign,
      'chassisNumber': chassisNumber,
      'engineNumber': engineNumber,
      'makeModel': makeModel,
      'yearOfInduction': yearOfInduction,
      'hasFirePump': hasFirePump,
      'insuranceDate': insuranceDate != null ? Timestamp.fromDate(insuranceDate!) : null,
      'insuranceExpiry': insuranceExpiry != null ? Timestamp.fromDate(insuranceExpiry!) : null,
      'fcDate': fcDate != null ? Timestamp.fromDate(fcDate!) : null,
      'fcExpiry': fcExpiry != null ? Timestamp.fromDate(fcExpiry!) : null,
      'taxDate': taxDate != null ? Timestamp.fromDate(taxDate!) : null,
      'taxExpiry': taxExpiry != null ? Timestamp.fromDate(taxExpiry!) : null,
      'pucDate': pucDate != null ? Timestamp.fromDate(pucDate!) : null,
      'pucExpiry': pucExpiry != null ? Timestamp.fromDate(pucExpiry!) : null,
      'adBlueDate': adBlueDate != null ? Timestamp.fromDate(adBlueDate!) : null,
      'adBlueExpiry': adBlueExpiry != null ? Timestamp.fromDate(adBlueExpiry!) : null,
      'currentOdometer': currentOdometer,
      'fuelConsumedThisFY': fuelConsumedThisFY,
      'prevFYHistory': prevFYHistory,
      'fuelTankCapacity': fuelTankCapacity,
      'currentFuelInTank': currentFuelInTank,
      'mileageReviewDate': mileageReviewDate != null ? Timestamp.fromDate(mileageReviewDate!) : null,
      'mileageOnRoad': mileageOnRoad,
      'mileageOnPumping': mileageOnPumping,
      'fixedDSConsumption': fixedDSConsumption,
      'lastServiceDate': lastServiceDate != null ? Timestamp.fromDate(lastServiceDate!) : null,
      'nextServiceAtKM': nextServiceAtKM,
      'nextServiceDate': nextServiceDate != null ? Timestamp.fromDate(nextServiceDate!) : null,
      'lastPumpServiceDate': lastPumpServiceDate != null ? Timestamp.fromDate(lastPumpServiceDate!) : null,
      'nextPumpServiceDate': nextPumpServiceDate != null ? Timestamp.fromDate(nextPumpServiceDate!) : null,
      'breakdowns': breakdowns.map((b) => b.toMap()).toList(),
      'repairHistory': repairHistory.map((r) => r.toMap()).toList(),
      'tempIssueHistory': tempIssueHistory.map((t) => t.toMap()).toList(),
      'inventory': inventory.map((i) => i.toMap()).toList(),
      'compartments': compartments.map((c) => c.toMap()).toList(),
    };
  }

  factory VehicleModel.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime? parseDateTime(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    return VehicleModel(
      id: documentId,
      regNumber: map['regNumber'] ?? '',
      type: map['type'] ?? '',
      shortName: map['shortName'] ?? '',
      status: map['status'] ?? 'Available',
      waterLevel: parseDouble(map['waterLevel']),
      fuelLevel: parseDouble(map['fuelLevel']),
      callSign: map['callSign'] ?? '',
      chassisNumber: map['chassisNumber'] ?? '',
      engineNumber: map['engineNumber'] ?? '',
      makeModel: map['makeModel'] ?? '',
      yearOfInduction: map['yearOfInduction'] ?? '',
      hasFirePump: map['hasFirePump'] ?? false,
      insuranceDate: parseDateTime(map['insuranceDate']),
      insuranceExpiry: parseDateTime(map['insuranceExpiry']),
      fcDate: parseDateTime(map['fcDate']),
      fcExpiry: parseDateTime(map['fcExpiry']),
      taxDate: parseDateTime(map['taxDate']),
      taxExpiry: parseDateTime(map['taxExpiry']),
      pucDate: parseDateTime(map['pucDate']),
      pucExpiry: parseDateTime(map['pucExpiry']),
      adBlueDate: parseDateTime(map['adBlueDate']),
      adBlueExpiry: parseDateTime(map['adBlueExpiry']),
      currentOdometer: parseDouble(map['currentOdometer']),
      fuelConsumedThisFY: parseDouble(map['fuelConsumedThisFY']),
      prevFYHistory: map['prevFYHistory'] ?? [],
      fuelTankCapacity: parseDouble(map['fuelTankCapacity']),
      currentFuelInTank: parseDouble(map['currentFuelInTank']),
      mileageReviewDate: parseDateTime(map['mileageReviewDate']),
      mileageOnRoad: parseDouble(map['mileageOnRoad']),
      mileageOnPumping: parseDouble(map['mileageOnPumping']),
      fixedDSConsumption: parseDouble(map['fixedDSConsumption']),
      lastServiceDate: parseDateTime(map['lastServiceDate']),
      nextServiceAtKM: parseDouble(map['nextServiceAtKM']),
      nextServiceDate: parseDateTime(map['nextServiceDate']),
      lastPumpServiceDate: parseDateTime(map['lastPumpServiceDate']),
      nextPumpServiceDate: parseDateTime(map['nextPumpServiceDate']),
      breakdowns: (map['breakdowns'] as List?)
              ?.map((item) => BreakdownRecord.fromMap(Map<String, dynamic>.from(item)))
              .toList() ?? [],
      repairHistory: (map['repairHistory'] as List?)
              ?.map((item) => RepairHistoryRecord.fromMap(Map<String, dynamic>.from(item)))
              .toList() ?? [],
      tempIssueHistory: (map['tempIssueHistory'] as List?)
              ?.map((item) => TempIssueHistoryRecord.fromMap(Map<String, dynamic>.from(item)))
              .toList() ?? [],
      inventory: (map['inventory'] as List?)
              ?.map((item) => InventoryItem.fromMap(Map<String, dynamic>.from(item)))
              .toList() ?? [],
      compartments: (map['compartments'] as List?)
              ?.map((item) => CompartmentModel.fromMap(Map<String, dynamic>.from(item)))
              .toList() ?? [],
    );
  }
}

class BreakdownRecord {
  final DateTime? date;
  final String details;

  BreakdownRecord({this.date, this.details = ''});

  Map<String, dynamic> toMap() {
    return {
      'date': date != null ? Timestamp.fromDate(date!) : null,
      'details': details,
    };
  }

  factory BreakdownRecord.fromMap(Map<String, dynamic> map) {
    DateTime? parseDateTime(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }
    return BreakdownRecord(
      date: parseDateTime(map['date']),
      details: map['details'] ?? '',
    );
  }
}

class RepairHistoryRecord {
  final String sl;
  final String offRoad;
  final String onRoad;
  final String duration;
  final String mechanicalRemarks;

  RepairHistoryRecord({
    this.sl = '',
    this.offRoad = '',
    this.onRoad = '',
    this.duration = '',
    this.mechanicalRemarks = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'sl': sl,
      'offRoad': offRoad,
      'onRoad': onRoad,
      'duration': duration,
      'mechanicalRemarks': mechanicalRemarks,
    };
  }

  factory RepairHistoryRecord.fromMap(Map<String, dynamic> map) {
    return RepairHistoryRecord(
      sl: map['sl']?.toString() ?? '',
      offRoad: map['offRoad'] ?? '',
      onRoad: map['onRoad'] ?? '',
      duration: map['duration'] ?? '',
      mechanicalRemarks: map['mechanicalRemarks'] ?? '',
    );
  }
}

class TempIssueHistoryRecord {
  final String sl;
  final String issued;
  final String returned;
  final String heldPeriod;
  final String stationUnitDetails;

  TempIssueHistoryRecord({
    this.sl = '',
    this.issued = '',
    this.returned = '',
    this.heldPeriod = '',
    this.stationUnitDetails = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'sl': sl,
      'issued': issued,
      'returned': returned,
      'heldPeriod': heldPeriod,
      'stationUnitDetails': stationUnitDetails,
    };
  }

  factory TempIssueHistoryRecord.fromMap(Map<String, dynamic> map) {
    return TempIssueHistoryRecord(
      sl: map['sl']?.toString() ?? '',
      issued: map['issued'] ?? '',
      returned: map['returned'] ?? '',
      heldPeriod: map['heldPeriod'] ?? '',
      stationUnitDetails: map['stationUnitDetails'] ?? '',
    );
  }
}

class InventoryItem {
  final int slNo;
  final String equipName;
  final int qty;
  final String remarks;

  InventoryItem({
    this.slNo = 1,
    this.equipName = '',
    this.qty = 0,
    this.remarks = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'slNo': slNo,
      'equipName': equipName,
      'qty': qty,
      'remarks': remarks,
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      slNo: map['slNo'] ?? 1,
      equipName: map['equipName'] ?? '',
      qty: map['qty'] ?? 0,
      remarks: map['remarks'] ?? '',
    );
  }
}

class LockerItemModel {
  final String name;
  final int qty;
  final String remarks;

  LockerItemModel({
    required this.name,
    required this.qty,
    this.remarks = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'qty': qty,
      'remarks': remarks,
    };
  }

  factory LockerItemModel.fromMap(Map<String, dynamic> map) {
    return LockerItemModel(
      name: map['name'] ?? '',
      qty: map['qty'] ?? 0,
      remarks: map['remarks'] ?? '',
    );
  }
}

class CompartmentModel {
  final String id; // e.g. L1, R1
  final String label; // e.g. Hoses, Pumps
  final String side; // left, right, rear
  final List<LockerItemModel> items;

  CompartmentModel({
    required this.id,
    required this.label,
    required this.side,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'side': side,
      'items': items.map((i) => i.toMap()).toList(),
    };
  }

  factory CompartmentModel.fromMap(Map<String, dynamic> map) {
    return CompartmentModel(
      id: map['id'] ?? '',
      label: map['label'] ?? '',
      side: map['side'] ?? 'left',
      items: (map['items'] as List?)
              ?.map((i) => LockerItemModel.fromMap(Map<String, dynamic>.from(i)))
              .toList() ??
          [],
    );
  }
}
