class MonthlyAttendance {
  final String id;
  final String manpowerId;
  final String yearMonth; // Format: "YYYY-MM"
  final Map<int, String> dailyStatus; // Key: Day of month (1-31), Value: Status code (P, A, L, N, etc.)

  MonthlyAttendance({
    required this.id,
    required this.manpowerId,
    required this.yearMonth,
    required this.dailyStatus,
  });

  Map<String, dynamic> toMap() {
    // Convert Map<int, String> to Map<String, String> for Firestore
    Map<String, String> firestoreDailyStatus = {};
    dailyStatus.forEach((key, value) {
      firestoreDailyStatus[key.toString()] = value;
    });

    return {
      'id': id,
      'manpowerId': manpowerId,
      'yearMonth': yearMonth,
      'dailyStatus': firestoreDailyStatus,
    };
  }

  factory MonthlyAttendance.fromMap(Map<String, dynamic> map, String documentId) {
    Map<int, String> parsedDailyStatus = {};
    if (map['dailyStatus'] != null) {
      final Map<String, dynamic> firestoreDailyStatus = map['dailyStatus'];
      firestoreDailyStatus.forEach((key, value) {
        parsedDailyStatus[int.parse(key)] = value.toString();
      });
    }

    return MonthlyAttendance(
      id: documentId,
      manpowerId: map['manpowerId'] ?? '',
      yearMonth: map['yearMonth'] ?? '',
      dailyStatus: parsedDailyStatus,
    );
  }

  MonthlyAttendance copyWith({
    String? id,
    String? manpowerId,
    String? yearMonth,
    Map<int, String>? dailyStatus,
  }) {
    return MonthlyAttendance(
      id: id ?? this.id,
      manpowerId: manpowerId ?? this.manpowerId,
      yearMonth: yearMonth ?? this.yearMonth,
      dailyStatus: dailyStatus ?? this.dailyStatus,
    );
  }
}

class AttendanceLegend {
  final String id;
  final String code; // e.g., "P", "SL"
  final String description; // e.g., "Present", "Sick Leave"
  final int colorValue; // e.g., 0xFF4CAF50

  AttendanceLegend({
    required this.id,
    required this.code,
    required this.description,
    required this.colorValue,
  });

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'description': description,
      'colorValue': colorValue,
    };
  }

  factory AttendanceLegend.fromMap(Map<String, dynamic> map, String documentId) {
    return AttendanceLegend(
      id: documentId,
      code: map['code'] ?? '',
      description: map['description'] ?? '',
      colorValue: map['colorValue'] ?? 0xFF9E9E9E, // Default to grey if missing
    );
  }
}
