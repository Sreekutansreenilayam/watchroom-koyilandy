import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? _user;
  String? _linkedPersonId;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<DocumentSnapshot>? _sessionSubscription;

  AuthProvider() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        // Only auto-listen if we aren't currently logging in.
        // During manual login, we will manually trigger this after setting the new session token.
        if (!_isLoading) {
          _listenToSession(user.uid);
        }
      } else {
        _sessionSubscription?.cancel();
        _linkedPersonId = null;
      }
      notifyListeners();
    });
  }

  User? get user => _user;
  String? get linkedPersonId => _linkedPersonId;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _user?.email == 'admin@frs.com' || _user?.email == 'admin@fire.com';
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Sign in with Email and Password
  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      // Single Device Session logic
      if (userCredential.user != null) {
        final String newSessionId = DateTime.now().millisecondsSinceEpoch.toString();
        
        // Save to SharedPreferences locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('sessionToken', newSessionId);

        // Save to Firestore
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'sessionToken': newSessionId,
          'email': email,
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Start listening to the session only after we have updated Firestore
        _listenToSession(userCredential.user!.uid);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      if (e.code == 'user-not-found') {
        _errorMessage = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        _errorMessage = 'Wrong password provided.';
      } else {
        _errorMessage = e.message ?? 'Authentication failed.';
      }
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred.';
      notifyListeners();
      return false;
    }
  }

  void _listenToSession(String uid) {
    _sessionSubscription?.cancel();
    _sessionSubscription = _firestore.collection('users').doc(uid).snapshots().listen((snapshot) async {
      if (snapshot.exists) {
        final data = snapshot.data();
        final firestoreSession = data?['sessionToken'] as String?;
        final newLinkedPersonId = data?['linkedPersonId'] as String?;

        if (_linkedPersonId != newLinkedPersonId) {
          _linkedPersonId = newLinkedPersonId;
          notifyListeners();
        }

        final prefs = await SharedPreferences.getInstance();
        final localSession = prefs.getString('sessionToken');

        // If local session doesn't match Firestore, force logout
        if (firestoreSession != null && localSession != null && firestoreSession != localSession) {
          if (_isLoading) {
            debugPrint("Ignoring mismatch during login process...");
            return;
          }
          debugPrint("Session mismatch. Logging out...");
          await signOut();
        }
      }
    });
  }

  // Sign Out
  Future<void> signOut() async {
    _sessionSubscription?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sessionToken');
    await _auth.signOut();
  }
  
  // Clear Error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    super.dispose();
  }
}
