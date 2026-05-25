import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'blind_notes.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            scanned_text TEXT,
            summary TEXT,
            date TEXT
          )
        ''');
      },
    );
  }

  static Future<void> saveNote(String scannedText, String summary) async {
    final db = await database;
    await db.insert('notes', {
      'scanned_text': scannedText,
      'summary': summary,
      'date': DateTime.now().toString().substring(0, 16),
    });
  }

  static Future<List<Map<String, dynamic>>> getNotes() async {
    final db = await database;
    return db.query('notes', orderBy: 'id DESC');
  }

  // Filter notes by a specific date prefix e.g. "2024-06-01"
  static Future<List<Map<String, dynamic>>> getNotesByDate(String datePrefix) async {
    final db = await database;
    return db.query(
      'notes',
      where: 'date LIKE ?',
      whereArgs: ['$datePrefix%'],
      orderBy: 'id DESC',
    );
  }

  static Future<void> deleteNote(int id) async {
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteAllNotes() async {
    final db = await database;
    await db.delete('notes');
  }
}