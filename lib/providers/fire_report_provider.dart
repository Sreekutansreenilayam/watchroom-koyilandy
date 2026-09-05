import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fire_report_model.dart';

class FireReportProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<FireReportModel> _reports = [];
  bool _isLoading = false;

  List<FireReportModel> get reports => _reports;
  bool get isLoading => _isLoading;

  FireReportProvider() {
    fetchReports();
  }

  Future<void> fetchReports() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore.collection('fire_reports').get();
      debugPrint("Fetched \${snapshot.docs.length} documents from fire_reports");
      _reports = snapshot.docs.map((doc) => FireReportModel.fromMap(doc.data(), doc.id)).toList();
      _reports.sort((a, b) => b.date.compareTo(a.date));
      debugPrint("Successfully parsed \${_reports.length} reports");
    } catch (e, stackTrace) {
      debugPrint("Error fetching fire reports: $e\n$stackTrace");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addReport(FireReportModel report) async {
    try {
      final mapData = report.toMap();
      mapData.remove('id');
      final docRef = await _firestore.collection('fire_reports').add(mapData);
      
      final newReport = FireReportModel.fromMap(mapData, docRef.id);
      _reports.insert(0, newReport);
      notifyListeners();
    } catch (e) {
      debugPrint("Error adding fire report: $e");
      rethrow;
    }
  }

  Future<void> updateReport(FireReportModel report) async {
    try {
      final mapData = report.toMap();
      mapData.remove('id');
      await _firestore.collection('fire_reports').doc(report.id).update(mapData);
      
      final index = _reports.indexWhere((r) => r.id == report.id);
      if (index != -1) {
        _reports[index] = report;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error updating fire report: $e");
      rethrow;
    }
  }

  Future<void> deleteReport(String id) async {
    try {
      await _firestore.collection('fire_reports').doc(id).delete();
      _reports.removeWhere((r) => r.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint("Error deleting fire report: $e");
      rethrow;
    }
  }
}
