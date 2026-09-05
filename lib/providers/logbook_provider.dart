import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/logbook_model.dart';
import '../services/access_control.dart';

class LogbookProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<LogbookEntry> _entries = [];
  bool _isLoading = false;
  String _errorMessage = '';
  StreamSubscription<QuerySnapshot>? _subscription;

  List<LogbookEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // Real-time listener for logbook entries of a vehicle
  void listenToEntries(String vehicleId, DateTime monthYear) {
    _subscription?.cancel();
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    final startOfMonth = DateTime(monthYear.year, monthYear.month, 1);
    final endOfMonth = DateTime(monthYear.year, monthYear.month + 1, 0, 23, 59, 59);

    _subscription = _firestore
        .collection('logbooks')
        .where('vehicleId', isEqualTo: vehicleId)
        .snapshots()
        .listen(
      (snapshot) {
        final allVehicleEntries = snapshot.docs.map((doc) => LogbookEntry.fromFirestore(doc)).toList();
        
        _entries = allVehicleEntries.where((e) {
          return e.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
                 e.date.isBefore(endOfMonth.add(const Duration(seconds: 1)));
        }).toList();

        _entries.sort((a, b) {
          DateTime aDateOnly = DateTime(a.date.year, a.date.month, a.date.day);
          DateTime bDateOnly = DateTime(b.date.year, b.date.month, b.date.day);
          int dateCmp = aDateOnly.compareTo(bDateOnly);
          if (dateCmp != 0) return dateCmp;

          bool aIsTake = a.actionType == 'Taking on Charge' || a.actionType == 'Emergency Taking on Charge';
          bool bIsTake = b.actionType == 'Taking on Charge' || b.actionType == 'Emergency Taking on Charge';
          if (aIsTake && !bIsTake) return -1;
          if (!aIsTake && bIsTake) return 1;

          String aTime = a.departureTime.isNotEmpty ? a.departureTime : (a.pumpStartTime.isNotEmpty ? a.pumpStartTime : '23:59');
          String bTime = b.departureTime.isNotEmpty ? b.departureTime : (b.pumpStartTime.isNotEmpty ? b.pumpStartTime : '23:59');
          int aMins = AccessControl.timeToDutyMinutes(aTime);
          int bMins = AccessControl.timeToDutyMinutes(bTime);
          int timeCmp = aMins.compareTo(bMins);
          if (timeCmp != 0) return timeCmp;
          
          if (a.actionType == 'Fuel Receipt' && b.actionType == 'Fuel Receipt') {
            int getSerial(String r) {
              try {
                final parts = r.split('/');
                if (parts.isNotEmpty) {
                  return int.tryParse(parts.last.trim()) ?? 0;
                }
              } catch (_) {}
              return 0;
            }
            return getSerial(a.remarks).compareTo(getSerial(b.remarks));
          }
          
          return 0;
        });
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = 'Failed to fetch logbook entries: $e';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> fetchEntries(String vehicleId, DateTime monthYear) async {
    listenToEntries(vehicleId, monthYear);
  }

  // Add a new entry
  Future<bool> addEntry(LogbookEntry entry) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _firestore.collection('logbooks').add(entry.toMap());
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add logbook entry: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update an existing entry
  Future<bool> updateEntry(LogbookEntry entry) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _firestore.collection('logbooks').doc(entry.id).update(entry.toMap());
      await cascadeUpdates(entry.vehicleId); // Recalculate
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update logbook entry: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete an entry
  Future<bool> deleteEntry(String entryId, String vehicleId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _firestore.collection('logbooks').doc(entryId).delete();
      await cascadeUpdates(vehicleId); // Recalculate
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete logbook entry: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  Future<void> cascadeUpdates(String vehicleId) async {
    try {
      final snapshot = await _firestore.collection('logbooks')
          .where('vehicleId', isEqualTo: vehicleId)
          .get();
          
      final allEntries = snapshot.docs.map((doc) => LogbookEntry.fromFirestore(doc)).toList();
      if (allEntries.isEmpty) return;

      allEntries.sort((a, b) {
        DateTime aDateOnly = DateTime(a.date.year, a.date.month, a.date.day);
        DateTime bDateOnly = DateTime(b.date.year, b.date.month, b.date.day);
        int dateCmp = aDateOnly.compareTo(bDateOnly);
        if (dateCmp != 0) return dateCmp;

        bool aIsTake = a.actionType == 'Taking on Charge' || a.actionType == 'Emergency Taking on Charge';
        bool bIsTake = b.actionType == 'Taking on Charge' || b.actionType == 'Emergency Taking on Charge';
        if (aIsTake && !bIsTake) return -1;
        if (!aIsTake && bIsTake) return 1;

        String aTime = a.departureTime.isNotEmpty ? a.departureTime : (a.pumpStartTime.isNotEmpty ? a.pumpStartTime : '23:59');
        String bTime = b.departureTime.isNotEmpty ? b.departureTime : (b.pumpStartTime.isNotEmpty ? b.pumpStartTime : '23:59');
        int aMins = AccessControl.timeToDutyMinutes(aTime);
        int bMins = AccessControl.timeToDutyMinutes(bTime);
        int timeCmp = aMins.compareTo(bMins);
        if (timeCmp != 0) return timeCmp;

        if (a.actionType == 'Fuel Receipt' && b.actionType == 'Fuel Receipt') {
          int getSerial(String r) {
            try {
              final parts = r.split('/');
              if (parts.isNotEmpty) {
                return int.tryParse(parts.last.trim()) ?? 0;
              }
            } catch (_) {}
            return 0;
          }
          return getSerial(a.remarks).compareTo(getSerial(b.remarks));
        }

        return 0;
      });

      double runningKm = allEntries.first.previousKms;
      double runningFuel = allEntries.first.remainingFuelInTank;
      
      double fuelConsumedThisFY = 0;
      final now = DateTime.now();
      int startYear = now.month >= 4 ? now.year : now.year - 1;
      DateTime fyStart = DateTime(startYear, 4, 1);
      DateTime fyEnd = DateTime(startYear + 1, 3, 31, 23, 59, 59);

      final batch = _firestore.batch();
      int updateCount = 0;

      for (var entry in allEntries) {
        bool needsUpdate = false;
        Map<String, dynamic> updates = {};

        if ((entry.previousKms - runningKm).abs() > 0.01) {
          updates['previousKms'] = runningKm;
          needsUpdate = true;
        }
        if ((entry.remainingFuelInTank - runningFuel).abs() > 0.01) {
          updates['remainingFuelInTank'] = runningFuel;
          needsUpdate = true;
        }

        if (needsUpdate) {
          batch.update(_firestore.collection('logbooks').doc(entry.id), updates);
          updateCount++;
        }

        runningKm += entry.travelledDistance + entry.pumpKm;
        runningFuel += entry.suppliedFuel - entry.fuelConsumedForJourney - entry.fuelConsumedForPump;
        if (runningFuel < 0) runningFuel = 0;
        
        if (entry.date.isAfter(fyStart.subtract(const Duration(seconds: 1))) && 
            entry.date.isBefore(fyEnd.add(const Duration(seconds: 1)))) {
          fuelConsumedThisFY += entry.fuelConsumedForJourney + entry.fuelConsumedForPump;
        }
      }

      if (updateCount > 0) {
        await batch.commit();
      }

      await _firestore.collection('vehicles').doc(vehicleId).update({
        'currentOdometer': runningKm,
        'currentFuelInTank': runningFuel,
        'fuelConsumedThisFY': fuelConsumedThisFY,
      });

    } catch (e) {
      debugPrint("Error in cascadeUpdates: $e");
    }
  }
}
