import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:key_banana/services/definition_service.dart';

const _foundBody = '''
[
  {
    "word": "hello",
    "meanings": [
      {
        "partOfSpeech": "exclamation",
        "definitions": [
          {
            "definition": "used as a greeting.",
            "example": "hello there!",
            "synonyms": [],
            "antonyms": []
          }
        ]
      }
    ]
  }
]
''';

const _notFoundBody =
    '{"title":"No Definitions Found","message":"Sorry pal","resolution":"Try again"}';

void main() {
  setUp(clearDefinitionCache);

  group('parseDefinitionResponse', () {
    test('reads the first definition, part of speech and example', () {
      final r = parseDefinitionResponse(_foundBody);
      expect(r.status, DefinitionStatus.found);
      expect(r.partOfSpeech, 'exclamation');
      expect(r.definition, 'used as a greeting.');
      expect(r.example, 'hello there!');
    });

    test('the example is optional', () {
      final r = parseDefinitionResponse(
        '[{"meanings":[{"partOfSpeech":"noun","definitions":'
        '[{"definition":"a thing"}]}]}]',
      );
      expect(r.status, DefinitionStatus.found);
      expect(r.example, isNull);
    });

    test('skips a meaning with no definitions and uses the next', () {
      final r = parseDefinitionResponse(
        '[{"meanings":[{"partOfSpeech":"verb","definitions":[]},'
        '{"partOfSpeech":"noun","definitions":[{"definition":"x"}]}]}]',
      );
      expect(r.status, DefinitionStatus.found);
      expect(r.partOfSpeech, 'noun');
    });

    test('the not-found object is notFound', () {
      expect(
        parseDefinitionResponse(_notFoundBody).status,
        DefinitionStatus.notFound,
      );
    });

    test('an empty list is notFound', () {
      expect(parseDefinitionResponse('[]').status, DefinitionStatus.notFound);
    });

    test('invalid JSON is unavailable, not a crash', () {
      expect(
        parseDefinitionResponse('<html>oops</html>').status,
        DefinitionStatus.unavailable,
      );
    });
  });

  group('fetchDefinition', () {
    test('requests the right HTTPS URL and returns the definition', () async {
      Uri? requested;
      final client = MockClient((request) async {
        requested = request.url;
        return http.Response(_foundBody, 200);
      });

      final r = await fetchDefinition('  Hello ', client: client);

      expect(
        requested.toString(),
        'https://api.dictionaryapi.dev/api/v2/entries/en/hello',
      );
      expect(r.status, DefinitionStatus.found);
    });

    test('a 404 is notFound', () async {
      final client = MockClient((_) async => http.Response(_notFoundBody, 404));
      final r = await fetchDefinition('zzzz', client: client);
      expect(r.status, DefinitionStatus.notFound);
    });

    test('a 500 is unavailable', () async {
      final client = MockClient((_) async => http.Response('error', 500));
      final r = await fetchDefinition('hello', client: client);
      expect(r.status, DefinitionStatus.unavailable);
    });

    test('a network error is unavailable, not thrown', () async {
      final client = MockClient((_) async => throw Exception('offline'));
      final r = await fetchDefinition('hello', client: client);
      expect(r.status, DefinitionStatus.unavailable);
    });

    test('a word with unsafe characters never reaches the network', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(_foundBody, 200);
      });

      for (final bad in ['../etc', 'a b', 'hello?x=1', '', 'café']) {
        final r = await fetchDefinition(bad, client: client);
        expect(r.status, DefinitionStatus.notFound);
      }
      expect(calls, 0);
    });

    test('successful answers are cached; failures are not', () async {
      var calls = 0;
      var fail = true;
      final client = MockClient((_) async {
        calls++;
        return fail
            ? http.Response('error', 500)
            : http.Response(_foundBody, 200);
      });

      expect(
        (await fetchDefinition('hello', client: client)).status,
        DefinitionStatus.unavailable,
      );
      fail = false;
      expect(
        (await fetchDefinition('hello', client: client)).status,
        DefinitionStatus.found,
      );
      expect(
        (await fetchDefinition('hello', client: client)).status,
        DefinitionStatus.found,
      );

      expect(calls, 2); // the failure and the first success; then the cache
    });
  });
}
