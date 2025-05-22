import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:spendtrack/screens/login_page.dart';
// import 'package:your_app_name/screens/transaction_list_page.dart'; // No longer the direct landing
import 'package:spendtrack/screens/shared_summaries_host_page.dart'; // Import the new host page

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<fb_auth.User?>();

    print("AuthWrapper: build called.");
    if (firebaseUser != null) {
      print("AuthWrapper: User is logged in (UID: ${firebaseUser.uid}), showing SharedSummariesHostPage.");
      return const SharedSummariesHostPage(); // MODIFIED: Navigate to host page
    } else {
      print("AuthWrapper: User is NOT logged in, showing LoginPage.");
      return const LoginPage();
    }
  }
}