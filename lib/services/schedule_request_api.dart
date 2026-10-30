import 'dart:convert';

import 'package:http/http.dart' as http;

class ScheduleEntry {
  ScheduleEntry(this.json);
  final Map<String, dynamic> json;
  int get id => (json['id'] as num).toInt();
  int get userId => (json['userId'] as num).toInt();
  String get name => json['fullName'] as String? ?? 'Nhân viên';
  String get type => json['type'] as String;
  String get title => type == 'late' ? 'Xin đi muộn' : 'Xin về sớm';
  String get status => json['status'] as String;
  String get statusLabel => switch (status) {
    'approved' => 'Đã duyệt',
    'rejected' => 'Từ chối',
    _ => 'Chờ duyệt',
  };
  String get reason => json['reason'] as String? ?? '';
  String get note => json['reviewNote'] as String? ?? '';
  String? get reviewer => json['reviewerName'] as String?;
  String get dateLabel {
    final date = DateTime.parse(json['workDate'] as String);
    return '${date.day}/${date.month}/${date.year}';
  }

  String get timeLabel {
    final minutes = (json['timeMinutes'] as num).toInt();
    return '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  }
}

class ScheduleRequestApi {
  ScheduleRequestApi(String baseUrl, this.token, {http.Client? client})
    : base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
      client = client ?? http.Client();
  final Uri base;
  final String token;
  final http.Client client;
  Future<dynamic> _send(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final request = http.Request(
      method,
      base.resolve('api/ScheduleRequests$path'),
    );
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json; charset=utf-8',
    });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await client.send(request).timeout(const Duration(seconds: 90)),
    ).timeout(const Duration(seconds: 90));
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? decoded['message'] : null;
      throw Exception(
        message ??
            (response.statusCode == 404
                ? 'Máy chủ chưa có chức năng xin đi muộn/về sớm. Cần triển khai backend mới lên Render.'
                : response.statusCode == 401
                ? 'Phiên đăng nhập hết hạn. Hãy đăng nhập lại.'
                : 'Không thực hiện được (${response.statusCode}).'),
      );
    }
    return decoded;
  }

  Future<List<ScheduleEntry>> list() async => ((await _send('GET', '')) as List)
      .map((json) => ScheduleEntry(json as Map<String, dynamic>))
      .toList();
  Future<ScheduleEntry> create(
    String type,
    DateTime date,
    int minutes,
    String reason,
  ) async => ScheduleEntry(
    await _send('POST', '', {
      'type': type,
      'workDate':
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'timeMinutes': minutes,
      'reason': reason,
    }) as Map<String, dynamic>,
  );
  Future<ScheduleEntry> review(int id, bool approve, String note) async =>
      ScheduleEntry(
        await _send('POST', '/$id/review', {
          'status': approve ? 'approved' : 'rejected',
          'note': note,
        }) as Map<String, dynamic>,
      );
}
