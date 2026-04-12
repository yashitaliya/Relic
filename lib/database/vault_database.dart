import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'dart:typed_data';

class VaultFile {
  final String id;
  final String originalPath;
  final String encryptedPath;
  final String type; // 'image' or 'video'
  final DateTime dateAdded;
  final Uint8List? thumbnail;
  final String? originalFilename;
  final DateTime? originalCreatedAt;

  VaultFile({
    required this.id,
    required this.originalPath,
    required this.encryptedPath,
    required this.type,
    required this.dateAdded,
    this.thumbnail,
    this.originalFilename,
    this.originalCreatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'originalPath': originalPath,
      'encryptedPath': encryptedPath,
      'type': type,
      'dateAdded': dateAdded.toIso8601String(),
      'thumbnail': thumbnail,
      'originalFilename': originalFilename,
      'originalCreatedAt': originalCreatedAt?.toIso8601String(),
    };
  }

  factory VaultFile.fromMap(Map<String, dynamic> map) {
    return VaultFile(
      id: map['id'],
      originalPath: map['originalPath'],
      encryptedPath: map['encryptedPath'],
      type: map['type'],
      dateAdded: DateTime.parse(map['dateAdded']),
      thumbnail: map['thumbnail'],
      originalFilename: map['originalFilename'],
      originalCreatedAt: map['originalCreatedAt'] == null
          ? null
          : DateTime.parse(map['originalCreatedAt']),
    );
  }
}

class VaultDatabase {
  static final VaultDatabase instance = VaultDatabase._init();
  static Database? _database;

  VaultDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('vault.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE vault_files (
        id TEXT PRIMARY KEY,
        originalPath TEXT NOT NULL,
        encryptedPath TEXT NOT NULL,
        type TEXT NOT NULL,
        dateAdded TEXT NOT NULL,
        thumbnail BLOB,
        originalFilename TEXT,
        originalCreatedAt TEXT
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE vault_files ADD COLUMN thumbnail BLOB');
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE vault_files ADD COLUMN originalFilename TEXT',
      );
      await db.execute(
        'ALTER TABLE vault_files ADD COLUMN originalCreatedAt TEXT',
      );
    }
  }

  Future<void> insertFile(VaultFile file) async {
    final db = await database;
    await db.insert('vault_files', file.toMap());
  }

  Future<List<VaultFile>> getAllFiles() async {
    final db = await database;
    final result = await db.query('vault_files', orderBy: 'dateAdded DESC');
    return result.map((json) => VaultFile.fromMap(json)).toList();
  }

  Future<void> deleteFile(String id) async {
    final db = await database;
    await db.delete('vault_files', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
