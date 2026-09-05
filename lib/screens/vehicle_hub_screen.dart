import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vehicle_provider.dart';
import '../models/vehicle_model.dart';
import '../providers/equipment_provider.dart';
import '../models/equipment_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleHubScreen extends StatefulWidget {
  const VehicleHubScreen({super.key});

  @override
  State<VehicleHubScreen> createState() => _VehicleHubScreenState();
}

class _VehicleHubScreenState extends State<VehicleHubScreen> {
  VehicleModel? _selectedVehicle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Visual Asset Hub'),
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

              final filteredVehicles = provider.vehicles.where((v) {
                final type = v.type.toLowerCase().trim();
                return type == 'foam tender' ||
                       type == 'water bowser' ||
                       type == 'mtu' ||
                       type == 'ambulance' ||
                       type == 'frv' ||
                       type == 'qrv';
              }).toList();

              if (filteredVehicles.isEmpty) {
                return const Center(child: Text('No active hub assets available', style: TextStyle(color: Colors.white)));
              }

              // Set initially selected vehicle or sync if deleted/changed
              if (filteredVehicles.isNotEmpty) {
                final exists = filteredVehicles.any((v) => v.id == _selectedVehicle?.id);
                if (!exists) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _selectedVehicle = filteredVehicles.first;
                    });
                  });
                } else {
                  // Keep it updated with latest from provider
                  final latest = filteredVehicles.firstWhere((v) => v.id == _selectedVehicle?.id);
                  if (latest.regNumber != _selectedVehicle?.regNumber || latest.status != _selectedVehicle?.status) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {
                        _selectedVehicle = latest;
                      });
                    });
                  }
                }
              } else {
                if (_selectedVehicle != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _selectedVehicle = null;
                    });
                  });
                }
              }

              return Column(
                children: [
                  const SizedBox(height: 16),
                  // Single Vehicle Card with Left & Right Nav Arrows
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Left Arrow Button
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 24),
                          onPressed: () {
                            final idx = filteredVehicles.indexWhere((v) => v.id == _selectedVehicle?.id);
                            if (idx != -1) {
                              setState(() {
                                _selectedVehicle = filteredVehicles[(idx - 1 + filteredVehicles.length) % filteredVehicles.length];
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        // Selected Vehicle Card
                        Expanded(
                          child: _selectedVehicle == null
                              ? const SizedBox(
                                  height: 140,
                                  child: Center(child: Text('No vehicle selected', style: TextStyle(color: Colors.white70))),
                                )
                              : Builder(
                                  builder: (context) {
                                    final double waterRatio = _selectedVehicle!.waterLevel.clamp(0.0, 1.0);
                                    final String waterPercent = "${(waterRatio * 100).toStringAsFixed(0)}%";

                                    final double fuelRatio = _selectedVehicle!.fuelTankCapacity > 0
                                        ? (_selectedVehicle!.currentFuelInTank / _selectedVehicle!.fuelTankCapacity).clamp(0.0, 1.0)
                                        : _selectedVehicle!.fuelLevel;
                                    final String fuelPercent = "${(fuelRatio * 100).toStringAsFixed(0)}%";

                                    return SizedBox(
                                      height: 140,
                                      child: _buildGlassCard(
                                        isSelected: true,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  _selectedVehicle!.regNumber,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                _buildStatusDot(_selectedVehicle!.status),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _selectedVehicle!.type,
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.6),
                                                fontSize: 12,
                                              ),
                                            ),
                                            const Spacer(),
                                            // Water Level Progress Bar (Clickable to edit)
                                            GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () => _showWaterLevelDialog(context, _selectedVehicle!),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.water_drop, color: Colors.lightBlue, size: 16),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: LinearProgressIndicator(
                                                        value: waterRatio,
                                                        backgroundColor: Colors.white.withOpacity(0.1),
                                                        color: Colors.lightBlue,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      waterPercent,
                                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            // Fuel Level Progress Bar (Linked to master registry)
                                            Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.local_gas_station, color: Colors.orange, size: 16),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: LinearProgressIndicator(
                                                      value: fuelRatio,
                                                      backgroundColor: Colors.white.withOpacity(0.1),
                                                      color: Colors.orange,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    fuelPercent,
                                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                ),
                        ),
                        const SizedBox(width: 8),
                        // Right Arrow Button
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 24),
                          onPressed: () {
                            final idx = filteredVehicles.indexWhere((v) => v.id == _selectedVehicle?.id);
                            if (idx != -1) {
                              setState(() {
                                _selectedVehicle = filteredVehicles[(idx + 1) % filteredVehicles.length];
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Interactive Vehicle Details
                  if (_selectedVehicle != null)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: _buildInteractiveVehicleDetails(_selectedVehicle!),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveVehicleDetails(VehicleModel vehicle) {
    if (vehicle.compartments.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Equipment Compartments',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: double.infinity,
                height: 400,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  children: [
                    // Cabin / Front Driver Panel (pointing UP)
                    Container(
                      height: 50,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          // Co-Driver (Left Side)
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_outline, color: Colors.white.withOpacity(0.25), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'CO-DRIVER',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.25),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Middle Divider
                          Container(
                            width: 1,
                            height: 25,
                            color: Colors.white.withOpacity(0.08),
                          ),
                          // Driver + Steering Wheel (Right Side)
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.amberAccent, width: 1.5),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.add, color: Colors.amberAccent, size: 8),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.person, color: Colors.amberAccent, size: 16),
                                const SizedBox(width: 6),
                                const Text(
                                  'DRIVER',
                                  style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Empty body chassis
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: const Center(
                          child: Text(
                            'No lockers configured',
                            style: TextStyle(color: Colors.white24, fontSize: 13, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final frontLockers = vehicle.compartments.where((c) => c.side == 'front').toList();
    final leftLockers = vehicle.compartments.where((c) => c.side == 'left').toList();
    final rightLockers = vehicle.compartments.where((c) => c.side == 'right').toList();
    final rearLockers = vehicle.compartments.where((c) => c.side == 'rear').toList();

    int getLockerRowIndex(String id) {
      final match = RegExp(r'\d+$').firstMatch(id);
      if (match != null) {
        final numVal = int.tryParse(match.group(0)!);
        if (numVal != null) {
          return numVal - 1;
        }
      }
      return 0;
    }

    final Map<int, CompartmentModel> leftByRow = {};
    for (var locker in leftLockers) {
      leftByRow[getLockerRowIndex(locker.id)] = locker;
    }

    final Map<int, CompartmentModel> rightByRow = {};
    for (var locker in rightLockers) {
      rightByRow[getLockerRowIndex(locker.id)] = locker;
    }

    int maxRow = -1;
    for (var idx in leftByRow.keys) {
      if (idx > maxRow) maxRow = idx;
    }
    for (var idx in rightByRow.keys) {
      if (idx > maxRow) maxRow = idx;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Equipment Compartments',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Vertical Vehicle Layout
          Center(
            child: Container(
              width: double.infinity,
              height: 480,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  // Cabin / Front Driver Panel (pointing UP - absolute front)
                  Container(
                    height: 50,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                      ),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        // Co-Driver (Left Side)
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_outline, color: Colors.white.withOpacity(0.25), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'CO-DRIVER',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.25),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Middle Divider / Partition
                        Container(
                          width: 1,
                          height: 25,
                          color: Colors.white.withOpacity(0.08),
                        ),
                        // Driver + Steering Wheel (Right Side)
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Steering Wheel Symbol
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.amberAccent, width: 1.5),
                                ),
                                child: const Center(
                                  child: Icon(Icons.add, color: Colors.amberAccent, size: 8),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.person, color: Colors.amberAccent, size: 16),
                              const SizedBox(width: 6),
                              const Text(
                                'DRIVER',
                                style: TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Front Column (full-width lockers created after driver cabin)
                  if (frontLockers.isNotEmpty) ...[
                    Column(
                      children: frontLockers.map((locker) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: SizedBox(
                            height: 65,
                            width: double.infinity,
                            child: GestureDetector(
                              onTap: () => _showLockerItemsSheet(context, vehicle, locker, isEditable: false),
                              onLongPress: () => _showLockerItemsSheet(context, vehicle, locker, isEditable: true),
                              child: _buildLockerBox(locker),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                  ],
                  const SizedBox(height: 10),
                  // Middle (Left & Right columns side-by-side - Expanded Grid)
                  if (maxRow >= 0)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: List.generate(maxRow + 1, (rowIdx) {
                          final leftLocker = leftByRow[rowIdx];
                          final rightLocker = rightByRow[rowIdx];
                          final isLast = rowIdx == maxRow;

                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: isLast ? 0.0 : 10.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: leftLocker != null
                                        ? GestureDetector(
                                            onTap: () => _showLockerItemsSheet(context, vehicle, leftLocker, isEditable: false),
                                            onLongPress: () => _showLockerItemsSheet(context, vehicle, leftLocker, isEditable: true),
                                            child: _buildLockerBox(leftLocker),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: rightLocker != null
                                        ? GestureDetector(
                                            onTap: () => _showLockerItemsSheet(context, vehicle, rightLocker, isEditable: false),
                                            onLongPress: () => _showLockerItemsSheet(context, vehicle, rightLocker, isEditable: true),
                                            child: _buildLockerBox(rightLocker),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    )
                  else
                    const Expanded(child: SizedBox.shrink()),
                  // Rear Column (bottom-most part of the vehicle)
                  if (rearLockers.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Column(
                      children: rearLockers.map((locker) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: SizedBox(
                            height: 65,
                            width: double.infinity,
                            child: GestureDetector(
                              onTap: () => _showLockerItemsSheet(context, vehicle, locker, isEditable: false),
                              onLongPress: () => _showLockerItemsSheet(context, vehicle, locker, isEditable: true),
                              child: _buildLockerBox(locker),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockerBox(CompartmentModel locker) {
    final isL1 = locker.id.toUpperCase() == 'L1';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isL1 ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isL1 ? Colors.greenAccent : Colors.white.withOpacity(0.12),
          width: isL1 ? 1.5 : 1,
        ),
        boxShadow: isL1 ? [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 6)] : null,
      ),
      child: Center(
        child: Text(
          locker.id.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, bool isSelected = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFFE53935) : Colors.white.withOpacity(0.1),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: const Color(0xFFE53935).withOpacity(0.3), blurRadius: 10)]
                : [],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildStatusDot(String status) {
    Color color;
    switch (status) {
      case 'Available':
        color = Colors.greenAccent;
        break;
      case 'On Duty':
        color = Colors.redAccent;
        break;
      case 'Maintenance':
        color = Colors.orangeAccent;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 4)],
      ),
    );
  }

  void _showWaterLevelDialog(BuildContext context, VehicleModel vehicle) {
    double tempWater = vehicle.waterLevel;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              title: const Text('Update Water Tank Level', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(tempWater * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: tempWater,
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    activeColor: Colors.lightBlue,
                    inactiveColor: Colors.white10,
                    onChanged: (val) {
                      setState(() {
                        tempWater = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPresetButton(setState, '0%', 0.0, tempWater, (newVal) {
                        setState(() {
                          tempWater = newVal;
                        });
                      }),
                      _buildPresetButton(setState, '25%', 0.25, tempWater, (newVal) {
                        setState(() {
                          tempWater = newVal;
                        });
                      }),
                      _buildPresetButton(setState, '50%', 0.5, tempWater, (newVal) {
                        setState(() {
                          tempWater = newVal;
                        });
                      }),
                      _buildPresetButton(setState, '75%', 0.75, tempWater, (newVal) {
                        setState(() {
                          tempWater = newVal;
                        });
                      }),
                      _buildPresetButton(setState, '100%', 1.0, tempWater, (newVal) {
                        setState(() {
                          tempWater = newVal;
                        });
                      }),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final updated = VehicleModel(
                      id: vehicle.id,
                      regNumber: vehicle.regNumber,
                      type: vehicle.type,
                      status: vehicle.status,
                      waterLevel: tempWater,
                      fuelLevel: vehicle.fuelLevel,
                      callSign: vehicle.callSign,
                      chassisNumber: vehicle.chassisNumber,
                      engineNumber: vehicle.engineNumber,
                      makeModel: vehicle.makeModel,
                      yearOfInduction: vehicle.yearOfInduction,
                      hasFirePump: vehicle.hasFirePump,
                      insuranceDate: vehicle.insuranceDate,
                      insuranceExpiry: vehicle.insuranceExpiry,
                      fcDate: vehicle.fcDate,
                      fcExpiry: vehicle.fcExpiry,
                      pucDate: vehicle.pucDate,
                      pucExpiry: vehicle.pucExpiry,
                      adBlueDate: vehicle.adBlueDate,
                      adBlueExpiry: vehicle.adBlueExpiry,
                      currentOdometer: vehicle.currentOdometer,
                      fuelConsumedThisFY: vehicle.fuelConsumedThisFY,
                      prevFYHistory: vehicle.prevFYHistory,
                      fuelTankCapacity: vehicle.fuelTankCapacity,
                      currentFuelInTank: vehicle.currentFuelInTank,
                      mileageReviewDate: vehicle.mileageReviewDate,
                      mileageOnRoad: vehicle.mileageOnRoad,
                      fixedDSConsumption: vehicle.fixedDSConsumption,
                      lastServiceDate: vehicle.lastServiceDate,
                      nextServiceAtKM: vehicle.nextServiceAtKM,
                      nextServiceDate: vehicle.nextServiceDate,
                      lastPumpServiceDate: vehicle.lastPumpServiceDate,
                      nextPumpServiceDate: vehicle.nextPumpServiceDate,
                      breakdowns: vehicle.breakdowns,
                      repairHistory: vehicle.repairHistory,
                      tempIssueHistory: vehicle.tempIssueHistory,
                      inventory: vehicle.inventory,
                      compartments: vehicle.compartments,
                    );

                    await context.read<VehicleProvider>().updateVehicle(updated);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Water Tank Level updated successfully!'), backgroundColor: Colors.green),
                      );
                    }
                  },
                  child: const Text('SAVE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPresetButton(StateSetter dialogSetState, String label, double val, double currentVal, Function(double) onSelected) {
    final isSelected = (currentVal - val).abs() < 0.01;
    return InkWell(
      onTap: () => onSelected(val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.lightBlue.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          border: Border.all(color: isSelected ? Colors.lightBlue : Colors.white10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.lightBlue : Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showLockerItemsSheet(BuildContext context, VehicleModel vehicle, CompartmentModel locker, {required bool isEditable}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LockerItemsSheet(vehicle: vehicle, locker: locker, isEditable: isEditable),
    );
  }
}

class LockerItemsSheet extends StatefulWidget {
  final VehicleModel vehicle;
  final CompartmentModel locker;
  final bool isEditable;
  const LockerItemsSheet({
    super.key,
    required this.vehicle,
    required this.locker,
    required this.isEditable,
  });

  @override
  State<LockerItemsSheet> createState() => _LockerItemsSheetState();
}

class _LockerItemsSheetState extends State<LockerItemsSheet> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<LockerItemModel> _items = [];
  bool _isAdding = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String? _selectedEquipName;
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _items.addAll(widget.locker.items);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _qtyController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _saveToDatabase() async {
    final updatedCompartments = widget.vehicle.compartments.map((comp) {
      if (comp.id == widget.locker.id) {
        return CompartmentModel(
          id: comp.id,
          label: comp.label,
          side: comp.side,
          items: _items,
        );
      }
      return comp;
    }).toList();

    final updatedVehicle = VehicleModel(
      id: widget.vehicle.id,
      regNumber: widget.vehicle.regNumber,
      type: widget.vehicle.type,
      status: widget.vehicle.status,
      waterLevel: widget.vehicle.waterLevel,
      fuelLevel: widget.vehicle.fuelLevel,
      callSign: widget.vehicle.callSign,
      chassisNumber: widget.vehicle.chassisNumber,
      engineNumber: widget.vehicle.engineNumber,
      makeModel: widget.vehicle.makeModel,
      yearOfInduction: widget.vehicle.yearOfInduction,
      hasFirePump: widget.vehicle.hasFirePump,
      insuranceDate: widget.vehicle.insuranceDate,
      insuranceExpiry: widget.vehicle.insuranceExpiry,
      fcDate: widget.vehicle.fcDate,
      fcExpiry: widget.vehicle.fcExpiry,
      pucDate: widget.vehicle.pucDate,
      pucExpiry: widget.vehicle.pucExpiry,
      adBlueDate: widget.vehicle.adBlueDate,
      adBlueExpiry: widget.vehicle.adBlueExpiry,
      currentOdometer: widget.vehicle.currentOdometer,
      fuelConsumedThisFY: widget.vehicle.fuelConsumedThisFY,
      prevFYHistory: widget.vehicle.prevFYHistory,
      fuelTankCapacity: widget.vehicle.fuelTankCapacity,
      currentFuelInTank: widget.vehicle.currentFuelInTank,
      mileageReviewDate: widget.vehicle.mileageReviewDate,
      mileageOnRoad: widget.vehicle.mileageOnRoad,
      fixedDSConsumption: widget.vehicle.fixedDSConsumption,
      lastServiceDate: widget.vehicle.lastServiceDate,
      nextServiceAtKM: widget.vehicle.nextServiceAtKM,
      nextServiceDate: widget.vehicle.nextServiceDate,
      lastPumpServiceDate: widget.vehicle.lastPumpServiceDate,
      nextPumpServiceDate: widget.vehicle.nextPumpServiceDate,
      breakdowns: widget.vehicle.breakdowns,
      repairHistory: widget.vehicle.repairHistory,
      tempIssueHistory: widget.vehicle.tempIssueHistory,
      inventory: widget.vehicle.inventory,
      compartments: updatedCompartments,
    );

    await context.read<VehicleProvider>().updateVehicle(updatedVehicle);
  }

  Future<bool> _addItem(LockerItemModel newItem) async {
    final allEquipments = context.read<EquipmentProvider>().equipments;
    final equip = allEquipments.firstWhere(
      (e) => e.name.toLowerCase() == newItem.name.toLowerCase(),
      orElse: () => throw Exception('Equipment not found in Master.'),
    );

    if (newItem.qty > equip.serviceableQty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient stock. Only ${equip.serviceableQty} available in store.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return false;
    }

    setState(() {
      _items.add(newItem);
      _listKey.currentState?.insertItem(_items.length - 1, duration: const Duration(milliseconds: 300));
    });

    await FirebaseFirestore.instance
        .collection('equipment_heads')
        .doc(equip.id)
        .update({'serviceableQty': FieldValue.increment(-newItem.qty)});

    await _saveToDatabase();
    return true;
  }

  Future<void> _removeItem(int index) async {
    final removedItem = _items[index];
    setState(() {
      _items.removeAt(index);
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => _buildItemRow(removedItem, animation, index, isRemoving: true),
        duration: const Duration(milliseconds: 250),
      );
    });

    final allEquipments = context.read<EquipmentProvider>().equipments;
    final EquipmentHead? equip = allEquipments.cast<EquipmentHead?>().firstWhere(
      (e) => e!.name.toLowerCase() == removedItem.name.toLowerCase(),
      orElse: () => null,
    );

    if (equip != null) {
      await FirebaseFirestore.instance
          .collection('equipment_heads')
          .doc(equip.id)
          .update({'serviceableQty': FieldValue.increment(removedItem.qty)});
    }

    await _saveToDatabase();
  }

  Future<bool> _updateItem(int index, LockerItemModel updatedItem) async {
    final oldItem = _items[index];
    final diff = updatedItem.qty - oldItem.qty;
    if (diff == 0) {
      setState(() {
        _items[index] = updatedItem;
      });
      await _saveToDatabase();
      return true;
    }

    final allEquipments = context.read<EquipmentProvider>().equipments;
    final equip = allEquipments.firstWhere(
      (e) => e.name.toLowerCase() == updatedItem.name.toLowerCase(),
      orElse: () => throw Exception('Equipment not found in Master.'),
    );

    if (diff > 0 && diff > equip.serviceableQty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient stock. Only ${equip.serviceableQty} more available in store.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return false;
    }

    setState(() {
      _items[index] = updatedItem;
    });

    await FirebaseFirestore.instance
        .collection('equipment_heads')
        .doc(equip.id)
        .update({'serviceableQty': FieldValue.increment(-diff)});

    await _saveToDatabase();
    return true;
  }

  void _showEditDialog(LockerItemModel item, int index) {
    final qtyController = TextEditingController(text: item.qty.toString());
    final remarksController = TextEditingController(text: item.remarks);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          title: Text('Edit ${item.name}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.02),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarksController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Remarks (Optional)',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.02),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final qty = int.tryParse(qtyController.text) ?? 1;
                final success = await _updateItem(index, LockerItemModel(
                  name: item.name,
                  qty: qty,
                  remarks: remarksController.text.trim(),
                ));
                if (success && context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildItemRow(LockerItemModel item, Animation<double> animation, int index, {bool isRemoving = false}) {
    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: GestureDetector(
            onLongPress: (!widget.isEditable || isRemoving) ? null : () => _showEditDialog(item, index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (item.remarks.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.remarks,
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Quantity Shifted to Right Side
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.withOpacity(0.2)),
                    ),
                    child: Text(
                      'Qty: ${item.qty}',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  if (widget.isEditable && !isRemoving) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => _removeItem(index),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allEquipments = context.watch<EquipmentProvider>().equipments;
    final searchQuery = _searchController.text.trim().toLowerCase();

    final List<EquipmentHead> suggestions = allEquipments.where((e) {
      final nameMatch = e.name.toLowerCase().contains(searchQuery);
      final alreadyAdded = _items.any((item) => item.name.toLowerCase() == e.name.toLowerCase());
      return nameMatch && !alreadyAdded;
    }).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.locker.id.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  if (widget.isEditable)
                    IconButton(
                      icon: Icon(_isAdding ? Icons.close : Icons.add_circle, color: Colors.amber, size: 28),
                      onPressed: () {
                        setState(() {
                          _isAdding = !_isAdding;
                          _selectedEquipName = null;
                          _searchController.clear();
                          _qtyController.text = '1';
                          _remarksController.clear();
                        });
                        if (_isAdding) {
                          _searchFocusNode.requestFocus();
                        }
                      },
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),

            const Divider(color: Colors.white10),

            // Interactive content
            Expanded(
              child: Stack(
                children: [
                  // Scrollable List of existing items
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _items.isEmpty
                        ? const Center(
                            child: Text(
                              'No items inside this locker',
                              style: TextStyle(color: Colors.white30, fontStyle: FontStyle.italic),
                            ),
                          )
                        : AnimatedList(
                            key: _listKey,
                            initialItemCount: _items.length,
                            itemBuilder: (context, index, animation) {
                              return _buildItemRow(_items[index], animation, index);
                            },
                          ),
                  ),

                  // Add Item Search Autocomplete Overlay
                  if (_isAdding)
                    Positioned.fill(
                      child: Container(
                        color: const Color(0xFF141414).withOpacity(0.98),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Search Equipment Master',
                              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),

                            // Search Box
                            TextFormField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Enter equipment name...',
                                hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                                prefixIcon: const Icon(Icons.search, color: Colors.white30, size: 20),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                                        onPressed: () {
                                          setState(() {
                                            _searchController.clear();
                                            _selectedEquipName = null;
                                          });
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.04),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  // Trigger suggestions update
                                });
                              },
                            ),

                            const SizedBox(height: 12),

                            // Suggestion Dropdown List (if no selection is made yet)
                            if (_selectedEquipName == null)
                              Expanded(
                                child: suggestions.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No matching items in charge.\nAdd items to Equipment module first.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.white24, fontSize: 13, height: 1.4),
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: suggestions.length,
                                        itemBuilder: (context, idx) {
                                          final equip = suggestions[idx];
                                          final availQty = equip.serviceableQty;
                                          return ListTile(
                                            title: Text(equip.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                            subtitle: Text(equip.category.split(' (')[0], style: const TextStyle(color: Colors.white30, fontSize: 11)),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: availQty > 0
                                                        ? Colors.green.withOpacity(0.15)
                                                        : Colors.red.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(
                                                      color: availQty > 0
                                                          ? Colors.greenAccent.withOpacity(0.4)
                                                          : Colors.redAccent.withOpacity(0.4),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'Avail: $availQty',
                                                    style: TextStyle(
                                                      color: availQty > 0 ? Colors.greenAccent : Colors.redAccent,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 12),
                                              ],
                                            ),
                                            onTap: () {
                                              setState(() {
                                                _selectedEquipName = equip.name;
                                                _searchController.text = equip.name;
                                              });
                                            },
                                          );
                                        },
                                      ),
                              ),

                            // Qty & Remarks details (once suggestion is selected)
                            if (_selectedEquipName != null) ...[
                              Builder(builder: (context) {
                                final selectedEquip = allEquipments.cast<EquipmentHead?>().firstWhere(
                                  (e) => e!.name.toLowerCase() == _selectedEquipName!.toLowerCase(),
                                  orElse: () => null,
                                );
                                final maxAvail = selectedEquip?.serviceableQty ?? 0;
                                final enteredQty = int.tryParse(_qtyController.text) ?? 0;
                                final isOverLimit = enteredQty > maxAvail;

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.02),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isOverLimit
                                          ? Colors.redAccent.withOpacity(0.4)
                                          : Colors.white.withOpacity(0.05),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Selected: $_selectedEquipName',
                                              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: maxAvail > 0
                                                  ? Colors.green.withOpacity(0.12)
                                                  : Colors.red.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: maxAvail > 0
                                                    ? Colors.greenAccent.withOpacity(0.4)
                                                    : Colors.redAccent.withOpacity(0.4),
                                              ),
                                            ),
                                            child: Text(
                                              'Available: $maxAvail',
                                              style: TextStyle(
                                                color: maxAvail > 0 ? Colors.greenAccent : Colors.redAccent,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _qtyController,
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(
                                          color: isOverLimit ? Colors.redAccent : Colors.white,
                                        ),
                                        onChanged: (_) => setState(() {}),
                                        decoration: InputDecoration(
                                          labelText: 'Quantity',
                                          labelStyle: TextStyle(
                                            color: isOverLimit ? Colors.redAccent : Colors.white54,
                                            fontSize: 12,
                                          ),
                                          filled: true,
                                          fillColor: isOverLimit
                                              ? Colors.red.withOpacity(0.06)
                                              : Colors.white.withOpacity(0.02),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: BorderSide(
                                              color: isOverLimit ? Colors.redAccent : Colors.white24,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: BorderSide(
                                              color: isOverLimit
                                                  ? Colors.redAccent.withOpacity(0.6)
                                                  : Colors.white12,
                                            ),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          suffixIcon: isOverLimit
                                              ? const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20)
                                              : null,
                                          helperText: isOverLimit
                                              ? '⚠  Exceeds available stock ($maxAvail)'
                                              : 'Max: $maxAvail',
                                          helperStyle: TextStyle(
                                            color: isOverLimit ? Colors.redAccent : Colors.white30,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _remarksController,
                                        style: const TextStyle(color: Colors.white),
                                        decoration: InputDecoration(
                                          labelText: 'Remarks (Optional)',
                                          labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(0.02),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isOverLimit ? Colors.red.shade800 : Colors.amber,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onPressed: isOverLimit
                                              ? () {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        '⚠  Only $maxAvail unit${maxAvail == 1 ? '' : 's'} available in store. Please enter a valid quantity.',
                                                      ),
                                                      backgroundColor: Colors.redAccent,
                                                      behavior: SnackBarBehavior.floating,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                    ),
                                                  );
                                                }
                                              : () {
                                                  final qty = int.tryParse(_qtyController.text) ?? 1;
                                                  _addItem(LockerItemModel(
                                                    name: _selectedEquipName!,
                                                    qty: qty,
                                                    remarks: _remarksController.text.trim(),
                                                  ));
                                                  setState(() {
                                                    _isAdding = false;
                                                    _selectedEquipName = null;
                                                    _searchController.clear();
                                                    _remarksController.clear();
                                                    _qtyController.text = '1';
                                                  });
                                                },
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              if (isOverLimit) ...[
                                                const Icon(Icons.block, size: 16),
                                                const SizedBox(width: 6),
                                                const Text('EXCEEDS STOCK', style: TextStyle(fontWeight: FontWeight.bold)),
                                              ] else ...[
                                                const Icon(Icons.add, size: 16, color: Colors.black),
                                                const SizedBox(width: 6),
                                                const Text('ADD TO LOCKER', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
