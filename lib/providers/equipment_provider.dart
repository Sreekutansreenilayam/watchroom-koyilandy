import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/equipment_model.dart';

class EquipmentProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<EquipmentHead> _equipments = [];
  bool _isLoading = false;
  String? _error;

  List<EquipmentHead> get equipments => _equipments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  EquipmentProvider() {
    _init();
  }

  void _init() {
    _firestore.collection('equipment_heads').snapshots().listen((snapshot) {
      _equipments = snapshot.docs.map((doc) => EquipmentHead.fromMap(doc.data(), doc.id)).toList();
      // Sort alphabetically by name
      _equipments.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      notifyListeners();
    });
  }

  Future<String> addEquipmentHead(String name, String category) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Check if equipment with same name already exists
      final existingIndex = _equipments.indexWhere((e) => e.name.toLowerCase() == name.toLowerCase());
      if (existingIndex != -1) {
        throw Exception('Equipment with this name already exists.');
      }

      final newHead = EquipmentHead(
        id: '',
        name: name,
        category: category,
        totalQty: 0,
        serviceableQty: 0,
        unserviceableQty: 0,
      );

      final docRef = await _firestore.collection('equipment_heads').add(newHead.toMap());
      return docRef.id;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addStockEntry({
    required String headId,
    required DateTime dateTakenIntoCharge,
    required int quantity,
    required String brand,
    required String serialNumbers,
    DateTime? warrantyExpiry,
    DateTime? lastServiceDate,
    DateTime? nextServiceDate,
    required String assignedTo,
    String? lockerNumber,
    String invoiceNo = '',
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final entry = EquipmentStockEntry(
        id: '',
        headId: headId,
        dateTakenIntoCharge: dateTakenIntoCharge,
        quantity: quantity,
        brand: brand,
        serialNumbers: serialNumbers,
        warrantyExpiry: warrantyExpiry,
        lastServiceDate: lastServiceDate,
        nextServiceDate: nextServiceDate,
        assignedTo: assignedTo,
        lockerNumber: lockerNumber,
        invoiceNo: invoiceNo,
      );

      WriteBatch batch = _firestore.batch();
      
      DocumentReference entryRef = _firestore.collection('equipment_entries').doc();
      batch.set(entryRef, entry.toMap());

      DocumentReference headRef = _firestore.collection('equipment_heads').doc(headId);
      batch.update(headRef, {
        'totalQty': FieldValue.increment(quantity),
        'serviceableQty': FieldValue.increment(quantity),
      });

      await batch.commit();

    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addHistoryEntry({
    required String headId,
    required String type,
    required String status,
    required int quantityAffected,
    required DateTime fromDate,
    DateTime? toDate,
    String? voucherNumber,
    required String remarks,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final history = EquipmentHistory(
        id: '',
        headId: headId,
        type: type,
        status: status,
        quantityAffected: quantityAffected,
        fromDate: fromDate,
        toDate: toDate,
        voucherNumber: voucherNumber,
        remarks: remarks,
      );

      WriteBatch batch = _firestore.batch();
      
      DocumentReference historyRef = _firestore.collection('equipment_history').doc();
      batch.set(historyRef, history.toMap());

      if (type == 'STATUS_CHANGE') {
        DocumentReference headRef = _firestore.collection('equipment_heads').doc(headId);
        if (status == 'UNSERVICEABLE') {
          batch.update(headRef, {
            'serviceableQty': FieldValue.increment(-quantityAffected),
            'unserviceableQty': FieldValue.increment(quantityAffected),
          });
        } else if (status == 'SERVICEABLE') {
          batch.update(headRef, {
            'serviceableQty': FieldValue.increment(quantityAffected),
            'unserviceableQty': FieldValue.increment(-quantityAffected),
          });
        }
      } else if (type == 'TEMP_ISSUE') {
        DocumentReference headRef = _firestore.collection('equipment_heads').doc(headId);
        batch.update(headRef, {
          'issuedQty': FieldValue.increment(quantityAffected),
        });
      } else if (type == 'RETURN_TEMP_ISSUE') {
        DocumentReference headRef = _firestore.collection('equipment_heads').doc(headId);
        batch.update(headRef, {
          'issuedQty': FieldValue.increment(-quantityAffected),
        });
      }

      await batch.commit();

    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // _recalculateHeadQuantities removed as we use atomic increments

  Stream<List<EquipmentStockEntry>> getStockEntries(String headId) {
    return _firestore.collection('equipment_entries')
        .where('headId', isEqualTo: headId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => EquipmentStockEntry.fromMap(doc.data(), doc.id)).toList();
          list.sort((a, b) => b.dateTakenIntoCharge.compareTo(a.dateTakenIntoCharge));
          return list;
        });
  }

  Stream<List<EquipmentHistory>> getHistoryEntries(String headId) {
    return _firestore.collection('equipment_history')
        .where('headId', isEqualTo: headId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => EquipmentHistory.fromMap(doc.data(), doc.id)).toList();
          list.sort((a, b) => b.fromDate.compareTo(a.fromDate));
          return list;
        });
  }

  Future<void> deleteStockEntry(EquipmentStockEntry entry) async {
      final int qty = entry.quantity;
      
      WriteBatch batch = _firestore.batch();
      batch.delete(_firestore.collection('equipment_entries').doc(entry.id));
      
      batch.update(_firestore.collection('equipment_heads').doc(entry.headId), {
        'totalQty': FieldValue.increment(-qty),
        'serviceableQty': FieldValue.increment(-qty),
      });
      
      await batch.commit();
  }

  Future<void> updateEquipmentHead(String id, String name, String category) async {
    await _firestore.collection('equipment_heads').doc(id).update({
      'name': name,
      'category': category,
    });
  }

  Future<void> deleteEquipmentHead(String id) async {
    await _firestore.collection('equipment_heads').doc(id).delete();
  }

  Future<void> updateStockEntry(EquipmentStockEntry oldEntry, EquipmentStockEntry newEntry) async {
      WriteBatch batch = _firestore.batch();
      
      batch.update(_firestore.collection('equipment_entries').doc(newEntry.id), newEntry.toMap());

      int diff = newEntry.quantity - oldEntry.quantity;
      if (diff != 0) {
        batch.update(_firestore.collection('equipment_heads').doc(newEntry.headId), {
          'totalQty': FieldValue.increment(diff),
          'serviceableQty': FieldValue.increment(diff),
        });
      }

      await batch.commit();
  }

  Future<void> updateHistoryEntry(EquipmentHistory oldEntry, EquipmentHistory newEntry) async {
      WriteBatch batch = _firestore.batch();
      
      batch.update(_firestore.collection('equipment_history').doc(newEntry.id), newEntry.toMap());

      DocumentReference headRef = _firestore.collection('equipment_heads').doc(newEntry.headId);
      
      // 1. Revert old entry effects
      if (oldEntry.type == 'STATUS_CHANGE') {
        if (oldEntry.status == 'UNSERVICEABLE') {
          batch.update(headRef, {
            'serviceableQty': FieldValue.increment(oldEntry.quantityAffected),
            'unserviceableQty': FieldValue.increment(-oldEntry.quantityAffected),
          });
        } else if (oldEntry.status == 'SERVICEABLE') {
          batch.update(headRef, {
            'serviceableQty': FieldValue.increment(-oldEntry.quantityAffected),
            'unserviceableQty': FieldValue.increment(oldEntry.quantityAffected),
          });
        }
      }

      // 2. Apply new entry effects
      if (newEntry.type == 'STATUS_CHANGE') {
        if (newEntry.status == 'UNSERVICEABLE') {
          batch.update(headRef, {
            'serviceableQty': FieldValue.increment(-newEntry.quantityAffected),
            'unserviceableQty': FieldValue.increment(newEntry.quantityAffected),
          });
        } else if (newEntry.status == 'SERVICEABLE') {
          batch.update(headRef, {
            'serviceableQty': FieldValue.increment(newEntry.quantityAffected),
            'unserviceableQty': FieldValue.increment(-newEntry.quantityAffected),
          });
        }
      }

      await batch.commit();
  }

  Future<void> deleteHistoryEntry(EquipmentHistory entry) async {
      WriteBatch batch = _firestore.batch();
      batch.delete(_firestore.collection('equipment_history').doc(entry.id));

      if (entry.type == 'STATUS_CHANGE') {
        DocumentReference headRef = _firestore.collection('equipment_heads').doc(entry.headId);
        if (entry.status == 'UNSERVICEABLE') {
          batch.update(headRef, {
            'serviceableQty': FieldValue.increment(entry.quantityAffected),
            'unserviceableQty': FieldValue.increment(-entry.quantityAffected),
          });
        } else if (entry.status == 'SERVICEABLE') {
          batch.update(headRef, {
            'serviceableQty': FieldValue.increment(-entry.quantityAffected),
            'unserviceableQty': FieldValue.increment(entry.quantityAffected),
          });
        }
      }

      await batch.commit();
  }
}
