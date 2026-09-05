import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/auth_provider.dart';
import '../providers/vehicle_provider.dart';
import '../providers/incident_provider.dart';
import '../providers/duty_provider.dart';
import '../providers/manpower_provider.dart';
import '../models/vehicle_model.dart';
import 'login_screen.dart';
import 'duty_screen.dart';
import 'vehicle_hub_screen.dart';
import 'admin_hub_screen.dart';
import 'incident_report_screen.dart';
import '../widgets/pulse_marker.dart';
import '../models/incident_model.dart';
import '../models/duty_register_model.dart';
import '../services/access_control.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Station Location - Meenchanda (approx)
  final LatLng _stationLocation = const LatLng(11.2189, 75.7925);
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DutyProvider>().fetchDutyRegisters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // 1. Interactive Map Background
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _stationLocation,
              initialZoom: 14.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.keralafiremda.watchroom',
              ),
              MarkerLayer(
                markers: _buildMapMarkers(context),
              ),
            ],
          ),

          // 2. Top App Bar Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopGlassBar(),
          ),

          // 3. Quick Actions & Summary Window Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick Actions row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildFloatingAction(
                          icon: Icons.add_alert,
                          label: 'New Incident',
                          color: Colors.orange,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const IncidentReportScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFloatingAction(
                          icon: Icons.calendar_month,
                          label: 'Duty Roster',
                          color: Colors.blue,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DutyScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Summary Window
                _buildSummaryWindow(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMapMarkers(BuildContext context) {
    final incidentProvider = context.watch<IncidentProvider>();
    final activeIncidents = incidentProvider.activeIncidents;

    List<Marker> markers = [];

    // 1. Station Marker
    markers.add(
      Marker(
        point: _stationLocation,
        width: 60,
        height: 60,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFD32F2F).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.local_fire_department, color: Color(0xFFE53935), size: 36),
        ),
      ),
    );

    // 2. Active Incidents and SFRO/Vehicle Locations
    for (var incident in activeIncidents) {
      // Incident Pulse Marker
      markers.add(
        Marker(
          point: LatLng(incident.latitude, incident.longitude),
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () => _showIncidentDetails(context, incident),
            child: PulseMarker(
              pulseColor: Colors.orangeAccent,
              size: 50,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.whatshot, color: Colors.orangeAccent, size: 28),
              ),
            ),
          ),
        ),
      );

      // SFRO / Responding Vehicle Marker (if different from incident loc, though typically they head there)
      if (incident.sfroLatitude != null && incident.sfroLongitude != null) {
        markers.add(
          Marker(
            point: LatLng(incident.sfroLatitude!, incident.sfroLongitude!),
            width: 24,
            height: 24,
            child: _buildDotMarker(Colors.redAccent),
          ),
        );
      }
    }

    return markers;
  }

  void _showIncidentDetails(BuildContext context, IncidentModel incident) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Incident Details',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text('Type: ${incident.type}', style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Address: ${incident.address}', style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await context.read<IncidentProvider>().resolveIncident(incident.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Mark as Resolved', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showVehiclesList(BuildContext context, List<VehicleModel> vehicles, DutyRegisterModel? todayRegister) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24.0, right: 24.0, top: 24.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Vehicles List', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              if (vehicles.isEmpty)
                const Padding(padding: EdgeInsets.only(bottom: 24), child: Text('No vehicles available.', style: TextStyle(color: Colors.white70)))
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: vehicles.length,
                    itemBuilder: (context, index) {
                      final v = vehicles[index];
                      bool isAvailable = v.status.toUpperCase() == 'READY';
                      String displayStatus = v.status;
                      
                      if (todayRegister != null) {
                        try {
                          final va = todayRegister.vehicleAssignments.firstWhere((a) {
                             String aName = a.vehicleName.toUpperCase();
                             String vReg = v.regNumber.toUpperCase();
                             String vCall = v.callSign.toUpperCase();
                             String vType = v.type.toUpperCase();
                             
                             String normAName = aName.replaceAll(' ', '').replaceAll('-', '');
                             String normVReg = vReg.replaceAll(' ', '').replaceAll('-', '');
                             
                             return normAName.contains(normVReg) || 
                                    (vCall.isNotEmpty && (aName.contains(vCall) || vCall.contains(aName))) ||
                                    (vType.isNotEmpty && (aName.contains(vType) || vType.contains(aName)));
                          });
                          if (va.isOffRoad || va.remarks == 'OF THE ROAD' || va.remarks.startsWith('OF THE ROAD')) {
                            isAvailable = false;
                            displayStatus = 'OFF ROAD (via Duty Register)';
                          } else if (va.isAttached) {
                            isAvailable = false;
                            displayStatus = 'ATTACHED AT ${va.remarks}';
                          }
                        } catch (_) {}
                      }

                      return Card(
                        color: const Color(0xFF2C2C2C),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: Icon(Icons.fire_truck, color: isAvailable ? Colors.greenAccent : Colors.redAccent),
                          title: Text(v.callSign.isNotEmpty ? '${v.callSign} (${v.regNumber})' : v.regNumber, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('Status: $displayStatus', style: TextStyle(color: isAvailable ? Colors.greenAccent : Colors.redAccent)),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showPersonnelList(BuildContext context, DutyRegisterModel? todayRegister, int overallCount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24.0, right: 24.0, top: 24.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Personnel on Duty ($overallCount)', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              if (todayRegister == null)
                const Padding(padding: EdgeInsets.only(bottom: 24), child: Text('No personnel list found for today.', style: TextStyle(color: Colors.white70)))
              else
                Builder(
                  builder: (context) {
                    Set<String> uniqueIds = {};
                    Set<String> ccvIds = {};
                    
                    for (var v in todayRegister.vehicleAssignments) {
                       List<String> assigned = [
                          ...v.sfro.split(','),
                          ...v.fro.split(','),
                          ...v.khg.split(','),
                          ...v.froD.split(',')
                       ].map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                       
                       if (v.vehicleName.toUpperCase().contains('CCV')) {
                         ccvIds.addAll(assigned);
                         continue;
                       }
                       uniqueIds.addAll(assigned);
                    }
                    uniqueIds.addAll(todayRegister.phoneDutyIds);
                    uniqueIds.addAll(todayRegister.messengerIds);
                    uniqueIds.addAll(todayRegister.sentryDutyIds);
                    uniqueIds.addAll(todayRegister.controlRoomIds);
                    uniqueIds.addAll(todayRegister.specialDutyIds);
                    uniqueIds.addAll(todayRegister.trainingOverrideIds);
                    
                    uniqueIds.removeAll(ccvIds);
                    
                    final filteredAssignments = todayRegister.vehicleAssignments
                        .where((va) => !va.vehicleName.toUpperCase().contains('CCV'))
                        .toList();

                    return Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('All ${uniqueIds.length} Unique IDs:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) {
                                List<String> sortedIds = uniqueIds.toList();
                                final personnelList = context.read<ManpowerProvider>().personnelList;

                                sortedIds.sort((a, b) {
                                  int indexA = personnelList.indexWhere((p) => p.idNumber == a);
                                  int indexB = personnelList.indexWhere((p) => p.idNumber == b);
                                  
                                  if (indexA == -1) indexA = 999999;
                                  if (indexB == -1) indexB = 999999;
                                  
                                  return indexA.compareTo(indexB);
                                });

                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: sortedIds.map((id) => Chip(
                                    label: Text(id, style: const TextStyle(fontSize: 12, color: Colors.white)),
                                    backgroundColor: const Color(0xFF2C2C2C),
                                    side: BorderSide.none,
                                    padding: EdgeInsets.zero,
                                  )).toList(),
                                );
                              }
                            ),
                            const SizedBox(height: 24),
                            const Text('Vehicle Assignments:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                            const SizedBox(height: 12),
                            if (filteredAssignments.isEmpty)
                               const Text('No vehicles assigned.', style: TextStyle(color: Colors.white70))
                            else
                               ListView.builder(
                                 physics: const NeverScrollableScrollPhysics(),
                                 shrinkWrap: true,
                                 itemCount: filteredAssignments.length,
                                 itemBuilder: (context, index) {
                                   final va = filteredAssignments[index];
                                   final personnelList = [];
                                   if (va.sfro.isNotEmpty) personnelList.add('SFRO: ${va.sfro}');
                                   if (va.fro.isNotEmpty) personnelList.add('FRO: ${va.fro}');
                                   if (va.khg.isNotEmpty) personnelList.add('KHG: ${va.khg}');
                                   if (va.froD.isNotEmpty) personnelList.add('FRO(D): ${va.froD}');
                                   
                                   String personnelText = personnelList.join('\n');
                                   if (va.isOffRoad) {
                                       personnelText = 'OFF ROAD';
                                   } else if (personnelList.isEmpty) {
                                       personnelText = 'No personnel assigned';
                                   }

                                   return Card(
                                     color: const Color(0xFF2C2C2C),
                                     margin: const EdgeInsets.only(bottom: 12),
                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                     child: ListTile(
                                       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                       title: Text(va.vehicleName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                       subtitle: Padding(
                                         padding: const EdgeInsets.only(top: 8.0),
                                         child: Text(personnelText, style: const TextStyle(color: Colors.white70, height: 1.5)),
                                       ),
                                     ),
                                   );
                                 },
                               ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showActiveIncidentsList(BuildContext context, List<IncidentModel> activeIncidents) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24.0, right: 24.0, top: 24.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Active Incidents List',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              if (activeIncidents.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 24.0),
                  child: Text('No active incidents at the moment.', style: TextStyle(color: Colors.white70)),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: activeIncidents.length,
                    itemBuilder: (context, index) {
                      final incident = activeIncidents[index];
                      return Card(
                        color: const Color(0xFF2C2C2C),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: const Icon(Icons.whatshot, color: Colors.orangeAccent),
                          title: Text(incident.type, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(incident.address, style: const TextStyle(color: Colors.white70)),
                          trailing: IconButton(
                            icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                            onPressed: () async {
                              await context.read<IncidentProvider>().resolveIncident(incident.id);
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _mapController.move(LatLng(incident.latitude, incident.longitude), 15.0);
                          },
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDotMarker(Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.6), blurRadius: 8, spreadRadius: 2)
        ],
      ),
    );
  }

  Widget _buildTopGlassBar() {
    final authProvider = context.watch<AuthProvider>();
    final manpowerProvider = context.watch<ManpowerProvider>();
    String loginText = '';
    
    if (authProvider.linkedPersonId != null && authProvider.linkedPersonId!.isNotEmpty) {
      try {
        final person = manpowerProvider.personnelList.firstWhere((p) => p.id == authProvider.linkedPersonId);
        loginText = 'Login by : ${person.designation} ${person.name}';
      } catch (_) {}
    } else if (authProvider.isAdmin) {
      loginText = 'Login by : Admin';
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            bottom: 16,
            left: 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A).withOpacity(0.7),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kerala Fire & Rescue Station',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Meenchanda',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (loginText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          loginText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white70),
                onPressed: () async {
                  await context.read<AuthProvider>().signOut();
                  if (mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryWindow() {
    final vehicleProvider = context.watch<VehicleProvider>();
    final incidentProvider = context.watch<IncidentProvider>();
    final dutyProvider = context.watch<DutyProvider>();
    final manpowerProvider = context.watch<ManpowerProvider>();
    
    int activeIncidentsCount = incidentProvider.activeIncidents.length;
    
    int personnelCount = 0;
    DutyRegisterModel? todayRegisterModel;
    if (dutyProvider.registers.isNotEmpty) {
      final activeDate = AccessControl.getActiveDutyDate();
      
      var matches = dutyProvider.registers.where((r) => 
          r.date.year == activeDate.year && 
          r.date.month == activeDate.month && 
          r.date.day == activeDate.day);
          
      if (matches.isNotEmpty) {
        todayRegisterModel = matches.first;
      } else if (dutyProvider.registers.isNotEmpty) {
        // Fallback to the most recent register if today's hasn't been created yet
        todayRegisterModel = dutyProvider.registers.first;
      }
      
      if (todayRegisterModel != null) {
        Set<String> uniqueIds = {};
        Set<String> ccvIds = {};
        
        for (var v in todayRegisterModel.vehicleAssignments) {
           List<String> assigned = [
              ...v.sfro.split(','),
              ...v.fro.split(','),
              ...v.khg.split(','),
              ...v.froD.split(',')
           ].map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
           
           if (v.vehicleName.toUpperCase().contains('CCV')) {
             ccvIds.addAll(assigned);
             continue; // Exclude CCV personnel vehicle row
           }
           uniqueIds.addAll(assigned);
        }
        uniqueIds.addAll(todayRegisterModel.phoneDutyIds);
        uniqueIds.addAll(todayRegisterModel.messengerIds);
        uniqueIds.addAll(todayRegisterModel.sentryDutyIds);
        uniqueIds.addAll(todayRegisterModel.controlRoomIds);
        uniqueIds.addAll(todayRegisterModel.specialDutyIds);
        uniqueIds.addAll(todayRegisterModel.trainingOverrideIds);
        
        uniqueIds.removeAll(ccvIds); // Strictly exclude anyone assigned to CCV
        
        personnelCount = uniqueIds.length;
      } else {
        personnelCount = 0;
      }
    } else {
      personnelCount = 0; 
    }

    int totalVehicles = vehicleProvider.vehicles.length;
    int availableVehicles = 0;
    for (var v in vehicleProvider.vehicles) {
      bool isAvail = v.status.toUpperCase() == 'READY';
      if (todayRegisterModel != null) {
        try {
          final va = todayRegisterModel.vehicleAssignments.firstWhere((a) {
             String aName = a.vehicleName.toUpperCase();
             String vReg = v.regNumber.toUpperCase();
             String vCall = v.callSign.toUpperCase();
             String vType = v.type.toUpperCase();
             
             String normAName = aName.replaceAll(' ', '').replaceAll('-', '');
             String normVReg = vReg.replaceAll(' ', '').replaceAll('-', '');
             
             return normAName.contains(normVReg) || 
                    (vCall.isNotEmpty && (aName.contains(vCall) || vCall.contains(aName))) ||
                    (vType.isNotEmpty && (aName.contains(vType) || vType.contains(aName)));
          });
          if (va.isOffRoad || va.remarks == 'OF THE ROAD' || va.remarks.startsWith('OF THE ROAD')) {
            isAvail = false;
          } else if (va.isAttached) {
            isAvail = false;
          }
        } catch (_) {}
      }
      if (isAvail) availableVehicles++;
    }

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A).withOpacity(0.85),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Situational Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem(
                    icon: Icons.fire_truck,
                    value: '$availableVehicles/$totalVehicles',
                    label: 'Vehicles Available',
                    color: Colors.greenAccent,
                    onTap: () => _showVehiclesList(context, vehicleProvider.vehicles, todayRegisterModel),
                  ),
                  Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
                  _buildSummaryItem(
                    icon: Icons.people_alt,
                    value: '$personnelCount',
                    label: 'Personnel on Duty',
                    color: Colors.blueAccent,
                    onTap: () => _showPersonnelList(context, todayRegisterModel, personnelCount),
                  ),
                  Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
                  _buildSummaryItem(
                    icon: Icons.whatshot,
                    value: '$activeIncidentsCount',
                    label: 'Active Incidents',
                    color: Colors.orangeAccent,
                    onTap: () => _showActiveIncidentsList(context, incidentProvider.activeIncidents),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Links to other hubs
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.build_circle, size: 18),
                      label: const Text('Asset Hub'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const VehicleHubScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.admin_panel_settings, size: 18),
                      label: const Text('Administration'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminHubScreen()),
                        );
                      },
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
