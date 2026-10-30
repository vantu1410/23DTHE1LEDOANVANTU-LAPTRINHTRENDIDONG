import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ledoanvantu2/services/attendance_api.dart';

void main() {
  test('cancel sends DELETE to the attendance endpoint exactly once', () async {
    final requests = <http.Request>[];
    final api = AttendanceApi(
      'https://example.com',
      'test-token',
      client: MockClient((r) async {
        requests.add(r);
        return http.Response('', 204);
      }),
    );
    await api.cancelRecord(42);
    expect(requests.single.method, 'DELETE');
    expect(
      requests.single.url.toString(),
      'https://example.com/api/AttendanceApi/42',
    );
    expect(requests.single.headers['Authorization'], 'Bearer test-token');
  });
  test(
    'cancel reports forbidden response rather than pretending success',
    () async {
      final api = AttendanceApi(
        'https://example.com',
        'test-token',
        client: MockClient((r) async => http.Response('', 403)),
      );
      expect(() => api.cancelRecord(42), throwsException);
    },
  );
}
