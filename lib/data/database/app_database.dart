import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// SQLite database helper for StudyBuddy.
class AppDatabase {
  AppDatabase._();

  static const _dbName = 'study_buddy.db';
  static const _dbVersion = 2;

  static Database? _instance;

  static Future<Database> instance({
    DatabaseFactory? factory,
    String? path,
  }) async {
    if (_instance != null) return _instance!;
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await dbFactory.getDatabasesPath(), _dbName);
    _instance = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    return _instance!;
  }

  static Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE flashcards ADD COLUMN mastered INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE quiz_results ADD COLUMN wrong_ids TEXT',
      );
    }
  }

  static Future<void> onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        source_type TEXT NOT NULL DEFAULT 'text',
        file_name TEXT,
        summary TEXT,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE flashcards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        material_id INTEGER NOT NULL,
        front TEXT NOT NULL,
        back TEXT NOT NULL,
        mastered INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (material_id) REFERENCES materials (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE quiz_questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        material_id INTEGER NOT NULL,
        question TEXT NOT NULL,
        options TEXT NOT NULL,
        correct_index INTEGER NOT NULL,
        explanation TEXT,
        FOREIGN KEY (material_id) REFERENCES materials (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE quiz_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        material_id INTEGER NOT NULL,
        total INTEGER NOT NULL,
        correct INTEGER NOT NULL,
        date INTEGER,
        wrong_ids TEXT,
        FOREIGN KEY (material_id) REFERENCES materials (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE study_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        material_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        items TEXT NOT NULL,
        created_at INTEGER,
        FOREIGN KEY (material_id) REFERENCES materials (id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }
}