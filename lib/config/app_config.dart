import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppConfig {
  static Future<void> init() async {
    // No-op for standalone project
  }

  static bool get isKoyilandy => true;
  static bool get isMeenchanda => false;

  static String get stationName => 'Fire & Rescue Station, Koyilandy';

  static String get stationNameShort => 'FRS Koyilandy';

  static String get stationNamePdfHeader => 'FIRE & RESCUE STATION KOYILANDY';

  static String get stationCity => 'Koyilandy';

  static LatLng get stationLocation => const LatLng(11.4398, 75.6983);
}
