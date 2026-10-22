import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_app/game/date_service.dart';


void main() {
  test('fetchDate returns today in YYYYMMDD format', () async {
    final result = await fetchDate();

    print('Date returned: $result');

    expect(result, matches(RegExp(r'^\d{8}$')));
    expect(result, '20261010');
  });
}