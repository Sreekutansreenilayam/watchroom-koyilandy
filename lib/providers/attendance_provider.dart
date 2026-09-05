import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';

class AttendanceAction {
  final Map<String, String?> previousStatuses; // Key: cellId (mId_yearMonth_day)
  AttendanceAction(this.previousStatuses);
}

class AttendanceProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final Map<String, MonthlyAttendance> _attendanceMap = {};
  final Map<String, MonthlyAttendance> _prevAttendanceMap = {};
  List<AttendanceLegend> _legends = [];
  bool _isLoading = false;
  String _currentYearMonth = ""; 
  String _prevYearMonth = "";
  AttendanceAction? _lastAction;
  AttendanceAction? _redoAction;

  Map<String, MonthlyAttendance> get attendanceMap => _attendanceMap;
  Map<String, MonthlyAttendance> get prevAttendanceMap => _prevAttendanceMap;
  List<AttendanceLegend> get legends => _legends;
  bool get isLoading => _isLoading;
  String get currentYearMonth => _currentYearMonth;
  String get prevYearMonth => _prevYearMonth;
  bool get canUndo => _lastAction != null;
  bool get canRedo => _redoAction != null;

  AttendanceProvider() {
    _loadLegends();
  }

  Future<void> _loadLegends() async {
    try {
      final snapshot = await _firestore.collection('attendance_legends').get();
      if (snapshot.docs.isEmpty) {
        await _addDefaultLegends();
      } else {
        _legends = snapshot.docs.map((doc) => AttendanceLegend.fromMap(doc.data(), doc.id)).toList();
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading legends: $e");
    }
  }

  Future<void> _addDefaultLegends() async {
    final defaults = [
      AttendanceLegend(id: '', code: 'P', description: 'Present', colorValue: Colors.green.value),
      AttendanceLegend(id: '', code: 'A', description: 'Absent', colorValue: Colors.red.value),
      AttendanceLegend(id: '', code: 'L', description: 'Leave', colorValue: Colors.orange.value),
      AttendanceLegend(id: '', code: 'ND', description: 'Night Duty', colorValue: Colors.purpleAccent.value),
    ];

    for (var legend in defaults) {
      final docRef = await _firestore.collection('attendance_legends').add(legend.toMap());
      _legends.add(AttendanceLegend(
        id: docRef.id,
        code: legend.code,
        description: legend.description,
        colorValue: legend.colorValue,
      ));
    }
  }

  Future<void> addCustomLegend(String code, String description, int colorValue) async {
    try {
      final newLegend = AttendanceLegend(id: '', code: code, description: description, colorValue: colorValue);
      final docRef = await _firestore.collection('attendance_legends').add(newLegend.toMap());
      _legends.add(AttendanceLegend(
        id: docRef.id,
        code: code,
        description: description,
        colorValue: colorValue,
      ));
      notifyListeners();
    } catch (e) {
      debugPrint("Error adding legend: $e");
    }
  }

  Future<void> updateLegend(String id, String code, String description, int colorValue) async {
    if (id.isEmpty) return; 
    try {
      await _firestore.collection('attendance_legends').doc(id).update({
        'code': code,
        'description': description,
        'colorValue': colorValue,
      });
      final index = _legends.indexWhere((l) => l.id == id);
      if (index != -1) {
        _legends[index] = AttendanceLegend(id: id, code: code, description: description, colorValue: colorValue);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error updating legend: $e");
    }
  }

  Future<void> deleteLegend(String id) async {
    if (id.isEmpty) return;
    try {
      await _firestore.collection('attendance_legends').doc(id).delete();
      _legends.removeWhere((l) => l.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint("Error deleting legend: $e");
    }
  }

  Future<void> loadAttendanceForMonth(DateTime date) async {
    _isLoading = true;
    _lastAction = null;
    _redoAction = null;
    Future.microtask(() => notifyListeners());

    _currentYearMonth = "${date.year}-${date.month.toString().padLeft(2, '0')}";
    final prevDate = DateTime(date.year, date.month - 1, 1);
    _prevYearMonth = "${prevDate.year}-${prevDate.month.toString().padLeft(2, '0')}";
    
    try {
      final results = await Future.wait([
        _firestore.collection('attendance').where('yearMonth', isEqualTo: _currentYearMonth).get(),
        _firestore.collection('attendance').where('yearMonth', isEqualTo: _prevYearMonth).get(),
      ]);

      _attendanceMap.clear();
      for (var doc in results[0].docs) {
        final attendance = MonthlyAttendance.fromMap(doc.data(), doc.id);
        _attendanceMap[attendance.manpowerId] = attendance;
      }

      _prevAttendanceMap.clear();
      for (var doc in results[1].docs) {
        final attendance = MonthlyAttendance.fromMap(doc.data(), doc.id);
        _prevAttendanceMap[attendance.manpowerId] = attendance;
      }
    } catch (e) {
      debugPrint("Error loading attendance: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateAttendance(String cellId, String status) async {
    await updateMultipleAttendance({ cellId }, status);
  }

  // selectedCells format: set of "manpowerId_yearMonth_day" strings
  Future<void> updateMultipleAttendance(Set<String> selectedCells, String status) async {
    final WriteBatch batch = _firestore.batch();
    
    Map<String, String?> previousStatuses = {};
    Map<String, List<int>> currentUpdatesByMId = {};
    Map<String, List<int>> prevUpdatesByMId = {};
    
    for (String cell in selectedCells) {
      final parts = cell.split('_');
      if (parts.length >= 3) {
        final mId = parts[0];
        final ym = parts[1];
        final day = int.tryParse(parts[2]);
        
        if (day != null) {
          if (ym == _currentYearMonth) {
            currentUpdatesByMId.putIfAbsent(mId, () => []).add(day);
            previousStatuses[cell] = _attendanceMap[mId]?.dailyStatus[day];
          } else if (ym == _prevYearMonth) {
            prevUpdatesByMId.putIfAbsent(mId, () => []).add(day);
            previousStatuses[cell] = _prevAttendanceMap[mId]?.dailyStatus[day];
          }
        }
      }
    }
    
    _lastAction = AttendanceAction(previousStatuses);
    _redoAction = null;

    _applyBatchUpdates(batch, currentUpdatesByMId, _currentYearMonth, _attendanceMap, status);
    _applyBatchUpdates(batch, prevUpdatesByMId, _prevYearMonth, _prevAttendanceMap, status);

    notifyListeners();

    try {
      await batch.commit();
    } catch (e) {
      debugPrint("Error in batch update: $e");
    }
  }

  void _applyBatchUpdates(WriteBatch batch, Map<String, List<int>> updatesByMId, String ym, Map<String, MonthlyAttendance> map, String status) {
    for (var entry in updatesByMId.entries) {
      final mId = entry.key;
      final days = entry.value;
      final docId = "${mId}_$ym";
      final docRef = _firestore.collection('attendance').doc(docId);

      if (map.containsKey(mId)) {
        final current = map[mId]!;
        final updatedDailyStatus = Map<int, String>.from(current.dailyStatus);
        Map<String, dynamic> firestoreUpdates = {};
        
        for (int day in days) {
          if (status.isEmpty) {
            updatedDailyStatus.remove(day);
            firestoreUpdates['dailyStatus.${day.toString()}'] = FieldValue.delete();
          } else {
            updatedDailyStatus[day] = status;
            firestoreUpdates['dailyStatus.${day.toString()}'] = status;
          }
        }
        
        map[mId] = current.copyWith(dailyStatus: updatedDailyStatus);
        if (firestoreUpdates.isNotEmpty) batch.update(docRef, firestoreUpdates);
      } else {
        if (status.isNotEmpty) {
          Map<int, String> newDailyStatus = { for (var d in days) d: status };
          final newAttendance = MonthlyAttendance(id: docId, manpowerId: mId, yearMonth: ym, dailyStatus: newDailyStatus);
          map[mId] = newAttendance;
          batch.set(docRef, newAttendance.toMap());
        }
      }
    }
  }

  Future<void> undoLastAction() async {
    if (_lastAction == null) return;
    
    final previousStatuses = _lastAction!.previousStatuses;
    Map<String, String?> currentStatusesForRedo = {};
    
    for (var cellId in previousStatuses.keys) {
      final parts = cellId.split('_');
      final mId = parts[0];
      final ym = parts[1];
      final day = int.parse(parts[2]);
      if (ym == _currentYearMonth) {
        currentStatusesForRedo[cellId] = _attendanceMap[mId]?.dailyStatus[day];
      } else if (ym == _prevYearMonth) {
        currentStatusesForRedo[cellId] = _prevAttendanceMap[mId]?.dailyStatus[day];
      }
    }
    
    _redoAction = AttendanceAction(currentStatusesForRedo);
    _lastAction = null; 
    
    await _applyRevertAction(previousStatuses);
  }

  Future<void> redoLastAction() async {
    if (_redoAction == null) return;
    
    final previousStatuses = _redoAction!.previousStatuses;
    Map<String, String?> currentStatusesForUndo = {};
    
    for (var cellId in previousStatuses.keys) {
      final parts = cellId.split('_');
      final mId = parts[0];
      final ym = parts[1];
      final day = int.parse(parts[2]);
      if (ym == _currentYearMonth) {
        currentStatusesForUndo[cellId] = _attendanceMap[mId]?.dailyStatus[day];
      } else if (ym == _prevYearMonth) {
        currentStatusesForUndo[cellId] = _prevAttendanceMap[mId]?.dailyStatus[day];
      }
    }
    
    _lastAction = AttendanceAction(currentStatusesForUndo);
    _redoAction = null; 
    
    await _applyRevertAction(previousStatuses);
  }

  Future<void> _applyRevertAction(Map<String, String?> statusesToApply) async {
    final WriteBatch batch = _firestore.batch();
    
    Map<String, Map<int, String?>> currentUpdatesByMId = {};
    Map<String, Map<int, String?>> prevUpdatesByMId = {};
    
    for (var entry in statusesToApply.entries) {
      final parts = entry.key.split('_');
      final mId = parts[0];
      final ym = parts[1];
      final day = int.parse(parts[2]);
      final status = entry.value;
      
      if (ym == _currentYearMonth) {
        currentUpdatesByMId.putIfAbsent(mId, () => {})[day] = status;
      } else if (ym == _prevYearMonth) {
        prevUpdatesByMId.putIfAbsent(mId, () => {})[day] = status;
      }
    }
    
    _applyRevertBatch(batch, currentUpdatesByMId, _currentYearMonth, _attendanceMap);
    _applyRevertBatch(batch, prevUpdatesByMId, _prevYearMonth, _prevAttendanceMap);
    
    notifyListeners();
    try {
      await batch.commit();
    } catch (e) {
      debugPrint("Error in revert batch: $e");
    }
  }

  void _applyRevertBatch(WriteBatch batch, Map<String, Map<int, String?>> updatesByMId, String ym, Map<String, MonthlyAttendance> map) {
    for (var entry in updatesByMId.entries) {
      final mId = entry.key;
      final daysMap = entry.value;
      final docId = "${mId}_$ym";
      final docRef = _firestore.collection('attendance').doc(docId);
      
      if (map.containsKey(mId)) {
        final current = map[mId]!;
        final updatedDailyStatus = Map<int, String>.from(current.dailyStatus);
        Map<String, dynamic> firestoreUpdates = {};
        
        for (var dayEntry in daysMap.entries) {
          final day = dayEntry.key;
          final status = dayEntry.value;
          
          if (status == null || status.isEmpty) {
            updatedDailyStatus.remove(day);
            firestoreUpdates['dailyStatus.${day.toString()}'] = FieldValue.delete();
          } else {
            updatedDailyStatus[day] = status;
            firestoreUpdates['dailyStatus.${day.toString()}'] = status;
          }
        }
        map[mId] = current.copyWith(dailyStatus: updatedDailyStatus);
        if (firestoreUpdates.isNotEmpty) batch.update(docRef, firestoreUpdates);
      }
    }
  }
}

