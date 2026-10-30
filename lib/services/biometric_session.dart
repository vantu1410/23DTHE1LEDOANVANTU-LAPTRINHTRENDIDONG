import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';

import 'auth_api.dart';

class BiometricSession {
  static const _storage = FlutterSecureStorage();
  static Float32List? _enrollment;
  static Future<bool> available() async => Platform.isAndroid;
  static Future<Float32List?> capture() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 1024,
      imageQuality: 90,
    );
    if (photo == null) return null;
    FaceDetector? detector;
    try {
      final bytes = await photo.readAsBytes();
      detector = await FaceDetector.create();
      final faces = await detector.detectFacesFromBytes(
        bytes,
        mode: FaceDetectionMode.full,
      );
      if (faces.length != 1 || faces.single.score < .85) {
        throw Exception(
          'Cần một khuôn mặt rõ, đủ sáng và nhìn thẳng vào camera.',
        );
      }
      return await detector.getFaceEmbedding(faces.single, bytes);
    } finally {
      await detector?.dispose();
      final file = File(photo.path);
      if (await file.exists()) await file.delete();
    }
  }

  static Future<bool> authenticate() async {
    _enrollment = await capture();
    return _enrollment != null;
  }

  static Future<void> clear() => _storage.delete(key: 'tutime.face');
  static Future<bool> isEnabledFor(AuthSession session, String baseUrl) async {
    final raw = await _storage.read(key: 'tutime.face');
    if (raw == null) return false;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return data['baseUrl'] == baseUrl &&
          data['id'] == session.userId &&
          data['token'] == session.token &&
          !_expired(session.token);
    } catch (_) {
      return false;
    }
  }

  static bool _expired(String token) {
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
    ) as Map<String, dynamic>;
    return (claims['exp'] as num).toInt() <=
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  static Future<void> save(AuthSession session, String baseUrl) async {
    if (_enrollment == null) throw Exception('Chưa chụp khuôn mặt.');
    if (_expired(session.token)) {
      throw Exception(
        'Phiên đã hết hạn. Vui lòng đăng nhập lại bằng OTP trước khi đăng ký khuôn mặt.',
      );
    }
    await _storage.write(
      key: 'tutime.face',
      value: jsonEncode({
        'baseUrl': baseUrl,
        'token': session.token,
        'name': session.fullName,
        'username': session.username,
        'id': session.userId,
        'role': session.role,
        'embedding': _enrollment!.toList(),
        'attempts': 0,
      }),
    );
    _enrollment = null;
  }

  static Future<AuthSession?> unlock(String baseUrl) async {
    final raw = await _storage.read(key: 'tutime.face');
    if (raw == null) {
      throw Exception(
        'Đăng nhập mật khẩu/OTP rồi đăng ký khuôn mặt trong Cài đặt trước.',
      );
    }
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final token = data['token'] as String;
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
    ) as Map<String, dynamic>;
    if (data['baseUrl'] != baseUrl ||
        (claims['exp'] as num).toInt() <=
            DateTime.now().millisecondsSinceEpoch ~/ 1000) {
      await clear();
      throw Exception(
        'Phiên hết hạn. Vui lòng đăng nhập lại bằng mật khẩu và OTP.',
      );
    }
    final embedding = await capture();
    if (embedding == null) return null;
    final reference = Float32List.fromList(
      (data['embedding'] as List).map((v) => (v as num).toDouble()).toList(),
    );
    final similarity = FaceDetector.compareFaces(reference, embedding);
    if (!similarity.isFinite || similarity < .70) {
      final attempts = (data['attempts'] as int? ?? 0) + 1;
      if (attempts >= 5) {
        await clear();
      } else {
        data['attempts'] = attempts;
        await _storage.write(key: 'tutime.face', value: jsonEncode(data));
      }
      throw Exception(
        'Khuôn mặt không khớp. Sau 5 lần sai cần đăng nhập OTP lại.',
      );
    }
    data['attempts'] = 0;
    await _storage.write(key: 'tutime.face', value: jsonEncode(data));
    return AuthSession(
      token: token,
      fullName: data['name'] as String,
      username: data['username'] as String,
      userId: data['id'] as int?,
      role: data['role'] as String,
    );
  }
}
