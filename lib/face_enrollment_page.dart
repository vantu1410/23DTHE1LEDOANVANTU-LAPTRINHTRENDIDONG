import 'package:flutter/material.dart';

class FaceEnrollmentPage extends StatefulWidget {
  const FaceEnrollmentPage({
    super.key,
    required this.name,
    required this.username,
    required this.checkEnabled,
    required this.enroll,
    required this.verify,
    required this.disable,
  });
  final String name;
  final String username;
  final Future<bool> Function() checkEnabled;
  final Future<bool> Function() enroll;
  final Future<bool> Function() verify;
  final Future<void> Function() disable;
  @override
  State<FaceEnrollmentPage> createState() => _FaceEnrollmentPageState();
}

class _FaceEnrollmentPageState extends State<FaceEnrollmentPage> {
  bool _enabled = false;
  bool _busy = true;
  String? _message;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final enabled = await widget.checkEnabled();
      if (mounted) setState(() => _enabled = enabled);
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = 'Không đọc được trạng thái khuôn mặt. Hãy thử lại.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<bool> Function() action, String success) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
      _message = null;
    });
    try {
      final completed = await action();
      final enabled = await widget.checkEnabled();
      if (mounted) {
        setState(() {
          _enabled = enabled;
          _message = completed ? success : 'Đã hủy quét khuôn mặt.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD2AE68);
    const green = Color(0xFF52C49A);
    const text = Color(0xFFF2F4F7);
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập bằng khuôn mặt')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF302A20), Color(0xFF15191F)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: gold.withValues(alpha: .3)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    border: Border.all(color: gold, width: 2),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Icon(
                    Icons.face_retouching_natural,
                    size: 72,
                    color: gold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: text,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '@${widget.username}',
                  style: const TextStyle(color: Color(0xFFA0A9B6)),
                ),
                const SizedBox(height: 14),
                Text(
                  _enabled
                      ? 'ĐÃ ĐĂNG KÝ TRÊN THIẾT BỊ NÀY'
                      : 'CHƯA ĐĂNG KÝ KHUÔN MẶT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _enabled ? green : gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Quét một lần, đăng nhập thuận tiện hơn',
            style: TextStyle(
              color: text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '1. Bạn đã đăng nhập bằng mật khẩu và OTP.\n2. Mở camera, nhìn thẳng, chụp rõ một khuôn mặt và xác nhận ảnh.\n3. Lần sau chọn “Đăng nhập bằng khuôn mặt” ở màn hình đăng nhập.',
            style: TextStyle(color: Color(0xFFB6BEC9), height: 1.6),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _run(
                    widget.enroll,
                    'Đã đăng ký khuôn mặt cho tài khoản này.',
                  ),
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(
              _enabled
                  ? 'Quét lại để cập nhật khuôn mặt'
                  : 'Quét mặt và đăng ký',
            ),
          ),
          if (_enabled)
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(
                      widget.verify,
                      'Khuôn mặt khớp tài khoản. Đăng nhập khuôn mặt đã sẵn sàng.',
                    ),
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Kiểm tra khuôn mặt'),
            ),
          if (_enabled)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      await widget.disable();
                      return true;
                    }, 'Đã tắt đăng nhập khuôn mặt trên thiết bị này.'),
              child: const Text('Tắt đăng nhập khuôn mặt'),
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  LinearProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Đang xử lý khuôn mặt…'),
                ],
              ),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _failed
                        ? Theme.of(context).colorScheme.error
                        : green,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),
          const Text(
            'Mẫu khuôn mặt lưu mã hóa trên thiết bị. Khi đổi tài khoản hoặc phiên hết hạn, hãy đăng nhập OTP và đăng ký lại. Nhận diện camera phục vụ bài demo, chưa chống ảnh/video giả mạo.',
            style: TextStyle(
              color: Color(0xFFA0A9B6),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
