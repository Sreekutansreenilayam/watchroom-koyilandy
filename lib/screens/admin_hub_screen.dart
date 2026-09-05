import 'dart:ui';
import 'package:flutter/material.dart';
import 'vehicle_list_screen.dart';
import 'duty_screen.dart';
import 'manpower_screen.dart';
import 'user_management_screen.dart';
import 'dosr_screen.dart';
import 'fire_report_screen.dart';
import 'incident_reports_list_screen.dart';
import 'friday_paradestate_screen.dart';
import 'fuel_screen.dart';
import 'equipment_screen.dart';
import 'registers_records_screen.dart';
import 'contacts_screen.dart';
import 'updates_screen.dart';
import 'vouchers_screen.dart';
import 'logbook_vehicles_screen.dart';
import '../services/access_control.dart';

class AdminHubScreen extends StatelessWidget {
  const AdminHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> modules = [
      {'title': 'Menpower', 'icon': Icons.people, 'color': Colors.blue, 'route': const ManpowerScreen()},
      {'title': 'Vehicles', 'icon': Icons.fire_truck, 'color': Colors.green, 'route': const VehicleListScreen()},
      {'title': 'Equipments', 'icon': Icons.handyman, 'color': Colors.orange, 'route': const EquipmentScreen()},
      {'title': 'Logbook', 'icon': Icons.menu_book, 'color': Colors.brown, 'route': const LogbookVehiclesScreen()},
      {'title': 'Updates', 'icon': Icons.update, 'color': Colors.cyan, 'route': const UpdatesScreen()},
      {'title': 'Vouchers', 'icon': Icons.receipt, 'color': Colors.amber, 'route': const VouchersScreen()},
      {'title': 'Fuel', 'icon': Icons.local_gas_station, 'color': Colors.redAccent, 'route': const FuelScreen()},
      {'title': 'Duty Mgt.', 'icon': Icons.calendar_month, 'color': Colors.indigo, 'route': const DutyScreen()},
      {'title': 'User Mgt.', 'icon': Icons.manage_accounts, 'color': Colors.teal, 'route': const UserManagementScreen()},
      {'title': 'DOSR', 'icon': Icons.assignment, 'color': Colors.purple, 'route': const DosrScreen()},
      {'title': 'Fire Report', 'icon': Icons.local_fire_department, 'color': Colors.red, 'route': const FireReportScreen()},
      {'title': 'Incident Report', 'icon': Icons.description, 'color': Colors.orangeAccent, 'route': const IncidentReportsListScreen()},
      {'title': 'Paradestate', 'icon': Icons.group, 'color': Colors.lightBlue, 'route': const FridayParadestateScreen()},
      {'title': 'Register\'s Records', 'icon': Icons.library_books, 'color': Colors.deepOrange, 'route': const RegistersRecordsScreen()},
      {'title': 'Contacts', 'icon': Icons.contacts, 'color': Colors.pinkAccent, 'route': const ContactsScreen()},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Administration Hub', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.5,
            colors: [
              Color(0xFF2C0B0B),
              Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              itemCount: modules.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (context, index) {
                final module = modules[index];
                return _buildGlassModuleCard(context, module);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassModuleCard(BuildContext context, Map<String, dynamic> module) {
    final Color iconColor = module['color'] as Color;

    return GestureDetector(
      onTap: () {
        final moduleTitle = module['title'] as String;
        final isDriver = AccessControl.isDriver(context);
        final isSfroM = AccessControl.isSfroM(context);
        final isAdmin = AccessControl.isAdmin(context);

        final allowedDriverModules = ['Vehicles', 'Equipments', 'Logbook', 'Updates', 'Vouchers', 'Fuel', 'Register\'s Records', 'Contacts'];

        if (isDriver && !allowedDriverModules.contains(moduleTitle)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are not authorized to operate this module. Please contact the on-duty SFRO for assistance.'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }

        if (moduleTitle == 'Logbook' && !isDriver && !isSfroM && !isAdmin) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are not authorized to operate this module as you are not a designated driver at this station.'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }

        if (module.containsKey('route')) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => module['route'] as Widget),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${module['title']} module coming soon!'),
              backgroundColor: Colors.white24,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: iconColor.withOpacity(0.3)),
                  ),
                  child: Icon(
                    module['icon'] as IconData,
                    color: iconColor,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  module['title'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
