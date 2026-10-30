import 'dart:convert';

import 'package:http/http.dart' as http;

class FeatureApiException implements Exception {
  FeatureApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => message;
}

class FeatureApi {
  FeatureApi(String baseUrl, this.token, {http.Client? client})
    : base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
      client = client ?? http.Client();
  final Uri base;
  final String token;
  final http.Client client;

  Future<dynamic> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final request = http.Request(method, base.resolve('api/$path'));
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await client.send(request).timeout(const Duration(seconds: 90)),
    ).timeout(const Duration(seconds: 90));
    dynamic decoded;
    if (response.bodyBytes.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        decoded = null;
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FeatureApiException(
        response.statusCode,
        decoded is Map && decoded['message'] != null
            ? decoded['message'].toString()
            : response.statusCode == 401
            ? 'Phiên đã hết hiệu lực. Hãy đăng nhập lại bằng mật khẩu và OTP.'
            : 'Không kết nối được chức năng trên API (${response.statusCode}).',
      );
    }
    return decoded;
  }
}
