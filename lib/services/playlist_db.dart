import 'package:sqflite/sqflite.dart';

class CustomPlaylist {
  final int id;
  final String name;
  final DateTime createdAt;

  CustomPlaylist({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'name': name,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory CustomPlaylist.fromMap(Map<String, dynamic> map) => CustomPlaylist(
        id: map['id'] as int,
        name: map['name'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}

class PlaylistDb {
  static final PlaylistDb instance = PlaylistDb._init();
  static Database? _database;

  PlaylistDb._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('playon_playlists.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$filePath';

    return await openDatabase(
      path,
      version: 1,
      onConfigure: _onConfigure,
      onCreate: _createDB,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE playlist_songs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id INTEGER NOT NULL,
        song_id INTEGER NOT NULL,
        FOREIGN KEY (playlist_id) REFERENCES playlists (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_playlist_songs_playlist_id 
      ON playlist_songs (playlist_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_playlist_songs_song_id 
      ON playlist_songs (song_id)
    ''');
  }

  Future<CustomPlaylist> createPlaylist(String name) async {
    final db = await database;
    final now = DateTime.now();
    final id = await db.insert('playlists', {
      'name': name.trim(),
      'created_at': now.millisecondsSinceEpoch,
    });
    return CustomPlaylist(id: id, name: name.trim(), createdAt: now);
  }

  Future<List<CustomPlaylist>> getAllPlaylists() async {
    final db = await database;
    final result = await db.query('playlists', orderBy: 'created_at DESC');
    return result.map((map) => CustomPlaylist.fromMap(map)).toList();
  }

  Future<int> deletePlaylist(int id) async {
    final db = await database;
    await db.delete('playlist_songs', where: 'playlist_id = ?', whereArgs: [id]);
    return await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> renamePlaylist(int id, String newName) async {
    final db = await database;
    return await db.update(
      'playlists',
      {'name': newName.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    final db = await database;
    final existing = await db.query(
      'playlist_songs',
      where: 'playlist_id = ? AND song_id = ?',
      whereArgs: [playlistId, songId],
    );
    if (existing.isEmpty) {
      await db.insert('playlist_songs', {
        'playlist_id': playlistId,
        'song_id': songId,
      });
    }
  }

  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    final db = await database;
    await db.delete(
      'playlist_songs',
      where: 'playlist_id = ? AND song_id = ?',
      whereArgs: [playlistId, songId],
    );
  }

  Future<List<int>> getSongIdsForPlaylist(int playlistId) async {
    final db = await database;
    final result = await db.query(
      'playlist_songs',
      columns: ['song_id'],
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'id ASC',
    );
    return result.map((row) => row['song_id'] as int).toList();
  }

  Future<Map<int, int>> getSongCountsPerPlaylist() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT playlist_id, COUNT(song_id) as count 
      FROM playlist_songs 
      GROUP BY playlist_id
    ''');
    final map = <int, int>{};
    for (final row in result) {
      map[row['playlist_id'] as int] = row['count'] as int;
    }
    return map;
  }
}
