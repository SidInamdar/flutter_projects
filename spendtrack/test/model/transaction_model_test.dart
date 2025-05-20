// test/models/transaction_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spendtrack/models/transaction_model.dart'; // Replace your_app_name

void main() {
  group('TransactionModel', () {
    test('should create a TransactionModel instance with given values', () {
      final date = DateTime.now();
      final transaction = TransactionModel(
        id: 1,
        amount: 100.0,
        description: 'Test Transaction',
        tags: 'test, flutter',
        date: date,
      );

      expect(transaction.id, 1);
      expect(transaction.amount, 100.0);
      expect(transaction.description, 'Test Transaction');
      expect(transaction.tags, 'test, flutter');
      expect(transaction.date, date);
    });

    test('toMap should return a valid map', () {
      final date = DateTime(2024, 5, 20);
      final transaction = TransactionModel(
        id: 1,
        amount: 100.0,
        description: 'Lunch',
        tags: 'food',
        date: date,
      );

      final map = transaction.toMap();

      expect(map['id'], 1);
      expect(map['amount'], 100.0);
      expect(map['description'], 'Lunch');
      expect(map['tags'], 'food');
      expect(map['date'], date.toIso8601String());
    });

    test('fromMap should create a valid TransactionModel instance', () {
      final date = DateTime(2024, 5, 20);
      final map = {
        'id': 1,
        'amount': 100.0,
        'description': 'Lunch',
        'tags': 'food',
        'date': date.toIso8601String(),
      };

      final transaction = TransactionModel.fromMap(map);

      expect(transaction.id, 1);
      expect(transaction.amount, 100.0);
      expect(transaction.description, 'Lunch');
      expect(transaction.tags, 'food');
      expect(transaction.date, date);
    });
  });
}

