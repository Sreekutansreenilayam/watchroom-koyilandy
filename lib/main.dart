  import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/duty_provider.dart';
import 'providers/vehicle_provider.dart';
import 'providers/manpower_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/sentry_provider.dart';
import 'providers/fuel_provider.dart';
import 'providers/equipment_provider.dart';
import 'providers/incident_provider.dart';
import 'providers/fire_report_provider.dart';
import 'providers/incident_report_provider.dart';
import 'providers/contact_provider.dart';
import 'providers/voucher_provider.dart';
import 'providers/logbook_provider.dart';
import 'widgets/version_check_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  runApp(const FireRescueApp());
}

class FireRescueApp extends StatelessWidget {
  const FireRescueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DutyProvider()),
        ChangeNotifierProvider(create: (_) => VehicleProvider()),
        ChangeNotifierProvider(create: (_) => ManpowerProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => SentryProvider()),
        ChangeNotifierProvider(create: (_) => FuelProvider()),
        ChangeNotifierProvider(create: (_) => EquipmentProvider()),
        ChangeNotifierProvider(create: (_) => IncidentProvider()),
        ChangeNotifierProvider(create: (_) => FireReportProvider()),
        ChangeNotifierProvider(create: (_) => IncidentReportProvider()),
        ChangeNotifierProvider(create: (_) => ContactProvider()),
        ChangeNotifierProvider(create: (_) => VoucherProvider()),
        ChangeNotifierProvider(create: (_) => LogbookProvider()),
      ],
      child: MaterialApp(
        title: 'Fire & Rescue',
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          );
        },
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0A0A0A), // Very dark background
          primaryColor: const Color(0xFFD32F2F), // Crimson Red
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFD32F2F),
            secondary: Color(0xFFE53935),
            surface: Color(0xFF1E1E1E),
          ),
          textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
          useMaterial3: true,
        ),
        home: const VersionCheckWrapper(child: AuthWrapper()),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
