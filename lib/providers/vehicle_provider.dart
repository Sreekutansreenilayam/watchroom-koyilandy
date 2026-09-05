import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehicle_model.dart';
import '../models/logbook_model.dart';

class VehicleProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<VehicleModel> _vehicles = [];
  bool _isLoading = true;

  List<VehicleModel> get vehicles => _vehicles;
  bool get isLoading => _isLoading;

  VehicleProvider() {
    _listenToData();
  }

  void _listenToData() {
    _firestore.collection('vehicles').snapshots().listen((snapshot) {
      _vehicles = snapshot.docs.map((doc) {
        return VehicleModel.fromMap(doc.data(), doc.id);
      }).toList();
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> updateVehicleStatus(String id, String status) async {
    try {
      await _firestore.collection('vehicles').doc(id).update({'status': status});
    } catch (e) {
      debugPrint("Error updating vehicle status: $e");
    }
  }

  Future<void> addVehicle(VehicleModel vehicle) async {
    try {
      final mapData = vehicle.toMap();
      await _firestore.collection('vehicles').add(mapData);
    } catch (e) {
      debugPrint("Error adding vehicle: $e");
    }
  }

  Future<void> updateVehicle(VehicleModel vehicle) async {
    try {
      final mapData = vehicle.toMap();
      await _firestore.collection('vehicles').doc(vehicle.id).update(mapData);
    } catch (e) {
      debugPrint("Error updating vehicle: $e");
    }
  }

  Future<void> updateVehicleOdometerAndFuel({
    required String vehicleId,
    required double currentOdometer,
    required double currentFuelInTank,
    double? fuelConsumed,
  }) async {
    try {
      Map<String, dynamic> updates = {
        'currentOdometer': currentOdometer,
        'currentFuelInTank': currentFuelInTank,
      };
      if (fuelConsumed != null && fuelConsumed != 0) {
        updates['fuelConsumedThisFY'] = FieldValue.increment(fuelConsumed);
      }
      await _firestore.collection('vehicles').doc(vehicleId).update(updates);
    } catch (e) {
      debugPrint("Error updating vehicle odometer and fuel: $e");
    }
  }

  Future<void> revertVehicleMasterOnEntryDelete({
    required String vehicleId,
    required LogbookEntry entryToDelete,
    required List<LogbookEntry> remainingEntries,
  }) async {
    try {
      final otherEntries = remainingEntries.where((e) => e.id != entryToDelete.id).toList();
      otherEntries.sort((a, b) => a.date.compareTo(b.date));

      double newOdometer;
      double newFuelInTank;
      double fuelConsumedToSubtract = entryToDelete.fuelConsumedForJourney + entryToDelete.fuelConsumedForPump;

      if (otherEntries.isNotEmpty) {
        final lastRemaining = otherEntries.last;
        newOdometer = lastRemaining.previousKms + lastRemaining.travelledDistance + lastRemaining.pumpKm;
        newFuelInTank = lastRemaining.remainingFuelInTank;
      } else {
        newOdometer = entryToDelete.previousKms;
        newFuelInTank = entryToDelete.remainingFuelInTank + fuelConsumedToSubtract - entryToDelete.suppliedFuel;
        if (newFuelInTank < 0) newFuelInTank = 0;
      }

      Map<String, dynamic> updates = {
        'currentOdometer': newOdometer,
        'currentFuelInTank': newFuelInTank,
      };

      if (fuelConsumedToSubtract > 0) {
        updates['fuelConsumedThisFY'] = FieldValue.increment(-fuelConsumedToSubtract);
      }

      await _firestore.collection('vehicles').doc(vehicleId).update(updates);
    } catch (e) {
      debugPrint("Error reverting vehicle master on entry delete: $e");
    }
  }

  Future<void> deleteVehicle(String id) async {
    try {
      await _firestore.collection('vehicles').doc(id).delete();
    } catch (e) {
      debugPrint("Error deleting vehicle: $e");
    }
  }
}
