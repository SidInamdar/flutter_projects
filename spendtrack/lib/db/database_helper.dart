// lib/db/database_helper.dart
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:spendtrack/models/transaction_model.dart'; // Assuming app name is spendtrack
import 'package:spendtrack/models/recurring_transaction_suggestion.dart'; // Assuming app name is spendtrack

// UserProfile model
class UserProfile {
  final String uid;
  final String displayName;
  final String email;

  UserProfile({required this.uid, required this.displayName, required this.email});

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid, // Use the passed UID (which is the Firebase node key)
      displayName: map['displayName'] as String? ?? 'N/A',
      email: map['email'] as String? ?? 'N/A',
    );
  }
}

class DatabaseHelper {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final fb_auth.FirebaseAuth _firebaseAuth = fb_auth.FirebaseAuth.instance;

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  String? get _currentUserId => _firebaseAuth.currentUser?.uid;

  // --- Profile Methods ---
  DatabaseReference _userProfileRef(String userId) {
    return _database.ref('users/$userId/profile');
  }

  Future<void> updateUserProfile({required String userId, required String displayName, required String email}) async {
    final ref = _userProfileRef(userId);
    try {
      await ref.set({
        'displayName': displayName,
        'email': email.toLowerCase(), // Store email in lowercase for consistency
        'uid': userId, // Storing UID within profile is fine, though key is also UID
      });
      print("DB_HELPER: User profile updated for $userId");
    } catch (e) {
      print("DB_HELPER: Error updating user profile for $userId: $e");
      rethrow;
    }
  }

  Future<UserProfile?> getUserProfileData(String userId) async {
    final ref = _userProfileRef(userId);
    try {
      final event = await ref.once(DatabaseEventType.value);
      if (event.snapshot.exists && event.snapshot.value != null) {
        // Pass the userId (which is the node key) directly to fromMap
        return UserProfile.fromMap(userId, Map<String, dynamic>.from(event.snapshot.value as Map));
      }
      return null;
    } catch (e) {
      print("DB_HELPER: Error fetching user profile for $userId: $e");
      return null;
    }
  }

  // REFINED: Get all user profiles
  Future<List<UserProfile>> getAllUserProfiles() async {
    final List<UserProfile> profiles = [];
    final usersRef = _database.ref('users');
    try {
      final event = await usersRef.once(DatabaseEventType.value);
      print("DB_HELPER_GET_ALL_PROFILES: Snapshot raw value: ${event.snapshot.value}");
      if (event.snapshot.exists && event.snapshot.value != null) {
        final Map<dynamic, dynamic> allUsersData = event.snapshot.value as Map<dynamic, dynamic>;
        allUsersData.forEach((uidKey, userData) { // uidKey is the actual Firebase UID
          if (userData is Map && userData.containsKey('profile') && userData['profile'] is Map) {
            final profileData = Map<String, dynamic>.from(userData['profile'] as Map);
            // Use uidKey (the actual node key/Firebase UID) when creating UserProfile
            profiles.add(UserProfile.fromMap(uidKey as String, profileData));
          } else {
            print("DB_HELPER: Skipping user data for UID $uidKey due to unexpected structure: $userData");
          }
        });
        profiles.sort((a,b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      }
      print("DB_HELPER: Fetched ${profiles.length} user profiles.");
      return profiles;
    } catch (e) {
      print("DB_HELPER: Error fetching all user profiles: $e");
      return [];
    }
  }

  Future<String?> findUserUidByEmail(String email) async {
    if (email.isEmpty) return null;
    final String normalizedEmail = email.toLowerCase().trim();
    try {
      final usersRef = _database.ref('users');
      final event = await usersRef.orderByChild('profile/email').equalTo(normalizedEmail).limitToFirst(1).once();
      if (event.snapshot.exists && event.snapshot.value != null) {
        final Map<dynamic, dynamic> usersFound = event.snapshot.value as Map<dynamic, dynamic>;
        if (usersFound.isNotEmpty) {
          return usersFound.keys.first as String?;
        }
      }
      return null;
    } catch (e) {
      print("DB_HELPER: Error finding user by email $normalizedEmail: $e");
      return null;
    }
  }

  // --- Transaction Methods (User-Specific) ---
  DatabaseReference? _currentUserTransactionsRef() {
    final userId = _currentUserId;
    if (userId == null) return null;
    return _database.ref('users/$userId/transactions');
  }

  DatabaseReference _transactionsRefForUser(String userId) {
    return _database.ref('users/$userId/transactions');
  }

  Future<String?> insert(TransactionModel transaction) async {
    final ref = _currentUserTransactionsRef();
    if (ref == null) throw Exception("User not authenticated for transaction insert");
    try {
      final newTransactionRef = ref.push();
      await newTransactionRef.set(transaction.toMapWithoutId());
      return newTransactionRef.key;
    } catch (e) { rethrow; }
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final ref = _currentUserTransactionsRef();
    if (ref == null) {
      print("DB_HELPER: Current user ID is null, cannot fetch own transactions.");
      return [];
    }
    return _fetchTransactionsFromRef(ref);
  }

  Future<List<TransactionModel>> getAllTransactionsForUser(String targetUserId) async {
    print("DB_HELPER: Fetching transactions for target user ID: $targetUserId");
    final ref = _transactionsRefForUser(targetUserId);
    return _fetchTransactionsFromRef(ref);
  }

  Future<List<TransactionModel>> _fetchTransactionsFromRef(DatabaseReference ref) async {
    try {
      final event = await ref.orderByChild('date').once(DatabaseEventType.value);
      final List<TransactionModel> transactions = [];
      if (event.snapshot.exists && event.snapshot.value != null) {
        final Map<dynamic, dynamic> transactionsMap = event.snapshot.value as Map<dynamic, dynamic>;
        transactionsMap.forEach((key, value) {
          if (value is Map) {
            final transactionData = Map<String, dynamic>.from(value);
            transactions.add(TransactionModel.fromMapFirebase(key, transactionData));
          }
        });
        transactions.sort((a, b) => b.date.compareTo(a.date));
      }
      print("DB_HELPER: Fetched ${transactions.length} transactions from Firebase path: ${ref.path}");
      return transactions;
    } catch (e) {
      print("DB_HELPER: Error fetching transactions from Firebase path ${ref.path}: $e");
      return [];
    }
  }

  Future<void> delete(String firebaseKey) async {
    final ref = _currentUserTransactionsRef();
    if (ref == null) throw Exception("User not authenticated for transaction delete");
    try {
      await ref.child(firebaseKey).remove();
    } catch (e) { rethrow; }
  }

  Future<List<RecurringTransactionSuggestion>> getTopRecurringTransactions() async {
    final allTransactions = await getAllTransactions();
    if (allTransactions.isEmpty) return [];
    Map<String, int> recurrenceMap = {};
    for (var transaction in allTransactions) {
      if (transaction.tags.isNotEmpty) {
        String key = "${transaction.amount.toInt()}_${transaction.tags.toLowerCase().trim()}";
        recurrenceMap[key] = (recurrenceMap[key] ?? 0) + 1;
      }
    }
    List<MapEntry<String, int>> sortedRecurrences = recurrenceMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    List<RecurringTransactionSuggestion> suggestions = [];
    for (int i = 0; i < sortedRecurrences.length && i < 7; i++) {
      var entry = sortedRecurrences[i];
      List<String> parts = entry.key.split('_');
      if (parts.length >= 2) {
        double amount = double.tryParse(parts[0]) ?? 0.0;
        String tags = parts.sublist(1).join('_');
        suggestions.add(RecurringTransactionSuggestion(amount: amount, tags: tags, recurrenceCount: entry.value));
      }
    }
    return suggestions;
  }
}
