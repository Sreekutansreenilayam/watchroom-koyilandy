import 'package:cloud_firestore/cloud_firestore.dart';

class VoucherItem {
  final String ledgerPageNo;
  final String description; // Nomenclature
  final String au;
  final int qty;
  final String remarks;

  VoucherItem({
    this.ledgerPageNo = '',
    this.description = '',
    this.au = '',
    this.qty = 1,
    this.remarks = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'ledgerPageNo': ledgerPageNo,
      'description': description,
      'au': au,
      'qty': qty,
      'remarks': remarks,
    };
  }

  factory VoucherItem.fromMap(Map<String, dynamic> map) {
    return VoucherItem(
      ledgerPageNo: map['ledgerPageNo'] ?? '',
      description: map['description'] ?? '',
      au: map['au'] ?? '',
      qty: map['qty'] ?? 1,
      remarks: map['remarks'] ?? '',
    );
  }
}

class VoucherModel {
  final String id;
  final String type; // 'Temporary' or 'Permanent'
  final String category; // 'Vehicle', 'Equipment', 'Misc'
  
  // Issuing Officer
  final String ivNo;
  final DateTime? issueDate;
  final String issueStation;
  
  // Receiving Officer
  final String rvNo;
  final DateTime? receiptDate;
  final String receiptStation;
  
  // Items List
  final List<VoucherItem> items;
  
  // Signatures - Issued By
  final String issuedByIdNo;
  final String issuedByDesignation;
  final String issuedByName;
  final String issuedByStation;
  final String issuedByMobile;
  final DateTime? issuedByDate;
  
  // Signatures - Received By
  final String receivedByIdNo;
  final String receivedByDesignation;
  final String receivedByName;
  final String receivedByStation;
  final String receivedByMobile;
  final DateTime? receivedByDate;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  VoucherModel({
    required this.id,
    required this.type,
    this.category = 'Misc',
    this.ivNo = '',
    this.issueDate,
    this.issueStation = 'Fire & Rescue Station, Meenchanda',
    this.rvNo = '',
    this.receiptDate,
    this.receiptStation = '',
    this.items = const [],
    this.issuedByIdNo = '',
    this.issuedByDesignation = '',
    this.issuedByName = '',
    this.issuedByStation = '',
    this.issuedByMobile = '',
    this.issuedByDate,
    this.receivedByIdNo = '',
    this.receivedByDesignation = '',
    this.receivedByName = '',
    this.receivedByStation = '',
    this.receivedByMobile = '',
    this.receivedByDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : this.createdAt = createdAt ?? DateTime.now(),
       this.updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'category': category,
      'ivNo': ivNo,
      'issueDate': issueDate != null ? Timestamp.fromDate(issueDate!) : null,
      'issueStation': issueStation,
      'rvNo': rvNo,
      'receiptDate': receiptDate != null ? Timestamp.fromDate(receiptDate!) : null,
      'receiptStation': receiptStation,
      'items': items.map((i) => i.toMap()).toList(),
      'issuedByIdNo': issuedByIdNo,
      'issuedByDesignation': issuedByDesignation,
      'issuedByName': issuedByName,
      'issuedByStation': issuedByStation,
      'issuedByMobile': issuedByMobile,
      'issuedByDate': issuedByDate != null ? Timestamp.fromDate(issuedByDate!) : null,
      'receivedByIdNo': receivedByIdNo,
      'receivedByDesignation': receivedByDesignation,
      'receivedByName': receivedByName,
      'receivedByStation': receivedByStation,
      'receivedByMobile': receivedByMobile,
      'receivedByDate': receivedByDate != null ? Timestamp.fromDate(receivedByDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory VoucherModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return VoucherModel(
      id: id,
      type: map['type'] ?? 'Temporary',
      category: map['category'] ?? 'Misc',
      ivNo: map['ivNo'] ?? '',
      issueDate: parseDate(map['issueDate']),
      issueStation: map['issueStation'] ?? '',
      rvNo: map['rvNo'] ?? '',
      receiptDate: parseDate(map['receiptDate']),
      receiptStation: map['receiptStation'] ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((item) => VoucherItem.fromMap(Map<String, dynamic>.from(item)))
              .toList() ?? [],
      issuedByIdNo: map['issuedByIdNo'] ?? '',
      issuedByDesignation: map['issuedByDesignation'] ?? '',
      issuedByName: map['issuedByName'] ?? '',
      issuedByStation: map['issuedByStation'] ?? '',
      issuedByMobile: map['issuedByMobile'] ?? '',
      issuedByDate: parseDate(map['issuedByDate']),
      receivedByIdNo: map['receivedByIdNo'] ?? '',
      receivedByDesignation: map['receivedByDesignation'] ?? '',
      receivedByName: map['receivedByName'] ?? '',
      receivedByStation: map['receivedByStation'] ?? '',
      receivedByMobile: map['receivedByMobile'] ?? '',
      receivedByDate: parseDate(map['receivedByDate']),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(map['updatedAt']) ?? DateTime.now(),
    );
  }
}
