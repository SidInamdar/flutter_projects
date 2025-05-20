// lib/db/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';
import '../models/recurring_transaction_suggestion.dart';

class DatabaseHelper {
  static const _databaseName = "MyTransactions.db";
  static const _databaseVersion = 1; // Increment if schema changes

  static const table = 'transactions';

  static const columnId = 'id';
  static const columnAmount = 'amount';
  static const columnDescription = 'description';
  static const columnTags = 'tags';
  static const columnDate = 'date';

  // Make this a singleton class
  DatabaseHelper._privateConstructor(); // Private constructor
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor(); // Static final instance

  // Only have a single app-wide reference to the database
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // This opens the database (and creates it if it doesn't exist)
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      // onUpgrade: _onUpgrade, // Add if you have schema migrations
    );
  }

  // SQL code to create the database table
  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnAmount REAL NOT NULL,
        $columnDescription TEXT NOT NULL,
        $columnTags TEXT,
        $columnDate TEXT NOT NULL
      )
    ''');
  }

  // Optional: Add _onUpgrade for schema migrations
  // Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
  //   if (oldVersion < 2) {
  //     // await db.execute("ALTER TABLE $table ADD COLUMN new_column TEXT;");
  //   }
  // }

  // --- CRUD Methods ---
  Future<int> insert(TransactionModel transaction) async {
    Database db = await instance.database;
    return await db.insert(table, transaction.toMap());
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      orderBy: '$columnDate DESC',
    );
    return List.generate(maps.length, (i) {
      return TransactionModel.fromMap(maps[i]);
    });
  }

  Future<int> update(TransactionModel transaction) async {
    Database db = await instance.database;
    int id = transaction.id!;
    return await db.update(table, transaction.toMap(),
        where: '$columnId = ?', whereArgs: [id]);
  }

  Future<int> delete(int id) async {
    Database db = await instance.database;
    return await db.delete(table, where: '$columnId = ?', whereArgs: [id]);
  }

  Future<List<RecurringTransactionSuggestion>> getTopRecurringTransactions() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT $columnAmount, $columnTags, COUNT(*) as recurrence_count
      FROM $table
      WHERE $columnAmount IS NOT NULL AND $columnTags IS NOT NULL AND $columnTags != '' 
      GROUP BY $columnAmount, $columnTags
      ORDER BY recurrence_count DESC
      LIMIT 7 
    '''); // CHANGED: LIMIT 3 to LIMIT 7

    if (maps.isNotEmpty) {
      return maps.map((map) {
        return RecurringTransactionSuggestion(
          amount: map[columnAmount] as double,
          tags: map[columnTags] as String,
          recurrenceCount: map['recurrence_count'] as int,
        );
      }).toList();
    }
    return [];
  }
}