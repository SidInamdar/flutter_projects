class TransactionModel {
  final int? id; // Nullable for new transactions not yet in DB
  final double amount;
  final String description;
  final String tags; // Could be comma-separated or a JSON string
  final DateTime date;

  TransactionModel({
    this.id,
    required this.amount,
    required this.description,
    required this.tags,
    required this.date,
  });

  // Convert a TransactionModel into a Map. The keys must correspond to the names of the
  // columns in the database.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'description': description,
      'tags': tags,
      'date': date.toIso8601String(), // Store date as ISO8601 string
    };
  }

  // Implement toString to make it easier to see information when debugging.
  @override
  String toString() {
    return 'Transaction{id: $id, amount: $amount, description: $description, tags: $tags, date: $date}';
  }

  // Helper method to create a TransactionModel from a Map
  static TransactionModel fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      amount: map['amount'] as double,
      description: map['description'] as String,
      tags: map['tags'] as String,
      date: DateTime.parse(map['date'] as String),
    );
  }
}