class FireReportVehicleDetail {
  final String stationName;
  final String vehicleType;
  final String regNo;
  final String timeOut;
  final String timeReached;
  final String timeLeft;
  final String timeIn;
  final String distanceTripKm;
  final String pumpWorkedTime;

  FireReportVehicleDetail({
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

  factory FireReportVehicleDetail.fromMap(Map<String, dynamic> map) {
    return FireReportVehicleDetail(
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

class FireReportModel {
  final String id;
  // General Info
  final String station;
  final String location;
  final String officerInChargeId;
  final String reportNumber;
  final DateTime date;
  
  // Call Details
  final String callerName;
  final String callerPhone;
  final String buildingsInvolved;
  final String occupantName;
  final String ownerNameAndAddress;
  final String occupation;
  final DateTime? firstTurnoutTime;
  final DateTime? callTime;
  final DateTime? reachedTime;
  final String distanceFromStationKm;
  final DateTime? actualFireTime;
  
  // Fire Details
  final String propertiesInvolved;
  final String typeOfFire; // Small/Medium/Large
  final String extentOfFire;
  final String confirmedCause;
  final String damageDescription;
  
  // Estimates
  final double estValuePropertiesInvolved;
  final double estValueCouldHaveCaught;
  final double estValueBuildingDamage;
  final double estValueContentsDamage;
  
  // Assessment
  final String assessingOfficerId;
  final DateTime? assessmentDate;
  final int totalWorkingHours;
  final int totalWorkingMinutes;
  
  // Rescues & Casualties
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
  
  // Vehicles and Personnel
  final List<FireReportVehicleDetail> vehicleDetails;
  final List<String> attendingOfficersIds;
  final List<String> attendingPersonnelIds;
  
  // Remarks
  final String hoseNo;
  final String remarks;

  FireReportModel({
    required this.id,
    this.station = 'മീഞ്ചന്ത',
    required this.location,
    required this.officerInChargeId,
    required this.reportNumber,
    required this.date,
    required this.callerName,
    required this.callerPhone,
    required this.buildingsInvolved,
    required this.occupantName,
    required this.ownerNameAndAddress,
    required this.occupation,
    this.firstTurnoutTime,
    this.callTime,
    this.reachedTime,
    required this.distanceFromStationKm,
    this.actualFireTime,
    required this.propertiesInvolved,
    required this.typeOfFire,
    required this.extentOfFire,
    required this.confirmedCause,
    required this.damageDescription,
    required this.estValuePropertiesInvolved,
    required this.estValueCouldHaveCaught,
    required this.estValueBuildingDamage,
    required this.estValueContentsDamage,
    required this.assessingOfficerId,
    this.assessmentDate,
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
    required this.natureOfDeath,
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
      'ownerNameAndAddress': ownerNameAndAddress,
      'occupation': occupation,
      'firstTurnoutTime': firstTurnoutTime?.toIso8601String(),
      'callTime': callTime?.toIso8601String(),
      'reachedTime': reachedTime?.toIso8601String(),
      'distanceFromStationKm': distanceFromStationKm,
      'actualFireTime': actualFireTime?.toIso8601String(),
      'propertiesInvolved': propertiesInvolved,
      'typeOfFire': typeOfFire,
      'extentOfFire': extentOfFire,
      'confirmedCause': confirmedCause,
      'damageDescription': damageDescription,
      'estValuePropertiesInvolved': estValuePropertiesInvolved,
      'estValueCouldHaveCaught': estValueCouldHaveCaught,
      'estValueBuildingDamage': estValueBuildingDamage,
      'estValueContentsDamage': estValueContentsDamage,
      'assessingOfficerId': assessingOfficerId,
      'assessmentDate': assessmentDate?.toIso8601String(),
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

  factory FireReportModel.fromMap(Map<String, dynamic> map, String docId) {
    return FireReportModel(
      id: docId,
      station: map['station'] ?? 'മീഞ്ചന്ത',
      location: map['location'] ?? '',
      officerInChargeId: map['officerInChargeId'] ?? '',
      reportNumber: map['reportNumber'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      callerName: map['callerName'] ?? '',
      callerPhone: map['callerPhone'] ?? '',
      buildingsInvolved: map['buildingsInvolved'] ?? '',
      occupantName: map['occupantName'] ?? '',
      ownerNameAndAddress: map['ownerNameAndAddress'] ?? '',
      occupation: map['occupation'] ?? '',
      firstTurnoutTime: map['firstTurnoutTime'] != null ? DateTime.parse(map['firstTurnoutTime']) : null,
      callTime: map['callTime'] != null ? DateTime.parse(map['callTime']) : null,
      reachedTime: map['reachedTime'] != null ? DateTime.parse(map['reachedTime']) : null,
      distanceFromStationKm: map['distanceFromStationKm']?.toString() ?? '',
      actualFireTime: map['actualFireTime'] != null ? DateTime.parse(map['actualFireTime']) : null,
      propertiesInvolved: map['propertiesInvolved'] ?? '',
      typeOfFire: map['typeOfFire'] ?? '',
      extentOfFire: map['extentOfFire'] ?? '',
      confirmedCause: map['confirmedCause'] ?? '',
      damageDescription: map['damageDescription'] ?? '',
      estValuePropertiesInvolved: (map['estValuePropertiesInvolved'] ?? 0.0).toDouble(),
      estValueCouldHaveCaught: (map['estValueCouldHaveCaught'] ?? 0.0).toDouble(),
      estValueBuildingDamage: (map['estValueBuildingDamage'] ?? 0.0).toDouble(),
      estValueContentsDamage: (map['estValueContentsDamage'] ?? 0.0).toDouble(),
      assessingOfficerId: map['assessingOfficerId'] ?? '',
      assessmentDate: map['assessmentDate'] != null ? DateTime.parse(map['assessmentDate']) : null,
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
      vehicleDetails: map['vehicleDetails'] != null ? List<FireReportVehicleDetail>.from(map['vehicleDetails']?.map((x) => FireReportVehicleDetail.fromMap(x))) : [],
      attendingOfficersIds: List<String>.from(map['attendingOfficersIds'] ?? []),
      attendingPersonnelIds: List<String>.from(map['attendingPersonnelIds'] ?? []),
      hoseNo: map['hoseNo'] ?? '',
      remarks: map['remarks'] ?? '',
    );
  }
}
