import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../screens/force_update_screen.dart';

class VersionCheckWrapper extends StatefulWidget {
  final Widget child;

  const VersionCheckWrapper({super.key, required this.child});

  @override
  State<VersionCheckWrapper> createState() => _VersionCheckWrapperState();
}

class _VersionCheckWrapperState extends State<VersionCheckWrapper> {
  bool _isLoading = true;
  bool _needsUpdate = false;
  String _updateUrl = '';

  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    try {
      // 1. Get current app version
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;

      // 2. Fetch minimum required version from Firebase
      final DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('app_info')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        final String minVersion = data['min_version'] ?? '1.0.0';
        final String updateLink = data['update_link'] ?? '';

        // 3. Compare versions
        // E.g., '1.0.1' vs '1.0.0'
        if (_isUpdateRequired(currentVersion, minVersion)) {
          setState(() {
            _needsUpdate = true;
            _updateUrl = updateLink;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint("Error checking app version: $e");
    }

    // If there's an error or no update needed, proceed normally
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isUpdateRequired(String currentVersion, String minVersion) {
    String cVersion = currentVersion.split('+')[0];
    String mVersion = minVersion.split('+')[0];
    List<int> currentParts = cVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> minParts = mVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      int curr = i < currentParts.length ? currentParts[i] : 0;
      int min = i < minParts.length ? minParts[i] : 0;

      if (curr < min) return true;
      if (curr > min) return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFD32F2F)),
        ),
      );
    }

    if (_needsUpdate) {
      return ForceUpdateScreen(updateUrl: _updateUrl);
    }

    return widget.child;
  }
}
