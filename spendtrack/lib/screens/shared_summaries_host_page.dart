// lib/screens/shared_summaries_host_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spendtrack/db/database_helper.dart';
import 'package:spendtrack/services/auth_service.dart';
import 'package:spendtrack/screens/transaction_list_page.dart';
import 'package:spendtrack/screens/summary_page.dart';
// UserProfile should be imported if it's in a separate file,
// or it's already accessible if defined in db_helper.dart

class SharedSummariesHostPage extends StatefulWidget {
  const SharedSummariesHostPage({super.key});

  @override
  State<SharedSummariesHostPage> createState() => _SharedSummariesHostPageState();
}

class _SharedSummariesHostPageState extends State<SharedSummariesHostPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  String? _currentUserId;
  String _currentUserDisplayNameForAppBar = "User"; // For AppBar title

  @override
  void initState() {
    super.initState();
    // Number of tabs: My Transactions, My Summary, Other Users' Summaries
    _tabController = TabController(length: 3, vsync: this);
    // It's safer to get user details after the first frame if context is needed deeply
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authService = Provider.of<AuthService>(context, listen: false);
        setState(() {
          _currentUserId = authService.currentUser?.uid;
          _currentUserDisplayNameForAppBar = authService.currentUser?.displayName?.split(' ').first ?? "User";
          print("SharedSummariesHostPage: Current User ID: $_currentUserId, Display Name: $_currentUserDisplayNameForAppBar");
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false); // For sign out
    final Color onPrimaryColor = Colors.grey.shade600; //Theme.of(context).colorScheme.onPrimary; // Get onPrimary color for text

    return Scaffold(
      appBar: AppBar(
        title: Text("$_currentUserDisplayNameForAppBar's Dashboard"),
        // backgroundColor: Theme.of(context).colorScheme.primary, // AppBar usually takes this by default
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt_rounded), text: "Transactions", ),
            Tab(icon: Icon(Icons.insights_rounded), text: "My Summary"),
            Tab(icon: Icon(Icons.people_alt_outlined), text: "All Users"),
          ],
          indicatorColor: onPrimaryColor, // Make indicator visible
          labelColor: onPrimaryColor, // Color for the selected tab's label & icon
          unselectedLabelColor: onPrimaryColor.withOpacity(0.75), // Color for unselected tabs' labels & icons
          indicatorWeight: 3.0, // Make indicator a bit thicker
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await authService.signOut();
              // AuthWrapper will handle navigation to LoginPage
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const TransactionListPage(),
          const SummaryPage(),
          _buildAllUsersList(),
        ],
      ),
    );
  }

  Widget _buildAllUsersList() {
    print("SHARED_HOST_PAGE: _buildAllUsersList called. Current User ID for filtering: $_currentUserId");
    if (_currentUserId == null) {
      return const Center(child: Text("Authenticating... Please wait."));
    }

    return FutureBuilder<List<UserProfile>>(
      future: _dbHelper.getAllUserProfiles(),
      builder: (context, snapshot) {
        print("SHARED_HOST_PAGE (FutureBuilder): Connection State: ${snapshot.connectionState}");
        if (snapshot.hasError) {
          print("SHARED_HOST_PAGE (FutureBuilder): Error: ${snapshot.error}");
          print("SHARED_HOST_PAGE (FutureBuilder): StackTrace: ${snapshot.stackTrace}");
          return Center(child: Text("Error fetching users: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
          print("SHARED_HOST_PAGE (FutureBuilder): Waiting for data...");
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data == null) {
          print("SHARED_HOST_PAGE (FutureBuilder): No data received from getAllUserProfiles, or data is null.");
          return const Center(child: Text("No user data found.", style: TextStyle(fontSize: 16, color: Colors.grey)));
        }

        final allUserProfiles = snapshot.data!;
        print("SHARED_HOST_PAGE (FutureBuilder): Received ${allUserProfiles.length} total user profiles from DB.");
        // allUserProfiles.forEach((p) => print("  - Profile: ${p.displayName} (${p.uid})"));


        // Filter out the current user from the list
        final otherUsers = allUserProfiles.where((user) => user.uid != _currentUserId).toList();
        print("SHARED_HOST_PAGE (FutureBuilder): After filtering current user, ${otherUsers.length} other users remaining.");


        if (otherUsers.isEmpty) {
          print("SHARED_HOST_PAGE (FutureBuilder): No other users to display.");
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "No other users found, or you are the only registered user.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }

        print("SHARED_HOST_PAGE (FutureBuilder): Building ListView for ${otherUsers.length} users.");
        return ListView.builder(
          itemCount: otherUsers.length,
          itemBuilder: (context, index) {
            final user = otherUsers[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  child: Text(
                    user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : "?",
                    style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(user.email),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                onTap: () {
                  print("SHARED_HOST_PAGE: Navigating to summary for ${user.displayName} (UID: ${user.uid})");
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SummaryPage(
                        targetUserId: user.uid,
                        targetUserName: user.displayName,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
