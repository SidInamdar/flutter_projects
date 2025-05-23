// lib/screens/add_transaction_page.dart
import 'package:flutter/material.dart';
import 'package:spendtrack/models/transaction_model.dart';
import 'package:spendtrack/db/database_helper.dart';
import 'package:spendtrack/models/recurring_transaction_suggestion.dart';
import 'package:collection/collection.dart'; // Import for SetEquality
// Assuming app name is spendtrack for imports

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController(); // User can still type custom tags

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<RecurringTransactionSuggestion> _recurringSuggestions = [];
  bool _isLoadingSuggestions = true;
  final String _indianRupeeSymbol = '₹';

  // --- Predefined Tags ---
  final List<String> _predefinedTags = [
    // Food & Drinks
    "Groceries", "Dining Out", "Takeaway/Delivery", "Office Lunch/Snacks",
    // Commute & Vehicle
    "Public Transport", "Fuel", "Taxi/Rideshare", "Vehicle Maintenance",
    // Housing & Utilities
    "Rent/EMI", "Utilities", "Home Maintenance",
    // Shopping
    "Online Shopping", "Tech/Gadgets", "Clothing", "Household Items",
    // Personal & Lifestyle
    "Personal Care", "Health & Wellness", "Entertainment", "Subscriptions",
    // Large & One-Time
    "Travel/Vacation", "Gifts & Donations", "Financial",
    // Miscellaneous
    "Miscellaneous"
  ];
  Set<String> _selectedPredefinedTags = {}; // Tracks selected predefined tags

  @override
  void initState() {
    super.initState();
    _fetchRecurringSuggestions();
    _tagsController.addListener(_onTagsTextChanged); // Listen to manual text changes
  }

  void _onTagsTextChanged() {
    // When user types manually, update the selected predefined tags based on text field content
    final currentTags = _tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toSet();
    if (!SetEquality().equals(currentTags, _selectedPredefinedTags.map((t) => t.trim()).toSet())) {
      setState(() {
        _selectedPredefinedTags = _predefinedTags.where((pt) => currentTags.contains(pt)).toSet();
      });
    }
  }


  Future<void> _fetchRecurringSuggestions() async {
    if (!mounted) return;
    setState(() => _isLoadingSuggestions = true);
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
      setState(() => _isLoadingSuggestions = false);
    }
  }

  @override
  void dispose() {
    _tagsController.removeListener(_onTagsTextChanged);
    _amountController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _submitTransaction() async {
    if (_formKey.currentState!.validate()) {
      final amount = double.tryParse(_amountController.text);
      final String description = _descriptionController.text;
      // Use the text from the controller, which is updated by chip selection or manual input
      final String tags = _tagsController.text.trim().replaceAll(RegExp(r',*$'), ''); // Remove trailing commas


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

      try {
        final firebaseKey = await _dbHelper.insert(newTransaction);
        if (firebaseKey != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction Saved!')),
          );
          _formKey.currentState!.reset();
          _amountController.clear();
          _descriptionController.clear();
          _tagsController.clear(); // This will also trigger _onTagsTextChanged, clearing _selectedPredefinedTags
          // _selectedPredefinedTags.clear(); // Explicitly clear selected tags state
          // setState(() {}); // Ensure UI for chips updates if _tagsController.clear() doesn't trigger listener fast enough

          _fetchRecurringSuggestions();
          if (Navigator.canPop(context)) {
            Navigator.pop(context, true);
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save transaction.'), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving transaction: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _applySuggestion(RecurringTransactionSuggestion suggestion) {
    _amountController.text = suggestion.amount.toInt().toString();
    _tagsController.text = suggestion.tags; // This will trigger _onTagsTextChanged
    // Update selected predefined tags based on the suggestion
    final suggestedTags = suggestion.tags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toSet();
    setState(() {
      _selectedPredefinedTags = _predefinedTags.where((pt) => suggestedTags.contains(pt)).toSet();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Applied: $_indianRupeeSymbol${suggestion.amount.toInt()} - ${suggestion.tags}')),
    );
  }

  Widget _buildRecurringSuggestions() {
    if (_isLoadingSuggestions) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
      );
    }
    if (_recurringSuggestions.isEmpty) {
      return const SizedBox.shrink(); // Don't show if no suggestions
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16), // Space before suggestions
        Text(
          'Quick Add (Most Frequent):',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: _recurringSuggestions.map((suggestion) {
            return ActionChip(
              avatar: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                child: Text(
                  suggestion.recurrenceCount.toString(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              label: Text('$_indianRupeeSymbol${suggestion.amount.toInt()} - ${suggestion.tags}'),
              onPressed: () => _applySuggestion(suggestion),
              tooltip: 'Count: ${suggestion.recurrenceCount}. Tap to autofill.',
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- Widget for Predefined Tags ---
  Widget _buildPredefinedTags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          "Select Tags (or type custom):",
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8.0),
        Wrap(
          spacing: 8.0, // Horizontal space between chips
          runSpacing: 4.0, // Vertical space between lines of chips
          children: _predefinedTags.map((tag) {
            final isSelected = _selectedPredefinedTags.contains(tag);
            return FilterChip(
              label: Text(tag),
              selected: isSelected,
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    _selectedPredefinedTags.add(tag);
                  } else {
                    _selectedPredefinedTags.remove(tag);
                  }
                  // Update the text field based on selected predefined tags
                  _tagsController.text = _selectedPredefinedTags.join(', ');
                });
              },
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
              labelStyle: TextStyle(
                fontSize: 13,
                color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).textTheme.bodyLarge?.color,
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Makes chip smaller
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), // Adjust padding
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
                decoration: const InputDecoration(labelText: 'Amount*', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter an amount';
                  if (double.tryParse(value) == null) return 'Please enter a valid number';
                  if (double.parse(value) <= 0) return 'Amount must be greater than zero';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description)),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              // --- Tags Section ---
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  hintText: "e.g., food, travel, groceries",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
                // Listener updates _selectedPredefinedTags if user types manually
              ),
              _buildPredefinedTags(), // Display selectable predefined tags

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitTransaction,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 18)),
                child: const Text('Save Transaction'),
              ),
              _buildRecurringSuggestions(), // Display recurring suggestions
            ],
          ),
        ),
      ),
    );
  }
}
