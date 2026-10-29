import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'models/employee.dart';
import 'models/punch_record.dart';
import 'services/attendance_api.dart';
import 'services/auth_api.dart';
import 'services/employee_api.dart';

void main() => runApp(const ChamCongApp());

const ink = Color(0xFF15243A);
const navy = Color(0xFF142E50);
const blue = Color(0xFF3978F6);
const canvas = Color(0xFFF4F7FB);
const green = Color(0xFF18A979);
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
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
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
        accessToken = session.token;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomePage(
            role: displayRole,
            name: displayName,
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
                    Icons.fingerprint_rounded,
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
    this.accessToken,
  });
  final String role;
  final String name;
  final String? accessToken;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
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
            child: const Icon(Icons.fingerprint, color: blue),
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
              checkedIn
                  ? Icons.logout_rounded
                  : Icons.face_retouching_natural_rounded,
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
            'Xác thực khuôn mặt  ·  QR  ·  Vị trí GPS',
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
        'Hồ sơ và mã nhân viên',
        () => _notice('Hồ sơ nhân viên sẽ kết nối API.'),
      ),
      if (isAdmin)
        _setting(
          Icons.qr_code_2_rounded,
          'Mã QR điểm danh hôm nay',
          'Hiển thị mã cho nhân viên quét tại văn phòng',
          _showOfficeQr,
        ),
      _setting(
        Icons.verified_user_outlined,
        'Bảo mật & OTP',
        'Email OTP đang bật',
        () => _notice('Cài đặt bảo mật'),
      ),
      _setting(
        Icons.help_outline,
        'Trợ giúp',
        'Hướng dẫn sử dụng TuTime',
        () => _notice('Liên hệ quản trị viên để được hỗ trợ.'),
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

  void _punch() {
    _verifyAndPunch();
  }

  Future<void> _verifyAndPunch() async {
    try {
      final qr = await Navigator.of(context)
          .push<String>(MaterialPageRoute(builder: (_) => const QrScanPage()));
      if (!mounted || qr == null) return;
      if (qr != _officeQrPayload()) {
        _notice('QR không hợp lệ. Hãy quét mã chấm công của công ty.');
        return;
      }

      final authenticated = await LocalAuthentication().authenticate(
        localizedReason: 'Xác nhận danh tính để chấm công',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (!mounted || !authenticated) return;

      final position = await _getCurrentPosition();
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        officeLatitude,
        officeLongitude,
      );
      if (distance > officeRadiusMeters) {
        _notice(
          'Bạn đang cách văn phòng ${distance.round()}m; bán kính cho phép ${officeRadiusMeters.round()}m.',
        );
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
              'QR + sinh trắc học + GPS',
            ),
          );
        } else {
          checkedOut = true;
          records.add(
            PunchRecord(
              'Chấm công tan ca',
              DateTime.now(),
              'Văn phòng · ${distance.round()}m',
              'QR + sinh trắc học + GPS',
            ),
          );
        }
      });
      if (_attendanceApi != null) await _refreshHistory();
      _notice('Đã xác minh QR, sinh trắc học và vị trí. Chấm công thành công.');
    } catch (error) {
      if (mounted) _notice(error.toString().replaceFirst('Exception: ', ''));
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

  String _officeQrPayload() {
    final now = DateTime.now();
    final day =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return 'TUTIME:OFFICE:$day';
  }

  void _showOfficeQr() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR điểm danh hôm nay'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: _officeQrPayload(),
              size: 230,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 12),
            Text(
              _officeQrPayload(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF78869A)),
            ),
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

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  bool completed = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Quét QR chấm công'),
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          onDetect: (capture) {
            if (completed || capture.barcodes.isEmpty) return;
            final value = capture.barcodes.first.rawValue;
            if (value == null) return;
            completed = true;
            Navigator.of(context).pop(value);
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
          bottom: 44,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .66),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Đưa mã QR của công ty vào khung để xác thực điểm chấm công.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      ],
    ),
  );
}
