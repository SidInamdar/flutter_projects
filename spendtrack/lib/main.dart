import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Import FFI
import 'dart:io'; // Import for Platform check

import 'screens/transaction_list_page.dart';
import 'db/database_helper.dart';

void main() async {
  // VERY IMPORTANT: This line MUST be the first line in main()
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for desktop or testing if necessary
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit(); // Initialize FFI
    databaseFactory = databaseFactoryFfi; // Set the FFI factory
  }
  // If you are ONLY developing for desktop and not mobile, you might just do:
  // sqfliteFfiInit();
  // databaseFactory = databaseFactoryFfi;
  // without the Platform check.

  // Optional: Explicitly initialize the database (can help with timing)
  // await DatabaseHelper.instance.database;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Transaction Tracker',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: const TransactionListPage(),
    );
  }
}