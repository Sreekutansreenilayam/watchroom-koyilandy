import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/manpower_model.dart';
import '../config/app_config.dart';

class ManpowerProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Manpower> _personnelList = [];
  bool _isLoading = true;

  List<Manpower> get personnelList => _personnelList;
  List<Manpower> get activePersonnelList => getActivePersonnelForDate(DateTime.now());

  List<Manpower> get pastPersonnelList {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _personnelList.where((m) {
      if (m.exitDate != null) {
        final exitDate = DateTime(m.exitDate!.year, m.exitDate!.month, m.exitDate!.day);
        return !today.isBefore(exitDate);
      }
      return !m.isActive; // Fallback for permanently deleted/inactive without exit date
    }).toList();
  }

  List<Manpower> getActivePersonnelForDate(DateTime targetDate) {
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    
    return _personnelList.where((m) {
      if (m.stationIn != null) {
        final stIn = DateTime(m.stationIn!.year, m.stationIn!.month, m.stationIn!.day);
        if (target.isBefore(stIn)) {
          return false;
        }
      }
      if (m.exitDate != null) {
        final exitDate = DateTime(m.exitDate!.year, m.exitDate!.month, m.exitDate!.day);
        // If target date is strictly after exit date, they are inactive on that date
        // (They are still active ON their exit date)
        if (target.isAfter(exitDate)) {
           return false;
        }
      } else if (!m.isActive) {
        // If they are explicitly inactive and have no exit date (e.g., legacy data)
        return false;
      }
      return true; // Active on this date
    }).toList();
  }
  bool get isLoading => _isLoading;

  ManpowerProvider() {
    _listenToData();
  }

  int _extractNumber(String idStr) {
    final match = RegExp(r'\d+').firstMatch(idStr);
    if (match != null) {
      return int.tryParse(match.group(0) ?? '') ?? -1;
    }
    return -1;
  }

  void _listenToData() {
    _firestore.collection('manpower').snapshots().listen((snapshot) {
      _personnelList = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Ensure document ID is used as the model ID
        
        // Auto-migrate legacy designations
        bool changed = false;
        if (data['designation'] == 'Gr STO' || data['designation'] == 'Gr ASTO') {
          data['designation'] = 'SFRO';
          changed = true;
        } else if (data['designation'] == 'Gr STO (M)' || data['designation'] == 'Gr ASTO (M)') {
          data['designation'] = 'SFRO (M)';
          changed = true;
        }
        
        if (changed) {
          _firestore.collection('manpower').doc(doc.id).update({'designation': data['designation']});
        }
        
        return Manpower.fromMap(data);
      }).toList();

      final rankOrder = {
        'STO': 1,
        'ASTO': 2,
        'SFRO': 3,
        'SFRO (M)': 4,
        'FRO (D)': 5,
        'SFRO (D)': 5,
        'FRO': 6,
        'KHG': 7,
        'Trainees': 8,
      };

      _personnelList.sort((a, b) {
        // Inactive personnel should go to the bottom of the main list if viewed together
        if (a.isActive != b.isActive) {
          return a.isActive ? -1 : 1;
        }

        final rankA = rankOrder[a.designation] ?? 99;
        final rankB = rankOrder[b.designation] ?? 99;
        
        if (rankA != rankB) {
          return rankA.compareTo(rankB);
        }

        bool isTrainee = a.designation.toLowerCase() == 'trainees' && b.designation.toLowerCase() == 'trainees';

        if (!isTrainee) {
          bool aIsHome = a.currentStation.trim().toLowerCase() == AppConfig.stationNameShort.toLowerCase() || a.currentStation.isEmpty;
          bool bIsHome = b.currentStation.trim().toLowerCase() == AppConfig.stationNameShort.toLowerCase() || b.currentStation.isEmpty;
          
          if (aIsHome && !bIsHome) return -1;
          if (!aIsHome && bIsHome) return 1;
          
          if (!aIsHome && !bIsHome && a.currentStation != b.currentStation) {
            return a.currentStation.compareTo(b.currentStation);
          }

          if (a.gender != b.gender) {
            return a.gender == 'Male' ? -1 : 1;
          }
        }

        if (a.sortOrder != b.sortOrder) {
          return a.sortOrder.compareTo(b.sortOrder);
        }
        
        // Inside same rank and gender, sort by extracted ID number
        int getSeniorityWeight(String id) {
          final match = RegExp(r'\d+').firstMatch(id);
          if (match == null) return 999999;
          String digits = match.group(0)!;
          int num = int.parse(digits);
          
          if (num < 100) return num + 200000; // 1 or 2 digit
          if (num < 1000) return num + 100000; // 3 digit
          if (digits.startsWith('1')) return num + 50000; // starts with 1
          
          return num;
        }
        
        int weightA = getSeniorityWeight(a.idNumber);
        int weightB = getSeniorityWeight(b.idNumber);
        
        if (weightA != weightB) {
          return weightA.compareTo(weightB);
        }
        
        // Fallback
        return a.idNumber.compareTo(b.idNumber);
      });

      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addManpower(Manpower manpower) async {
    try {
      final mapData = manpower.toMap();
      mapData.remove('id'); // Firestore auto-generates ID
      await _firestore.collection('manpower').add(mapData);
    } catch (e) {
      debugPrint("Error adding manpower: $e");
    }
  }

  Future<void> updateManpower(Manpower manpower) async {
    try {
      final mapData = manpower.toMap();
      mapData.remove('id'); // We don't need to save the ID inside the document fields unnecessarily
      await _firestore.collection('manpower').doc(manpower.id).update(mapData);
    } catch (e) {
      debugPrint("Error updating manpower: $e");
    }
  }

  Future<void> deleteManpower(String id) async {
    try {
      await _firestore.collection('manpower').doc(id).delete();
    } catch (e) {
      debugPrint("Error deleting manpower: $e");
    }
  }

  Future<void> archiveManpower(String id, String reason, DateTime exitDate) async {
    try {
      await _firestore.collection('manpower').doc(id).update({
        'isActive': false,
        'exitReason': reason,
        'exitDate': exitDate.toIso8601String(),
      });
    } catch (e) {
      debugPrint("Error archiving manpower: $e");
    }
  }

  Future<void> restoreManpower(String id) async {
    try {
      await _firestore.collection('manpower').doc(id).update({
        'isActive': true,
        'exitReason': FieldValue.delete(),
        'exitDate': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint("Error restoring manpower: $e");
    }
  }

  Future<void> reorderManpower(List<Manpower> subList, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final item = subList.removeAt(oldIndex);
    subList.insert(newIndex, item);
    
    WriteBatch batch = _firestore.batch();
    for (int i = 0; i < subList.length; i++) {
      final docRef = _firestore.collection('manpower').doc(subList[i].id);
      batch.update(docRef, {'sortOrder': i});
    }
    
    try {
      await batch.commit();
    } catch (e) {
      debugPrint("Error reordering manpower: $e");
    }
  }
}
