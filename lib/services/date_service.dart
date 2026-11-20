import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Longest we wait for the time server before falling back to device time.
const Duration _requestTimeout = Duration(seconds: 2);

/// A valid date key looks like "20261111".
final RegExp _dateKeyPattern = RegExp(r'^\d{8}$');

/// Returns today's UTC date as a yyyymmdd string.
///
/// Uses the time API so every player shares the same daily puzzle, and falls
/// back to the device clock if the request fails, times out or returns
/// something unexpected. Never throws.
///
/// Pass a [client] in tests. A client passed in is left open for the caller.
Future<String> fetchDate({http.Client? client}) async {
  final httpClient = client ?? http.Client();
  try {
    final address = Uri.parse('https://timeapi.io/api/v1/time/current/utc');

    final response = await httpClient
        .get(address, headers: {'accept': '*/*'})
        .timeout(_requestTimeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final utcTime = data is Map ? data['utc_time'] : null;

      if (utcTime is String) {
        // Keep only the date part and strip the dashes.
        // "2026-11-11T11:08:14..." -> "20261111"
        final key = utcTime.split('T')[0].replaceAll('-', '');
        if (_dateKeyPattern.hasMatch(key)) return key;
      }
      debugPrint('Time API returned an unexpected body: ${response.body}');
    } else {
      debugPrint('Time API returned status ${response.statusCode}.');
    }
  } catch (e) {
    debugPrint('Failed to reach time server: $e');
  } finally {
    // Only close a client created here. A client passed in belongs to the
    // caller.
    if (client == null) httpClient.close();
  }

  // Reached on any failure above (a successful response returns early).
  debugPrint('Using fallback device time.');
  return _deviceDateKey();
}

/// Today's UTC date from the device clock, as yyyymmdd.
///
/// Used only as a fallback, since a wrong device clock can give a player a
/// different daily puzzle from everyone else.
String _deviceDateKey() {
  final iso = DateTime.now().toUtc().toIso8601String();
  return iso.split('T')[0].replaceAll('-', '');
}
