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
import 'package:share_plus/share_plus.dart';

import 'models/employee.dart';
import 'employee_editor_dialog.dart';
import 'face_enrollment_page.dart';
import 'pressure_dashboard.dart';
import 'models/punch_record.dart';
import 'services/attendance_api.dart';
import 'services/admin_user_api.dart';
import 'services/auth_api.dart';
import 'services/employee_api.dart';
import 'services/biometric_session.dart';
import 'settings_page.dart';
import 'schedule_requests_page.dart';
import 'services/schedule_request_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPreferences.instance.load();
  runApp(const ChamCongApp());
}

const ink = Color(0xFFF2F4F7);
const navy = Color(0xFF171A20);
const blue = Color(0xFFD2AE68);
const canvas = Color(0xFF0B0D11);
const surface = Color(0xFF14171D);
const surfaceAlt = Color(0xFF1B1F27);
const border = Color(0xFF2A3039);
const muted = Color(0xFFA0A9B6);
const green = Color(0xFF52C49A);
const companyQrPayload = 'TUTIME:OFFICE:23DTHE1LEDOANVANTU-GROUP8';
double _configuredNumber(String value, double fallback) {
  final normalized = value.trim().replaceFirst(RegExp(r'[\\/]+$'), '');
  return double.tryParse(normalized) ?? fallback;
}

final officeLatitude = _configuredNumber(
  const String.fromEnvironment('OFFICE_LAT', defaultValue: '10.7769'),
  10.7769,
);
final officeLongitude = _configuredNumber(
  const String.fromEnvironment('OFFICE_LNG', defaultValue: '106.7009'),
  106.7009,
);

class ChamCongApp extends StatelessWidget {
  const ChamCongApp({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppPreferences.instance,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TuTime · Chấm công',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Color(AppPreferences.instance.background),
        colorScheme: ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.dark,
          primary: blue,
          surface: surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: canvas,
          foregroundColor: ink,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: const CardThemeData(
          color: surface,
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surface,
          indicatorColor: blue.withValues(alpha: .17),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? blue : muted,
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected) ? blue : muted,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
        dialogTheme: const DialogThemeData(backgroundColor: surface),
        fontFamily: 'Roboto',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceAlt,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: blue, width: 1.4),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(AppPreferences.instance.scale),
        ),
        child: child!,
      ),
      home: const LoginPage(),
    ),
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

  Future<void> _faceLogin() async {
    setState(() => busy = true);
    try {
      final session = await BiometricSession.unlock(_apiBaseUrl);
      if (session == null || !mounted) return;
      await AttendanceApi(_apiBaseUrl, session.token).getHistory();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomePage(
            role: session.role.toLowerCase() == 'admin'
                ? 'Quản trị viên'
                : 'Nhân viên',
            name: session.fullName,
            username: session.username,
            userId: session.userId,
            accessToken: session.token,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
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
        await BiometricSession.clear();
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
                  style: TextStyle(fontSize: 16, color: muted),
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
                  style: TextStyle(color: muted, fontSize: 15),
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
                    autofillHints: const <String>[],
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.email_outlined),
                      hintText: 'ten@congty.vn',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  isRegistering ? 'Tên đăng nhập' : 'Tên đăng nhập hoặc email',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: user,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const <String>[],
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_outline),
                    hintText: isRegistering
                        ? 'Nhập tên đăng nhập'
                        : 'Nhập tên đăng nhập hoặc email',
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
                  autofillHints: const <String>[],
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
                if (!isRegistering && !showOtp)
                  TextButton.icon(
                    onPressed: busy ? null : _faceLogin,
                    icon: const Icon(Icons.face),
                    label: const Text('Đăng nhập bằng khuôn mặt'),
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
                      color: muted,
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
  bool showingAdminAttendance = false;
  late String _displayName = widget.name;
  late final EmployeeApi? _employeeApi;
  late final AttendanceApi? _attendanceApi;
  String? _apiError;
  bool checkedIn = false;
  bool checkedOut = false;
  bool _punching = false;
  bool _loadingLocation = false;
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
        final today = remoteRecords.where(
          (r) =>
              r.userId == widget.userId &&
              DateUtils.isSameDay(r.time, DateTime.now()),
        );
        checkedIn = today.any((r) => r.action.contains('vào ca'));
        checkedOut = today.any((r) => r.action.contains('tan ca'));
      });
    } catch (error) {
      if (mounted) _notice(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _dashboard(),
      isAdmin
          ? (showingAdminAttendance ? _adminAttendance() : _employees())
          : _history(),
      _profile(),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: tab, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        backgroundColor: surface,
        indicatorColor: blue.withValues(alpha: .17),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(
              isAdmin ? Icons.groups_2_outlined : Icons.receipt_long_outlined,
            ),
            label: isAdmin
                ? (showingAdminAttendance ? 'Chấm công' : 'Nhân viên')
                : 'Lịch sử',
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
              color: surfaceAlt,
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
            backgroundColor: surfaceAlt,
            child: Text(
              _displayName.isNotEmpty ? _displayName[0] : 'T',
              style: const TextStyle(color: navy, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      Text(_greeting(), style: const TextStyle(color: muted, fontSize: 14)),
      const SizedBox(height: 4),
      Text(
        _displayName,
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
              _workedToday(),
              Icons.schedule_rounded,
              surfaceAlt,
              blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _metric(
              isAdmin ? 'Có mặt' : 'Tăng ca hôm nay',
              isAdmin
                  ? '${employees.where((e) => e.present).length}/${employees.length}'
                  : _todayOvertimeLabel(),
              isAdmin ? Icons.groups_rounded : Icons.timelapse_rounded,
              const Color(0xFF172720),
              green,
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      _locationCard(),
      if (widget.accessToken != null) ...[
        const SizedBox(height: 12),
        _setting(
          Icons.face_retouching_natural,
          'Quét / đăng ký khuôn mặt',
          'Bật đăng nhập khuôn mặt cho tài khoản của bạn',
          _openFaceSetup,
        ),
      ],
      const SizedBox(height: 12),
      _setting(
        Icons.event_available_outlined,
        'Xin đi muộn / về sớm',
        isAdmin
            ? 'Xem và duyệt đơn xin phép của nhân viên'
            : 'Gửi đơn và xem kết quả duyệt',
        _openScheduleRequests,
      ),
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
      Row(
        children: [
          const Expanded(
            child: Text(
              'Hoạt động gần đây',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
          ),
          if (isAdmin)
            TextButton(
              onPressed: () => setState(() {
                showingAdminAttendance = true;
                tab = 1;
              }),
              child: const Text('Xem tất cả'),
            ),
        ],
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
        colors: [Color(0xFF332A1B), Color(0xFF171A20)],
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
      color: surface,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF55452B).withValues(alpha: .05),
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
                color: const Color(0xFF172720),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 7, color: green),
                  SizedBox(width: 5),
                  Text(
                    checkedOut
                        ? 'ĐÃ TAN CA'
                        : checkedIn
                        ? 'ĐANG TRONG CA'
                        : 'CHƯA VÀO CA',
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
            onPressed: checkedOut || _punching ? null : _punch,
            icon: _punching
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    checkedIn
                        ? Icons.logout_rounded
                        : Icons.qr_code_scanner_rounded,
                  ),
            label: Text(
              _punching
                  ? 'Đang xử lý chấm công…'
                  : checkedIn
                  ? 'Chấm công tan ca'
                  : 'Chấm công vào ca',
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
            'Ca chuẩn 08:00–17:00 · sau 17:00 tính tăng ca',
            style: TextStyle(fontSize: 11, color: muted),
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text(
            'QR công ty  ·  Vị trí GPS',
            style: TextStyle(fontSize: 11, color: muted),
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
                    color: muted,
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
      color: surface,
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
            Text(label, style: const TextStyle(fontSize: 11, color: muted)),
          ],
        ),
      ],
    ),
  );

  Widget _locationCard() => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: surfaceAlt,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: surfaceAlt,
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
                'Vị trí hiện tại',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: ink,
                  fontSize: 13,
                ),
              ),
              Text(
                'Nhấn biểu tượng để xem và chia sẻ vị trí',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Xem và chia sẻ vị trí',
          onPressed: _loadingLocation ? null : _shareCurrentLocation,
          icon: _loadingLocation
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location_rounded, color: blue),
        ),
      ],
    ),
  );

  Widget _emptyActivity() => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      children: [
        Icon(Icons.event_note_outlined, color: muted),
        SizedBox(width: 10),
        Text(
          'Chưa có hoạt động. Hãy chấm công để bắt đầu.',
          style: TextStyle(fontSize: 12, color: muted),
        ),
      ],
    ),
  );

  Widget _recordTile(PunchRecord item) => Container(
    margin: const EdgeInsets.only(top: 7),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: surface,
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
                style: const TextStyle(color: muted, fontSize: 11),
              ),
              if (item.approvalLabel != null)
                Text(
                  item.approvalLabel!,
                  style: const TextStyle(
                    color: green,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (_overtimeMinutes(item) > 0)
                Text(
                  'Tăng ca ${_formatDuration(_overtimeMinutes(item))}',
                  style: const TextStyle(
                    color: green,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
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
        style: TextStyle(color: muted),
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
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 14),
      _adminSectionToggle(),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: _metric(
              'Nhân sự',
              '${employees.length}',
              Icons.groups_rounded,
              surfaceAlt,
              blue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metric(
              'Có mặt',
              '${employees.where((e) => e.present).length}',
              Icons.check_circle_outline,
              const Color(0xFF172720),
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
              ? const Color(0xFF302719)
              : _apiError == null
              ? const Color(0xFF172720)
              : const Color(0xFF301C1D),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          _employeeApi == null
              ? 'Đang dùng dữ liệu demo. Chạy với --dart-define=API_BASE_URL=https://api-cua-nhom để bật CRUD REST.'
              : _apiError ?? 'Đã tải danh sách từ API /api/EmployeeApi.',
          style: TextStyle(
            fontSize: 11,
            color: _employeeApi == null
                ? const Color(0xFFE0B863)
                : _apiError == null
                ? green
                : const Color(0xFFE48B8B),
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
                color: muted,
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

  Widget _adminSectionToggle() => SegmentedButton<bool>(
    segments: const [
      ButtonSegment(
        value: false,
        icon: Icon(Icons.groups_2_outlined),
        label: Text('Nhân viên'),
      ),
      ButtonSegment(
        value: true,
        icon: Icon(Icons.receipt_long_outlined),
        label: Text('Chấm công'),
      ),
    ],
    selected: {showingAdminAttendance},
    onSelectionChanged: (selection) => setState(() {
      showingAdminAttendance = selection.first;
      tab = 1;
      if (showingAdminAttendance) _refreshHistory();
    }),
  );

  Widget _adminAttendance() => RefreshIndicator(
    onRefresh: _refreshHistory,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Lịch sử chấm công',
                style: TextStyle(
                  fontSize: 24,
                  color: ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Tải lại',
              onPressed: _refreshHistory,
              icon: const Icon(Icons.refresh_rounded, color: blue),
            ),
          ],
        ),
        const SizedBox(height: 5),
        const Text(
          'Không chặn theo bán kính. Lượt xa hoặc GPS thiếu chính xác được đánh dấu để admin đối soát và hủy nếu cần.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 14),
        _adminSectionToggle(),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceAlt,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '${records.length} lượt gần nhất · Không chặn theo bán kính · Nhấn xóa để hủy một lượt.',
            style: const TextStyle(
              color: navy,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (records.isEmpty)
          _emptyActivity()
        else
          ...records.map(_adminAttendanceTile),
      ],
    ),
  );

  Widget _adminAttendanceTile(PunchRecord record) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.employeeName?.isNotEmpty == true
                        ? record.employeeName!
                        : 'Nhân viên ${record.username ?? ''}',
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (record.username?.isNotEmpty == true)
                    Text(
                      '@${record.username}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Hủy lượt chấm công',
              onPressed: record.recordId == null
                  ? null
                  : () => _cancelAttendance(record),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFE07E78),
              ),
            ),
          ],
        ),
        Text(
          '${record.action} · ${record.time.day.toString().padLeft(2, '0')}/${record.time.month.toString().padLeft(2, '0')}/${record.time.year} ${_clock(record.time)}',
          style: const TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _recordTag(
              record.distanceFromOfficeMeters == null
                  ? record.place
                  : '${record.distanceFromOfficeMeters!.toStringAsFixed(1)} m từ văn phòng',
              blue,
            ),
            _recordTag(
              record.accuracyMeters == null
                  ? 'Sai số GPS chưa có'
                  : 'Sai số GPS ±${record.accuracyMeters!.toStringAsFixed(1)} m',
              record.accuracyMeters != null && record.accuracyMeters! <= 20
                  ? green
                  : const Color(0xFFE0B863),
            ),
            if (record.approvalLabel != null)
              _recordTag(record.approvalLabel!, green),
            if (_overtimeMinutes(record) > 0)
              _recordTag(
                'Tăng ca ${_formatDuration(_overtimeMinutes(record))}',
                green,
              ),
            if ((record.distanceFromOfficeMeters ?? 0) > 150 ||
                record.accuracyMeters == null ||
                record.accuracyMeters! > 25)
              _recordTag('Cần admin đối soát', const Color(0xFFE0B863)),
          ],
        ),
        if (record.latitude != null && record.longitude != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            'GPS: ${record.latitude!.toStringAsFixed(6)}, ${record.longitude!.toStringAsFixed(6)}',
            style: const TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ],
    ),
  );

  Widget _recordTag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );

  Future<void> _cancelAttendance(PunchRecord record) async {
    if (_attendanceApi == null || record.recordId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy lượt chấm công?'),
        content: Text(
          'Hủy ${record.action.toLowerCase()} của ${record.employeeName ?? record.username ?? 'nhân viên'}? Thao tác này xóa lượt khỏi lịch sử.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy lượt'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final api = _attendanceApi;
      final recordId = record.recordId;
      await api.cancelRecord(recordId!);
      if (!mounted) return;
      setState(
        () => records.removeWhere((item) => item.recordId == record.recordId),
      );
      await _refreshHistory();
      await _refreshEmployees();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã hủy lượt chấm công.')));
    } catch (error) {
      if (mounted) _notice(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget _employeeTile(Employee e) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: surfaceAlt,
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
                '${e.code} · ${e.role}\n${e.email.isEmpty ? 'Chưa có email liên kết' : e.email} · ${e.userId == null ? 'Chưa liên kết' : 'Đã liên kết'}',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: e.present
                ? const Color(0xFF172720)
                : const Color(0xFF302719),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            e.present ? 'Có mặt' : 'Chưa đến',
            style: TextStyle(
              fontSize: 10,
              color: e.present ? green : const Color(0xFFE0B863),
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
              backgroundColor: surfaceAlt,
              child: Icon(Icons.person, color: blue, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName,
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
      if (widget.accessToken != null)
        _setting(
          Icons.settings,
          'Cài đặt',
          'Cỡ chữ, màu nền, khuôn mặt và hồ sơ',
          () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SettingsPage(
                session: AuthSession(
                  token: widget.accessToken!,
                  fullName: _displayName,
                  username: widget.username,
                  userId: widget.userId,
                  role: isAdmin ? 'Admin' : 'Employee',
                ),
                baseUrl: _apiBaseUrl,
                onFaceSetup: _openFaceSetup,
                onNameChanged: (value) {
                  setState(() => _displayName = value);
                  _refreshEmployees();
                },
              ),
            ),
          ),
        ),
      if (widget.accessToken != null)
        _setting(
          Icons.face_retouching_natural,
          'Quét / đăng ký khuôn mặt',
          'Đăng ký và kiểm tra khuôn mặt của tài khoản này',
          _openFaceSetup,
        ),
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
          foregroundColor: const Color(0xFFE07E78),
          padding: const EdgeInsets.all(15),
          side: const BorderSide(color: border),
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
      tileColor: surface,
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
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: muted),
      ),
      trailing: const Icon(Icons.chevron_right, color: muted),
    ),
  );

  Future<void> _openFaceSetup() async {
    if (widget.accessToken == null) {
      _notice('Hãy đăng nhập bằng mật khẩu và OTP trước.');
      return;
    }
    final session = AuthSession(
      token: widget.accessToken!,
      fullName: _displayName,
      username: widget.username,
      userId: widget.userId,
      role: isAdmin ? 'Admin' : 'Employee',
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FaceEnrollmentPage(
          name: _displayName,
          username: widget.username,
          checkEnabled: () =>
              BiometricSession.isEnabledFor(session, _apiBaseUrl),
          enroll: () async {
            if (!await BiometricSession.available()) {
              throw Exception('Quét khuôn mặt hiện hỗ trợ trên Android.');
            }
            if (!await BiometricSession.authenticate()) return false;
            await BiometricSession.save(session, _apiBaseUrl);
            return true;
          },
          verify: () async {
            final matched = await BiometricSession.unlock(_apiBaseUrl);
            if (matched == null) return false;
            if (matched.userId != session.userId) {
              throw Exception(
                'Khuôn mặt đang được đăng ký cho tài khoản khác. Hãy đăng ký lại.',
              );
            }
            return true;
          },
          disable: BiometricSession.clear,
        ),
      ),
    );
  }

  Future<void> _openScheduleRequests() async {
    if (widget.accessToken == null) {
      _notice('Hãy đăng nhập bằng tài khoản để gửi đơn.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScheduleRequestsPage(
          api: ScheduleRequestApi(_apiBaseUrl, widget.accessToken!),
          isAdmin: isAdmin,
          userId: widget.userId,
        ),
      ),
    );
    if (mounted && _attendanceApi != null) await _refreshHistory();
  }

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
          Text('Họ tên: $_displayName'),
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
        'Chấm công: quét QR công ty → ghi nhận GPS và khoảng cách tới văn phòng → gửi bản ghi. Admin xem, kiểm tra độ chính xác và hủy lượt chấm công ở mục Chấm công. Mục Đo áp suất không khí có thể chạy bằng cảm biến ảo trên Android Emulator.',
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
    setState(() => _punching = true);
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

      _notice('Đang lấy vị trí GPS và gửi lượt chấm công…');
      final position = await _getCurrentPosition();
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        officeLatitude,
        officeLongitude,
      );
      final double? accuracy =
          position.accuracy.isFinite && position.accuracy > 0
          ? position.accuracy
          : null;
      final coordinates =
          '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';

      final action = checkedIn ? 'checkOut' : 'checkIn';
      final now = DateTime.now();
      final overtimeMinutes = action == 'checkOut'
          ? _calculateOvertimeMinutes(now)
          : 0;
      if (_attendanceApi != null) {
        await _attendanceApi.record(
          type: action,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: accuracy,
          qrToken: qr,
        );
      }

      if (!mounted) return;
      setState(() {
        if (!checkedIn) {
          checkedIn = true;
          records.add(
            PunchRecord(
              'Chấm công vào ca',
              now,
              'Cách VP ${distance.toStringAsFixed(1)}m',
              '${accuracy == null ? 'GPS chưa có sai số' : 'GPS ±${accuracy.toStringAsFixed(1)}m'} · $coordinates',
              userId: widget.userId,
              employeeName: _displayName,
              overtimeMinutes: overtimeMinutes,
            ),
          );
        } else {
          checkedOut = true;
          records.add(
            PunchRecord(
              'Chấm công tan ca',
              now,
              'Cách VP ${distance.toStringAsFixed(1)}m',
              '${accuracy == null ? 'GPS chưa có sai số' : 'GPS ±${accuracy.toStringAsFixed(1)}m'} · $coordinates',
              userId: widget.userId,
              employeeName: _displayName,
              overtimeMinutes: overtimeMinutes,
            ),
          );
        }
      });
      if (_attendanceApi != null) await _refreshHistory();
      if (_employeeApi != null) await _refreshEmployees();
      if (!mounted) return;
      _notice(
        'Đã lưu vị trí GPS${accuracy == null ? '' : ' với sai số ±${accuracy.toStringAsFixed(1)}m'} và khoảng cách ${distance.toStringAsFixed(1)}m tới văn phòng. ${action == 'checkOut'
            ? overtimeMinutes > 0
                  ? 'Tăng ca ${_formatDuration(overtimeMinutes)}.'
                  : 'Không phát sinh tăng ca.'
            : ''} Chấm công thành công.',
      );
    } catch (error) {
      if (mounted) _notice(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _punching = false);
    }
  }

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
                  border: Border.all(color: border),
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
                'Nhân viên quét mã này để chấm công. Ứng dụng lưu GPS, sai số và khoảng cách để quản trị viên đối soát.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: muted, height: 1.4),
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

  Future<void> _shareCurrentLocation() async {
    setState(() => _loadingLocation = true);
    try {
      final position = await _getCurrentPosition();
      if (!mounted) return;
      final latitude = position.latitude.toStringAsFixed(6);
      final longitude = position.longitude.toStringAsFixed(6);
      final mapsLink = 'https://www.google.com/maps?q=$latitude,$longitude';
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Vị trí hiện tại'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText('Tọa độ: $latitude, $longitude'),
              const SizedBox(height: 8),
              Text(
                position.accuracy.isFinite && position.accuracy > 0
                    ? 'Sai số GPS: ±${position.accuracy.toStringAsFixed(1)} m'
                    : 'Chưa có thông tin sai số GPS',
              ),
              const SizedBox(height: 8),
              const Text('Chọn Chia sẻ để gửi liên kết bản đồ.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await SharePlus.instance.share(
                    ShareParams(text: 'Vị trí hiện tại của tôi: $mapsLink'),
                  );
                } catch (error) {
                  if (mounted) _notice('Không mở được chia sẻ vị trí: $error');
                }
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Chia sẻ'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _notice(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
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
  List<PunchRecord> _ownToday() =>
      records
          .where(
            (r) =>
                r.userId == widget.userId &&
                DateUtils.isSameDay(r.time, DateTime.now()),
          )
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));
  String _clockFor(String type) {
    final entries = _ownToday().where(
      (r) => r.action.contains(type == 'IN' ? 'vào ca' : 'tan ca'),
    );
    return entries.isEmpty
        ? '--:--'
        : _clock(type == 'IN' ? entries.first.time : entries.last.time);
  }

  String _workedToday() {
    DateTime? start;
    var minutes = 0;
    for (final r in _ownToday()) {
      if (r.action.contains('vào ca')) {
        start ??= r.time;
      } else if (start != null) {
        minutes += r.time.difference(start).inMinutes;
        start = null;
      }
    }
    if (start != null) minutes += DateTime.now().difference(start).inMinutes;
    return _formatDuration(minutes.clamp(0, 1440));
  }

  int _calculateOvertimeMinutes(DateTime time) {
    final shiftEnd = DateTime(time.year, time.month, time.day, 17);
    return time.isAfter(shiftEnd) ? time.difference(shiftEnd).inMinutes : 0;
  }

  int _overtimeMinutes(PunchRecord record) {
    if (!record.action.contains('tan ca')) return 0;
    return record.overtimeMinutes ?? _calculateOvertimeMinutes(record.time);
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (hours == 0) return '$remaining phút';
    if (remaining == 0) return '$hours h';
    return '$hours h $remaining p';
  }

  String _todayOvertimeLabel() {
    final today = DateTime.now();
    final total = records
        .where(
          (record) =>
              record.userId == widget.userId &&
              record.time.year == today.year &&
              record.time.month == today.month &&
              record.time.day == today.day,
        )
        .fold<int>(0, (sum, record) => sum + _overtimeMinutes(record));
    return total == 0 ? '0 phút' : _formatDuration(total);
  }

  void _notice(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
  );

  void _addEmployee() => _employeeDialog();
  void _editEmployee(Employee e) => _employeeDialog(existing: e);

  Future<void> _deleteEmployee(Employee employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa hồ sơ nhân viên?'),
        content: Text(
          'Bạn có chắc muốn xóa ${employee.name} (${employee.code}) không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE07E78),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa hồ sơ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
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
    final saved = await showDialog<Employee>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EmployeeEditorDialog(
        existing: existing,
        initialCode: 'NV-${(employees.length + 2).toString().padLeft(3, '0')}',
        save: (employee, {username, initialPassword}) async {
          if (_employeeApi == null) return employee;
          return existing == null
              ? _employeeApi.create(
                  employee,
                  username: username,
                  initialPassword: initialPassword,
                )
              : _employeeApi.update(employee);
        },
      ),
    );
    if (saved == null || !mounted) return;
    setState(() {
      if (existing == null) {
        employees.add(saved);
      } else {
        final index = employees.indexWhere(
          (e) =>
              e.id == existing.id &&
              (existing.id != null || identical(e, existing)),
        );
        if (index >= 0) employees[index] = saved;
      }
      _apiError = null;
    });
    _notice(
      existing != null
          ? 'Đã cập nhật nhân viên.'
          : _employeeApi == null
          ? 'Đã thêm nhân viên ở chế độ demo.'
          : saved.accountCreated && saved.loginUsername != null
          ? 'Đã thêm nhân viên và tạo tài khoản ${saved.loginUsername}. Nhân viên đăng nhập bằng mật khẩu ban đầu và OTP email.'
          : 'Đã thêm nhân viên và liên kết tài khoản hiện có.',
    );
  }
}

class PressureSensorPage extends StatefulWidget {
  const PressureSensorPage({super.key});

  @override
  State<PressureSensorPage> createState() => _PressureSensorPageState();
}

class _PressureSensorPageState extends State<PressureSensorPage>
    with WidgetsBindingObserver {
  StreamSubscription<BarometerEvent>? _subscription;
  double? _pressureHpa;
  bool _sensorUnavailable = false;
  bool _paused = false;
  bool _backgrounded = false;
  int _generation = 0;
  final List<PressureSample> _recentReadings = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSensor();
  }

  Future<void> _stopSensor() async {
    _generation++;
    final old = _subscription;
    _subscription = null;
    await old?.cancel();
  }

  Future<void> _startSensor() async {
    final generation = ++_generation;
    final old = _subscription;
    _subscription = null;
    try {
      await old?.cancel();
      if (!mounted || _paused || _backgrounded || generation != _generation) {
        return;
      }
      _subscription =
          barometerEventStream(
            samplingPeriod: const Duration(seconds: 1),
          ).listen(
            (event) {
              if (!mounted ||
                  generation != _generation ||
                  !event.pressure.isFinite ||
                  event.pressure <= 0) {
                return;
              }
              final now = DateTime.now();
              setState(() {
                _recentReadings.add(PressureSample(now, event.pressure));
                _recentReadings.removeWhere(
                  (reading) =>
                      now.difference(reading.time) > const Duration(minutes: 5),
                );
                _pressureHpa = event.pressure;
                _sensorUnavailable = false;
              });
            },
            onError: (Object error) {
              if (mounted && generation == _generation) {
                setState(() => _sensorUnavailable = true);
              }
            },
          );
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _sensorUnavailable = true);
      }
    }
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _stopSensor();
    } else {
      _startSensor();
    }
  }

  void _reset() {
    setState(() {
      _recentReadings.clear();
      _pressureHpa = null;
      _sensorUnavailable = false;
      _paused = false;
    });
    _startSensor();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _backgrounded = state != AppLifecycleState.resumed;
    if (_backgrounded) {
      _stopSensor();
    } else if (!_paused) {
      _startSensor();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đo áp suất không khí')),
    body: PressureDashboard(
      readings: List<PressureSample>.from(_recentReadings),
      current: _pressureHpa,
      unavailable: _sensorUnavailable,
      paused: _paused || _backgrounded,
      onPauseToggle: _togglePause,
      onReset: _reset,
    ),
  );
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
      final capture = await controller
          .analyzeImage(path)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw TimeoutException('Đọc QR mất quá lâu. Hãy thử lại.'),
          );
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
            if (readingImage || completed) return;
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
              FilledButton.icon(
                onPressed: readingImage ? null : _scanBuiltInCompanyQr,
                icon: readingImage
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.qr_code_2_rounded),
                label: Text(
                  readingImage
                      ? 'Đang đọc QR…'
                      : 'Dùng QR demo đã lưu trong app',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: blue,
                  foregroundColor: canvas,
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
                colors: [navy, Color(0xFF22262E)],
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
                    color: surface,
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
                        color: muted,
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
                        color: surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: border),
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
                                  ? surfaceAlt
                                  : const Color(0xFF172720),
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
                                            : const Color(0xFFE0B863),
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
                                      color: muted,
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
                                            color: Color(0xFFE07E78),
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
