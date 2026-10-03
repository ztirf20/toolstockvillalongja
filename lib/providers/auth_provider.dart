import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';

enum AuthStatus { loading, signedOut, signedIn, blocked }

class AuthFailure implements Exception {
  final String message;
  AuthFailure(this.message);
  @override
  String toString() => message;
}

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  AuthStatus _status = AuthStatus.loading;
  AppUser? _user;
  String _blockedMessage = '';
  bool _registering = false;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  AuthProvider() {
    _authSub = _auth.authStateChanges().listen(_onAuth);
  }

  AuthStatus get status => _status;
  AppUser? get user => _user;
  String get blockedMessage => _blockedMessage;
  bool get isOwner => _user?.isOwner ?? false;

  void _onAuth(User? u) {
    if (_registering) return;
    _profileSub?.cancel();
    _profileSub = null;
    if (u == null) {
      _user = null;
      _status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    _status = AuthStatus.loading;
    notifyListeners();
    _listenProfile(u);
  }

  void _listenProfile(User u) {
    _profileSub?.cancel();
    _profileSub = _fs.collection('users').doc(u.uid).snapshots().listen(
      (snap) {
        if (!snap.exists) {
          _user = null;
          _status = AuthStatus.blocked;
          _blockedMessage =
              'Your profile was not saved. Tap Sign out, then "Create one" and register again with the same email and password to finish setup.';
        } else {
          final appUser = AppUser.fromDoc(snap);
          _user = appUser;
          if (!appUser.active) {
            _status = AuthStatus.blocked;
            _blockedMessage =
                'Your account has been deactivated. Please contact the store owner.';
          } else {
            _status = AuthStatus.signedIn;
          }
        }
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('Profile stream error: $e');
        _status = AuthStatus.blocked;
        _blockedMessage =
            'Could not load your profile. Check your internet connection.';
        notifyListeners();
      },
    );
  }

  // ------------------------------------------------------------------ actions

  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_authMessage(e));
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String inviteCode = '',
  }) async {
    _registering = true;
    try {
      final user = await _createOrReuseLogin(email, password);
      try {
        final batch = _fs.batch();
        final data = <String, Object?>{
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'role': role.name,
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
        };
        if (role == UserRole.owner) {
          batch.set(_fs.collection('config').doc('store'), {
            'ownerUid': user.uid,
            'staffCode': _generateCode(),
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          data['inviteCode'] = inviteCode.trim().toUpperCase();
        }
        batch.set(_fs.collection('users').doc(user.uid), data);
        await batch.commit().timeout(const Duration(seconds: 20));
      } on TimeoutException {
        await _auth.signOut();
        throw AuthFailure(
            'Could not reach the database. Check that Firestore is created and your internet works, then try again with the same email.');
      } on FirebaseException catch (e) {
        await _auth.signOut();
        throw AuthFailure(_firestoreMessage(e, role));
      }
      _listenProfile(user);
    } finally {
      _registering = false;
    }
  }

  /// Creates the login. If the email already exists because an earlier
  /// attempt saved the login but not the profile, it reuses that login.
  Future<User> _createOrReuseLogin(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') throw AuthFailure(_authMessage(e));
    }

    final UserCredential cred;
    try {
      cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
    } on FirebaseAuthException {
      throw AuthFailure(
          'An account with this email already exists. Sign in instead, or use the same password you chose before.');
    }
    final user = cred.user!;
    try {
      final doc = await _fs.collection('users').doc(user.uid).get();
      if (doc.exists) {
        await _auth.signOut();
        throw AuthFailure(
            'An account with this email already exists. Please sign in instead.');
      }
    } on FirebaseException catch (e) {
      await _auth.signOut();
      throw AuthFailure(_firestoreMessage(e, UserRole.staff));
    }
    return user;
  }

  String _firestoreMessage(FirebaseException e, UserRole role) {
    switch (e.code) {
      case 'permission-denied':
        return role == UserRole.owner
            ? 'Permission denied. If an owner already exists, register as Staff. Otherwise check that Firestore is created and the rules are published. (${e.message})'
            : 'Permission denied. Check the staff code, and that Firestore is created and the rules are published. (${e.message})';
      case 'unavailable':
        return 'Cannot reach the database. Check your internet and try again.';
      default:
        return 'Could not save your profile (${e.code}). ${e.message ?? ''}';
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_authMessage(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  // ------------------------------------------------------- owner: team + code

  Stream<List<AppUser>> watchTeam() =>
      _fs.collection('users').snapshots().map((s) {
        final list = s.docs.map(AppUser.fromDoc).toList();
        list.sort((a, b) {
          if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        return list;
      });

  Stream<String?> watchStaffCode() => _fs
      .collection('config')
      .doc('store')
      .snapshots()
      .map((s) => s.data()?['staffCode'] as String?);

  Future<void> regenerateStaffCode() => _fs
      .collection('config')
      .doc('store')
      .update({'staffCode': _generateCode()});

  Future<void> setActive(String uid, bool active) =>
      _fs.collection('users').doc(uid).update({'active': active});

  // ------------------------------------------------------------------ helpers

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase yet.';
      default:
        return 'Something went wrong (${e.code}): ${e.message}';
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}