import 'package:cloud_firestore/cloud_firestore.dart';

class EquipmentHead {
  final String id;
  final String name;
  final String shortName;
  final String category;
  final int totalQty;
  final int serviceableQty;
  final int unserviceableQty;
  final int issuedQty;

  EquipmentHead({
    required this.id,
    required this.name,
    this.shortName = '',
    required this.category,
    required this.totalQty,
    required this.serviceableQty,
    required this.unserviceableQty,
    this.issuedQty = 0,
  });

  factory EquipmentHead.fromMap(Map<String, dynamic> map, String id) {
    return EquipmentHead(
      id: id,
      name: map['name'] ?? '',
      shortName: map['shortName'] ?? '',
      category: map['category'] ?? '',
      totalQty: map['totalQty'] ?? 0,
      serviceableQty: map['serviceableQty'] ?? 0,
      unserviceableQty: map['unserviceableQty'] ?? 0,
      issuedQty: map['issuedQty'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'shortName': shortName,
      'category': category,
      'totalQty': totalQty,
      'serviceableQty': serviceableQty,
      'unserviceableQty': unserviceableQty,
      'issuedQty': issuedQty,
    };
  }
}

class EquipmentStockEntry {
  final String id;
  final String headId;
  final DateTime dateTakenIntoCharge;
  final int quantity;
  final String brand;
  final String equipmentId;
  final String serialNumbers;
  final DateTime? warrantyExpiry;
  final DateTime? lastServiceDate;
  final DateTime? nextServiceDate;
  final String assignedTo;
  final String? lockerNumber;
  final String invoiceNo;

  EquipmentStockEntry({
    required this.id,
    required this.headId,
    required this.dateTakenIntoCharge,
    required this.quantity,
    required this.brand,
    this.equipmentId = '',
    required this.serialNumbers,
    this.warrantyExpiry,
    this.lastServiceDate,
    this.nextServiceDate,
    required this.assignedTo,
    this.lockerNumber,
    this.invoiceNo = '',
  });

  factory EquipmentStockEntry.fromMap(Map<String, dynamic> map, String id) {
    return EquipmentStockEntry(
      id: id,
      headId: map['headId'] ?? '',
      dateTakenIntoCharge: (map['dateTakenIntoCharge'] as Timestamp).toDate(),
      quantity: map['quantity'] ?? 0,
      brand: map['brand'] ?? '',
      equipmentId: map['equipmentId'] ?? '',
      serialNumbers: map['serialNumbers'] ?? '',
      warrantyExpiry: map['warrantyExpiry'] != null ? (map['warrantyExpiry'] as Timestamp).toDate() : null,
      lastServiceDate: map['lastServiceDate'] != null ? (map['lastServiceDate'] as Timestamp).toDate() : null,
      nextServiceDate: map['nextServiceDate'] != null ? (map['nextServiceDate'] as Timestamp).toDate() : null,
      assignedTo: map['assignedTo'] ?? '',
      lockerNumber: map['lockerNumber'],
      invoiceNo: map['invoiceNo'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'headId': headId,
      'dateTakenIntoCharge': Timestamp.fromDate(dateTakenIntoCharge),
      'quantity': quantity,
      'brand': brand,
      'equipmentId': equipmentId,
      'serialNumbers': serialNumbers,
      'warrantyExpiry': warrantyExpiry != null ? Timestamp.fromDate(warrantyExpiry!) : null,
      'lastServiceDate': lastServiceDate != null ? Timestamp.fromDate(lastServiceDate!) : null,
      'nextServiceDate': nextServiceDate != null ? Timestamp.fromDate(nextServiceDate!) : null,
      'assignedTo': assignedTo,
      'lockerNumber': lockerNumber,
      'invoiceNo': invoiceNo,
    };
  }
}

class EquipmentHistory {
  final String id;
  final String headId;
  final String type; // 'STATUS_CHANGE', 'TEMP_ISSUE'
  final String status; // 'SERVICEABLE', 'UNSERVICEABLE'
  final String equipmentId;
  final int quantityAffected;
  final DateTime fromDate;
  final DateTime? toDate;
  final String? voucherNumber;
  final String remarks;

  EquipmentHistory({
    required this.id,
    required this.headId,
    required this.type,
    required this.status,
    this.equipmentId = '',
    required this.quantityAffected,
    required this.fromDate,
    this.toDate,
    this.voucherNumber,
    required this.remarks,
  });

  factory EquipmentHistory.fromMap(Map<String, dynamic> map, String id) {
    return EquipmentHistory(
      id: id,
      headId: map['headId'] ?? '',
      type: map['type'] ?? '',
      status: map['status'] ?? '',
      equipmentId: map['equipmentId'] ?? '',
      quantityAffected: map['quantityAffected'] ?? 0,
      fromDate: (map['fromDate'] as Timestamp).toDate(),
      toDate: map['toDate'] != null ? (map['toDate'] as Timestamp).toDate() : null,
      voucherNumber: map['voucherNumber'],
      remarks: map['remarks'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'headId': headId,
      'type': type,
      'status': status,
      'equipmentId': equipmentId,
      'quantityAffected': quantityAffected,
      'fromDate': Timestamp.fromDate(fromDate),
      'toDate': toDate != null ? Timestamp.fromDate(toDate!) : null,
      'voucherNumber': voucherNumber,
      'remarks': remarks,
    };
  }
}
