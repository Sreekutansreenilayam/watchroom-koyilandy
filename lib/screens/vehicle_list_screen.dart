import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vehicle_provider.dart';
import 'vehicle_master_registry_screen.dart';

class VehicleListScreen extends StatelessWidget {
  const VehicleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'VEHICLES',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.amber,
            letterSpacing: 1.5,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.amber),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.amber, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VehicleMasterRegistryScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.5,
            colors: [
              Color(0xFF1E1010),
              Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer<VehicleProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator(color: Colors.amber));
              }

              if (provider.vehicles.isEmpty) {
                return const Center(
                  child: Text(
                    'No vehicles available',
                    style: TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                itemCount: provider.vehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = provider.vehicles[index];
                  final statusText = _getStatusText(vehicle.status);
                  final isGreen = _isGreenStatus(vehicle.status);

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VehicleMasterRegistryScreen(vehicle: vehicle),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Rotated Yellow Diamond Road Sign Icon
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFC49A24), // Mustard/Gold
                              borderRadius: BorderRadius.circular(6),
                            ),
                            transform: Matrix4.rotationZ(0.785398), // 45 deg
                            transformAlignment: Alignment.center,
                            child: Transform.rotate(
                              angle: -0.785398,
                              child: const Icon(
                                Icons.subdirectory_arrow_right_outlined,
                                color: Colors.black,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Middle Column: Vehicle Type and Reg Number Badge
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vehicle.type.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    vehicle.regNumber.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Right Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isGreen
                                  ? const Color(0xFF1B2F1F) // Specimen Green Back
                                  : const Color(0xFF2E1B1B), // Specimen Red/Orange Back
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isGreen
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.red.withOpacity(0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              statusText.toUpperCase(),
                              style: TextStyle(
                                color: isGreen ? Colors.greenAccent : Colors.redAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    if (status == 'READY' || status == 'Available') return 'READY';
    if (status == 'OFF ROAD') return 'OFF ROAD';
    if (status == 'MAINTENANCE') return 'MAINTENANCE';
    if (status == 'CONDEMNED') return 'CONDEMNED';
    return status;
  }

  bool _isGreenStatus(String status) {
    return status == 'READY' || status == 'Available';
  }
}
