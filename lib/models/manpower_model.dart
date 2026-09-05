class Manpower {
  final String id;
  final String idNumber;
  final String name;
  final String designation;
  final String mobileNumber;
  final DateTime? stationIn;
  final DateTime? stationOut;
  final bool isDriver;
  final String currentStation;
  final bool isTempAttachedForTraining;
  final String gender;
  final int sortOrder;
  final bool isActive;
  final String? exitReason;
  final DateTime? exitDate;

  Manpower({
    required this.id,
    required this.idNumber,
    required this.name,
    required this.designation,
    required this.mobileNumber,
    this.stationIn,
    this.stationOut,
    required this.isDriver,
    this.currentStation = 'FRS Meenchanda',
    this.isTempAttachedForTraining = false,
    this.gender = 'Male',
    this.sortOrder = 999,
    this.isActive = true,
    this.exitReason,
    this.exitDate,
  });

  String get displayGroup {
    String base = designation;
    if (base == 'SFRO (D)' || base == 'FRO (D)') {
      base = 'FRO (D)';
    }
    
    if (base.toLowerCase() == 'trainees') {
      return base;
    }
    
    if (currentStation.trim().isNotEmpty && currentStation.trim().toLowerCase() != 'frs meenchanda') {
       return '$base - $currentStation';
    }
    return base;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'idNumber': idNumber,
      'name': name,
      'designation': designation,
      'mobileNumber': mobileNumber,
      'stationIn': stationIn?.toIso8601String(),
      'stationOut': stationOut?.toIso8601String(),
      'isDriver': isDriver,
      'currentStation': currentStation,
      'isTempAttachedForTraining': isTempAttachedForTraining,
      'gender': gender,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'exitReason': exitReason,
      'exitDate': exitDate?.toIso8601String(),
    };
  }

  factory Manpower.fromMap(Map<String, dynamic> map) {
    return Manpower(
      id: map['id'] ?? '',
      idNumber: map['idNumber'] ?? '',
      name: map['name'] ?? '',
      designation: map['designation'] ?? '',
      mobileNumber: map['mobileNumber'] ?? '',
      stationIn: map['stationIn'] != null ? DateTime.parse(map['stationIn']) : DateTime(2026, 6, 1),
      stationOut: map['stationOut'] != null ? DateTime.parse(map['stationOut']) : null,
      isDriver: map['isDriver'] ?? false,
      currentStation: map['currentStation'] ?? 'FRS Meenchanda',
      isTempAttachedForTraining: map['isTempAttachedForTraining'] ?? false,
      gender: map['gender'] ?? 'Male',
      sortOrder: map['sortOrder'] ?? 999,
      isActive: map['isActive'] ?? true,
      exitReason: map['exitReason'],
      exitDate: map['exitDate'] != null ? DateTime.parse(map['exitDate']) : null,
    );
  }

  Manpower copyWith({
    String? idNumber,
    String? name,
    String? designation,
    String? mobileNumber,
    DateTime? stationIn,
    DateTime? stationOut,
    bool? isDriver,
    String? currentStation,
    bool? isTempAttachedForTraining,
    String? gender,
    int? sortOrder,
    bool? isActive,
    String? exitReason,
    DateTime? exitDate,
  }) {
    return Manpower(
      id: id,
      idNumber: idNumber ?? this.idNumber,
      name: name ?? this.name,
      designation: designation ?? this.designation,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      stationIn: stationIn ?? this.stationIn,
      stationOut: stationOut ?? this.stationOut,
      isDriver: isDriver ?? this.isDriver,
      currentStation: currentStation ?? this.currentStation,
      isTempAttachedForTraining: isTempAttachedForTraining ?? this.isTempAttachedForTraining,
      gender: gender ?? this.gender,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      exitReason: exitReason ?? this.exitReason,
      exitDate: exitDate ?? this.exitDate,
    );
  }
}
