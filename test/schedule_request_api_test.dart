import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ledoanvantu2/services/schedule_request_api.dart';

void main() {
  Map<String, dynamic> row({String status = 'pending'}) => {
    'id': 7,
    'userId': 2,
    'fullName': 'Nhân viên mẫu',
    'type': 'late',
    'workDate': '2026-10-30',
    'timeMinutes': 540,
    'reason': 'Có việc cá nhân',
    'status': status,
  };
  test(
    'create sends chosen date, time and reason with authentication',
    () async {
      final api = ScheduleRequestApi(
        'https://example.com',
        'token',
        client: MockClient((r) async {
          expect(r.method, 'POST');
          expect(r.url.toString(), 'https://example.com/api/ScheduleRequests');
          expect(r.headers['Authorization'], 'Bearer token');
          final body = jsonDecode(r.body);
          expect(body['workDate'], '2026-10-30');
          expect(body['timeMinutes'], 540);
          expect(body['reason'], 'Có việc cá nhân');
          return http.Response(
            jsonEncode(row()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final saved = await api.create(
        'late',
        DateTime(2026, 10, 30),
        540,
        'Có việc cá nhân',
      );
      expect(saved.statusLabel, 'Chờ duyệt');
      expect(saved.timeLabel, '09:00');
    },
  );
  test('review sends decision to the exact request endpoint', () async {
    final api = ScheduleRequestApi(
      'https://example.com/',
      'token',
      client: MockClient((r) async {
        expect(r.url.path, '/api/ScheduleRequests/7/review');
        expect(jsonDecode(r.body)['status'], 'approved');
        return http.Response.bytes(
          utf8.encode(jsonEncode(row(status: 'approved'))),
          200,
        );
      }),
    );
    expect((await api.review(7, true, 'Đồng ý')).statusLabel, 'Đã duyệt');
  });
  test('non-JSON missing backend is a clear error', () async {
    final api = ScheduleRequestApi(
      'https://example.com',
      'token',
      client: MockClient((r) async => http.Response('<html>404</html>', 404)),
    );
    await expectLater(
      api.list(),
      throwsA(predicate((e) => e.toString().contains('triển khai backend'))),
    );
  });
  test('already reviewed response is not treated as success', () async {
    final api = ScheduleRequestApi(
      'https://example.com',
      'token',
      client: MockClient(
        (r) async => http.Response.bytes(
          utf8.encode(jsonEncode({'message': 'Đơn đã được xử lý'})),
          409,
        ),
      ),
    );
    await expectLater(
      api.review(7, false, ''),
      throwsA(predicate((e) => e.toString() == 'Exception: Đơn đã được xử lý')),
    );
  });
}
