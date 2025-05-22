import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:spendtrack/services/auth_service.dart';
import 'package:spendtrack/models/transaction_model.dart';
import 'package:spendtrack/db/database_helper.dart';
import 'package:spendtrack/screens/add_transaction_page.dart';
import 'package:spendtrack/screens/summary_page.dart';
// Removed SharedSummariesHostPage import from here as it's not directly needed by this page's logout logic.
// Navigation to it is handled by AuthWrapper or other parts of your app.

class TransactionListPage extends StatefulWidget {
  const TransactionListPage({super.key});

  @override
  State<TransactionListPage> createState() => _TransactionListPageState();
}

class _TransactionListPageState extends State<TransactionListPage> {
  Future<List<TransactionModel>>? _transactionsFuture; // Made nullable for explicit initialization
  List<TransactionModel> _allTransactions = []; // To store fetched transactions for loading logic
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final String _indianRupeeSymbol = '₹';
  String? _expandedTransactionId; // Firebase key of the expanded transaction

  @override
  void initState() {
    super.initState();
    print("TransactionListPage: initState - Loading transactions for user.");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadTransactions();
      }
    });
  }

  void _loadTransactions() {
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.currentUser == null) {
      print("TransactionListPage: User not logged in, cannot load transactions.");
      if (mounted) {
        setState(() {
          _transactionsFuture = Future.value([]);
          _allTransactions = []; // Clear local list
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        // Assign the future to the state variable
        _transactionsFuture = _dbHelper.getAllTransactions().then((transactions) {
          if (mounted) {
            // Update the local list when data is successfully fetched
            _allTransactions = transactions;
          }
          return transactions; // Return transactions for the FutureBuilder
        }).catchError((e) {
          print("TransactionListPage: Error in _loadTransactions future: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error loading transactions: $e"), backgroundColor: Colors.red),
            );
            _allTransactions = []; // Clear on error
          }
          return <TransactionModel>[]; // Return empty list for FutureBuilder on error
        });
      });
    }
  }

  Future<void> _navigateToAddTransactionPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddTransactionPage()),
    );
    if (result == true && mounted) {
      _loadTransactions(); // This will re-fetch and update _transactionsFuture and _allTransactions
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
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('Are you sure you want to delete this transaction?'),
                const SizedBox(height: 8),
                Text('"${transaction.description.isNotEmpty ? transaction.description : "Transaction"}" - $_indianRupeeSymbol${transaction.amount.toInt()}'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _deleteTransaction(transaction.id!);
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      if (_expandedTransactionId == firebaseKey) {
        setState(() => _expandedTransactionId = null);
      }
      _loadTransactions(); // Re-fetch to update the list
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting transaction: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleExpand(String transactionId) {
    if (!mounted) return;
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
    // final authService = Provider.of<AuthService>(context, listen: false);
    // final currentUserName = authService.currentUser?.displayName?.split(' ').first ?? "My";

    // No AppBar here, assuming it's part of SharedSummariesHostPage's TabBarView structure

    return Scaffold(
      body: FutureBuilder<List<TransactionModel>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          // Show loader if future is not yet complete AND the local list is empty (initial load)
          if (snapshot.connectionState == ConnectionState.waiting && _allTransactions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading transactions: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            // This condition is met if the future completes with no data or an empty list
            return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No transactions found yet.\nTap the "+" button to add your first one!', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)),
                )
            );
          } else {
            // Data is available (either fresh or from previous successful fetch if future is re-triggered)
            final transactions = snapshot.data!;
            // _allTransactions is updated in _loadTransactions().then()
            // This ensures the loading condition `_allTransactions.isEmpty` works correctly on re-fetches.

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
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onLongPress: () => _toggleExpand(transaction.id!),
                    onTap: () => _toggleExpand(transaction.id!),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: isExpanded ? 12.0 : 8.0),
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
                                    const SizedBox(width: 10),
                                    if (!isExpanded)
                                      Expanded(
                                        child: Text(
                                          transaction.description.isNotEmpty ? transaction.description : (transaction.tags.isNotEmpty ? transaction.tags : "Transaction"),
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child: Text(formattedAmount, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: transaction.amount < 0 ? Colors.redAccent : Theme.of(context).colorScheme.primary)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                                    padding: const EdgeInsets.all(4),
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
                            Text(transaction.description.isNotEmpty ? transaction.description : "No description provided.", style: const TextStyle(fontSize: 14, color: Colors.black87)),
                            if (transaction.tags.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Tags: ${transaction.tags}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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
