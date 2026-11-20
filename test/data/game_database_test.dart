import 'package:flutter_test/flutter_test.dart';
import 'package:key_banana/data/game_database.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// A database error with a chosen message, standing in for the real ones the
/// plugin throws. Only the message matters to the check being tested.
class _FakeDbException implements DatabaseException {
  _FakeDbException(this.message);

  final String message;

  @override
  String toString() => 'DatabaseException($message)';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // ==========================================
  // 1. ERRORS THAT MEAN THE FILE IS UNREADABLE
  // ==========================================
  //
  // Only these may lead to the database being deleted and recreated.
  group('isUnreadableError: unreadable file', () {
    test('a wrong encryption key (SQLITE_NOTADB)', () {
      final error = _FakeDbException('file is not a database (code 26)');

      expect(GameDatabase.isUnreadableError(error), isTrue);
    });

    test('the same error worded the SQLCipher way', () {
      final error = _FakeDbException(
        'file is encrypted or is not a database (code 26)',
      );

      expect(GameDatabase.isUnreadableError(error), isTrue);
    });

    test('the result code name on its own (SQLITE_NOTADB)', () {
      final error = _FakeDbException('open failed: SQLITE_NOTADB');

      expect(GameDatabase.isUnreadableError(error), isTrue);
    });

    test('a corrupt file ("malformed")', () {
      final error = _FakeDbException(
        'database disk image is malformed (code 11)',
      );

      expect(GameDatabase.isUnreadableError(error), isTrue);
    });

    test('the result code name on its own (SQLITE_CORRUPT)', () {
      final error = _FakeDbException('open failed: SQLITE_CORRUPT');

      expect(GameDatabase.isUnreadableError(error), isTrue);
    });

    test('ignores letter case in the message', () {
      final error = _FakeDbException('FILE IS NOT A DATABASE');

      expect(GameDatabase.isUnreadableError(error), isTrue);
    });
  });

  // ==========================================
  // 2. ERRORS THAT MUST NEVER WIPE THE HISTORY
  // ==========================================
  //
  // These can happen to a healthy database, so they must be rethrown.
  group('isUnreadableError: ordinary errors keep the data', () {
    test('a locked database (SQLITE_BUSY)', () {
      final error = _FakeDbException('database is locked (code 5)');

      expect(GameDatabase.isUnreadableError(error), isFalse);
    });

    test('a disk I/O error', () {
      final error = _FakeDbException('disk I/O error (code 10)');

      expect(GameDatabase.isUnreadableError(error), isFalse);
    });

    test('a full disk', () {
      final error = _FakeDbException('database or disk is full (code 13)');

      expect(GameDatabase.isUnreadableError(error), isFalse);
    });

    test('a file that cannot be opened', () {
      final error = _FakeDbException('unable to open database file (code 14)');

      expect(GameDatabase.isUnreadableError(error), isFalse);
    });

    test('a read-only database', () {
      final error = _FakeDbException(
        'attempt to write a readonly database (code 8)',
      );

      expect(GameDatabase.isUnreadableError(error), isFalse);
    });

    test('a failed migration (bad SQL)', () {
      final error = _FakeDbException('no such column: streak_bonus (code 1)');

      expect(GameDatabase.isUnreadableError(error), isFalse);
    });

    test('a constraint error from saving the same day twice', () {
      final error = _FakeDbException(
        'UNIQUE constraint failed: games.date_key (code 2067)',
      );

      expect(GameDatabase.isUnreadableError(error), isFalse);
    });

    test('an empty message', () {
      expect(GameDatabase.isUnreadableError(_FakeDbException('')), isFalse);
    });
  });

  // ==========================================
  // 3. ERRORS THAT ARE NOT DATABASE ERRORS
  // ==========================================
  //
  // Even with a matching message, anything that is not a DatabaseException
  // is something else (for example secure storage failing) and is rethrown.
  group('isUnreadableError: not a database error', () {
    test('a plain Exception with a matching message', () {
      expect(
        GameDatabase.isUnreadableError(Exception('file is not a database')),
        isFalse,
      );
    });

    test('a StateError', () {
      expect(GameDatabase.isUnreadableError(StateError('malformed')), isFalse);
    });

    test('a String', () {
      expect(GameDatabase.isUnreadableError('file is not a database'), isFalse);
    });

    test('a platform error from secure storage', () {
      expect(
        GameDatabase.isUnreadableError(
          Exception('PlatformException(Exception encountered, read)'),
        ),
        isFalse,
      );
    });
  });
}
