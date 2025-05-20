import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spendtrack/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle(BuildContext context) async {
    // Ensure the widget is still mounted before proceeding.
    if (!mounted) {
      print("LoginPage: _signInWithGoogle called but widget not mounted. Aborting.");
      return;
    }

    // Set loading state to true to show progress indicator.
    setState(() => _isLoading = true);
    print("LoginPage: Attempting Google Sign-In...");

    // Access the AuthService from the Provider.
    // 'listen: false' is used because we are calling a method, not listening to changes here.
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final user = await authService.signInWithGoogle(); // This uses your existing Firebase packages
      if (user != null) {
        print("LoginPage: Google Sign-In through AuthService successful. User UID: ${user.uid}");
        // Navigation to the main app screen will be handled by the AuthWrapper
        // listening to authStateChanges. No explicit navigation needed here.
        // If the app is still stuck on this page after this message,
        // the issue is likely in the authStateChanges stream or AuthWrapper logic.
      } else {
        print("LoginPage: Google Sign-In through AuthService returned null (likely cancelled or failed before Firebase step).");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Google Sign-In was cancelled or failed.')),
          );
        }
      }
    } catch (e, s) {
      print("LoginPage: Error during Google Sign-In process: $e");
      print("LoginPage: Stacktrace for error: $s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred during sign-in: ${e.toString()}')),
        );
      }
    } finally {
      // Ensure loading state is turned off, regardless of success or failure,
      // but only if the widget is still mounted.
      if (mounted) {
        print("LoginPage: Google Sign-In process finished. Setting isLoading to false.");
        setState(() => _isLoading = false);
      } else {
        print("LoginPage: Google Sign-In process finished but widget was unmounted.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print("LoginPage: Build method called. isLoading: $_isLoading");
    return Scaffold(
      backgroundColor: Colors.grey[100], // A light background for the page
      appBar: AppBar(
        title: const Text('Welcome'),
        elevation: 0,
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Center(
        child: SingleChildScrollView( // Allows content to scroll if screen is small
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? Column( // Show loading indicator with some text
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Signing in...',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
            ],
          )
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch, // Makes button full width
            children: <Widget>[
              // App Logo/Name (Optional)
              Icon(
                Icons.track_changes, // Placeholder icon, replace with your app logo if you have one
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'SpendTrack', // Your App Name
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Track your expenses effortlessly.', // Your App Tagline
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                icon: Image.asset(
                  'assets/google_icon.png', // Make sure this asset is in your pubspec.yaml and assets folder
                  height: 22.0, // Slightly smaller icon for better balance
                  width: 22.0,
                ),
                label: const Text('Sign in with Google'),
                onPressed: () => _signInWithGoogle(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, // Google button standard
                  foregroundColor: Colors.black.withOpacity(0.75), // Standard Google button text color
                  minimumSize: const Size(double.infinity, 50), // Full width button
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(
                    fontSize: 17, // Slightly larger text
                    fontWeight: FontWeight.w500, // Medium weight
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    side: BorderSide(color: Colors.grey[300]!), // Subtle border
                  ),
                  elevation: 1, // Subtle shadow
                ),
              ),
              const SizedBox(height: 20),
              // You could add a small note here if needed
              // Text(
              //   'By signing in, you agree to our Terms of Service.',
              //   textAlign: TextAlign.center,
              //   style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
