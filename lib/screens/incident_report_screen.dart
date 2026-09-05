import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/incident_model.dart';
import '../providers/incident_provider.dart';

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedType;
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  LatLng _selectedLocation = const LatLng(11.2189, 75.7925); // Meenchanda default
  final MapController _mapController = MapController();
  Timer? _debounce;
  List<Map<String, dynamic>> _addressSuggestions = [];

  bool _isSaving = false;

  final List<String> _incidentTypes = ['Fire Call', 'Incident Call', 'Water Call', 'Assistant Call'];

  Future<void> _fetchAddressSuggestions(String query) async {
    if (query.length < 3) {
      if (mounted) setState(() => _addressSuggestions = []);
      return;
    }
    try {
      // Restrict search to ~45 km radius around Meenchanda (11.2189, 75.7925)
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&countrycodes=in&viewbox=75.379,11.624,76.205,10.813&bounded=1&limit=10');
      final response = await http.get(url, headers: {'User-Agent': 'com.keralafiremda.watchroom'});
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _addressSuggestions = data.map((e) => e as Map<String, dynamic>).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching address: $e');
    }
  }
  Future<void> _processMapsLink(String link) async {
    if (link.isEmpty || !link.contains('http')) return;
    try {
      Uri uri = Uri.parse(link);
      // Follow short links to get the full URL with coordinates
      if (link.contains('maps.app.goo.gl') || link.contains('goo.gl')) {
        final response = await http.get(uri);
        if (response.request?.url != null) {
          uri = response.request!.url;
        }
      }

      double? lat;
      double? lng;

      // Check for ?q=lat,lng
      final q = uri.queryParameters['q'];
      if (q != null && q.contains(',')) {
        final parts = q.split(',');
        lat = double.tryParse(parts[0]);
        lng = double.tryParse(parts[1]);
      } else {
        // Check for @lat,lng
        final path = uri.path;
        final atIndex = path.indexOf('@');
        if (atIndex != -1) {
          final parts = path.substring(atIndex + 1).split(',');
          if (parts.length >= 2) {
            lat = double.tryParse(parts[0]);
            lng = double.tryParse(parts[1]);
          }
        }
      }

      if (lat != null && lng != null) {
        if (mounted) {
          setState(() {
            _selectedLocation = LatLng(lat!, lng!);
          });
        }
        _mapController.move(_selectedLocation, 14.5);

        // Fetch address for this location
        if (_addressController.text.isEmpty) {
          final reverseUrl = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng');
          final revResponse = await http.get(reverseUrl, headers: {'User-Agent': 'com.keralafiremda.watchroom'});
          if (revResponse.statusCode == 200) {
            final data = json.decode(revResponse.body);
            if (data['display_name'] != null && mounted) {
              setState(() {
                _addressController.text = data['display_name'];
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing link: $e');
    }
  }

  Future<void> _saveIncident() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final newIncident = IncidentModel(
      id: '',
      type: _selectedType!,
      address: _addressController.text.trim(),
      latitude: _selectedLocation.latitude,
      longitude: _selectedLocation.longitude,
      status: 'Active',
      reportedTime: DateTime.now(),
      sfroLatitude: _selectedLocation.latitude, // Initial SFRO location assumption
      sfroLongitude: _selectedLocation.longitude,
    );

    await context.read<IncidentProvider>().addIncident(newIncident);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Report New Incident'),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Incident Type',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  hint: const Text('Select Incident Type', style: TextStyle(color: Colors.white54)),
                  dropdownColor: const Color(0xFF1A1A1A),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: _incidentTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type, style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select an incident type';
                    }
                    return null;
                  },
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedType = val);
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Paste Location Link (Optional)',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _linkController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. https://maps.app.goo.gl/...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search, color: Colors.white54),
                      onPressed: () {
                        _processMapsLink(_linkController.text.trim());
                      },
                    ),
                  ),
                  onFieldSubmitted: (value) {
                    _processMapsLink(value.trim());
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Address / Location Details',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _addressController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter address...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter address';
                    }
                    return null;
                  },
                  onChanged: (val) {
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 500), () {
                      _fetchAddressSuggestions(val);
                    });
                  },
                ),
                if (_addressSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _addressSuggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _addressSuggestions[index];
                        return ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.white54),
                          title: Text(
                            suggestion['display_name'] ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          onTap: () {
                            setState(() {
                              _addressController.text = suggestion['display_name'];
                              _selectedLocation = LatLng(
                                double.parse(suggestion['lat']),
                                double.parse(suggestion['lon']),
                              );
                              _addressSuggestions.clear();
                            });
                            _mapController.move(_selectedLocation, 14.5);
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Pick Location on Map',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _selectedLocation,
                        initialZoom: 14.5,
                        onTap: (tapPosition, point) {
                          setState(() {
                            _selectedLocation = point;
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.keralafiremda.watchroom',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selectedLocation,
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveIncident,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Report Incident',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
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
