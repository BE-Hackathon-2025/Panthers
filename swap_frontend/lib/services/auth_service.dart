import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (displayName != null && displayName.isNotEmpty) {
      await cred.user!.updateDisplayName(displayName);
    }
    await _ensureUserDoc(cred.user!);
    return cred;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) => _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      // ✅ Web: Use popup sign-in
      final provider = GoogleAuthProvider();
      final cred = await _auth.signInWithPopup(provider);
      await _ensureUserDoc(cred.user!);
      return cred;
    } else {
      // ✅ Mobile: Use GoogleSignIn with explicit clientId
      final googleSignIn = GoogleSignIn(
        clientId:
            '663805210025-648bm8jh9i8a0her3tbq5fc0cj9ouj7j.apps.googleusercontent.com', // your Web Client ID
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) throw Exception('Sign-in aborted');

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      await _ensureUserDoc(cred.user!);
      return cred;
    }
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        // ✅ For Android/iOS
        final googleSignIn = GoogleSignIn(
          clientId:
              '663805210025-648bm8jh9i8a0her3tbq5fc0cj9ouj7j.apps.googleusercontent.com',
        );
        if (await googleSignIn.isSignedIn()) {
          await googleSignIn.disconnect();
          await googleSignIn.signOut();
        }
      }
      await _auth.signOut();
      print('✅ Signed out successfully');
    } catch (e) {
      print('❌ Sign out error: $e');
    }
  }

  Future<void> _ensureUserDoc(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'photoUrl': user.photoURL,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
