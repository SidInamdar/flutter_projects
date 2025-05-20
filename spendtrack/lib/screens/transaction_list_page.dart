import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // For AuthService
import 'package:spendtrack/services/auth_service.dart'; // For AuthService
import 'package:spendtrack/models/transaction_model.dart';
import 'package:spendtrack/db/database_helper.dart'; // Now uses Firebase
import 'package:spendtrack/screens/add_transaction_page.dart';

class TransactionListPage extends StatefulWidget {
  const TransactionListPage({super.key});

  @override
  State<TransactionListPage> createState() => _TransactionListPageState();
}

class _TransactionListPageState extends State<TransactionListPage> {
  late Future<List<TransactionModel>> _transactionsFuture;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final String _indianRupeeSymbol = '₹';
  String? _expandedTransactionId; // Firebase key of the expanded transaction

  @override
  void initState() {
    super.initState();
    print("TransactionListPage: initState - Loading transactions for user.");
    _loadTransactions();
  }

  void _loadTransactions() {
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.currentUser == null) {
      print("TransactionListPage: User not logged in, cannot load transactions.");
      // This case should ideally be handled by AuthWrapper, but as a safeguard:
      setState(() {
        _transactionsFuture = Future.value([]); // Return empty if no user
      });
      return;
    }
    setState(() {
      _transactionsFuture = _dbHelper.getAllTransactions().catchError((e) {
        print("TransactionListPage: Error in _loadTransactions future: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading transactions: $e"), backgroundColor: Colors.red),
        );
        return <TransactionModel>[]; // Return empty list on error
      });
    });
  }

  Future<void> _navigateToAddTransactionPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddTransactionPage()),
    );
    if (result == true) { // Assuming AddTransactionPage returns true on successful save
      _loadTransactions();
    }
  }

  Future<void> _showDeleteConfirmationDialog(TransactionModel transaction) async {
    if (transaction.id == null) {
      print("Cannot delete transaction with null ID (Firebase key).");
      return;
    }
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('Are you sure you want to delete this transaction?'),
                const SizedBox(height: 8),
                Text('"${transaction.description}" - $_indianRupeeSymbol${transaction.amount.toInt()}'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteTransaction(transaction.id!); // Pass Firebase key
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTransaction(String firebaseKey) async {
    try {
      await _dbHelper.delete(firebaseKey);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      if (_expandedTransactionId == firebaseKey) {
        setState(() => _expandedTransactionId = null);
      }
      _loadTransactions();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting transaction: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleExpand(String transactionId) { // Takes Firebase key
    setState(() {
      if (_expandedTransactionId == transactionId) {
        _expandedTransactionId = null;
      } else {
        _expandedTransactionId = transactionId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text(authService.currentUser?.displayName?.split(' ')[0] ?? 'My Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
          ),
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
      body: FutureBuilder<List<TransactionModel>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          // ... (FutureBuilder logic remains largely the same, ensure transaction.id is handled as Firebase key)
          // Ensure _toggleExpand and delete use transaction.id! (which is now the Firebase key)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No transactions found. Tap + to add.'));
          } else {
            final transactions = snapshot.data!;
            return ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                final bool isExpanded = _expandedTransactionId == transaction.id;
                final String formattedDate = DateFormat('d MMM').format(transaction.date);
                final String formattedAmount = '$_indianRupeeSymbol${transaction.amount.toInt()}';

                if (transaction.id == null) {
                  return const Card(child: Padding(padding: EdgeInsets.all(8.0), child: Text("Error: Transaction missing ID")));
                }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: InkWell(
                    onLongPress: () => _toggleExpand(transaction.id!),
                    onTap: () => _toggleExpand(transaction.id!),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: isExpanded ? 12.0 : 5.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(formattedDate, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                                    const SizedBox(width: 8),
                                    if (!isExpanded)
                                      Expanded(
                                        child: Text(
                                          transaction.description.isNotEmpty ? transaction.description : (transaction.tags.isNotEmpty ? transaction.tags : "Transaction"),
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4.0),
                                    child: Text(formattedAmount, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: transaction.amount < 0 ? Colors.redAccent : Theme.of(context).colorScheme.primary)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    padding: const EdgeInsets.only(left: 4, top:0, bottom:0, right:0),
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Delete Transaction',
                                    onPressed: () => _showDeleteConfirmationDialog(transaction),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (isExpanded) ...[
                            const SizedBox(height: 8),
                            Text(transaction.description.isNotEmpty ? transaction.description : "No description", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                            if (transaction.tags.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Tags: ${transaction.tags}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                            const SizedBox(height: 4),
                          ]
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddTransactionPage,
        tooltip: 'Add Transaction',
        child: const Icon(Icons.add),
      ),
    );
  }
}
