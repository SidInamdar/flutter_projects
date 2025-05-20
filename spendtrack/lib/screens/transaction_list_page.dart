import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../models/transaction_model.dart';
import '../db/database_helper.dart';
import 'add_transaction_page.dart'; // To navigate to add transaction page

class TransactionListPage extends StatefulWidget {
  const TransactionListPage({super.key});

  @override
  State<TransactionListPage> createState() => _TransactionListPageState();
}

class _TransactionListPageState extends State<TransactionListPage> {
  late Future<List<TransactionModel>> _transactionsFuture;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final String _indianRupeeSymbol = '₹';
  int? _expandedTransactionId; // ID of the currently expanded transaction

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  void _loadTransactions() {
    setState(() {
      // Reset expanded ID when reloading, or you might keep it
      // _expandedTransactionId = null;
      _transactionsFuture = _dbHelper.getAllTransactions();
    });
  }

  Future<void> _navigateToAddTransactionPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddTransactionPage()),
    );
    if (result == true) {
      _loadTransactions();
    }
  }

  Future<void> _showDeleteConfirmationDialog(TransactionModel transaction) async {
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
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteTransaction(transaction.id!);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTransaction(int id) async {
    try {
      await _dbHelper.delete(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      // If the deleted transaction was the expanded one, collapse it
      if (_expandedTransactionId == id) {
        setState(() {
          _expandedTransactionId = null;
        });
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

  void _toggleExpand(int transactionId) {
    setState(() {
      if (_expandedTransactionId == transactionId) {
        _expandedTransactionId = null; // Collapse if already expanded
      } else {
        _expandedTransactionId = transactionId; // Expand this one
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
          ),
        ],
      ),
      body: FutureBuilder<List<TransactionModel>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
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
                // Inside ListView.builder's itemBuilder:
// ... (other code like final transaction = transactions[index]; etc.)

                final bool isExpanded = _expandedTransactionId == transaction.id;
                final String formattedDate = DateFormat('d MMM').format(transaction.date);
                final String formattedAmount = '$_indianRupeeSymbol${transaction.amount.toInt()}';

                if (transaction.id == null) {
                  print("TransactionListPage: itemBuilder - Transaction ID is NULL for description: ${transaction.description}");
                  return const Card(child: Padding(padding: EdgeInsets.all(8.0), child: Text("Error: Transaction ID is null")));
                }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: InkWell(
                    onLongPress: () {
                      _toggleExpand(transaction.id!);
                    },
                    onTap: () {
                      _toggleExpand(transaction.id!);
                    },
                    child: Padding(
                      // REDUCE VERTICAL PADDING HERE FOR COMPACT STATE
                      padding: EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: isExpanded ? 12.0 : 5.0 // Changed 8.0 to 5.0 (or try 4.0)
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min, // Make Column take minimum vertical space
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center, // Align items vertically in the center
                            children: [
                              Flexible(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center, // Align items vertically
                                  children: [
                                    Text(
                                      formattedDate,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w500
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (!isExpanded)
                                      Expanded(
                                        child: Text(
                                          transaction.description,
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
                                crossAxisAlignment: CrossAxisAlignment.center, // Align items vertically
                                children: [
                                  Padding( // Add slight padding if amount feels too close to delete icon
                                    padding: const EdgeInsets.only(right: 4.0),
                                    child: Text(
                                      formattedAmount,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: transaction.amount < 0 ? Colors.redAccent : Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  // IconButton itself has some intrinsic padding, making it smaller can be tricky
                                  // We already have minimal padding on it.
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    padding: const EdgeInsets.only(left: 4, top:0, bottom:0, right:0), // Adjusted left padding slightly
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Delete Transaction',
                                    onPressed: () {
                                      if (transaction.id != null) {
                                        _showDeleteConfirmationDialog(transaction);
                                      } else {
                                        print("TransactionListPage: Delete pressed for item with null ID!");
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (isExpanded) ...[
                            const SizedBox(height: 8), // This space only applies when expanded
                            Text(
                              transaction.description, // Full description when expanded
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                            if (transaction.tags.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Tags: ${transaction.tags}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                            const SizedBox(height: 4), // Small padding at the bottom when expanded
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