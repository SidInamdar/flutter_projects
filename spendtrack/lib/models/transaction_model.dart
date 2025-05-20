class TransactionModel {
  final String? id; // Now represents Firebase key, nullable for new transactions
  final double amount;
  final String description;
  final String tags;
  final DateTime date;

  TransactionModel({
    this.id,
    required this.amount,
    required this.description,
    required this.tags,
    required this.date,
  });

  // For saving to Firebase (doesn't include local 'id' as Firebase generates its own key)
  Map<String, dynamic> toMapWithoutId() {
    return {
      'amount': amount,
      'description': description,
      'tags': tags,
      'date': date.toIso8601String(), // Store date as ISO8601 string for sortability
    };
  }

  // For local use if needed (e.g., if you were still using SQLite in parallel)
  Map<String, dynamic> toMapWithLocalId() {
    return {
      'id': id, // This would be the local SQLite ID
      'amount': amount,
      'description': description,
      'tags': tags,
      'date': date.toIso8601String(),
    };
  }

  // Create a TransactionModel from a Firebase snapshot
  static TransactionModel fromMapFirebase(String key, Map<String, dynamic> map) {
    return TransactionModel(
      id: key, // Firebase key becomes the ID
      amount: (map['amount'] as num).toDouble(), // Firebase might store numbers as num
      description: map['description'] as String? ?? '', // Handle potential null
      tags: map['tags'] as String? ?? '',             // Handle potential null
      date: DateTime.parse(map['date'] as String),
    );
  }


  @override
  String toString() {
    return 'Transaction{id: $id, amount: $amount, description: $description, tags: $tags, date: $date}';
  }
}
    