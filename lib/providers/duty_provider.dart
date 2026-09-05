import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/duty_model.dart';
import '../models/duty_register_model.dart';

class DutyProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<DutyRoster> _rosters = [];
  bool _isLoading = false;

  List<DutyRoster> get rosters => _rosters;
  bool get isLoading => _isLoading;

  // Fetch all rosters, sorted by date descending
  Future<void> fetchRosters() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('duty_roster')
          .orderBy('date', descending: true)
          .get();
      
      _rosters = snapshot.docs.map((doc) => DutyRoster.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint("Error fetching rosters: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add a new roster
  Future<bool> addRoster(DateTime date, String shift, List<String> personnel) async {
    try {
      final newRoster = DutyRoster(
        id: '',
        date: date,
        shift: shift,
        personnelNames: personnel,
      );
      
      await _firestore.collection('duty_roster').add(newRoster.toMap());
      await fetchRosters(); // Refresh list
      return true;
    } catch (e) {
      debugPrint("Error adding roster: $e");
      return false;
    }
  }

  // -----------------------------------------------------
  // NEW DUTY REGISTER (Daily PDF Report Model)
  // -----------------------------------------------------
  List<DutyRegisterModel> _registers = [];
  List<DutyRegisterModel> get registers => _registers;

  Future<void> fetchDutyRegisters() async {
    _isLoading = true;
    notifyListeners();
    try {
      final snapshot = await _firestore
          .collection('duty_registers')
          .orderBy('date', descending: true)
          .get();
      _registers = snapshot.docs.map((doc) => DutyRegisterModel.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      debugPrint("Error fetching duty registers: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveDutyRegister(DutyRegisterModel register) async {
    try {
      // Find start and end of the day to check for existing records for the same date
      DateTime startOfDay = DateTime(register.date.year, register.date.month, register.date.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      final existingSnapshot = await _firestore
          .collection('duty_registers')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      if (existingSnapshot.docs.isNotEmpty) {
        // A register for this date already exists.
        String existingId = existingSnapshot.docs.first.id;
        
        // Delete any extra duplicates that might exist from previous bugs
        for (int i = 1; i < existingSnapshot.docs.length; i++) {
           await _firestore.collection('duty_registers').doc(existingSnapshot.docs[i].id).delete();
        }

        // Update the existing document with the new data
        await _firestore.collection('duty_registers').doc(existingId).update(register.toMap());
      } else {
        // No existing register for this day, create/update normally
        if (register.id.isEmpty) {
          await _firestore.collection('duty_registers').add(register.toMap());
        } else {
          await _firestore.collection('duty_registers').doc(register.id).update(register.toMap());
        }
      }
      
      await fetchDutyRegisters();
      return true;
    } catch (e) {
      debugPrint("Error saving duty register: $e");
      return false;
    }
  }

  // Delete a roster
  Future<void> deleteRoster(String id) async {
    try {
      await _firestore.collection('duty_roster').doc(id).delete();
      await fetchRosters();
    } catch (e) {
      debugPrint("Error deleting roster: $e");
    }
  }
}
