import 'package:cloud_firestore/cloud_firestore.dart';

class DutyRoster {
  final String id;
  final DateTime date;
  final String shift; // Day, Night
  final List<String> personnelNames;

  DutyRoster({
    required this.id,
    required this.date,
    required this.shift,
    required this.personnelNames,
  });

  factory DutyRoster.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return DutyRoster(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      shift: data['shift'] ?? '',
      personnelNames: List<String>.from(data['personnelNames'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'shift': shift,
      'personnelNames': personnelNames,
    };
  }
}
