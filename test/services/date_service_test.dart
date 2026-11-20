import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:key_banana/services/date_service.dart';

/// Today's UTC date from the device clock, as yyyymmdd. Mirrors the fallback
/// inside fetchDate.
String deviceDateKey() {
  final now = DateTime.now().toUtc();
  return '${now.year}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}';
}

/// A client that answers every request with [body] and [status].
MockClient replyWith(String body, {int status = 200}) {
  return MockClient((_) async => http.Response(body, status));
}

/// Asserts that [result] is today's device date. The clock is read before and
/// after the call so the test cannot fail if UTC midnight passes in between.
void expectDeviceDate(String result, String before, String after) {
  expect([before, after], contains(result));
}

void main() {
  // ==========================================
  // 1. TIME SERVER ANSWERS CORRECTLY
  // ==========================================
  group('when the time server answers', () {
    test('returns the server date as yyyymmdd', () async {
      final client = replyWith('{"utc_time":"2026-11-11T11:08:14.123Z"}');

      expect(await fetchDate(client: client), '20261111');
    });

    test('uses the server date, not the device date', () async {
      final client = replyWith('{"utc_time":"2020-01-02T00:00:00Z"}');

      expect(await fetchDate(client: client), '20200102');
    });

    test('keeps leading zeros in month and day', () async {
      final client = replyWith('{"utc_time":"2027-03-05T23:59:59Z"}');

      expect(await fetchDate(client: client), '20270305');
    });

    test('asks the HTTPS time endpoint', () async {
      Uri? requested;
      final client = MockClient((request) async {
        requested = request.url;
        return http.Response('{"utc_time":"2026-11-11T11:08:14Z"}', 200);
      });

      await fetchDate(client: client);

      expect(
        requested.toString(),
        'https://timeapi.io/api/v1/time/current/utc',
      );
    });

    test('makes exactly one request', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{"utc_time":"2026-11-11T11:08:14Z"}', 200);
      });

      await fetchDate(client: client);

      expect(calls, 1);
    });
  });

  // ==========================================
  // 2. FALLBACK TO THE DEVICE CLOCK
  // ==========================================
  group('falls back to the device clock', () {
    test('when the server returns a non-200 status', () async {
      final before = deviceDateKey();
      final result = await fetchDate(
        client: replyWith('{"utc_time":"2020-01-02T00:00:00Z"}', status: 500),
      );
      final after = deviceDateKey();

      expectDeviceDate(result, before, after);
    });

    test('when the body is not valid JSON', () async {
      final before = deviceDateKey();
      final result = await fetchDate(client: replyWith('<html>oops</html>'));
      final after = deviceDateKey();

      expectDeviceDate(result, before, after);
    });

    test('when the body is JSON but not an object', () async {
      final before = deviceDateKey();
      final result = await fetchDate(client: replyWith('["2026-11-11"]'));
      final after = deviceDateKey();

      expectDeviceDate(result, before, after);
    });

    test('when utc_time is missing', () async {
      final before = deviceDateKey();
      final result = await fetchDate(client: replyWith('{"other":"value"}'));
      final after = deviceDateKey();

      expectDeviceDate(result, before, after);
    });

    test('when utc_time is not a string', () async {
      final before = deviceDateKey();
      final result = await fetchDate(client: replyWith('{"utc_time":12345}'));
      final after = deviceDateKey();

      expectDeviceDate(result, before, after);
    });

    test('when the date is not eight digits', () async {
      final before = deviceDateKey();
      final result = await fetchDate(
        client: replyWith('{"utc_time":"2026-1-1T11:08:14Z"}'),
      );
      final after = deviceDateKey();

      expectDeviceDate(result, before, after);
    });

    test('when the date contains letters', () async {
      final before = deviceDateKey();
      final result = await fetchDate(
        client: replyWith('{"utc_time":"abcd-ef-ghT11:08:14Z"}'),
      );
      final after = deviceDateKey();

      expectDeviceDate(result, before, after);
    });

    test('when the request throws', () async {
      final before = deviceDateKey();
      final result = await fetchDate(
        client: MockClient((_) async => throw Exception('offline')),
      );
      final after = deviceDateKey();

      expectDeviceDate(result, before, after);
    });
  });

  // ==========================================
  // 3. SHAPE OF THE RESULT
  // ==========================================
  group('result format', () {
    test('is always eight digits, even on fallback', () async {
      final fromServer = await fetchDate(
        client: replyWith('{"utc_time":"2026-11-11T11:08:14Z"}'),
      );
      final fromFallback = await fetchDate(
        client: MockClient((_) async => throw Exception('offline')),
      );

      expect(fromServer, matches(RegExp(r'^\d{8}$')));
      expect(fromFallback, matches(RegExp(r'^\d{8}$')));
    });

    test('can be parsed as the integer seed the game uses', () async {
      final result = await fetchDate(
        client: replyWith('{"utc_time":"2026-11-11T11:08:14Z"}'),
      );

      expect(int.parse(result), 20261111);
    });
  });
}
