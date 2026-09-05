import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/incident_model.dart';

class IncidentProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<IncidentModel> _incidents = [];
  bool _isLoading = true;

  List<IncidentModel> get incidents => _incidents;
  
  List<IncidentModel> get activeIncidents =>
      _incidents.where((i) => i.status == 'Active').toList();

  bool get isLoading => _isLoading;

  IncidentProvider() {
    _listenToIncidents();
  }

  void _listenToIncidents() {
    _firestore
        .collection('incidents')
        .orderBy('reportedTime', descending: true)
        .snapshots()
        .listen((snapshot) {
      _incidents = snapshot.docs.map((doc) {
        return IncidentModel.fromMap(doc.data(), doc.id);
      }).toList();
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addIncident(IncidentModel incident) async {
    try {
      final mapData = incident.toMap();
      await _firestore.collection('incidents').add(mapData);
    } catch (e) {
      debugPrint("Error adding incident: $e");
    }
  }

  Future<void> resolveIncident(String id) async {
    try {
      await _firestore.collection('incidents').doc(id).update({
        'status': 'Resolved',
        'resolvedTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error resolving incident: $e");
    }
  }

  Future<void> updateSfroLocation(String id, double lat, double lng) async {
    try {
      await _firestore.collection('incidents').doc(id).update({
        'sfroLatitude': lat,
        'sfroLongitude': lng,
      });
    } catch (e) {
      debugPrint("Error updating SFRO location: $e");
    }
  }
}
