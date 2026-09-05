import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/incident_report_model.dart';

class IncidentReportProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<IncidentReportModel> _reports = [];
  bool _isLoading = false;

  List<IncidentReportModel> get reports => _reports;
  bool get isLoading => _isLoading;

  IncidentReportProvider() {
    fetchReports();
  }

  Future<void> fetchReports() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore.collection('incident_reports').get();
      debugPrint("Fetched \${snapshot.docs.length} documents from incident_reports");
      _reports = snapshot.docs.map((doc) => IncidentReportModel.fromMap(doc.data(), doc.id)).toList();
      _reports.sort((a, b) => b.date.compareTo(a.date));
      debugPrint("Successfully parsed \${_reports.length} reports");
    } catch (e, stackTrace) {
      debugPrint("Error fetching incident reports: $e\n$stackTrace");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addReport(IncidentReportModel report) async {
    try {
      final mapData = report.toMap();
      mapData.remove('id');
      final docRef = await _firestore.collection('incident_reports').add(mapData);
      
      final newReport = IncidentReportModel.fromMap(mapData, docRef.id);
      _reports.insert(0, newReport);
      notifyListeners();
    } catch (e) {
      debugPrint("Error adding incident report: $e");
      rethrow;
    }
  }

  Future<void> updateReport(IncidentReportModel report) async {
    try {
      final mapData = report.toMap();
      mapData.remove('id');
      await _firestore.collection('incident_reports').doc(report.id).update(mapData);
      
      final index = _reports.indexWhere((r) => r.id == report.id);
      if (index != -1) {
        _reports[index] = report;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error updating incident report: $e");
      rethrow;
    }
  }

  Future<void> deleteReport(String id) async {
    try {
      await _firestore.collection('incident_reports').doc(id).delete();
      _reports.removeWhere((r) => r.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint("Error deleting incident report: $e");
      rethrow;
    }
  }
}
