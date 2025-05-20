import 'package:firebase_auth/firebase_auth.dart' as fb_auth; // Alias
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final fb_auth.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Optional: If you need to request specific scopes
    // scopes: ['email', 'https://www.googleapis.com/auth/contacts.readonly'],
  );

  AuthService(this._firebaseAuth);

  Stream<fb_auth.User?> get authStateChanges => _firebaseAuth.authStateChanges();
  fb_auth.User? get currentUser => _firebaseAuth.currentUser;

  Future<fb_auth.User?> signInWithGoogle() async {
    try {
      GoogleSignInAccount? googleUser;
      if (kIsWeb) {
        // For web, use signInSilently first or direct signIn
        googleUser = await _googleSignIn.signInSilently();
        googleUser ??= await _googleSignIn.signIn();
      } else {
        googleUser = await _googleSignIn.signIn();
      }

      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final fb_auth.AuthCredential credential = fb_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final fb_auth.UserCredential userCredential =
      await _firebaseAuth.signInWithCredential(credential);
      return userCredential.user;
    } on fb_auth.FirebaseAuthException catch (e) {
      print("Firebase Auth Exception: ${e.message}");
      // Handle specific errors (e.g., account-exists-with-different-credential)
      return null;
    } catch (e) {
      print("Google Sign-In Error: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut(); // Sign out from Google
    await _firebaseAuth.signOut(); // Sign out from Firebase
  }
}