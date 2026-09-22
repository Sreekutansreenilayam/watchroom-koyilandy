import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fuel_model.dart';
import '../models/vehicle_model.dart';
import '../models/logbook_model.dart';

class FuelProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<FuelLedger> _ledgers = [];
  bool _isLoading = false;
  String? _error;

  List<FuelLedger> get ledgers => _ledgers;
  List<FuelLedger> get fuelLedgers => _ledgers.where((l) => l.type == 'Fuel').toList();
  List<FuelLedger> get oilLedgers => _ledgers.where((l) => l.type == 'Oil').toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  FuelProvider() {
    _init();
  }

  void _init() {
    _firestore.collection('fuel_ledgers').orderBy('ledgerNumber').snapshots().listen((snapshot) {
      _ledgers = snapshot.docs.map((doc) => FuelLedger.fromMap(doc.data(), doc.id)).toList();
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      notifyListeners();
    });
  }

  Future<void> addLedger(String name, String type) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Find the highest ledger number
      int nextLedgerNumber = 1001;
      final snapshot = await _firestore
          .collection('fuel_ledgers')
          .orderBy('ledgerNumber', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final lastLedger = FuelLedger.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
        nextLedgerNumber = lastLedger.ledgerNumber + 1;
      }

      final newLedger = FuelLedger(
        id: '',
        ledgerNumber: nextLedgerNumber,
        name: name,
        type: type,
        currentBalance: 0.0,
        lastSerialNumber: 0,
      );

      await _firestore.collection('fuel_ledgers').add(newLedger.toMap());
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> editLedger(String ledgerId, String newName, String newType) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _firestore.collection('fuel_ledgers').doc(ledgerId).update({
        'name': newName,
        'type': newType,
      });
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteLedger(String ledgerId) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Delete the ledger document
      await _firestore.collection('fuel_ledgers').doc(ledgerId).delete();
      
      // Also delete all transactions associated with this ledger
      final txSnapshot = await _firestore.collection('fuel_transactions').where('ledgerId', isEqualTo: ledgerId).get();
      WriteBatch batch = _firestore.batch();
      for (var doc in txSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetAllFuelData() async {
    try {
      _isLoading = true;
      notifyListeners();

      final txSnapshot = await _firestore.collection('fuel_transactions').get();
      final logbookSnapshot = await _firestore.collection('logbooks').where('actionType', isEqualTo: 'Fuel Receipt').get();
      final ledgerSnapshot = await _firestore.collection('fuel_ledgers').get();

      WriteBatch batch = _firestore.batch();
      int count = 0;

      for (var doc in txSnapshot.docs) {
        batch.delete(doc.reference);
        count++;
        if (count >= 490) {
          await batch.commit();
          batch = _firestore.batch();
          count = 0;
        }
      }

      for (var doc in logbookSnapshot.docs) {
        batch.delete(doc.reference);
        count++;
        if (count >= 490) {
          await batch.commit();
          batch = _firestore.batch();
          count = 0;
        }
      }

      for (var doc in ledgerSnapshot.docs) {
        batch.update(doc.reference, {
          'currentBalance': 0.0,
          'lastSerialNumber': 0,
        });
        count++;
        if (count >= 490) {
          await batch.commit();
          batch = _firestore.batch();
          count = 0;
        }
      }

      if (count > 0) {
        await batch.commit();
      }

    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTransaction({
    required String ledgerId,
    required DateTime date,
    required String party,
    required String type, // 'RECEIPT' or 'ISSUE'
    required double quantity,
    required String remarks,
    String? customVoucherNumber,
    String operatorName = '',
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get latest ledger state
      final latestLedger = _ledgers.firstWhere((l) => l.id == ledgerId);

      // Simulate new balances to check for negative stock
      final txSnapshot = await _firestore.collection('fuel_transactions').where('ledgerId', isEqualTo: ledgerId).get();
      var transactions = txSnapshot.docs.map((doc) => FuelTransaction.fromMap(doc.data(), doc.id)).toList();
      
      transactions.add(FuelTransaction(
        id: 'temp',
        ledgerId: ledgerId,
        date: date,
        party: party,
        type: type,
        quantity: quantity,
        balanceAfter: 0,
        voucherNumber: 'temp',
        remarks: remarks,
        operatorName: operatorName,
      ));

      transactions.sort((a, b) {
        int dateCmp = a.date.compareTo(b.date);
        if (dateCmp != 0) return dateCmp;
        int serialA = a.voucherNumber == 'temp' ? 999999 : (int.tryParse(a.voucherNumber.split('/').last) ?? 0);
        int serialB = b.voucherNumber == 'temp' ? 999999 : (int.tryParse(b.voucherNumber.split('/').last) ?? 0);
        return serialA.compareTo(serialB);
      });

      double simBalance = 0;
      for (var tx in transactions) {
        if (tx.type == 'RECEIPT') {
          simBalance += tx.quantity;
        } else {
          simBalance -= tx.quantity;
        }
        if (simBalance < 0) {
          _error = 'Transaction causes stock to become negative. Please check stock availability.';
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      // Calculate new balance
      double newBalance = latestLedger.currentBalance;
      if (type == 'RECEIPT') {
        newBalance += quantity;
      } else if (type == 'ISSUE') {
        newBalance -= quantity;
      }

      // Generate Voucher Number
      int nextSerial = latestLedger.lastSerialNumber + 1;
      String dateStr = '${date.day.toString().padLeft(2, '0')}${date.month.toString().padLeft(2, '0')}${date.year}';
      String serialStr = nextSerial.toString().padLeft(2, '0');
      String voucherNumber = customVoucherNumber ?? '${latestLedger.ledgerNumber}/$dateStr/$serialStr';

      String? linkedLogbookEntryId;

      // Run as batch to update both transaction and ledger safely
      WriteBatch batch = _firestore.batch();

      if (type == 'ISSUE') {
        final vehicleSnapshot = await _firestore.collection('vehicles').get();
        final vehicles = vehicleSnapshot.docs.map((doc) => VehicleModel.fromMap(doc.data(), doc.id)).toList();
        VehicleModel? matchedVehicle;
        for (var v in vehicles) {
          if ('${v.type} (${v.regNumber})' == party) {
            matchedVehicle = v;
            break;
          }
        }

        if (matchedVehicle != null) {
          final logbookRef = _firestore.collection('logbooks').doc();
          linkedLogbookEntryId = logbookRef.id;
          
          final bool isAdBlue = latestLedger.name.toLowerCase().contains('adblue') || latestLedger.name.toLowerCase().contains('ad blue') || latestLedger.name.toLowerCase().contains('addblue') || latestLedger.name.toLowerCase().contains('add blue');
          final itemName = (latestLedger.type == 'Oil' || isAdBlue) ? latestLedger.name : 'ഇന്ധനം';
          double supFuel = 0;
          double supOil = 0;
          double supGrease = 0;
          double supDWater = 0;
          double supAdBlue = 0;

          String lname = latestLedger.name.toLowerCase();
          if (lname.contains('adblue') || lname.contains('ad blue') || lname.contains('addblue') || lname.contains('add blue')) {
              supAdBlue = quantity;
          } else if (latestLedger.type == 'Fuel') {
              supFuel = quantity;
          } else {
              if (lname.contains('grease') || lname.contains('fluid')) {
                  supGrease = quantity;
              } else if (lname.contains('water')) {
                  supDWater = quantity;
              } else {
                  supOil = quantity;
              }
          }

          final logbookEntry = LogbookEntry(
            id: logbookRef.id,
            vehicleId: matchedVehicle.id,
            date: date,
            previousKms: 0,
            remainingFuelInTank: 0,
            suppliedFuel: supFuel,
            oil: supOil,
            grease: supGrease,
            dWater: supDWater,
            adBlue: supAdBlue,
            departureTime: '',
            fromPlace: '',
            toPlace: '',
            arrivalTime: '',
            travelledDistance: 0,
            pumpStartTime: '',
            pumpEndTime: '',
            pumpDuration: '',
            fuelConsumedForJourney: 0,
            fuelConsumedForPump: 0,
            remarks: 'സ്റ്റോറിൽ നിന്നും ${quantity % 1 == 0 ? quantity.toInt() : quantity.toStringAsFixed(3)} ലിറ്റർ $itemName കൈപ്പറ്റി. വൗച്ചർ നമ്പർ: $voucherNumber',
            vehicleCheckTime: '',
            operatorName: operatorName,
            actionType: 'Fuel Receipt',
          );
          batch.set(logbookRef, logbookEntry.toMap());
        }
      }

      DocumentReference txRef = _firestore.collection('fuel_transactions').doc();

      final transaction = FuelTransaction(
        id: txRef.id,
        ledgerId: ledgerId,
        date: date,
        party: party,
        type: type,
        quantity: quantity,
        balanceAfter: newBalance,
        voucherNumber: voucherNumber,
        remarks: remarks,
        linkedLogbookEntryId: linkedLogbookEntryId,
        operatorName: operatorName,
      );
      
      batch.set(txRef, transaction.toMap());
      
      DocumentReference ledgerRef = _firestore.collection('fuel_ledgers').doc(ledgerId);
      batch.update(ledgerRef, {
        'currentBalance': newBalance,
        'lastSerialNumber': nextSerial,
      });

      await batch.commit();

    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _recalculateLedgerBalances(String ledgerId) async {
    final txSnapshot = await _firestore.collection('fuel_transactions').where('ledgerId', isEqualTo: ledgerId).get();
    var transactions = txSnapshot.docs.map((doc) => FuelTransaction.fromMap(doc.data(), doc.id)).toList();
    
    // Sort chronologically. Oldest first.
    transactions.sort((a, b) {
      int dateCmp = a.date.compareTo(b.date);
      if (dateCmp != 0) return dateCmp;
      int serialA = int.tryParse(a.voucherNumber.split('/').last) ?? 0;
      int serialB = int.tryParse(b.voucherNumber.split('/').last) ?? 0;
      return serialA.compareTo(serialB);
    });

    double runningBalance = 0;
    WriteBatch batch = _firestore.batch();
    
    for (var tx in transactions) {
      if (tx.type == 'RECEIPT') {
        runningBalance += tx.quantity;
      } else {
        runningBalance -= tx.quantity;
      }
      
      if (tx.balanceAfter != runningBalance) {
        batch.update(_firestore.collection('fuel_transactions').doc(tx.id), {'balanceAfter': runningBalance});
      }
    }
    
    batch.update(_firestore.collection('fuel_ledgers').doc(ledgerId), {'currentBalance': runningBalance});
    await batch.commit();
  }

  Future<void> deleteTransaction(FuelTransaction tx) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _firestore.collection('fuel_transactions').doc(tx.id).delete();
      if (tx.linkedLogbookEntryId != null && tx.linkedLogbookEntryId!.isNotEmpty) {
        await _firestore.collection('logbooks').doc(tx.linkedLogbookEntryId).delete();
      }
      await _recalculateLedgerBalances(tx.ledgerId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> editTransaction({
    required FuelTransaction tx,
    required DateTime date,
    required String party,
    required String type,
    required double quantity,
    required String remarks,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Simulate new balances to check for negative stock
      final txSnapshot = await _firestore.collection('fuel_transactions').where('ledgerId', isEqualTo: tx.ledgerId).get();
      var transactions = txSnapshot.docs.map((doc) => FuelTransaction.fromMap(doc.data(), doc.id)).toList();
      
      // Update the transaction in simulation
      int idx = transactions.indexWhere((t) => t.id == tx.id);
      if (idx != -1) {
        transactions[idx] = FuelTransaction(
          id: tx.id,
          ledgerId: tx.ledgerId,
          date: date,
          party: party,
          type: type,
          quantity: quantity,
          balanceAfter: 0,
          voucherNumber: tx.voucherNumber,
          remarks: remarks,
          linkedLogbookEntryId: tx.linkedLogbookEntryId,
        );
      }

      transactions.sort((a, b) {
        int dateCmp = a.date.compareTo(b.date);
        if (dateCmp != 0) return dateCmp;
        int serialA = a.voucherNumber == 'temp' ? 999999 : (int.tryParse(a.voucherNumber.split('/').last) ?? 0);
        int serialB = b.voucherNumber == 'temp' ? 999999 : (int.tryParse(b.voucherNumber.split('/').last) ?? 0);
        return serialA.compareTo(serialB);
      });

      double simBalance = 0;
      for (var t in transactions) {
        if (t.type == 'RECEIPT') {
          simBalance += t.quantity;
        } else {
          simBalance -= t.quantity;
        }
        if (simBalance < 0) {
          _error = 'Transaction causes stock to become negative. Please check stock availability.';
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      await _firestore.collection('fuel_transactions').doc(tx.id).update({
        'date': Timestamp.fromDate(date),
        'party': party,
        'type': type,
        'quantity': quantity,
        'remarks': remarks,
      });
      if (tx.linkedLogbookEntryId != null && tx.linkedLogbookEntryId!.isNotEmpty) {
        final latestLedger = _ledgers.firstWhere((l) => l.id == tx.ledgerId);
        final bool isAdBlue = latestLedger.name.toLowerCase().contains('adblue') || latestLedger.name.toLowerCase().contains('ad blue') || latestLedger.name.toLowerCase().contains('addblue') || latestLedger.name.toLowerCase().contains('add blue');
        final itemName = (latestLedger.type == 'Oil' || isAdBlue) ? latestLedger.name : 'ഇന്ധനം';
        
        double supFuel = 0;
        double supOil = 0;
        double supGrease = 0;
        double supDWater = 0;
        double supAdBlue = 0;

        String lname = latestLedger.name.toLowerCase();
        if (lname.contains('adblue') || lname.contains('ad blue') || lname.contains('addblue') || lname.contains('add blue')) {
            supAdBlue = quantity;
        } else if (latestLedger.type == 'Fuel') {
            supFuel = quantity;
        } else {
            if (lname.contains('grease') || lname.contains('fluid')) {
                supGrease = quantity;
            } else if (lname.contains('water')) {
                supDWater = quantity;
            } else {
                supOil = quantity;
            }
        }

        await _firestore.collection('logbooks').doc(tx.linkedLogbookEntryId).update({
          'date': Timestamp.fromDate(date),
          'suppliedFuel': supFuel,
          'oil': supOil,
          'grease': supGrease,
          'dWater': supDWater,
          'adBlue': supAdBlue,
          'remarks': 'സ്റ്റോറിൽ നിന്നും ${quantity % 1 == 0 ? quantity.toInt() : quantity.toStringAsFixed(3)} ലിറ്റർ $itemName കൈപ്പറ്റി. വൗച്ചർ നമ്പർ: ${tx.voucherNumber}',
        });
      }
      await _recalculateLedgerBalances(tx.ledgerId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<List<FuelTransaction>> getTransactionsForLedger(String ledgerId) {
    return _firestore
        .collection('fuel_transactions')
        .where('ledgerId', isEqualTo: ledgerId)
        .snapshots()
        .map((snapshot) {
            final list = snapshot.docs.map((doc) => FuelTransaction.fromMap(doc.data(), doc.id)).toList();
            // Sort chronologically. Oldest first.
            list.sort((a, b) {
              int dateCmp = a.date.compareTo(b.date);
              if (dateCmp != 0) return dateCmp;
              int serialA = int.tryParse(a.voucherNumber.split('/').last) ?? 0;
              int serialB = int.tryParse(b.voucherNumber.split('/').last) ?? 0;
              return serialA.compareTo(serialB);
            });
            return list;
        });
  }
}
