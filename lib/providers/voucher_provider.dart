import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/voucher_model.dart';

class VoucherProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<VoucherModel> _vouchers = [];
  bool _isLoading = false;
  String? _error;

  List<VoucherModel> get vouchers => _vouchers;
  List<VoucherModel> get tempVouchers => _vouchers.where((v) => v.type == 'Temporary').toList();
  List<VoucherModel> get permanentVouchers => _vouchers.where((v) => v.type == 'Permanent').toList();
  
  bool get isLoading => _isLoading;
  String? get error => _error;

  VoucherProvider() {
    _init();
  }

  Future<String> generateIvNo(String category, String type) async {
    int maxSeq = 0;
    final regex = RegExp(r'-(\d{4})/');
    
    for (var v in _vouchers) {
      if (v.ivNo.isNotEmpty) {
        final match = regex.firstMatch(v.ivNo);
        if (match != null) {
          final seqStr = match.group(1);
          if (seqStr != null) {
            final seq = int.tryParse(seqStr) ?? 0;
            if (seq > maxSeq) {
              maxSeq = seq;
            }
          }
        }
      }
    }
    
    final nextSeq = (maxSeq + 1).toString().padLeft(4, '0');
    
    String catStr = 'MISC';
    if (category == 'Vehicle') catStr = 'VEH';
    if (category == 'Equipment') catStr = 'EQPT';
    
    String typeStr = type == 'Temporary' ? 'T' : 'P';
    
    return 'IV/FRS/MDA/$catStr-$nextSeq/$typeStr';
  }

  void _init() {
    _firestore.collection('vouchers').orderBy('createdAt', descending: true).snapshots().listen((snapshot) {
      _vouchers = snapshot.docs.map((doc) => VoucherModel.fromMap(doc.data(), doc.id)).toList();
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      notifyListeners();
    });
  }

  Future<void> addVoucher(VoucherModel voucher) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final mapData = voucher.toMap();
      await _firestore.collection('vouchers').add(mapData);
    } catch (e) {
      _error = e.toString();
      debugPrint("Error adding voucher: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateVoucher(VoucherModel voucher) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final mapData = voucher.toMap();
      mapData['updatedAt'] = FieldValue.serverTimestamp();
      
      await _firestore.collection('vouchers').doc(voucher.id).update(mapData);
    } catch (e) {
      _error = e.toString();
      debugPrint("Error updating voucher: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteVoucher(String id) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _firestore.collection('vouchers').doc(id).delete();
    } catch (e) {
      _error = e.toString();
      debugPrint("Error deleting voucher: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
