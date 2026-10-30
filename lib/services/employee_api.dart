import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/employee.dart';

class EmployeeApi {
  EmployeeApi(String baseUrl, {String? token, http.Client? client})
    : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
      _accessToken = token,
      _client = client ?? http.Client() {
    if (_baseUri.scheme != 'https') {
      throw ArgumentError(
        'API_BASE_URL phải là HTTPS và được deploy công khai.',
      );
    }
  }

  final Uri _baseUri;
  final String? _accessToken;
  final http.Client _client;
  Uri get _employeesUri => _baseUri.resolve('api/EmployeeApi');

  Future<List<Employee>> getAll() async {
    final response = await _client
        .get(_employeesUri, headers: _jsonHeaders)
        .timeout(const Duration(seconds: 90), onTimeout: _timeout);
    _check(response);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const FormatException(
        'API danh sách nhân viên phải trả về JSON array.',
      );
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Employee.fromJson)
        .toList();
  }

  Future<Employee> create(Employee employee) async {
    final response = await _client
        .post(
          _employeesUri,
          headers: _jsonHeaders,
          body: jsonEncode(employee.toJson()),
        )
        .timeout(const Duration(seconds: 90), onTimeout: _timeout);
    _check(response);
    if (response.bodyBytes.isEmpty) return employee;
    return Employee.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<Employee> update(Employee employee) async {
    if (employee.id == null) {
      throw ArgumentError('Nhân viên cần có ID để cập nhật trên máy chủ.');
    }
    final response = await _client
        .put(
          _baseUri.resolve('api/EmployeeApi/${employee.id}'),
          headers: _jsonHeaders,
          body: jsonEncode(employee.toJson()),
        )
        .timeout(const Duration(seconds: 90), onTimeout: _timeout);
    _check(response);
    if (response.bodyBytes.isEmpty) return employee;
    return Employee.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<void> delete(int? id) async {
    if (id == null) {
      throw ArgumentError('Nhân viên cần có ID để xóa trên máy chủ.');
    }
    final response = await _client
        .delete(_baseUri.resolve('api/EmployeeApi/$id'), headers: _jsonHeaders)
        .timeout(const Duration(seconds: 90), onTimeout: _timeout);
    _check(response);
  }

  Map<String, String> get _jsonHeaders => {
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=utf-8',
    if (_accessToken != null && _accessToken.isNotEmpty)
      'Authorization': 'Bearer $_accessToken',
  };

  void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = utf8.decode(response.bodyBytes);
      String? message;
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['message'] is String) {
          message = decoded['message'] as String;
        }
      } catch (_) {
        /* Non-JSON gateway responses are handled below. */
      }
      throw Exception(
        message ??
            switch (response.statusCode) {
              401 => 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
              403 => 'Chỉ quản trị viên được thay đổi hồ sơ nhân viên.',
              _ =>
                'Không lưu hoặc tải được nhân viên (${response.statusCode}). Vui lòng thử lại.',
            },
      );
    }
  }

  http.Response _timeout() => throw Exception(
    'Máy chủ phản hồi chậm. Chưa xác nhận được kết quả; hãy tải lại danh sách trước khi lưu lại.',
  );
}
