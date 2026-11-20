import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Longest we wait for the dictionary server.
const Duration _requestTimeout = Duration(seconds: 5);

/// Only plain letters are ever put into the request URL.
final RegExp _wordPattern = RegExp(r'^[a-z]{1,45}$');

/// How a definition lookup ended.
enum DefinitionStatus {
  /// A definition was found.
  found,

  /// The server answered but has no definition for this word.
  notFound,

  /// The lookup failed (offline, timeout, server error, unreadable reply).
  unavailable,
}

/// The outcome of a definition lookup. Always returned, never thrown, so the
/// UI can switch on [status] and show a friendly message.
///
/// The text fields are only filled in when [status] is
/// [DefinitionStatus.found].
class DefinitionResult {
  const DefinitionResult.found({
    required this.partOfSpeech,
    required this.definition,
    this.example,
  }) : status = DefinitionStatus.found;

  const DefinitionResult.notFound()
    : status = DefinitionStatus.notFound,
      partOfSpeech = null,
      definition = null,
      example = null;

  const DefinitionResult.unavailable()
    : status = DefinitionStatus.unavailable,
      partOfSpeech = null,
      definition = null,
      example = null;

  /// Whether the lookup found a definition, found none, or failed.
  final DefinitionStatus status;

  /// Word type, e.g. "noun" or "verb". Empty if the API gave none.
  final String? partOfSpeech;

  /// The first definition, trimmed.
  final String? definition;

  /// An example sentence, or null if the API gave none.
  final String? example;
}

/// Turns the Free Dictionary API's JSON into a [DefinitionResult].
///
/// A found word is a list of entries, each with `meanings`, each with
/// `definitions`. A missing word is a plain object ({"title": "No
/// Definitions Found", ...}). The API does not promise specific status codes,
/// so the shape of the body decides, not the status.
///
/// Uses the first usable definition it finds. Returns
/// [DefinitionStatus.unavailable] if [body] is not valid JSON.
@visibleForTesting
DefinitionResult parseDefinitionResponse(String body) {
  try {
    final data = jsonDecode(body);
    if (data is! List || data.isEmpty) return const DefinitionResult.notFound();

    // Skip over anything malformed rather than failing the whole lookup.
    for (final entry in data) {
      if (entry is! Map) continue;
      final meanings = entry['meanings'];
      if (meanings is! List) continue;

      for (final meaning in meanings) {
        if (meaning is! Map) continue;
        final definitions = meaning['definitions'];
        if (definitions is! List || definitions.isEmpty) continue;

        final first = definitions.first;
        if (first is! Map) continue;
        final text = first['definition'];
        if (text is! String || text.trim().isEmpty) continue;

        final example = first['example'];
        final partOfSpeech = meaning['partOfSpeech'];
        return DefinitionResult.found(
          partOfSpeech: partOfSpeech is String ? partOfSpeech : '',
          definition: text.trim(),
          example: example is String && example.trim().isNotEmpty
              ? example.trim()
              : null,
        );
      }
    }
    return const DefinitionResult.notFound();
  } on FormatException {
    return const DefinitionResult.unavailable();
  }
}

/// Remembers answers for the rest of the app session, so reopening the same
/// word is instant and works offline. Failures are never cached.
final Map<String, DefinitionResult> _cache = {};

/// Empties the definition cache. Used by tests.
@visibleForTesting
void clearDefinitionCache() => _cache.clear();

/// Looks up a word on the Free Dictionary API (HTTPS only, 5 second timeout).
///
/// Never throws. Pass a [client] in tests. A client passed in is left open
/// for the caller.
Future<DefinitionResult> fetchDefinition(
  String word, {
  http.Client? client,
}) async {
  // Anything that isn't plain letters never reaches the network.
  final clean = word.trim().toLowerCase();
  if (!_wordPattern.hasMatch(clean)) return const DefinitionResult.notFound();

  final cached = _cache[clean];
  if (cached != null) return cached;

  final httpClient = client ?? http.Client();
  try {
    final uri = Uri.https('api.dictionaryapi.dev', '/api/v2/entries/en/$clean');
    final response = await httpClient.get(uri).timeout(_requestTimeout);

    final DefinitionResult result;
    if (response.statusCode == 200) {
      result = parseDefinitionResponse(response.body);
    } else if (response.statusCode == 404) {
      result = const DefinitionResult.notFound();
    } else {
      result = const DefinitionResult.unavailable();
    }

    // Cache found and not-found answers, but not failures, so a retry can
    // succeed.
    if (result.status != DefinitionStatus.unavailable) _cache[clean] = result;
    return result;
  } catch (e) {
    debugPrint('Definition lookup failed: $e');
    return const DefinitionResult.unavailable();
  } finally {
    // Only close a client created here. A client passed in belongs to the
    // caller.
    if (client == null) httpClient.close();
  }
}
