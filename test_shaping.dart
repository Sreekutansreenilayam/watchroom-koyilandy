import 'package:flutter_test/flutter_test.dart';
import 'lib/models/fire_report_model.dart';

void main() {
  test('Test parsing FireReportModel', () {
    final Map<String, dynamic> firestoreData = {
      "casualtiesOthersMale": 0,
      "casualtiesOthersNames": "",
      "confirmedCause": "വൃക്തമല്ല",
      "damageDescription": "തെങ്ങിൻ തടികൾ വേസ്റ്റുകൾ എന്നിവ",
      "date": "2026-01-03T00:00:00.000",
      "distanceFromStationKm": "4",
      "estValueBuildingDamage": 0,
      "estValueContentsDamage": 1000,
      "estValueCouldHaveCaught": 20000000,
      "estValuePropertiesInvolved": 20000,
      "extentOfFire": "ഒരുമുടി നിന്നു",
      "firstTurnoutTime": "2026-01-03T20:20:00.000",
      "location": "മീഞ്ചന്ത",
      "natureOfDeath": ""
    };

    try {
      final model = FireReportModel.fromMap(firestoreData, 'KwKbwVwk1X6WAKrsB752');
      print('Parsed successfully: \${model.location}');
    } catch (e, stack) {
      print('Error: \$e');
      print(stack);
    }
  });
}
