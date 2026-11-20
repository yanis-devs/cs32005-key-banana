import 'package:flutter_test/flutter_test.dart';
import 'package:key_banana/data/date_key.dart';

void main() {
  group('formatDateKey', () {
    test('formats a normal date', () {
      expect(formatDateKey(20261114), '14 Nov 2026');
    });

    test('does not pad the day', () {
      expect(formatDateKey(20270101), '1 Jan 2027');
    });

    test('handles the end of the year', () {
      expect(formatDateKey(20261231), '31 Dec 2026');
    });

    test('an unreadable key comes back as plain digits, not a crash', () {
      expect(formatDateKey(19001399), '19001399');
      expect(formatDateKey(0), '0');
    });
  });
}
