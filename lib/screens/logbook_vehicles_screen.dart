import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vehicle_provider.dart';
import '../models/vehicle_model.dart';
import '../providers/auth_provider.dart';
import '../providers/manpower_provider.dart';
import 'logbook_detail_screen.dart';

class LogbookVehiclesScreen extends StatefulWidget {
  const LogbookVehiclesScreen({super.key});

  @override
  State<LogbookVehiclesScreen> createState() => _LogbookVehiclesScreenState();
}

class _LogbookVehiclesScreenState extends State<LogbookVehiclesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Logbook - Vehicles', style: TextStyle(fontWeight: FontWeight.bold)),
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
          child: Consumer<VehicleProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
              }

              if (provider.vehicles.isEmpty) {
                return const Center(
                  child: Text('No vehicles available.', style: TextStyle(color: Colors.white70)),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.builder(
                  itemCount: provider.vehicles.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.9,
                  ),
                  itemBuilder: (context, index) {
                    final vehicle = provider.vehicles[index];
                    return _buildVehicleCard(context, vehicle);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleCard(BuildContext context, VehicleModel vehicle) {
    return GestureDetector(
      onTap: () {
        final authProvider = context.read<AuthProvider>();
        final manpowerProvider = context.read<ManpowerProvider>();
        final linkedPersonId = authProvider.linkedPersonId;

        bool isLoggedUserKhg = false;
        if (linkedPersonId != null && linkedPersonId.isNotEmpty) {
          try {
            final loggedInPerson = manpowerProvider.personnelList.firstWhere((p) => p.id == linkedPersonId);
            final desig = loggedInPerson.designation.toUpperCase();
            isLoggedUserKhg = desig.contains('HG') || desig.contains('KHG');
          } catch (_) {}
        }

        final vehicleType = vehicle.type.toLowerCase();
        final isLightVehicle = vehicleType.contains('bullet') ||
                               vehicleType.contains('frv') ||
                               vehicleType.contains('icv') ||
                               vehicleType.contains('jeep') ||
                               vehicleType.contains('amb') ||
                               vehicleType.contains('qrv') ||
                               vehicleType.contains('tc');

        if (isLoggedUserKhg && !isLightVehicle) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are not authorized to open this logbook'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LogbookDetailScreen(vehicle: vehicle)),
        );
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
                    color: Colors.brown.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.brown.withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.menu_book,
                    color: Colors.brown,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Logbook',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  vehicle.regNumber,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  vehicle.type,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.amberAccent,
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
