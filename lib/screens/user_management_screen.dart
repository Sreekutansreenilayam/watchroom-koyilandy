import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/manpower_provider.dart';
import '../models/manpower_model.dart';
import '../providers/auth_provider.dart';
import '../config/app_config.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _linkUser(String userId, String personId) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'linkedPersonId': personId,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully linked user!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error linking: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('User Management', style: TextStyle(fontWeight: FontWeight.bold)),
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
              Color(0xFF0D2C2C), // teal glow
              Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No users found in database. Users must log in at least once.', style: TextStyle(color: Colors.white70)));
              }

              final users = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final email = data['email']?.toString().toLowerCase() ?? '';
                return email != 'admin@frs.com' && email != 'admin@fire.com';
              }).toList();

              return Consumer<ManpowerProvider>(
                builder: (context, manpowerProvider, child) {
                  final allPersonnel = manpowerProvider.personnelList;

                  final currentUserEmail = context.watch<AuthProvider>().user?.email;
                  final isAdmin = currentUserEmail == 'admin@frs.com' || currentUserEmail == 'admin@fire.com';

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: DataTable(
                                    headingTextStyle: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
                                    dataTextStyle: const TextStyle(color: Colors.white),
                                    columns: [
                                      const DataColumn(label: Text('Username (Email)')),
                                      const DataColumn(label: Text('Password')),
                                      const DataColumn(label: Text('Assigned Person')),
                                      if (isAdmin) const DataColumn(label: Text('Action')),
                                    ],
                                    rows: users.map((doc) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      final email = data['email'] ?? 'Unknown';
                                      final linkedPersonId = data['linkedPersonId'] as String?;

                                      Widget assignedWidget;
                                      if (linkedPersonId != null && linkedPersonId.isNotEmpty) {
                                        // Already linked
                                        final person = allPersonnel.firstWhere(
                                          (p) => p.id == linkedPersonId,
                                          orElse: () => Manpower(id: '', name: 'Unknown', idNumber: '', designation: '', mobileNumber: '', currentStation: '', isDriver: false)
                                        );
                                        assignedWidget = Row(
                                          children: [
                                            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                                            const SizedBox(width: 8),
                                            Text('${person.name} (${person.idNumber})', style: const TextStyle(color: Colors.greenAccent)),
                                          ],
                                        );
                                      } else {
                                        // Not linked
                                        String? selectedPersonId;
                                        assignedWidget = StatefulBuilder(
                                          builder: (context, setState) {
                                            return Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: DropdownButtonHideUnderline(
                                                    child: DropdownButton<String>(
                                                      value: selectedPersonId,
                                                      hint: const Text('Select Person', style: TextStyle(color: Colors.white54)),
                                                      dropdownColor: const Color(0xFF1A1A1A),
                                                      style: const TextStyle(color: Colors.white),
                                                      items: allPersonnel.map((p) {
                                                        return DropdownMenuItem<String>(
                                                          value: p.id,
                                                          child: Text('${p.name} (${p.idNumber})'),
                                                        );
                                                      }).toList(),
                                                      onChanged: (val) {
                                                        setState(() => selectedPersonId = val);
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                ElevatedButton(
                                                  onPressed: selectedPersonId == null ? null : () => _linkUser(doc.id, selectedPersonId!),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.teal,
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  child: const Text('Link'),
                                                ),
                                              ],
                                            );
                                          }
                                        );
                                      }

                                      List<DataCell> cells = [
                                        DataCell(Text(email, style: const TextStyle(fontWeight: FontWeight.w500))),
                                        DataCell(const Text('********', style: TextStyle(letterSpacing: 2))),
                                        DataCell(assignedWidget),
                                      ];

                                      if (isAdmin) {
                                        cells.add(
                                          DataCell(
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                                              tooltip: 'Remove Record',
                                              onPressed: () async {
                                                bool? confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    backgroundColor: const Color(0xFF1A1A1A),
                                                    title: const Text('Remove User Record?', style: TextStyle(color: Colors.white)),
                                                    content: Text('This will remove $email from this list. Ensure you have also deleted them from Firebase Authentication.', style: const TextStyle(color: Colors.white70)),
                                                    actions: [
                                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: Colors.redAccent))),
                                                    ]
                                                  )
                                                );

                                                if (confirm == true) {
                                                  await _firestore.collection('users').doc(doc.id).delete();
                                                }
                                              },
                                            )
                                          )
                                        );
                                      }

                                      return DataRow(cells: cells);
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              const Text(
                                'We have proudly transformed our traditional station operations into a fully digital system, streamlining processes, reducing paperwork, and enhancing overall efficiency.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Designed and created by Sreenath KK, FRS Meenchanda.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.tealAccent.withOpacity(0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              FutureBuilder<PackageInfo>(
                                future: PackageInfo.fromPlatform(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Text('Loading version...', style: TextStyle(color: Colors.white38, fontSize: 12));
                                  }
                                  if (snapshot.hasError) {
                                    return Text('Version error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent, fontSize: 10));
                                  }
                                  if (snapshot.hasData) {
                                    return Text(
                                      'Version ${snapshot.data!.version}',
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12,
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
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
}
