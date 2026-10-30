import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/punch_record.dart';

class AttendanceApi {
  AttendanceApi(String baseUrl, String accessToken, {http.Client? client})
    : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
      _accessToken = accessToken,
      _client = client ?? http.Client();

  final Uri _baseUri;
  final String _accessToken;
  final http.Client _client;
  Uri get _uri => _baseUri.resolve('api/AttendanceApi');

  Future<void> record({
    required String type,
    required double latitude,
    required double longitude,
    required double? accuracyMeters,
    required String qrToken,
  }) async {
    final response = await _client
        .post(
          _uri,
          headers: _headers,
          body: jsonEncode({
            'type': type,
            'latitude': latitude,
            'longitude': longitude,
            'accuracyMeters': accuracyMeters,
            'qrToken': qrToken,
          }),
        )
        .timeout(const Duration(seconds: 90));
    _check(response);
  }

  Future<List<PunchRecord>> getHistory() async {
    final response = await _client
        .get(_uri, headers: _headers)
        .timeout(const Duration(seconds: 90));
    _check(response);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) return [];
    return decoded.whereType<Map<String, dynamic>>().map((json) {
      final type = (json['type'] ?? '').toString();
      final distance = (json['distanceFromOfficeMeters'] as num?)?.toDouble();
      final accuracy = (json['accuracyMeters'] as num?)?.toDouble();
      final latitude = (json['latitude'] as num?)?.toDouble();
      final longitude = (json['longitude'] as num?)?.toDouble();
      final coordinateText = latitude == null || longitude == null
          ? 'GPS'
          : '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
      return PunchRecord(
        type == 'checkIn' ? 'Chấm công vào ca' : 'Chấm công tan ca',
        DateTime.parse(json['recordedAtUtc'].toString()).toLocal(),
        distance == null
            ? 'Khoảng cách chưa có dữ liệu'
            : 'Cách văn phòng ${distance.toStringAsFixed(1)}m',
        accuracy == null
            ? '$coordinateText · GPS'
            : '$coordinateText · sai số ±${accuracy.toStringAsFixed(1)}m',
        recordId: (json['id'] as num?)?.toInt(),
        userId: (json['userId'] as num?)?.toInt(),
        employeeName: (json['fullName'] ?? '').toString(),
        username: (json['username'] ?? '').toString(),
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracy,
        distanceFromOfficeMeters: distance,
        overtimeMinutes: (json['overtimeMinutes'] as num?)?.toInt(),
        approvalLabel: json['approvalLabel'] as String?,
      );
    }).toList();
  }

  Future<void> cancelRecord(int id) async {
    final response = await _client
        .delete(_baseUri.resolve('api/AttendanceApi/$id'), headers: _headers)
        .timeout(const Duration(seconds: 90));
    _check(response);
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=utf-8',
    'Authorization': 'Bearer $_accessToken',
  };

  void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = utf8.decode(response.bodyBytes);
      String message = 'API lỗi ${response.statusCode}';
      try {
        final json = jsonDecode(body) as Map<String, dynamic>;
        message = (json['message'] ?? message).toString();
      } catch (_) {
        if (body.isNotEmpty) message = body;
      }
      throw Exception(message);
    }
  }
}
