import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ledoanvantu2/services/feature_api.dart';

void main() {
  test(
    'logout is an authenticated POST and accepts empty successful response',
    () async {
      final api = FeatureApi(
        'https://example.com/',
        'token',
        client: MockClient((r) async {
          expect(r.method, 'POST');
          expect(r.url.toString(), 'https://example.com/api/Auth/logout');
          expect(r.headers['Authorization'], 'Bearer token');
          return http.Response('', 204);
        }),
      );
      expect(await api.request('POST', 'Auth/logout'), isNull);
    },
  );
  test('sends sensor readings and returns server statistics', () async {
    final api = FeatureApi(
      'https://example.com',
      'token',
      client: MockClient((r) async {
        expect(jsonDecode(r.body)['values'], [1010, 1014]);
        return http.Response('{"average":1012,"warning":true}', 200);
      }),
    );
    final result = await api.request('POST', 'Pressure', {
      'values': [1010, 1014],
    });
    expect(result['average'], 1012);
    expect(result['warning'], true);
  });
  test(
    'unauthorized response remains distinguishable for expired-session logout',
    () async {
      final api = FeatureApi(
        'https://example.com',
        'revoked',
        client: MockClient((r) async => http.Response('', 401)),
      );
      await expectLater(
        api.request('POST', 'Auth/logout'),
        throwsA(
          isA<FeatureApiException>().having((e) => e.statusCode, 'status', 401),
        ),
      );
    },
  );
}
