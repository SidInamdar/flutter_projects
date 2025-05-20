// lib/screens/add_transaction_page.dart
import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../db/database_helper.dart';
import '../models/recurring_transaction_suggestion.dart';

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<RecurringTransactionSuggestion> _recurringSuggestions = [];
  bool _isLoadingSuggestions = true;
  final String _indianRupeeSymbol = '₹'; // Still used for the label part

  // ... (initState, _fetchRecurringSuggestions, dispose, _submitTransaction, _applySuggestion methods remain the same) ...
  @override
  void initState() {
    super.initState();
    _fetchRecurringSuggestions();
  }

  Future<void> _fetchRecurringSuggestions() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSuggestions = true;
    });
    try {
      final suggestions = await _dbHelper.getTopRecurringTransactions();
      if (!mounted) return;
      setState(() {
        _recurringSuggestions = suggestions;
        _isLoadingSuggestions = false;
      });
    } catch (e) {
      if (!mounted) return;
      print("Error fetching recurring suggestions: $e");
      setState(() {
        _isLoadingSuggestions = false;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _submitTransaction() async {
    if (_formKey.currentState!.validate()) {
      final amount = double.tryParse(_amountController.text);
      final String description = _descriptionController.text;
      final String tags = _tagsController.text;

      if (amount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid amount entered.')),
        );
        return;
      }

      final newTransaction = TransactionModel(
        amount: amount,
        description: description,
        tags: tags,
        date: DateTime.now(),
      );

      await _dbHelper.insert(newTransaction);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction Saved!')),
      );

      _formKey.currentState!.reset();
      _amountController.clear();
      _descriptionController.clear();
      _tagsController.clear();

      _fetchRecurringSuggestions();
    }
  }

  void _applySuggestion(RecurringTransactionSuggestion suggestion) {
    _amountController.text = suggestion.amount.toInt().toString();
    _tagsController.text = suggestion.tags;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Applied suggestion for $_indianRupeeSymbol${suggestion.amount.toInt()} - ${suggestion.tags}')),
    );
  }


  Widget _buildSuggestions() {
    if (_isLoadingSuggestions) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
      );
    }

    if (_recurringSuggestions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 16.0),
        child: Text("No frequent transactions to suggest yet.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Quick Add (Most Frequent):',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: _recurringSuggestions.map((suggestion) {
            return ActionChip(
              avatar: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer, // Adjusted color for variety
                child: Text(
                  suggestion.recurrenceCount.toString(), // CHANGED: Use recurrence count
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 12, // Adjust font size if needed
                  ),
                ),
              ),
              label: Text('$_indianRupeeSymbol${suggestion.amount.toInt()} - ${suggestion.tags}'), // Label still shows amount and tags
              onPressed: () {
                _applySuggestion(suggestion);
              },
              tooltip: 'Count: ${suggestion.recurrenceCount}. Tap to autofill amount and tags.',
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Transaction'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount*',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Amount must be greater than zero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter at least one tag';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitTransaction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('Save Transaction'),
              ),
              _buildSuggestions(),
            ],
          ),
        ),
      ),
    );
  }
}