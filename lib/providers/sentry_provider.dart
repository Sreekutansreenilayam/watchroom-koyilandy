import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sentry_register_model.dart';

class SentryProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<SentryRegisterModel> _registers = [];
  bool _isLoading = false;

  List<SentryRegisterModel> get registers => _registers;
  bool get isLoading => _isLoading;

  List<SentryExemption> _globalExemptions = [];
  List<SentryExemption> get globalExemptions => _globalExemptions;

  Future<void> fetchSentryRegisters() async {
    _isLoading = true;
    notifyListeners();
    try {
      final snapshot = await _firestore
          .collection('sentry_registers')
          .orderBy('date', descending: true)
          .get();
      var rawRegisters = snapshot.docs.map((doc) => SentryRegisterModel.fromMap(doc.id, doc.data())).toList();
      
      Map<String, SentryRegisterModel> uniqueRegs = {};
      for (var reg in rawRegisters) {
        String dateKey = "${reg.date.year}-${reg.date.month}-${reg.date.day}";
        if (!uniqueRegs.containsKey(dateKey)) {
          uniqueRegs[dateKey] = reg;
        } else {
          // If multiple exist for the same day, keep the one with larger ID (more recent)
          if (reg.id.compareTo(uniqueRegs[dateKey]!.id) > 0) {
            uniqueRegs[dateKey] = reg;
          }
        }
      }
      _registers = uniqueRegs.values.toList()..sort((a, b) => b.date.compareTo(a.date));
      
      final exemptionsDoc = await _firestore.collection('sentry_settings').doc('exemptions').get();
      if (exemptionsDoc.exists) {
         var exData = exemptionsDoc.data()?['list'] as List? ?? [];
         _globalExemptions = exData.map((e) => SentryExemption.fromMap(e as Map<String, dynamic>)).toList();
      } else {
         _globalExemptions = [];
      }
    } catch (e) {
      debugPrint("Error fetching sentry data: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveGlobalExemptions(List<SentryExemption> exemptions) async {
    try {
      await _firestore.collection('sentry_settings').doc('exemptions').set({
         'list': exemptions.map((e) => e.toMap()).toList(),
      }, SetOptions(merge: true));
      _globalExemptions = exemptions;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error saving global exemptions: $e");
      return false;
    }
  }

  Future<bool> saveSentryRegister(SentryRegisterModel register) async {
    try {
      if (register.id.isEmpty) {
        await _firestore.collection('sentry_registers').add(register.toMap());
      } else {
        await _firestore.collection('sentry_registers').doc(register.id).set(register.toMap(), SetOptions(merge: true));
      }
      await fetchSentryRegisters();
      return true;
    } catch (e) {
      debugPrint("Error saving sentry register: $e");
      return false;
    }
  }
}
