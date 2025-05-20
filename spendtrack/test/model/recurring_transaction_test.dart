// test/models/recurring_transaction_suggestion_test.dart
import 'package:flutter_test/flutter_test.dart';
// Replace your_app_name with your actual project name
import 'package:spendtrack/models/recurring_transaction_suggestion.dart';

void main() {
  group('RecurringTransactionSuggestion', () {
    test('should create an instance with given values', () {
      final suggestion = RecurringTransactionSuggestion(
        amount: 50.0,
        tags: 'coffee, daily',
        recurrenceCount: 5,
      );

      expect(suggestion.amount, 50.0);
      expect(suggestion.tags, 'coffee, daily');
      expect(suggestion.recurrenceCount, 5);
    });

    test('toString should return a readable string', () {
      final suggestion = RecurringTransactionSuggestion(
        amount: 50.0,
        tags: 'coffee',
        recurrenceCount: 5,
      );
      // Example: RecurringSuggestion(amount: 50.0, tags: "coffee", count: 5)
      expect(suggestion.toString(), contains('amount: 50.0'));
      expect(suggestion.toString(), contains('tags: "coffee"'));
      expect(suggestion.toString(), contains('count: 5'));
    });
  });
}
