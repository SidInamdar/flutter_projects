// lib/models/recurring_transaction_suggestion.dart
class RecurringTransactionSuggestion {
  final double amount;
  final String tags;
  final int recurrenceCount;

  RecurringTransactionSuggestion({
    required this.amount,
    required this.tags,
    required this.recurrenceCount,
  });

  @override
  String toString() {
    return 'RecurringSuggestion(amount: $amount, tags: "$tags", count: $recurrenceCount)';
  }
}