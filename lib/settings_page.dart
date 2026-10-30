import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'services/auth_api.dart';
import 'services/biometric_session.dart';
import 'services/feature_api.dart';

class AppPreferences extends ChangeNotifier {
  static final instance = AppPreferences();
  double scale = 1;
  int background = 0xFF0B0D11;
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    scale = (p.getDouble('textScale') ?? 1).clamp(.85, 1.4);
    background = p.getInt('background') ?? 0xFF0B0D11;
  }

  Future<void> change(double value, int color) async {
    scale = value;
    background = color;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setDouble('textScale', value);
    await p.setInt('background', color);
  }

  Future<void> loadRemote(FeatureApi api) async {
    final data = await api.request('GET', 'Settings');
    await change(
      (data['textScale'] as num).toDouble(),
      (data['background'] as num).toInt(),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.session,
    required this.baseUrl,
    required this.onNameChanged,
    required this.onFaceSetup,
  });
  final AuthSession session;
  final String baseUrl;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onFaceSetup;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final name = TextEditingController(text: widget.session.fullName);
  bool busy = false;
  Future<void> saveAppearance() async {
    setState(() => busy = true);
    try {
      final prefs = AppPreferences.instance;
      await FeatureApi(widget.baseUrl, widget.session.token).request(
        'PUT',
        'Settings',
        {'textScale': prefs.scale, 'background': prefs.background},
      );
      message('Đã lưu cỡ chữ và màu nền trên tài khoản.');
    } catch (error) {
      message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> saveProfile() async {
    final value = name.text.trim();
    if (value.length < 2 || value.length > 120) {
      message('Họ tên cần từ 2 đến 120 ký tự.');
      return;
    }
    setState(() => busy = true);
    try {
      final r = await http
          .put(
            Uri.parse('${widget.baseUrl}/api/Profile'),
            headers: {
              'Authorization': 'Bearer ${widget.session.token}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'fullName': value}),
          )
          .timeout(const Duration(seconds: 90));
      if (r.statusCode == 404) {
        throw Exception(
          'Máy chủ chưa triển khai API hồ sơ. Cần cập nhật backend trước khi lưu.',
        );
      }
      if (r.statusCode != 200) {
        throw Exception(
          'Không lưu được hồ sơ (${r.statusCode}). Vui lòng đăng nhập lại nếu phiên hết hạn.',
        );
      }
      widget.onNameChanged(value);
      // A saved biometric session contains the old profile; require enabling it again.
      await BiometricSession.clear();
      message('Đã cập nhật hồ sơ. Bạn có thể bật lại đăng nhập khuôn mặt.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      message(e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppPreferences.instance,
    builder: (context, _) {
      final p = AppPreferences.instance;
      return Scaffold(
        appBar: AppBar(title: const Text('Cài đặt')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Cỡ chữ: ${(p.scale * 100).round()}%'),
            Slider(
              value: p.scale,
              min: .85,
              max: 1.4,
              divisions: 11,
              onChanged: (v) => p.change(v, p.background),
            ),
            const Text('Màu nền'),
            Wrap(
              spacing: 12,
              children: [0xFF0B0D11, 0xFF14243A, 0xFF183328, 0xFF342238]
                  .map(
                    (c) => Semantics(
                      label: 'Màu nền ${c.toRadixString(16)}',
                      selected: c == p.background,
                      child: IconButton(
                        onPressed: () => p.change(p.scale, c),
                        style: IconButton.styleFrom(
                          backgroundColor: Color(c),
                          side: const BorderSide(color: Colors.white54),
                        ),
                        icon: Icon(
                          c == p.background
                              ? Icons.check
                              : Icons.circle_outlined,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            FilledButton.icon(
              onPressed: busy ? null : saveAppearance,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Lưu giao diện vào tài khoản'),
            ),
            const Divider(height: 36),
            const Text('Đăng nhập bằng khuôn mặt'),
            const Text(
              'Đăng nhập mật khẩu và OTP lần đầu, sau đó bật xác thực trên thiết bị này. Khi phiên hết hạn cần xác thực OTP lại.',
            ),
            FilledButton.icon(
              onPressed: busy ? null : widget.onFaceSetup,
              icon: const Icon(Icons.face),
              label: const Text('Mở quét / đăng ký khuôn mặt'),
            ),
            const Divider(height: 36),
            const Text(
              'Nhận diện camera dành cho bài demo, chưa có chống ảnh/video giả mạo. Mẫu khuôn mặt được mã hóa và đối chiếu trên API.',
            ),
            const Text('Hồ sơ cá nhân'),
            const SizedBox(height: 12),
            Text('Tên đăng nhập: ${widget.session.username}'),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Họ và tên'),
            ),
            FilledButton(
              onPressed: busy ? null : saveProfile,
              child: const Text('Lưu hồ sơ'),
            ),
          ],
        ),
      );
    },
  );
}
