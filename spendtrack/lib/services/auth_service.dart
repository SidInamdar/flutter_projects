// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:spendtrack/db/database_helper.dart'; // Your DatabaseHelper (soon to be TransactionService)

class AuthService {
  final fb_auth.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  // Get an instance of DatabaseHelper to save profile
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;


  AuthService(this._firebaseAuth);

  Stream<fb_auth.User?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map((user) {
      print("AuthService: authStateChanges emitted: ${user?.uid ?? 'null user'}");
      return user;
    });
  }

  fb_auth.User? get currentUser => _firebaseAuth.currentUser;

  Future<fb_auth.User?> signInWithGoogle() async {
    print("AuthService: signInWithGoogle called.");
    try {
      GoogleSignInAccount? googleUser;
      // ... (existing Google Sign-In logic from your debugged version) ...
      if (kIsWeb) {
        googleUser = await _googleSignIn.signInSilently();
        googleUser ??= await _googleSignIn.signIn();
      } else {
        googleUser = await _googleSignIn.signIn();
      }

      if (googleUser == null) {
        print("AuthService: GoogleSignIn.signIn() returned null.");
        return null;
      }
      print("AuthService: Google user obtained: ${googleUser.email}, ${googleUser.displayName}");

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final fb_auth.AuthCredential credential = fb_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print("AuthService: Attempting _firebaseAuth.signInWithCredential()...");
      final fb_auth.UserCredential userCredential =
      await _firebaseAuth.signInWithCredential(credential);
      print("AuthService: _firebaseAuth.signInWithCredential() successful. User: ${userCredential.user?.uid}");

      if (userCredential.user != null) {
        // Save/Update user profile information to Realtime Database
        await _dbHelper.updateUserProfile(
          userId: userCredential.user!.uid, // Pass UID
          displayName: userCredential.user!.displayName ?? googleUser.displayName ?? "User",
          email: userCredential.user!.email ?? googleUser.email ?? "no-email",
        );
        print("AuthService: User profile saved/updated for ${userCredential.user!.uid}");
      }
      return userCredential.user;
    } on fb_auth.FirebaseAuthException catch (e, s) {
      print("AuthService: FirebaseAuthException during Google Sign-In: ${e.message}, Code: ${e.code}");
      print("AuthService: Stacktrace: $s");
      return null;
    } catch (e, s) {
      print("AuthService: Generic error during Google Sign-In: $e");
      print("AuthService: Stacktrace: $s");
      return null;
    }
  }

  Future<void> signOut() async {
    // ... (existing signOut logic) ...
    print("AuthService: signOut called.");
    try {
      await _googleSignIn.signOut();
      print("AuthService: Signed out from Google.");
    } catch (e) {
      print("AuthService: Error signing out from Google: $e");
    }
    try {
      await _firebaseAuth.signOut();
      print("AuthService: Signed out from Firebase.");
    } catch (e) {
      print("AuthService: Error signing out from Firebase: $e");
    }
  }
}
