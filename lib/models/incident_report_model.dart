class IncidentReportVehicleDetail {
  final String stationName;
  final String vehicleType;
  final String regNo;
  final String timeOut;
  final String timeReached;
  final String timeLeft;
  final String timeIn;
  final String distanceTripKm;
  final String pumpWorkedTime;

  IncidentReportVehicleDetail({
    required this.stationName,
    required this.vehicleType,
    required this.regNo,
    required this.timeOut,
    required this.timeReached,
    required this.timeLeft,
    required this.timeIn,
    required this.distanceTripKm,
    required this.pumpWorkedTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'stationName': stationName,
      'vehicleType': vehicleType,
      'regNo': regNo,
      'timeOut': timeOut,
      'timeReached': timeReached,
      'timeLeft': timeLeft,
      'timeIn': timeIn,
      'distanceTripKm': distanceTripKm,
      'pumpWorkedTime': pumpWorkedTime,
    };
  }

  factory IncidentReportVehicleDetail.fromMap(Map<String, dynamic> map) {
    return IncidentReportVehicleDetail(
      stationName: map['stationName'] ?? '',
      vehicleType: map['vehicleType'] ?? '',
      regNo: map['regNo'] ?? '',
      timeOut: map['timeOut'] ?? '',
      timeReached: map['timeReached'] ?? '',
      timeLeft: map['timeLeft'] ?? '',
      timeIn: map['timeIn'] ?? '',
      distanceTripKm: map['distanceTripKm'] ?? '',
      pumpWorkedTime: map['pumpWorkedTime'] ?? '',
    );
  }
}

class IncidentReportModel {
  final String id;
  // General Info
  final String station;
  final String location;
  final String officerInChargeId;
  final String reportNumber;
  final DateTime date;
  
  // Call Details (1. വിളി)
  final String callerName;
  final String callerPhone;
  final String buildingsInvolved;
  final String occupantName;
  final String occupation;
  final String ownerNameAndAddress;
  final DateTime? callTime;
  final DateTime? turnoutTime;
  final DateTime? reachedTime;
  final String distanceFromStationKm;
  
  // Incident Details (2. സംഭവത്തിന്റെ വിശദവിവരങ്ങൾ)
  final String fullDetails;
  final String confirmedCause;
  final String serviceRendered;
  final String officerLeftLastId;
  final DateTime? dateAndTimeLeft;
  final int totalWorkingHours;
  final int totalWorkingMinutes;
  
  // Rescues & Casualties (3 & 4)
  final int rescuedWithoutFireForceMale;
  final int rescuedWithoutFireForceFemale;
  final int rescuedWithFireForceNoEqMale;
  final int rescuedWithFireForceNoEqFemale;
  final int rescuedWithFireForceEqMale;
  final int rescuedWithFireForceEqFemale;
  
  final int casualtiesFireForceMale;
  final int casualtiesFireForceFemale;
  final String casualtiesFireForceNames;
  final String casualtiesFireForceAddress;
  
  final int casualtiesOthersMale;
  final int casualtiesOthersFemale;
  final String casualtiesOthersNames;
  final String casualtiesOthersAddress;
  
  final String natureOfDeath;
  
  // Vehicles and Personnel (5 & 6)
  final List<IncidentReportVehicleDetail> vehicleDetails;
  final List<String> attendingOfficersIds;
  final List<String> attendingPersonnelIds;
  
  // Remarks (7)
  final String hoseNo;
  final String remarks;

  IncidentReportModel({
    required this.id,
    this.station = 'കൊയിലാണ്ടി',
    required this.location,
    required this.officerInChargeId,
    required this.reportNumber,
    required this.date,
    required this.callerName,
    required this.callerPhone,
    required this.buildingsInvolved,
    required this.occupantName,
    required this.occupation,
    required this.ownerNameAndAddress,
    this.callTime,
    this.turnoutTime,
    this.reachedTime,
    required this.distanceFromStationKm,
    required this.fullDetails,
    required this.confirmedCause,
    required this.serviceRendered,
    required this.officerLeftLastId,
    this.dateAndTimeLeft,
    required this.totalWorkingHours,
    required this.totalWorkingMinutes,
    required this.rescuedWithoutFireForceMale,
    required this.rescuedWithoutFireForceFemale,
    required this.rescuedWithFireForceNoEqMale,
    required this.rescuedWithFireForceNoEqFemale,
    required this.rescuedWithFireForceEqMale,
    required this.rescuedWithFireForceEqFemale,
    required this.casualtiesFireForceMale,
    required this.casualtiesFireForceFemale,
    required this.casualtiesFireForceNames,
    this.casualtiesFireForceAddress = '',
    required this.casualtiesOthersMale,
    required this.casualtiesOthersFemale,
    required this.casualtiesOthersNames,
    this.casualtiesOthersAddress = '',
    this.natureOfDeath = '',
    required this.vehicleDetails,
    required this.attendingOfficersIds,
    required this.attendingPersonnelIds,
    this.hoseNo = '',
    required this.remarks,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'station': station,
      'location': location,
      'officerInChargeId': officerInChargeId,
      'reportNumber': reportNumber,
      'date': date.toIso8601String(),
      'callerName': callerName,
      'callerPhone': callerPhone,
      'buildingsInvolved': buildingsInvolved,
      'occupantName': occupantName,
      'occupation': occupation,
      'ownerNameAndAddress': ownerNameAndAddress,
      'callTime': callTime?.toIso8601String(),
      'turnoutTime': turnoutTime?.toIso8601String(),
      'reachedTime': reachedTime?.toIso8601String(),
      'distanceFromStationKm': distanceFromStationKm,
      'fullDetails': fullDetails,
      'confirmedCause': confirmedCause,
      'serviceRendered': serviceRendered,
      'officerLeftLastId': officerLeftLastId,
      'dateAndTimeLeft': dateAndTimeLeft?.toIso8601String(),
      'totalWorkingHours': totalWorkingHours,
      'totalWorkingMinutes': totalWorkingMinutes,
      'rescuedWithoutFireForceMale': rescuedWithoutFireForceMale,
      'rescuedWithoutFireForceFemale': rescuedWithoutFireForceFemale,
      'rescuedWithFireForceNoEqMale': rescuedWithFireForceNoEqMale,
      'rescuedWithFireForceNoEqFemale': rescuedWithFireForceNoEqFemale,
      'rescuedWithFireForceEqMale': rescuedWithFireForceEqMale,
      'rescuedWithFireForceEqFemale': rescuedWithFireForceEqFemale,
      'casualtiesFireForceMale': casualtiesFireForceMale,
      'casualtiesFireForceFemale': casualtiesFireForceFemale,
      'casualtiesFireForceNames': casualtiesFireForceNames,
      'casualtiesFireForceAddress': casualtiesFireForceAddress,
      'casualtiesOthersMale': casualtiesOthersMale,
      'casualtiesOthersFemale': casualtiesOthersFemale,
      'casualtiesOthersNames': casualtiesOthersNames,
      'casualtiesOthersAddress': casualtiesOthersAddress,
      'natureOfDeath': natureOfDeath,
      'vehicleDetails': vehicleDetails.map((x) => x.toMap()).toList(),
      'attendingOfficersIds': attendingOfficersIds,
      'attendingPersonnelIds': attendingPersonnelIds,
      'hoseNo': hoseNo,
      'remarks': remarks,
    };
  }

  factory IncidentReportModel.fromMap(Map<String, dynamic> map, String docId) {
    return IncidentReportModel(
      id: docId,
      station: map['station'] ?? 'കൊയിലാണ്ടി',
      location: map['location'] ?? '',
      officerInChargeId: map['officerInChargeId'] ?? '',
      reportNumber: map['reportNumber'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      callerName: map['callerName'] ?? '',
      callerPhone: map['callerPhone'] ?? '',
      buildingsInvolved: map['buildingsInvolved'] ?? '',
      occupantName: map['occupantName'] ?? '',
      occupation: map['occupation'] ?? '',
      ownerNameAndAddress: map['ownerNameAndAddress'] ?? '',
      callTime: map['callTime'] != null ? DateTime.parse(map['callTime']) : null,
      turnoutTime: map['turnoutTime'] != null ? DateTime.parse(map['turnoutTime']) : null,
      reachedTime: map['reachedTime'] != null ? DateTime.parse(map['reachedTime']) : null,
      distanceFromStationKm: map['distanceFromStationKm']?.toString() ?? '',
      fullDetails: map['fullDetails'] ?? '',
      confirmedCause: map['confirmedCause'] ?? '',
      serviceRendered: map['serviceRendered'] ?? '',
      officerLeftLastId: map['officerLeftLastId'] ?? '',
      dateAndTimeLeft: map['dateAndTimeLeft'] != null ? DateTime.parse(map['dateAndTimeLeft']) : null,
      totalWorkingHours: map['totalWorkingHours'] ?? 0,
      totalWorkingMinutes: map['totalWorkingMinutes'] ?? 0,
      rescuedWithoutFireForceMale: map['rescuedWithoutFireForceMale'] ?? 0,
      rescuedWithoutFireForceFemale: map['rescuedWithoutFireForceFemale'] ?? 0,
      rescuedWithFireForceNoEqMale: map['rescuedWithFireForceNoEqMale'] ?? 0,
      rescuedWithFireForceNoEqFemale: map['rescuedWithFireForceNoEqFemale'] ?? 0,
      rescuedWithFireForceEqMale: map['rescuedWithFireForceEqMale'] ?? 0,
      rescuedWithFireForceEqFemale: map['rescuedWithFireForceEqFemale'] ?? 0,
      casualtiesFireForceMale: map['casualtiesFireForceMale'] ?? 0,
      casualtiesFireForceFemale: map['casualtiesFireForceFemale'] ?? 0,
      casualtiesFireForceNames: map['casualtiesFireForceNames'] ?? '',
      casualtiesFireForceAddress: map['casualtiesFireForceAddress'] ?? '',
      casualtiesOthersMale: map['casualtiesOthersMale'] ?? 0,
      casualtiesOthersFemale: map['casualtiesOthersFemale'] ?? 0,
      casualtiesOthersNames: map['casualtiesOthersNames'] ?? '',
      casualtiesOthersAddress: map['casualtiesOthersAddress'] ?? '',
      natureOfDeath: map['natureOfDeath'] ?? '',
      vehicleDetails: map['vehicleDetails'] != null
          ? List<IncidentReportVehicleDetail>.from(
              map['vehicleDetails']?.map((x) => IncidentReportVehicleDetail.fromMap(x)))
          : [],
      attendingOfficersIds: List<String>.from(map['attendingOfficersIds'] ?? []),
      attendingPersonnelIds: List<String>.from(map['attendingPersonnelIds'] ?? []),
      hoseNo: map['hoseNo'] ?? '',
      remarks: map['remarks'] ?? '',
    );
  }
}
