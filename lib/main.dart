import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'models/employee.dart';
import 'models/punch_record.dart';
import 'services/attendance_api.dart';
import 'services/admin_user_api.dart';
import 'services/auth_api.dart';
import 'services/employee_api.dart';

void main() => runApp(const ChamCongApp());

const ink = Color(0xFF15243A);
const navy = Color(0xFF142E50);
const blue = Color(0xFF3978F6);
const canvas = Color(0xFFF4F7FB);
const green = Color(0xFF18A979);
const companyQrPayload = 'TUTIME:OFFICE:23DTHE1LEDOANVANTU-GROUP8';
final officeLatitude = double.parse(
  const String.fromEnvironment('OFFICE_LAT', defaultValue: '10.7769'),
);
final officeLongitude = double.parse(
  const String.fromEnvironment('OFFICE_LNG', defaultValue: '106.7009'),
);
final officeRadiusMeters = double.parse(
  const String.fromEnvironment('OFFICE_RADIUS_M', defaultValue: '150'),
);

class ChamCongApp extends StatelessWidget {
  const ChamCongApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'TuTime · Chấm công',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(seedColor: blue, primary: blue),
      fontFamily: 'Roboto',
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    ),
    home: const LoginPage(),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ledoanvantu2-api.onrender.com',
  );
  final user = TextEditingController();
  final password = TextEditingController();
  final otp = TextEditingController();
  final fullName = TextEditingController();
  final email = TextEditingController();
  late final AuthApi? _authApi;
  bool showOtp = false;
  bool isRegistering = false;
  bool busy = false;
  String role = 'Nhân viên';

  @override
  void initState() {
    super.initState();
    _authApi = _apiBaseUrl.isEmpty ? null : AuthApi(_apiBaseUrl);
  }

  @override
  void dispose() {
    user.dispose();
    password.dispose();
    otp.dispose();
    fullName.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> _continueAuth() async {
    setState(() => busy = true);
    try {
      if (!showOtp) {
        if (_authApi == null) {
          if (isRegistering) {
            throw Exception(
              'Đăng ký email cần API đã deploy. Cấu hình API_BASE_URL trước.',
            );
          }
          setState(() => showOtp = true);
          return;
        }
        final result = isRegistering
            ? await _authApi.register(
                fullName: fullName.text.trim(),
                email: email.text.trim(),
                username: user.text.trim(),
                password: password.text,
              )
            : await _authApi.login(user.text.trim(), password.text);
        setState(() {
          showOtp = true;
          final debugOtp = result['debugOtp'];
          if (debugOtp != null) otp.text = debugOtp.toString();
        });
        if (result['debugOtp'] != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('API Development: OTP đã được điền để chạy thử.'),
            ),
          );
        }
        return;
      }

      String displayRole;
      String displayName;
      String displayUsername = user.text.trim();
      int? displayUserId;
      String? accessToken;
      if (_authApi == null) {
        if (otp.text.trim() != '123456') {
          throw Exception('Mã OTP demo không đúng. Nhập 123456.');
        }
        displayRole = role;
        displayName = role == 'Quản trị viên'
            ? 'Lê Đoàn Văn Tú'
            : 'Nguyễn Minh Anh';
      } else {
        final session = await _authApi.verifyOtp(
          user.text.trim(),
          otp.text.trim(),
        );
        displayRole = session.role.toLowerCase() == 'admin'
            ? 'Quản trị viên'
            : 'Nhân viên';
        displayName = session.fullName;
        displayUsername = session.username;
        displayUserId = session.userId;
        accessToken = session.token;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomePage(
            role: displayRole,
            name: displayName,
            username: displayUsername,
            userId: displayUserId,
            accessToken: accessToken,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: blue,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.event_available_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Xin chào 👋',
                  style: TextStyle(fontSize: 16, color: Color(0xFF7D8BA0)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chấm công\nthật dễ dàng.',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1.13,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Đăng nhập vào không gian làm việc của bạn.',
                  style: TextStyle(color: Color(0xFF78869A), fontSize: 15),
                ),
                const SizedBox(height: 30),
                if (isRegistering && !showOtp) ...[
                  const Text(
                    'Họ và tên',
                    style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: fullName,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.badge_outlined),
                      hintText: 'Nhập họ và tên',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Email',
                    style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.email_outlined),
                      hintText: 'ten@congty.vn',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Tên đăng nhập',
                  style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: user,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: [
                    isRegistering
                        ? AutofillHints.newUsername
                        : AutofillHints.username,
                  ],
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline),
                    hintText: 'Nhập tên đăng nhập',
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Mật khẩu',
                  style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: password,
                  obscureText: true,
                  enableSuggestions: false,
                  autofillHints: [
                    isRegistering
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.lock_outline),
                    hintText: 'Nhập mật khẩu',
                  ),
                ),
                if (showOtp) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'Mã OTP',
                    style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: otp,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.mark_email_read_outlined),
                      hintText: _authApi == null
                          ? 'OTP demo: 123456'
                          : 'Nhập mã đã gửi đến email',
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (_authApi == null && !showOtp && !isRegistering)
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.badge_outlined),
                      labelText: 'Vai trò demo',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Nhân viên',
                        child: Text('Nhân viên'),
                      ),
                      DropdownMenuItem(
                        value: 'Quản trị viên',
                        child: Text('Quản trị viên'),
                      ),
                    ],
                    onChanged: (v) => setState(() => role = v ?? role),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: busy ? null : _continueAuth,
                    style: FilledButton.styleFrom(
                      backgroundColor: blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      busy
                          ? 'Đang xử lý…'
                          : showOtp
                          ? 'Xác nhận OTP  →'
                          : isRegistering
                          ? 'Tạo tài khoản  →'
                          : 'Tiếp tục  →',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() {
                      if (showOtp) {
                        showOtp = false;
                        otp.clear();
                      } else {
                        isRegistering = !isRegistering;
                        user.clear();
                        password.clear();
                        fullName.clear();
                        email.clear();
                      }
                    }),
                    child: Text(
                      showOtp
                          ? 'Quay lại'
                          : isRegistering
                          ? 'Đã có tài khoản? Đăng nhập'
                          : 'Chưa có tài khoản? Đăng ký',
                      style: const TextStyle(
                        color: blue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Center(
                  child: Text(
                    'TU TIME  ·  CHẤM CÔNG THÔNG MINH',
                    style: TextStyle(
                      letterSpacing: 1.3,
                      color: Color(0xFF9AA6B5),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.role,
    required this.name,
    required this.username,
    this.userId,
    this.accessToken,
  });
  final String role;
  final String name;
  final String username;
  final int? userId;
  final String? accessToken;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ledoanvantu2-api.onrender.com',
  );
  int tab = 0;
  late final EmployeeApi? _employeeApi;
  late final AttendanceApi? _attendanceApi;
  String? _apiError;
  bool checkedIn = false;
  bool checkedOut = false;
  final List<Employee> employees = [
    Employee('Nguyễn Minh Anh', 'Thiết kế', 'NV-002', present: true),
    Employee('Trần Quốc Bảo', 'Kỹ thuật', 'NV-003'),
    Employee('Phạm Thu Hà', 'Nhân sự', 'NV-004', present: true),
  ];
  final List<PunchRecord> records = [];
  bool get isAdmin => widget.role == 'Quản trị viên';

  @override
  void initState() {
    super.initState();
    _employeeApi = _apiBaseUrl.isEmpty
        ? null
        : EmployeeApi(_apiBaseUrl, token: widget.accessToken);
    if (_employeeApi != null) _refreshEmployees();
    _attendanceApi = widget.accessToken == null || _apiBaseUrl.isEmpty
        ? null
        : AttendanceApi(_apiBaseUrl, widget.accessToken!);
    if (_attendanceApi != null) _refreshHistory();
  }

  Future<void> _refreshEmployees() async {
    try {
      final remoteEmployees = await _employeeApi!.getAll();
      if (!mounted) return;
      setState(() {
        employees
          ..clear()
          ..addAll(remoteEmployees);
        _apiError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _apiError = error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _refreshHistory() async {
    try {
      final remoteRecords = await _attendanceApi!.getHistory();
      if (!mounted) return;
      setState(() {
        records
          ..clear()
          ..addAll(remoteRecords);
        if (remoteRecords.isNotEmpty) {
          checkedIn = remoteRecords.first.action.contains('vào ca');
          checkedOut = remoteRecords.first.action.contains('tan ca');
        }
      });
    } catch (error) {
      if (mounted) _notice(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _dashboard(),
      isAdmin ? _employees() : _history(),
      _profile(),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: tab, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE5EDFF),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(
              isAdmin ? Icons.groups_2_outlined : Icons.receipt_long_outlined,
            ),
            label: isAdmin ? 'Nhân viên' : 'Lịch sử',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }

  Widget _dashboard() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    children: [
      Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE6EDFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.event_available_rounded, color: blue),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TU TIME',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: navy,
                  ),
                ),
                Text(
                  'Chấm công thông minh',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _notice('Bạn đã xem thông báo mới nhất.'),
            icon: const Badge(
              smallSize: 8,
              child: Icon(Icons.notifications_none_rounded, color: ink),
            ),
          ),
          CircleAvatar(
            backgroundColor: const Color(0xFFDCE8FF),
            child: Text(
              widget.name.isNotEmpty ? widget.name[0] : 'T',
              style: const TextStyle(color: navy, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      Text(
        _greeting(),
        style: const TextStyle(color: Color(0xFF7B899C), fontSize: 14),
      ),
      const SizedBox(height: 4),
      Text(
        widget.name,
        style: const TextStyle(
          fontSize: 23,
          color: ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 19),
      _datePanel(),
      const SizedBox(height: 16),
      _checkInCard(),
      const SizedBox(height: 17),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Tổng quan hôm nay',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => tab = 1),
            child: const Text('Xem lịch sử'),
          ),
        ],
      ),
      Row(
        children: [
          Expanded(
            child: _metric(
              'Giờ làm',
              checkedIn ? '03h 24m' : '00h 00m',
              Icons.schedule_rounded,
              const Color(0xFFEAF1FF),
              blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _metric(
              isAdmin ? 'Có mặt' : 'Đi muộn',
              isAdmin
                  ? '${employees.where((e) => e.present).length}/${employees.length}'
                  : '00 lần',
              isAdmin ? Icons.groups_rounded : Icons.timelapse_rounded,
              const Color(0xFFE7F7F1),
              green,
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      _locationCard(),
      if (isAdmin) ...[
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Nhân viên hôm nay',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => tab = 1),
              child: const Text('Quản lý'),
            ),
          ],
        ),
        ...employees.take(2).map(_employeeTile),
      ],
      const SizedBox(height: 18),
      const Text(
        'Hoạt động gần đây',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink),
      ),
      const SizedBox(height: 8),
      if (records.isEmpty)
        _emptyActivity()
      else
        ...records.reversed.take(3).map(_recordTile),
    ],
  );

  Widget _datePanel() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: navy,
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        colors: [Color(0xFF193A64), Color(0xFF24548A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _weekday(DateTime.now().weekday),
                style: const TextStyle(color: Color(0xFFB8CBE3), fontSize: 13),
              ),
              const SizedBox(height: 5),
              Text(
                '${DateTime.now().day} tháng ${DateTime.now().month}, ${DateTime.now().year}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.wb_sunny_outlined,
                    color: Color(0xFFFFD27D),
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Chúc bạn một ngày hiệu quả!',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .78),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(
            Icons.calendar_month_outlined,
            color: Colors.white,
            size: 26,
          ),
        ),
      ],
    ),
  );

  Widget _checkInCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF193A64).withValues(alpha: .05),
          blurRadius: 20,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Chấm công của bạn',
                style: TextStyle(
                  color: ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F8F2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Row(
                children: [
                  Icon(Icons.circle, size: 7, color: green),
                  SizedBox(width: 5),
                  Text(
                    'ĐANG TRONG CA',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: .4,
                      color: green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _timeBox(
                'VÀO CA',
                checkedIn ? _clockFor('IN') : '--:--',
                Icons.login_rounded,
                green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _timeBox(
                'TAN CA',
                checkedOut ? _clockFor('OUT') : '--:--',
                Icons.logout_rounded,
                blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 51,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: checkedOut ? null : _punch,
            icon: Icon(
              checkedIn ? Icons.logout_rounded : Icons.qr_code_scanner_rounded,
            ),
            label: Text(
              checkedIn ? 'Chấm công tan ca' : 'Chấm công vào ca',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: checkedIn ? navy : blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'QR công ty  ·  Vị trí GPS',
            style: TextStyle(fontSize: 11, color: Color(0xFF8B98AA)),
          ),
        ),
      ],
    ),
  );

  Widget _timeBox(String label, String time, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: canvas,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8290A3),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  time,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _metric(
    String label,
    String value,
    IconData icon,
    Color bg,
    Color color,
  ) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF8491A3)),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _locationCard() => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF1FF),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.location_on_outlined, color: blue),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vị trí làm việc',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: ink,
                  fontSize: 13,
                ),
              ),
              Text(
                'Văn phòng demo · Bán kính ${officeRadiusMeters.round()}m',
                style: TextStyle(color: Color(0xFF75859B), fontSize: 11),
              ),
            ],
          ),
        ),
        const Icon(Icons.my_location_rounded, color: blue, size: 20),
      ],
    ),
  );

  Widget _emptyActivity() => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      children: [
        Icon(Icons.event_note_outlined, color: Color(0xFF98A5B5)),
        SizedBox(width: 10),
        Text(
          'Chưa có hoạt động. Hãy chấm công để bắt đầu.',
          style: TextStyle(fontSize: 12, color: Color(0xFF8390A2)),
        ),
      ],
    ),
  );

  Widget _recordTile(PunchRecord item) => Container(
    margin: const EdgeInsets.only(top: 7),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        Icon(
          item.action.contains('vào')
              ? Icons.login_rounded
              : Icons.logout_rounded,
          color: green,
          size: 19,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.action,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: ink,
                  fontSize: 13,
                ),
              ),
              Text(
                '${item.place} · ${item.method}',
                style: const TextStyle(color: Color(0xFF8895A6), fontSize: 11),
              ),
            ],
          ),
        ),
        Text(
          _clock(item.time),
          style: const TextStyle(fontWeight: FontWeight.w800, color: ink),
        ),
      ],
    ),
  );

  Widget _history() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'Lịch sử chấm công',
        style: TextStyle(fontSize: 24, color: ink, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 5),
      const Text(
        'Theo dõi các lần vào ca và tan ca',
        style: TextStyle(color: Color(0xFF8090A4)),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: navy,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'THÁNG NÀY',
              style: TextStyle(
                color: Color(0xFFB8CBE3),
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '22 ngày công',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Đi muộn 0 lần  ·  Về sớm 0 lần',
              style: TextStyle(color: Color(0xFFD4E1F2), fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Hôm nay',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _notice('Bộ lọc lịch sử sẽ kết nối API.'),
            child: const Text('Lọc'),
          ),
        ],
      ),
      if (records.isEmpty)
        _emptyActivity()
      else
        ...records.reversed.map(_recordTile),
    ],
  );

  Widget _employees() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Nhân viên',
              style: TextStyle(
                fontSize: 24,
                color: ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton.filled(
            onPressed: _addEmployee,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      const SizedBox(height: 4),
      const Text(
        'Quản lý hồ sơ và tình trạng làm việc',
        style: TextStyle(color: Color(0xFF8090A4)),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: _metric(
              'Nhân sự',
              '${employees.length}',
              Icons.groups_rounded,
              const Color(0xFFEAF1FF),
              blue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metric(
              'Có mặt',
              '${employees.where((e) => e.present).length}',
              Icons.check_circle_outline,
              const Color(0xFFE7F7F1),
              green,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _employeeApi == null
              ? const Color(0xFFFFF4DD)
              : _apiError == null
              ? const Color(0xFFE7F7F1)
              : const Color(0xFFFFEBEB),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          _employeeApi == null
              ? 'Đang dùng dữ liệu demo. Chạy với --dart-define=API_BASE_URL=https://api-cua-nhom để bật CRUD REST.'
              : _apiError ?? 'Đã tải danh sách từ API /api/EmployeeApi.',
          style: TextStyle(
            fontSize: 11,
            color: _employeeApi == null
                ? const Color(0xFF9A6A17)
                : _apiError == null
                ? green
                : const Color(0xFFB34444),
          ),
        ),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          const Expanded(
            child: Text(
              'DANH SÁCH',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1,
                color: Color(0xFF8794A6),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (_employeeApi != null)
            IconButton(
              tooltip: 'Tải lại từ API',
              onPressed: _refreshEmployees,
              icon: const Icon(Icons.refresh_rounded, color: blue),
            ),
        ],
      ),
      const SizedBox(height: 8),
      ...employees.map(_employeeTile),
    ],
  );

  Widget _employeeTile(Employee e) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFE6EDFF),
          child: Text(
            e.name[0],
            style: const TextStyle(fontWeight: FontWeight.bold, color: navy),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: ink,
                  fontSize: 13,
                ),
              ),
              Text(
                '${e.code} · ${e.role}',
                style: const TextStyle(color: Color(0xFF8794A6), fontSize: 11),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: e.present
                ? const Color(0xFFE7F7F1)
                : const Color(0xFFFFF5E7),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            e.present ? 'Có mặt' : 'Chưa đến',
            style: TextStyle(
              fontSize: 10,
              color: e.present ? green : const Color(0xFFC4812E),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _editEmployee(e);
            if (v == 'delete') _deleteEmployee(e);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
            PopupMenuItem(value: 'delete', child: Text('Xóa nhân viên')),
          ],
        ),
      ],
    ),
  );

  Widget _profile() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'Tài khoản',
        style: TextStyle(fontSize: 24, color: ink, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: navy,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFFDCE8FF),
              child: Icon(Icons.person, color: navy, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAdmin ? 'Quản trị viên · TuTime' : 'Nhân viên · TuTime',
                    style: const TextStyle(
                      color: Color(0xFFC4D5EA),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _setting(
        Icons.badge_outlined,
        'Thông tin cá nhân',
        'Xem hồ sơ và vai trò hiện tại',
        _showAccountInfo,
      ),
      if (isAdmin)
        _setting(
          Icons.manage_accounts_outlined,
          'Quản lý tài khoản',
          'Xem và xóa tài khoản người dùng',
          _openAdminUsers,
        ),
      if (isAdmin)
        _setting(
          Icons.qr_code_2_rounded,
          'Mã QR công ty cố định',
          'Mở mã để lưu hoặc cho nhân viên quét chấm công',
          _showOfficeQr,
        ),
      _setting(
        Icons.verified_user_outlined,
        'Bảo mật & OTP',
        'Đăng nhập bằng mật khẩu và mã email OTP',
        _showSecurityInfo,
      ),
      _setting(
        Icons.speed_rounded,
        'Đo áp suất không khí',
        'Cảm biến khí áp · Mục d',
        () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const PressureSensorPage())),
      ),
      _setting(
        Icons.help_outline,
        'Trợ giúp',
        'Hướng dẫn sử dụng TuTime',
        _showHelp,
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (r) => false,
        ),
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Đăng xuất'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFD65353),
          padding: const EdgeInsets.all(15),
          side: const BorderSide(color: Color(0xFFF0DADA)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ],
  );

  Widget _setting(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    child: ListTile(
      onTap: onTap,
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      leading: Icon(icon, color: blue),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          color: ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF9AA6B5)),
    ),
  );

  void _openAdminUsers() {
    if (widget.accessToken == null || _apiBaseUrl.isEmpty) {
      _notice(
        'Không thể tải tài khoản: chưa kết nối API hoặc phiên đăng nhập.',
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminUsersPage(
          api: AdminUserApi(_apiBaseUrl, widget.accessToken!),
          currentUserId: widget.userId,
          currentUsername: widget.username,
        ),
      ),
    );
  }

  void _showAccountInfo() => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Thông tin tài khoản'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Họ tên: ${widget.name}'),
          const SizedBox(height: 8),
          Text('Vai trò: ${isAdmin ? 'Quản trị viên' : 'Nhân viên'}'),
          const SizedBox(height: 8),
          const Text('Hệ thống chấm công TuTime'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );

  void _showSecurityInfo() => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Bảo mật tài khoản'),
      content: const Text(
        'Đăng nhập cần tên đăng nhập, mật khẩu và mã OTP gửi đến email đã đăng ký. Mỗi mã OTP có thời hạn 5 phút. Không chia sẻ mã OTP cho người khác.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Đã hiểu'),
        ),
      ],
    ),
  );

  void _showHelp() => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Hướng dẫn nhanh'),
      content: const Text(
        'Chấm công: quét QR công ty → xác nhận vị trí GPS → gửi bản ghi. Admin quản lý nhân viên và tài khoản ở tab Tài khoản. Mục Đo áp suất không khí có thể chạy bằng cảm biến ảo trên Android Emulator.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );

  void _punch() => _verifyAndPunch();

  Future<void> _verifyAndPunch() async {
    try {
      final qr = await Navigator.of(context)
          .push<String>(MaterialPageRoute(builder: (_) => const QrScanPage()));
      if (!mounted || qr == null) return;
      if (qr != companyQrPayload) {
        _notice(
          'QR không đúng mã công ty. Hãy quét lại mã cố định của TuTime.',
        );
        return;
      }

      final position = await _getCurrentPosition();
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        officeLatitude,
        officeLongitude,
      );
      if (distance > officeRadiusMeters) {
        await _showGpsMismatch(position, distance);
        return;
      }

      final action = checkedIn ? 'checkOut' : 'checkIn';
      if (_attendanceApi != null) {
        await _attendanceApi.record(
          type: action,
          latitude: position.latitude,
          longitude: position.longitude,
          qrToken: qr,
        );
      }

      setState(() {
        if (!checkedIn) {
          checkedIn = true;
          employees.first.present = true;
          records.add(
            PunchRecord(
              'Chấm công vào ca',
              DateTime.now(),
              'Văn phòng · ${distance.round()}m',
              'QR công ty + GPS',
            ),
          );
        } else {
          checkedOut = true;
          records.add(
            PunchRecord(
              'Chấm công tan ca',
              DateTime.now(),
              'Văn phòng · ${distance.round()}m',
              'QR công ty + GPS',
            ),
          );
        }
      });
      if (_attendanceApi != null) await _refreshHistory();
      _notice('Đã xác minh QR công ty và vị trí. Chấm công thành công.');
    } catch (error) {
      if (mounted) _notice(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _showGpsMismatch(
    Position position,
    double distance,
  ) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.location_off_rounded, color: Color(0xFFD88700)),
      title: const Text('GPS chưa đúng vị trí văn phòng'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vị trí app nhận được: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
          ),
          const SizedBox(height: 8),
          Text(
            'Vị trí văn phòng: ${officeLatitude.toStringAsFixed(6)}, ${officeLongitude.toStringAsFixed(6)}',
          ),
          const SizedBox(height: 8),
          Text(
            'Khoảng cách ${distance.round()} m · giới hạn ${officeRadiusMeters.round()} m.',
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'GPS trên Android Emulator là vị trí mô phỏng riêng, không tự lấy vị trí Windows/Chrome đang chia sẻ. Mở nút ⋮ của giả lập → Location, nhập tọa độ văn phòng ở trên rồi đặt vị trí.',
              style: TextStyle(fontSize: 12, height: 1.45),
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Đã hiểu'),
        ),
      ],
    ),
  );

  Future<void> _showOfficeQr() async {
    try {
      final qrImage = await QrPainter(
        data: companyQrPayload,
        version: QrVersions.auto,
        gapless: true,
      ).toImageData(720, format: ui.ImageByteFormat.png);
      if (!mounted) return;
      if (qrImage == null) throw Exception('Không tạo được ảnh QR công ty.');
      final qrBytes = qrImage.buffer.asUint8List();

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.qr_code_2_rounded, color: blue, size: 30),
          title: const Text('Mã QR công ty cố định'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE8EDF4)),
                ),
                child: Image.memory(
                  qrBytes,
                  width: 230,
                  height: 230,
                  filterQuality: FilterQuality.none,
                  gaplessPlayback: true,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Nhân viên quét mã này để chấm công. Vị trí GPS vẫn phải nằm trong vùng văn phòng.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF78869A),
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        _notice(
          'Không mở được mã QR công ty: ${error.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }
  }

  Future<Position> _getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Hãy bật dịch vụ vị trí trên điện thoại.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Cần cho phép vị trí để chấm công.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Quyền vị trí đã bị từ chối. Hãy bật quyền trong Cài đặt.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 11
        ? 'Chào buổi sáng,'
        : h < 18
        ? 'Chào buổi chiều,'
        : 'Chào buổi tối,';
  }

  String _weekday(int n) => [
    'Thứ hai',
    'Thứ ba',
    'Thứ tư',
    'Thứ năm',
    'Thứ sáu',
    'Thứ bảy',
    'Chủ nhật',
  ][n - 1];
  String _clock(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  String _clockFor(String _) =>
      records.isEmpty ? _clock(DateTime.now()) : _clock(records.last.time);
  void _notice(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
  );

  void _addEmployee() => _employeeDialog();
  void _editEmployee(Employee e) => _employeeDialog(existing: e);

  Future<void> _deleteEmployee(Employee employee) async {
    try {
      if (_employeeApi != null) await _employeeApi.delete(employee.id);
      if (!mounted) return;
      setState(() {
        employees.remove(employee);
        _apiError = null;
      });
    } catch (error) {
      _notice(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _employeeDialog({Employee? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final code = TextEditingController(
      text:
          existing?.code ??
          'NV-${(employees.length + 2).toString().padLeft(3, '0')}',
    );
    final job = TextEditingController(text: existing?.role ?? 'Nhân viên');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Thêm nhân viên' : 'Cập nhật nhân viên'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Họ và tên'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: code,
              decoration: const InputDecoration(labelText: 'Mã nhân viên'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: job,
              decoration: const InputDecoration(
                labelText: 'Phòng ban / chức vụ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (result == true && name.text.trim().isNotEmpty) {
      final employee = Employee(
        name.text.trim(),
        job.text.trim(),
        code.text.trim(),
        id: existing?.id,
        present: existing?.present ?? false,
      );
      try {
        final saved = _employeeApi == null
            ? employee
            : existing == null
            ? await _employeeApi.create(employee)
            : await _employeeApi.update(employee);
        if (!mounted) return;
        setState(() {
          if (existing == null) {
            employees.add(saved);
          } else {
            final index = employees.indexOf(existing);
            if (index >= 0) employees[index] = saved;
          }
          _apiError = null;
        });
      } catch (error) {
        _notice(error.toString().replaceFirst('Exception: ', ''));
      }
    }
    name.dispose();
    code.dispose();
    job.dispose();
  }
}

class PressureSensorPage extends StatefulWidget {
  const PressureSensorPage({super.key});

  @override
  State<PressureSensorPage> createState() => _PressureSensorPageState();
}

class _PressureSensorPageState extends State<PressureSensorPage> {
  StreamSubscription<BarometerEvent>? _subscription;
  double? _pressureHpa;
  bool _sensorUnavailable = false;
  final List<_PressureReading> _recentReadings = [];

  double? get _fiveMinuteChange {
    if (_recentReadings.length < 2) return null;
    return (_recentReadings.last.value - _recentReadings.first.value).abs();
  }

  @override
  void initState() {
    super.initState();
    _subscription =
        barometerEventStream(samplingPeriod: const Duration(seconds: 1)).listen(
          (event) {
            if (!mounted) return;
            final now = DateTime.now();
            _recentReadings.add(_PressureReading(now, event.pressure));
            _recentReadings.removeWhere(
              (reading) =>
                  now.difference(reading.time) > const Duration(minutes: 5),
            );
            setState(() => _pressureHpa = event.pressure);
          },
          onError: (Object error) {
            if (mounted) setState(() => _sensorUnavailable = true);
          },
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Đo áp suất không khí'),
      backgroundColor: canvas,
      foregroundColor: ink,
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.speed_rounded, size: 72, color: blue),
            const SizedBox(height: 18),
            const Text(
              'Áp suất khí quyển',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _sensorUnavailable
                  ? 'Thiết bị không cung cấp cảm biến áp suất.'
                  : _pressureHpa == null
                  ? 'Đang đọc cảm biến…'
                  : '${_pressureHpa!.toStringAsFixed(1)} hPa',
              style: const TextStyle(
                fontSize: 30,
                color: navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (_fiveMinuteChange ?? 0) >= 2
                    ? const Color(0xFFFFF3E0)
                    : const Color(0xFFE9F8F2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    (_fiveMinuteChange ?? 0) >= 2
                        ? Icons.warning_amber_rounded
                        : Icons.eco_outlined,
                    color: (_fiveMinuteChange ?? 0) >= 2
                        ? const Color(0xFFD88700)
                        : green,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (_fiveMinuteChange ?? 0) >= 2
                              ? 'Áp suất đang thay đổi nhanh'
                              : 'Theo dõi môi trường trong ca',
                          style: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _fiveMinuteChange == null
                              ? 'Đang thu thập dữ liệu để tạo mốc theo dõi 5 phút.'
                              : 'Biến động 5 phút: ${_fiveMinuteChange!.toStringAsFixed(1)} hPa. Cảnh báo khi thay đổi từ 2 hPa.',
                          style: const TextStyle(
                            color: Color(0xFF78869A),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Tính năng riêng TuTime: cảnh báo sớm khi áp suất môi trường thay đổi nhanh trong ca làm.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF78869A),
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Dữ liệu đọc trực tiếp từ cảm biến khí áp của thiết bị.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF78869A)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Trên giả lập: mở ⋮ → Virtual sensors → Additional sensors → Pressure để thay đổi giá trị mô phỏng.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF78869A),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PressureReading {
  const _PressureReading(this.time, this.value);
  final DateTime time;
  final double value;
}

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  bool completed = false;
  bool readingImage = false;
  final MobileScannerController controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  Future<void> _scanSavedImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;
    await _analyzeQrImage(image.path);
  }

  Future<void> _scanBuiltInCompanyQr() async {
    setState(() => readingImage = true);
    try {
      final painter = QrPainter(
        data: companyQrPayload,
        version: QrVersions.auto,
        gapless: true,
      );
      final imageData = await painter.toImageData(
        600,
        format: ui.ImageByteFormat.png,
      );
      if (imageData == null) throw Exception('Không tạo được ảnh QR công ty.');
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}tutime-company-qr.png',
      );
      await file.writeAsBytes(imageData.buffer.asUint8List(), flush: true);
      if (mounted) await _analyzeQrImage(file.path);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không đọc được QR công ty: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => readingImage = false);
    }
  }

  Future<void> _analyzeQrImage(String path) async {
    setState(() => readingImage = true);
    try {
      completed = false;
      final capture = await controller.analyzeImage(path);
      if (!mounted) return;
      final value = capture?.barcodes.isNotEmpty == true
          ? capture!.barcodes.first.rawValue
          : null;
      if (value != null) {
        _finish(value);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy mã QR trong ảnh.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không đọc được ảnh QR: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => readingImage = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _finish(String value) {
    if (completed || !mounted) return;
    completed = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Quét QR chấm công'),
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          tooltip: 'Chọn ảnh QR đã lưu',
          onPressed: readingImage ? null : _scanSavedImage,
          icon: readingImage
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.photo_library_outlined),
        ),
      ],
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: controller,
          onDetect: (capture) {
            if (capture.barcodes.isEmpty) return;
            final value = capture.barcodes.first.rawValue;
            if (value == null) return;
            _finish(value);
          },
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        ),
        Positioned(
          left: 30,
          right: 30,
          bottom: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .66),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Quét QR công ty bằng camera, chọn ảnh đã lưu ở góc trên, hoặc dùng ảnh QR demo có sẵn cho một giả lập.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: readingImage ? null : _scanBuiltInCompanyQr,
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('Dùng QR demo đã lưu trong app'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: navy,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({
    super.key,
    required this.api,
    required this.currentUsername,
    this.currentUserId,
  });
  final AdminUserApi api;
  final int? currentUserId;
  final String currentUsername;

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<AdminUser> users = [];
  bool loading = true;
  String? error;
  String query = '';
  String roleFilter = 'Tất cả';
  final Set<int> deletingIds = {};

  int get _adminCount =>
      users.where((user) => user.role.toLowerCase() == 'admin').length;

  List<AdminUser> get _visibleUsers => users.where((user) {
    final isAdmin = user.role.toLowerCase() == 'admin';
    final matchesRole =
        roleFilter == 'Tất cả' ||
        (roleFilter == 'Quản trị viên' ? isAdmin : !isAdmin);
    final normalizedQuery = query.trim().toLowerCase();
    final matchesQuery =
        normalizedQuery.isEmpty ||
        user.fullName.toLowerCase().contains(normalizedQuery) ||
        user.username.toLowerCase().contains(normalizedQuery) ||
        user.email.toLowerCase().contains(normalizedQuery);
    return matchesRole && matchesQuery;
  }).toList();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await widget.api.getAll();
      if (!mounted) return;
      setState(() {
        users = loaded;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  Future<void> _delete(AdminUser user) async {
    final isCurrentUser =
        widget.currentUserId == user.id ||
        widget.currentUsername.toLowerCase() == user.username.toLowerCase();
    if (isCurrentUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không thể xóa tài khoản đang đăng nhập.'),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tài khoản?'),
        content: Text(
          'Xóa ${user.fullName} (${user.username})? Thao tác này cũng xóa lịch sử chấm công của tài khoản.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa tài khoản'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => deletingIds.add(user.id));
    try {
      await widget.api.delete(user.id);
      if (!mounted) return;
      setState(() {
        users.removeWhere((item) => item.id == user.id);
        deletingIds.remove(user.id);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã xóa tài khoản.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => deletingIds.remove(user.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Quản lý tài khoản'),
      backgroundColor: canvas,
      foregroundColor: ink,
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: loading ? null : _loadUsers,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [navy, Color(0xFF285B91)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.manage_accounts_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tài khoản hệ thống',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${users.length} tài khoản · $_adminCount quản trị viên',
                        style: const TextStyle(
                          color: Color(0xFFD3E3F5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, username hoặc email',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => setState(() => query = ''),
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 54,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            children: ['Tất cả', 'Nhân viên', 'Quản trị viên']
                .map(
                  (label) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: roleFilter == label,
                      onSelected: (_) => setState(() => roleFilter = label),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          size: 42,
                          color: blue,
                        ),
                        const SizedBox(height: 12),
                        Text(error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _loadUsers,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : _visibleUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person_search_rounded,
                        color: Color(0xFF9AA6B5),
                        size: 44,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        users.isEmpty
                            ? 'Chưa có tài khoản nào.'
                            : 'Không tìm thấy tài khoản phù hợp.',
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                    itemCount: _visibleUsers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final user = _visibleUsers[index];
                      final isAdmin = user.role.toLowerCase() == 'admin';
                      final isCurrentUser =
                          widget.currentUserId == user.id ||
                          widget.currentUsername.toLowerCase() ==
                              user.username.toLowerCase();
                      final isDeleting = deletingIds.contains(user.id);
                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: Color(0xFFE9EEF5)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: isAdmin
                                  ? const Color(0xFFE9EFFF)
                                  : const Color(0xFFE7F7F1),
                              child: Icon(
                                isAdmin
                                    ? Icons.admin_panel_settings_rounded
                                    : Icons.person_rounded,
                                color: isAdmin ? blue : green,
                              ),
                            ),
                            title: Text(
                              user.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '@${user.username} · ${user.email}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 7),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _accountTag(
                                        isAdmin ? 'Quản trị viên' : 'Nhân viên',
                                        isAdmin ? blue : green,
                                      ),
                                      _accountTag(
                                        user.emailVerified
                                            ? 'Email đã xác nhận'
                                            : 'Chưa xác nhận',
                                        user.emailVerified
                                            ? green
                                            : const Color(0xFFB7791F),
                                      ),
                                      if (isCurrentUser)
                                        _accountTag('Bạn', navy),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            isThreeLine: true,
                            trailing: isCurrentUser
                                ? const Tooltip(
                                    message: 'Không thể xóa tài khoản đang đăng nhập',
                                    child: Icon(
                                      Icons.lock_outline_rounded,
                                      color: Color(0xFF9AA6B5),
                                    ),
                                  )
                                : IconButton(
                                    tooltip: 'Xóa tài khoản',
                                    onPressed: isDeleting
                                        ? null
                                        : () => _delete(user),
                                    icon: isDeleting
                                        ? const SizedBox.square(
                                            dimension: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Color(0xFFD65353),
                                          ),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    ),
  );

  Widget _accountTag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );
}
