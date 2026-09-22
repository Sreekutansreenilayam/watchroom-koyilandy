import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppConfig {
  static const String flavorMeenchanda = 'meenchanda';
  static const String flavorKoyilandy = 'koyilandy';
  
  static String _currentFlavor = flavorMeenchanda;

  static Future<void> init() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (packageInfo.packageName.endsWith('.koyilandy')) {
        _currentFlavor = flavorKoyilandy;
      } else {
        _currentFlavor = flavorMeenchanda;
      }
    } catch (e) {
      _currentFlavor = flavorMeenchanda;
    }
  }

  static String get currentFlavor => _currentFlavor;

  static bool get isKoyilandy => currentFlavor == flavorKoyilandy;
  static bool get isMeenchanda => currentFlavor == flavorMeenchanda;

  static String get stationName {
    if (isKoyilandy) {
      return 'Fire & Rescue Station, Koyilandy';
    }
    return 'Fire & Rescue Station, Meenchanda';
  }

  static String get stationNameShort {
    if (isKoyilandy) {
      return 'FRS Koyilandy';
    }
    return 'FRS Meenchanda';
  }

  static String get stationNamePdfHeader {
    if (isKoyilandy) {
      return 'FIRE & RESCUE STATION KOYILANDY';
    }
    return 'FIRE & RESCUE STATION MEENCHANDA';
  }

  static String get stationCity {
    if (isKoyilandy) {
      return 'Koyilandy';
    }
    return 'Meenchanda';
  }

  static LatLng get stationLocation {
    if (isKoyilandy) {
      return const LatLng(11.4398, 75.6983);
    }
    return const LatLng(11.2189, 75.7925);
  }
}
