import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ledoanvantu2/models/employee.dart';
import 'package:ledoanvantu2/services/employee_api.dart';

void main() {
  Employee employee({int? id}) => Employee(
    'Nhân viên mới',
    'Kỹ thuật',
    'NV-010',
    id: id,
    email: 'moi@example.com',
  );

  test(
    'create sends initial credentials and reads created login details',
    () async {
      final api = EmployeeApi(
        'https://example.com',
        token: 'admin-token',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/EmployeeApi');
          expect(request.headers['Authorization'], 'Bearer admin-token');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['username'], 'nv-moi');
          expect(body['initialPassword'], 'MatKhau123');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                ...employee(id: 10).toJson(),
                'loginUsername': 'nv-moi',
                'accountCreated': true,
              }),
            ),
            201,
          );
        }),
      );
      final saved = await api.create(
        employee(),
        username: ' nv-moi ',
        initialPassword: 'MatKhau123',
      );
      expect(saved.loginUsername, 'nv-moi');
      expect(saved.accountCreated, isTrue);
      expect(saved.toJson().containsKey('initialPassword'), isFalse);
      expect(saved.toJson().containsKey('loginUsername'), isFalse);
    },
  );

  test(
    'create omits absent credentials when linking an existing account',
    () async {
      final api = EmployeeApi(
        'https://example.com',
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.containsKey('username'), isFalse);
          expect(body.containsKey('initialPassword'), isFalse);
          return http.Response('{}', 201);
        }),
      );
      await api.create(employee());
    },
  );

  test(
    'editing an employee sends no account credentials or creation metadata',
    () async {
      final api = EmployeeApi(
        'https://example.com',
        client: MockClient((request) async {
          expect(request.method, 'PUT');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.containsKey('username'), isFalse);
          expect(body.containsKey('initialPassword'), isFalse);
          expect(body.containsKey('loginUsername'), isFalse);
          expect(body.containsKey('accountCreated'), isFalse);
          return http.Response('', 204);
        }),
      );
      await api.update(employee(id: 10));
    },
  );
}
