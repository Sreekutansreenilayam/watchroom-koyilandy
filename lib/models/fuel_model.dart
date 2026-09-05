import 'package:cloud_firestore/cloud_firestore.dart';

class FuelLedger {
  final String id;
  final int ledgerNumber;
  final String name;
  final String type; // 'Fuel' or 'Oil'
  final double currentBalance;
  final int lastSerialNumber;

  FuelLedger({
    required this.id,
    required this.ledgerNumber,
    required this.name,
    required this.type,
    this.currentBalance = 0.0,
    this.lastSerialNumber = 0,
  });

  factory FuelLedger.fromMap(Map<String, dynamic> data, String id) {
    return FuelLedger(
      id: id,
      ledgerNumber: data['ledgerNumber'] ?? 0,
      name: data['name'] ?? '',
      type: data['type'] ?? 'Fuel',
      currentBalance: (data['currentBalance'] ?? 0).toDouble(),
      lastSerialNumber: data['lastSerialNumber'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ledgerNumber': ledgerNumber,
      'name': name,
      'type': type,
      'currentBalance': currentBalance,
      'lastSerialNumber': lastSerialNumber,
    };
  }
}

class FuelTransaction {
  final String id;
  final String ledgerId;
  final DateTime date;
  final String party;
  final String type; // 'RECEIPT' or 'ISSUE'
  final double quantity;
  final double balanceAfter;
  final String voucherNumber;
  final String remarks;
  final String? linkedLogbookEntryId;
  final String operatorName;

  FuelTransaction({
    required this.id,
    required this.ledgerId,
    required this.date,
    required this.party,
    required this.type,
    required this.quantity,
    required this.balanceAfter,
    required this.voucherNumber,
    this.remarks = '',
    this.linkedLogbookEntryId,
    this.operatorName = '',
  });

  factory FuelTransaction.fromMap(Map<String, dynamic> data, String id) {
    return FuelTransaction(
      id: id,
      ledgerId: data['ledgerId'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      party: data['party'] ?? '',
      type: data['type'] ?? 'RECEIPT',
      quantity: (data['quantity'] ?? 0).toDouble(),
      balanceAfter: (data['balanceAfter'] ?? 0).toDouble(),
      voucherNumber: data['voucherNumber'] ?? '',
      remarks: data['remarks'] ?? '',
      linkedLogbookEntryId: data['linkedLogbookEntryId'],
      operatorName: data['operatorName'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ledgerId': ledgerId,
      'date': Timestamp.fromDate(date),
      'party': party,
      'type': type,
      'quantity': quantity,
      'balanceAfter': balanceAfter,
      'voucherNumber': voucherNumber,
      'remarks': remarks,
      'linkedLogbookEntryId': linkedLogbookEntryId,
      'operatorName': operatorName,
    };
  }
}
