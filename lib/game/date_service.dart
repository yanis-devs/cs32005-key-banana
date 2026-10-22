import 'dart:convert';
import 'package:http/http.dart' as http;

Future<String> fetchDate() async {
  try {
    final address = Uri.parse('https://timeapi.io/api/v1/time/current/utc');

    final response = await http.get(
      address, 
      headers: {'accept': '*/*'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final String utcTimeString = data['utc_time'];

      // 1. Grab date part: "2026-10-10"
      // 2. Strip dashes: "20261010"
      return utcTimeString.split('T')[0].replaceAll('-', '');
    }
  } catch (e) {
    print('Failed to reach time server: $e');
  }

  // Fallback: If offline or failed, grab device time, format it, and clean it too!
  print('Using fallback device time.');
  final DateTime now = DateTime.now().toUtc();
  
  // Convert device DateTime to ISO string, grab the date part, and strip dashes
  final String deviceIsoString = now.toIso8601String();
  return deviceIsoString.split('T')[0].replaceAll('-', '');
}