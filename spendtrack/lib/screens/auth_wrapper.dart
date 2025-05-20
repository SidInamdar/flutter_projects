import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:spendtrack/screens/login_page.dart'; // We'll create this
import 'package:spendtrack/screens/transaction_list_page.dart'; // Your existing page

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<fb_auth.User?>();

    if (firebaseUser != null) {
      print("AuthWrapper: User is logged in (${firebaseUser.uid}), showing TransactionListPage");
      return const TransactionListPage();
    }
    // print("AuthWrapper: User is not logged in, showing LoginPage");
    // return const LoginPage();
    // Show the message as a popup for 2 seconds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("User is not logged in, showing LoginPage"),
        duration: Duration(seconds: 2),
      ));
    });
    return LoginPage();
  }
}