import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthApi {
  AuthApi(String baseUrl, {http.Client? client})
    : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
      _client = client ?? http.Client() {
    if (_baseUri.scheme != 'https') {
      throw ArgumentError(
        'API_BASE_URL phải là HTTPS và được deploy công khai.',
      );
    }
  }

  final Uri _baseUri;
  final http.Client _client;

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String username,
    required String password,
  }) => _post('api/Auth/register', {
    'fullName': fullName,
    'email': email,
    'username': username,
    'password': password,
  });

  Future<Map<String, dynamic>> login(String username, String password) =>
      _post('api/Auth/login', {'username': username, 'password': password});

  Future<AuthSession> verifyOtp(String username, String code) async {
    final result = await _post('api/Auth/verify-otp', {
      'username': username,
      'code': code,
    });
    final user = result['user'] as Map<String, dynamic>? ?? const {};
    return AuthSession(
      token: (result['accessToken'] ?? '').toString(),
      fullName: (user['fullName'] ?? username).toString(),
      role: (user['role'] ?? 'Employee').toString(),
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await _client
        .post(
          _baseUri.resolve(path),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode(body),
        )
        // Render's free instance can take 50+ seconds to wake after idle.
        .timeout(const Duration(seconds: 90));
    final decoded = response.bodyBytes.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        (decoded['message'] ?? 'API lỗi ${response.statusCode}').toString(),
      );
    }
    return decoded;
  }
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.fullName,
    required this.role,
  });
  final String token;
  final String fullName;
  final String role;
}
