import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/user.dart';

enum AuthStep {
  loggedOut,
  needsOnboarding,
  ready,
}

class ProfileProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const Map<String, int> _levelToRating = {
    'beginner': 1000,
    'intermediate': 1400,
    'advanced': 1800,
  };

  AuthStep _step = AuthStep.loggedOut;
  UserProfile? _profile;
  User? _firebaseUser;
  bool _loading = false;

  // --- getters ---
  AuthStep get step => _step;
  UserProfile? get profile => _profile;
  bool get isLoading => _loading;

  // -------------------------
  // STEP 1: Microsoft SSO
  // -------------------------
  Future<void> signInWithMicrosoft() async {
    try {
      _setLoading(true);

      final provider = OAuthProvider('microsoft.com');
      final cred = await _auth.signInWithProvider(provider);

      final user = cred.user;
      if (user == null) throw Exception('Login failed');

      _firebaseUser = user;

      final doc =
      await _db.collection('users').doc(user.uid).get();

      if (doc.exists) {
        _profile = UserProfile.fromMap(user.uid, doc.data()!);
        _step = AuthStep.ready;
      } else {
        _step = AuthStep.needsOnboarding;
      }

      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> restoreSession() async {
    final user = _auth.currentUser;

    if (user == null) {
      _step = AuthStep.loggedOut;
      notifyListeners();
      return;
    }

    _firebaseUser = user;

    final doc = await _db.collection('users').doc(user.uid).get();

    if (doc.exists) {
      _profile = UserProfile.fromMap(user.uid, doc.data()!);
      _step = AuthStep.ready;
    } else {
      _step = AuthStep.needsOnboarding;
    }

    notifyListeners();
  }

  // ----------------------------------
  // STEP 2: Onboarding (level → rating)
  // ----------------------------------
  Future<void> completeOnboarding({
    required String selectedLevel,
  }) async {
    if (_firebaseUser == null) return;

    final rating = _levelToRating[selectedLevel];
    if (rating == null) {
      throw Exception('Invalid level selected');
    }

    try {
      _setLoading(true);

      final profile = UserProfile(
        uid: _firebaseUser!.uid,
        email: _firebaseUser!.email ?? '',
        displayName:
        _firebaseUser!.displayName ?? 'Player',
        photoURL: _firebaseUser!.photoURL,
        rating: rating,
      );

      await _db
          .collection('users')
          .doc(profile.uid)
          .set(profile.toMap());

      _profile = profile;
      _step = AuthStep.ready;

      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> applyRatingDelta(int delta) async {
    if (_profile == null) return;

    final newRating = _profile!.rating + delta;

    try {
      _setLoading(true);

      // 1️⃣ Update Firestore
      await _db.collection('users').doc(_profile!.uid).update({
        'rating': newRating,
      });

      // 2️⃣ Update local state
      _profile = UserProfile(
        uid: _profile!.uid,
        email: _profile!.email,
        displayName: _profile!.displayName,
        photoURL: _profile!.photoURL,
        rating: newRating,
      );

      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }


  // -------------------------
  // STEP 3: Logout
  // -------------------------
  Future<void> signOut() async {
    await _auth.signOut();
    _firebaseUser = null;
    _profile = null;
    _step = AuthStep.loggedOut;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  /// Fetch a user profile by ID (for displaying host info, etc.)
  Future<UserProfile?> fetchUserProfile(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromMap(userId, doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
