// No more sqflite imports needed for main transaction data
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:spendtrack/models/transaction_model.dart';
import 'package:spendtrack/models/recurring_transaction_suggestion.dart';

class DatabaseHelper {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final fb_auth.FirebaseAuth _firebaseAuth = fb_auth.FirebaseAuth.instance;

  // Make this a singleton class (optional, but common pattern)
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  String? get _userId => _firebaseAuth.currentUser?.uid;

  DatabaseReference? _userTransactionsRef() {
    final userId = _userId;
    if (userId == null) return null;
    return _database.ref('users/$userId/transactions');
  }

  Future<String?> insert(TransactionModel transaction) async {
    final ref = _userTransactionsRef();
    if (ref == null) {
      print("User not logged in, cannot insert transaction.");
      throw Exception("User not authenticated");
    }
    try {
      // Use push() to generate a unique ID for the transaction
      final newTransactionRef = ref.push();
      await newTransactionRef.set(transaction.toMapWithoutId()); // Save data without local ID
      print("Transaction inserted to Firebase with key: ${newTransactionRef.key}");
      return newTransactionRef.key; // Return Firebase key
    } catch (e) {
      print("Error inserting transaction to Firebase: $e");
      rethrow;
    }
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final ref = _userTransactionsRef();
    if (ref == null) {
      print("User not logged in, cannot fetch transactions.");
      return [];
    }
    try {
      final snapshot = await ref.orderByChild('date').once(); // Order by date
      final List<TransactionModel> transactions = [];
      if (snapshot.snapshot.value != null) {
        final Map<dynamic, dynamic> transactionsMap =
        snapshot.snapshot.value as Map<dynamic, dynamic>;
        transactionsMap.forEach((key, value) {
          final transactionData = Map<String, dynamic>.from(value as Map);
          // Add Firebase key as 'id' to the model for client-side identification
          transactions.add(TransactionModel.fromMapFirebase(key, transactionData));
        });
        // Sort client-side if needed (Firebase sorts ascending, we want descending for display)
        transactions.sort((a, b) => b.date.compareTo(a.date));
      }
      print("Fetched ${transactions.length} transactions from Firebase.");
      return transactions;
    } catch (e) {
      print("Error fetching transactions from Firebase: $e");
      return [];
    }
  }

  Future<void> delete(String firebaseKey) async { // Now takes Firebase key
    final ref = _userTransactionsRef();
    if (ref == null) {
      print("User not logged in, cannot delete transaction.");
      throw Exception("User not authenticated");
    }
    try {
      await ref.child(firebaseKey).remove();
      print("Transaction deleted from Firebase with key: $firebaseKey");
    } catch (e) {
      print("Error deleting transaction from Firebase: $e");
      rethrow;
    }
  }

  Future<List<RecurringTransactionSuggestion>> getTopRecurringTransactions() async {
    // Fetch all transactions for the user
    final allTransactions = await getAllTransactions();
    if (allTransactions.isEmpty) {
      return [];
    }

    // Client-side processing for recurrence
    Map<String, int> recurrenceMap = {}; // Key: "amount_tags", Value: count

    for (var transaction in allTransactions) {
      if (transaction.tags.isNotEmpty) { // Only consider transactions with tags for suggestions
        String key = "${transaction.amount.toInt()}_${transaction.tags.toLowerCase().trim()}";
        recurrenceMap[key] = (recurrenceMap[key] ?? 0) + 1;
      }
    }

    List<MapEntry<String, int>> sortedRecurrences = recurrenceMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Sort by count descending

    List<RecurringTransactionSuggestion> suggestions = [];
    for (int i = 0; i < sortedRecurrences.length && i < 7; i++) { // Top 7
      var entry = sortedRecurrences[i];
      List<String> parts = entry.key.split('_');
      if (parts.length >= 2) {
        double amount = double.tryParse(parts[0]) ?? 0.0;
        String tags = parts.sublist(1).join('_'); // Re-join if tags had underscores
        suggestions.add(RecurringTransactionSuggestion(
          amount: amount,
          tags: tags,
          recurrenceCount: entry.value,
        ));
      }
    }
    print("Generated ${suggestions.length} recurring suggestions.");
    return suggestions;
  }
}
