import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/vehicle_provider.dart';
import '../providers/equipment_provider.dart';
import '../models/vehicle_model.dart';
import '../models/equipment_model.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  bool _isAlertBlinking = false;

  @override
  void initState() {
    super.initState();
    _checkFirstOpenToday();
  }

  Future<void> _checkFirstOpenToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastOpened = prefs.getString('last_alert_opened_date');
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (lastOpened != today) {
      setState(() {
        _isAlertBlinking = true;
      });
    }
  }

  Future<void> _markAsOpenedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setString('last_alert_opened_date', today);
    setState(() {
      _isAlertBlinking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Updates Hub', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer2<VehicleProvider, EquipmentProvider>(
        builder: (context, vehicleProvider, equipmentProvider, child) {
          if (vehicleProvider.isLoading || equipmentProvider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyan));
          }

          // Calculate alert counts
          int totalAlerts = 0;
          final now = DateTime.now();
          final currentMonthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          final next3MonthsEnd = DateTime(now.year, now.month + 3, 0, 23, 59, 59);

          List<Map<String, dynamic>> expired = [];
          List<Map<String, dynamic>> thisMonth = [];
          List<Map<String, dynamic>> next3Months = [];

          void categorizeAlert(String itemType, String itemName, String alertType, DateTime? date) {
            if (date == null) return;
            final alertData = {'itemType': itemType, 'name': itemName, 'alertType': alertType, 'date': date};
            if (date.isBefore(now)) {
              expired.add(alertData);
              totalAlerts++;
            } else if (date.isAfter(now) && date.isBefore(currentMonthEnd)) {
              thisMonth.add(alertData);
              totalAlerts++;
            } else if (date.isAfter(currentMonthEnd) && date.isBefore(next3MonthsEnd)) {
              next3Months.add(alertData);
              totalAlerts++;
            }
          }

          for (var v in vehicleProvider.vehicles) {
            final name = '${v.type} - ${v.regNumber}';
            categorizeAlert('Vehicle', name, 'Insurance', v.insuranceExpiry);
            categorizeAlert('Vehicle', name, 'Fitness (FC)', v.fcExpiry);
            categorizeAlert('Vehicle', name, 'PUC', v.pucExpiry);
            categorizeAlert('Vehicle', name, 'AdBlue', v.adBlueExpiry);
            categorizeAlert('Vehicle', name, 'Tax', v.taxExpiry);
            categorizeAlert('Vehicle', name, 'Next Service', v.nextServiceDate);
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildNavigationTile(
                context,
                title: 'Alerts',
                icon: Icons.warning_amber_rounded,
                color: Colors.redAccent,
                count: totalAlerts,
                isBlinking: _isAlertBlinking,
                onTap: () async {
                  // Capture blinking state to pass to details
                  final wasBlinking = _isAlertBlinking;
                  await _markAsOpenedToday();
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UpdatesDetailScreen(
                        title: 'Alerts',
                        child: _buildAlertsTabContent(expired, thisMonth, next3Months, wasBlinking),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildNavigationTile(
                context,
                title: 'Vehicle On Road',
                icon: Icons.fire_truck,
                color: Colors.green,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => UpdatesDetailScreen(title: 'Vehicle On Road', child: _buildVehicleOnRoadTab(vehicleProvider))));
                },
              ),
              const SizedBox(height: 12),
              _buildNavigationTile(
                context,
                title: 'Vehicle Off Road',
                icon: Icons.car_crash,
                color: Colors.orange,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => UpdatesDetailScreen(title: 'Vehicle Off Road', child: _buildVehicleOffRoadTab(vehicleProvider))));
                },
              ),
              const SizedBox(height: 12),
              _buildNavigationTile(
                context,
                title: 'Equipment On Road',
                icon: Icons.handyman,
                color: Colors.blue,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => UpdatesDetailScreen(title: 'Equipment On Road', child: _buildEquipmentOnRoadTab(equipmentProvider))));
                },
              ),
              const SizedBox(height: 12),
              _buildNavigationTile(
                context,
                title: 'Equipment Off Road',
                icon: Icons.build_circle,
                color: Colors.brown,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => UpdatesDetailScreen(title: 'Equipment Off Road', child: _buildEquipmentOffRoadTab(equipmentProvider))));
                },
              ),
              const SizedBox(height: 12),
              _buildNavigationTile(
                context,
                title: 'Condemnation',
                icon: Icons.delete_forever,
                color: Colors.grey,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const UpdatesDetailScreen(title: 'Condemnation', child: Center(child: Text('Coming soon', style: TextStyle(color: Colors.white54))))));
                },
              ),
              const SizedBox(height: 12),
              _buildNavigationTile(
                context,
                title: 'Voucher Details',
                icon: Icons.receipt_long,
                color: Colors.amber,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const UpdatesDetailScreen(title: 'Voucher Details', child: Center(child: Text('Coming soon', style: TextStyle(color: Colors.white54))))));
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNavigationTile(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap, int? count, bool isBlinking = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (count != null)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: BlinkingBadge(
                  count: count,
                  isBlinking: isBlinking,
                  color: color,
                ),
              ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // ALERTS DETAIL
  // --------------------------------------------------------------------------
  Widget _buildAlertsTabContent(List<Map<String, dynamic>> expired, List<Map<String, dynamic>> thisMonth, List<Map<String, dynamic>> next3Months, bool isBlinking) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAlertCategoryTable('Already Expired', expired, Colors.redAccent, isBlinking),
        const SizedBox(height: 24),
        _buildAlertCategoryTable('This Month', thisMonth, Colors.orangeAccent, isBlinking),
        const SizedBox(height: 24),
        _buildAlertCategoryTable('Within Three Months', next3Months, Colors.yellow, isBlinking),
      ],
    );
  }

  Widget _buildAlertCategoryTable(String title, List<Map<String, dynamic>> alerts, Color color, bool isBlinking) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            BlinkingBadge(count: alerts.length, isBlinking: isBlinking, color: color),
          ],
        ),
        const SizedBox(height: 8),
        if (alerts.isEmpty)
          const Text('No items in this category.', style: TextStyle(color: Colors.white54))
        else
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
                dataTextStyle: const TextStyle(color: Colors.white),
                columns: const [
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Name / Reg No')),
                  DataColumn(label: Text('Alert Detail')),
                  DataColumn(label: Text('Expiry Date')),
                ],
                rows: alerts.map((a) {
                  return DataRow(cells: [
                    DataCell(Text(a['itemType'])),
                    DataCell(Text(a['name'])),
                    DataCell(Text(a['alertType'])),
                    DataCell(Text(DateFormat('dd MMM yyyy').format(a['date'] as DateTime))),
                  ]);
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // VEHICLE ON ROAD
  // --------------------------------------------------------------------------
  Widget _buildVehicleOnRoadTab(VehicleProvider provider) {
    final onRoad = provider.vehicles.where((v) =>
        v.status.toUpperCase() != 'OFF ROAD' &&
        v.status.toUpperCase() != 'CONDEMNED').toList();
    return _buildVehicleTable(onRoad, showReason: false);
  }

  // --------------------------------------------------------------------------
  // VEHICLE OFF ROAD
  // --------------------------------------------------------------------------
  Widget _buildVehicleOffRoadTab(VehicleProvider provider) {
    final offRoad = provider.vehicles.where((v) => v.status.toUpperCase() == 'OFF ROAD').toList();
    return _buildVehicleTable(offRoad, showReason: true);
  }

  Widget _buildVehicleTable(List<VehicleModel> vehicles, {required bool showReason}) {
    if (vehicles.isEmpty) {
      return const Center(child: Text('No vehicles found.', style: TextStyle(color: Colors.white54)));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
            dataTextStyle: const TextStyle(color: Colors.white),
            columns: [
              const DataColumn(label: Text('Vehicle Name')),
              const DataColumn(label: Text('Reg Number')),
              const DataColumn(label: Text('Current Odometer')),
              const DataColumn(label: Text('Fuel Details')),
              if (showReason) const DataColumn(label: Text('Reason (Off Road)')),
            ],
            rows: vehicles.map((v) {
              String reason = '';
              if (showReason && v.breakdowns.isNotEmpty) {
                final sorted = List.from(v.breakdowns);
                sorted.sort((a, b) => (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));
                reason = sorted.first.details;
              }
              return DataRow(cells: [
                DataCell(Text(v.type)),
                DataCell(Text(v.regNumber)),
                DataCell(Text('${v.currentOdometer.toStringAsFixed(1)} KM')),
                DataCell(Text('${v.currentFuelInTank.toStringAsFixed(1)} L')),
                if (showReason) DataCell(Text(reason)),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // EQUIPMENT ON ROAD
  // --------------------------------------------------------------------------
  Widget _buildEquipmentOnRoadTab(EquipmentProvider provider) {
    final heads = provider.equipments.where((h) => h.serviceableQty > 0).toList();
    if (heads.isEmpty) return const Center(child: Text('No serviceable equipment found.', style: TextStyle(color: Colors.white54)));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
            dataTextStyle: const TextStyle(color: Colors.white),
            columns: const [
              DataColumn(label: Text('Equipment Name')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Serviceable Qty')),
            ],
            rows: heads.map((h) {
              return DataRow(cells: [
                DataCell(Text(h.name)),
                DataCell(Text(h.category)),
                DataCell(Text('${h.serviceableQty}')),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // EQUIPMENT OFF ROAD
  // --------------------------------------------------------------------------
  Widget _buildEquipmentOffRoadTab(EquipmentProvider provider) {
    final heads = provider.equipments.where((h) => h.unserviceableQty > 0).toList();
    if (heads.isEmpty) return const Center(child: Text('No unserviceable equipment found.', style: TextStyle(color: Colors.white54)));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
            dataTextStyle: const TextStyle(color: Colors.white),
            columns: const [
              DataColumn(label: Text('Equipment Name')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Unserviceable Qty')),
            ],
            rows: heads.map((h) {
              return DataRow(cells: [
                DataCell(Text(h.name)),
                DataCell(Text(h.category)),
                DataCell(Text('${h.unserviceableQty}')),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}


// --------------------------------------------------------------------------
// BLINKING BADGE
// --------------------------------------------------------------------------
class BlinkingBadge extends StatefulWidget {
  final int count;
  final bool isBlinking;
  final Color color;

  const BlinkingBadge({
    super.key,
    required this.count,
    required this.isBlinking,
    required this.color,
  });

  @override
  State<BlinkingBadge> createState() => _BlinkingBadgeState();
}

class _BlinkingBadgeState extends State<BlinkingBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);

    if (widget.isBlinking && widget.count > 0) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(BlinkingBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBlinking && widget.count > 0) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count == 0) return const SizedBox.shrink();

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.color),
      ),
      child: Text(
        '${widget.count}',
        style: TextStyle(
          color: widget.color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );

    if (widget.isBlinking && widget.count > 0) {
      return FadeTransition(
        opacity: _animation,
        child: badge,
      );
    } else {
      return badge;
    }
  }
}

// --------------------------------------------------------------------------
// DETAIL SCREEN (Opens when a list item is tapped)
// --------------------------------------------------------------------------
class UpdatesDetailScreen extends StatelessWidget {
  final String title;
  final Widget child;

  const UpdatesDetailScreen({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: child,
    );
  }
}
