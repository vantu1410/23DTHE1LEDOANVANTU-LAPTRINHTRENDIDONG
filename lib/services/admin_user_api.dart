import 'dart:convert';

import 'package:http/http.dart' as http;

class AdminUser {
  const AdminUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.username,
    required this.role,
    required this.emailVerified,
  });

  final int id;
  final String fullName;
  final String email;
  final String username;
  final String role;
  final bool emailVerified;

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: (json['id'] as num).toInt(),
    fullName: (json['fullName'] ?? '').toString(),
    email: (json['email'] ?? '').toString(),
    username: (json['username'] ?? '').toString(),
    role: (json['role'] ?? 'Employee').toString(),
    emailVerified: json['emailVerified'] as bool? ?? false,
  );
}

class AdminUserApi {
  AdminUserApi(String baseUrl, String accessToken, {http.Client? client})
    : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
      _accessToken = accessToken,
      _client = client ?? http.Client();

  final Uri _baseUri;
  final String _accessToken;
  final http.Client _client;

  Uri get _usersUri => _baseUri.resolve('api/AdminUsers');
  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=utf-8',
    'Authorization': 'Bearer $_accessToken',
  };

  Future<List<AdminUser>> getAll() async {
    final response = await _client
        .get(_usersUri, headers: _headers)
        .timeout(const Duration(seconds: 90));
    _check(response);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const FormatException('API tài khoản phải trả về JSON array.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(AdminUser.fromJson)
        .toList();
  }

  Future<void> delete(int id) async {
    final response = await _client
        .delete(_baseUri.resolve('api/AdminUsers/$id'), headers: _headers)
        .timeout(const Duration(seconds: 90));
    _check(response);
  }

  void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = utf8.decode(response.bodyBytes);
      var message = switch (response.statusCode) {
        401 =>
          'Phiên đăng nhập admin đã hết hạn. Hãy đăng xuất rồi đăng nhập lại.',
        403 => 'Tài khoản hiện tại không có quyền quản trị.',
        404 => 'Tài khoản không còn tồn tại. Hãy tải lại danh sách.',
        _ => 'API lỗi ${response.statusCode}',
      };
      try {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        message = (decoded['message'] ?? decoded['detail'] ?? message)
            .toString();
      } catch (_) {
        if (response.statusCode != 401 &&
            response.statusCode != 403 &&
            body.isNotEmpty) {
          message = body;
        }
      }
      throw Exception(message);
    }
  }
}
