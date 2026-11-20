import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../game/game_session.dart';
import 'streak.dart';

/// One finished daily game, as stored.
class SavedGame {
  const SavedGame({
    required this.dateKey,
    required this.score,
    required this.playedAt,
  });

  /// The game's date as yyyymmdd (e.g. 20261114).
  final int dateKey;

  /// Final score of the game.
  final double score;

  /// When the game was saved (UTC).
  final DateTime playedAt;
}

/// Summary numbers for the home and stats screens.
class GameStats {
  const GameStats({
    required this.gamesPlayed,
    required this.bestScore,
    required this.lastScore,
    required this.currentStreak,
  });

  /// Total number of saved daily games.
  final int gamesPlayed;

  /// Highest final score across all saved games (0 if none).
  final double bestScore;

  /// Score of the most recent daily game, or null if none played yet.
  final double? lastScore;

  /// Consecutive days played, as worked out by [computeStreak].
  final int currentStreak;
}

/// Encrypted local history of daily games.
///
/// The database is encrypted with SQLCipher. Its random passphrase is created
/// on first launch and kept in the Android Keystore through
/// flutter_secure_storage, so it never sits in the app's files or source code.
///
/// Only finished daily games are stored. Practice games are never saved.
class GameDatabase {
  GameDatabase._(this._db);

  /// Name of the database file inside the app's databases folder.
  static const String _fileName = 'kbanana.db';

  /// Secure-storage key under which the database passphrase is kept.
  static const String _passphraseKey = 'db_passphrase';

  final Database _db;

  /// Opens (creating if needed) the encrypted database.
  ///
  /// If the file cannot be opened (for example it was restored from a backup
  /// without its key), it is deleted and recreated empty, so the app still
  /// starts. Stored history is lost in that case.
  static Future<GameDatabase> open() async {
    final passphrase = await _getOrCreatePassphrase();
    final path = '${await getDatabasesPath()}/$_fileName';

    try {
      return GameDatabase._(await _openAt(path, passphrase));
    } catch (e) {
      // Only an unreadable file (wrong key, corrupt) is safe to discard. Busy,
      // I/O, disk-full and migration errors may hit a healthy database, so they
      // are rethrown and the history is kept.
      if (!isUnreadableError(e)) rethrow;

      debugPrint('Database is unreadable, recreating it: $e');
      await deleteDatabase(path);
      return GameDatabase._(await _openAt(path, passphrase));
    }
  }

  /// True for the errors that mean "this file cannot be decrypted or is
  /// corrupt": SQLite's NOTADB (wrong key), CORRUPT, or SQLCipher open failures.
  @visibleForTesting
  static bool isUnreadableError(Object error) {
    if (error is! DatabaseException) return false;
    final text = error.toString().toLowerCase();
    return text.contains('not a database') ||
        text.contains('sqlite_notadb') ||
        text.contains('malformed') ||
        text.contains('sqlite_corrupt') ||
        text.contains('open_failed');
  }

  /// Opens the database at [path] with [passphrase], creating the `games` and
  /// `rounds` tables on first run.
  static Future<Database> _openAt(String path, String passphrase) {
    return openDatabase(
      path,
      password: passphrase,
      version: 1,
      onCreate: (db, version) async {
        // date_key is UNIQUE: at most one daily game per day, enforced here
        // as well as in the UI.
        await db.execute('''
          CREATE TABLE games (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date_key INTEGER NOT NULL UNIQUE,
            score REAL NOT NULL,
            played_at TEXT NOT NULL
          )
        ''');
        // One row per round, linked to its game.
        await db.execute('''
          CREATE TABLE rounds (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            game_id INTEGER NOT NULL REFERENCES games(id),
            round_number INTEGER NOT NULL,
            constraint_text TEXT NOT NULL,
            word TEXT NOT NULL,
            outcome TEXT NOT NULL,
            seconds_left REAL NOT NULL,
            points REAL NOT NULL
          )
        ''');
      },
    );
  }

  /// Returns the stored database passphrase, generating and saving a new
  /// random one on first launch.
  static Future<String> _getOrCreatePassphrase() async {
    const storage = FlutterSecureStorage();

    var passphrase = await storage.read(key: _passphraseKey);
    if (passphrase == null) {
      // 32 random bytes from a cryptographically secure source, written as
      // a 64-character hex string.
      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      passphrase = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await storage.write(key: _passphraseKey, value: passphrase);
    }
    return passphrase;
  }

  /// Saves a finished daily game and all its rounds in one transaction, so a
  /// game is never half-saved.
  ///
  /// Throws if the game is a practice game, is not finished, or today's daily
  /// game was already saved. Check [hasPlayedDaily] first.
  Future<void> saveGame(GameSession session) async {
    if (session.isPractice) {
      throw ArgumentError('Practice games are not saved.');
    }
    if (!session.isFinished) {
      throw StateError('Only finished games can be saved.');
    }

    await _db.transaction((txn) async {
      final gameId = await txn.insert('games', {
        'date_key': session.dateKey,
        'score': session.finalScore,
        'played_at': DateTime.now().toUtc().toIso8601String(),
      });

      for (final r in session.results) {
        await txn.insert('rounds', {
          'game_id': gameId,
          'round_number': r.round,
          'constraint_text': r.constraint,
          'word': r.word,
          // Stored by enum name, which is why RoundOutcome values must not
          // be renamed after release.
          'outcome': r.outcome.name,
          'seconds_left': r.secondsLeft,
          'points': r.points,
        });
      }
    });
  }

  /// The saved game for [dateKey] (yyyymmdd), or null if not played.
  Future<SavedGame?> getDailyGame(int dateKey) async {
    final rows = await _db.query(
      'games',
      where: 'date_key = ?',
      whereArgs: [dateKey],
      limit: 1,
    );
    return rows.isEmpty ? null : _toSavedGame(rows.first);
  }

  /// Whether a daily game has already been saved for [dateKey] (yyyymmdd).
  Future<bool> hasPlayedDaily(int dateKey) async =>
      await getDailyGame(dateKey) != null;

  /// Totals and streak. [todayKey] is the current date as yyyymmdd.
  Future<GameStats> getStats(int todayKey) async {
    final rows = await _db.query('games', orderBy: 'date_key DESC');
    if (rows.isEmpty) {
      return const GameStats(
        gamesPlayed: 0,
        bestScore: 0,
        lastScore: null,
        currentStreak: 0,
      );
    }

    final games = rows.map(_toSavedGame).toList(); // newest first
    return GameStats(
      gamesPlayed: games.length,
      bestScore: games.map((g) => g.score).reduce(max),
      lastScore: games.first.score,
      currentStreak: computeStreak(
        games.map((g) => g.dateKey).toList(),
        todayKey,
      ),
    );
  }

  /// The most recent saved games, newest first.
  Future<List<SavedGame>> getHistory({int limit = 10}) async {
    final rows = await _db.query(
      'games',
      orderBy: 'date_key DESC',
      limit: limit,
    );
    return rows.map(_toSavedGame).toList();
  }

  /// Closes the database connection.
  Future<void> close() => _db.close();

  /// Converts a `games` table row into a [SavedGame].
  static SavedGame _toSavedGame(Map<String, Object?> row) => SavedGame(
    dateKey: row['date_key'] as int,
    score: (row['score'] as num).toDouble(),
    playedAt: DateTime.parse(row['played_at'] as String),
  );
}
