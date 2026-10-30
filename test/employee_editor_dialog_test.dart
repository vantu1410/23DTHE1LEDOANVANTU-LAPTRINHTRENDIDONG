import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledoanvantu2/employee_editor_dialog.dart';
import 'package:ledoanvantu2/models/employee.dart';

Employee employee({String email = 'nhanvien@example.com'}) => Employee(
  'Nhân viên mẫu',
  'Kỹ thuật',
  'NV-002',
  id: 2,
  userId: 8,
  email: email,
  present: true,
);

Future<void> openEditor(
  WidgetTester tester, {
  Employee? existing,
  required Future<Employee> Function(Employee) save,
  EmployeeEditorSave? saveWithAccount,
  ValueChanged<Employee?>? result,
  Size surfaceSize = const Size(900, 1200),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final saved = await showDialog<Employee>(
                context: context,
                barrierDismissible: false,
                builder: (_) => EmployeeEditorDialog(
                  existing: existing,
                  initialCode: 'NV-003',
                  save:
                      saveWithAccount ??
                      (value, {username, initialPassword}) => save(value),
                ),
              );
              result?.call(saved);
            },
            child: const Text('Mở'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('new account fields remain reachable on a small phone', (
    tester,
  ) async {
    await openEditor(
      tester,
      surfaceSize: const Size(360, 640),
      save: (value) async => value,
    );
    final passwordField = find.byKey(
      const ValueKey('employee-initial-password'),
    );
    await tester.ensureVisible(passwordField);
    await tester.pumpAndSettle();
    expect(passwordField.hitTestable(), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(find.byType(EmployeeEditorDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'new employee submits credentials without storing the password in its profile',
    (tester) async {
      String? sentUsername;
      String? sentPassword;
      Employee? sentEmployee;
      await openEditor(
        tester,
        save: (value) async => value,
        saveWithAccount: (value, {username, initialPassword}) async {
          sentEmployee = value;
          sentUsername = username;
          sentPassword = initialPassword;
          return value;
        },
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'Nhân viên mới');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'moi@example.com',
      );
      final usernameField = find.byKey(const ValueKey('employee-username'));
      final passwordField = find.byKey(
        const ValueKey('employee-initial-password'),
      );
      await tester.ensureVisible(usernameField);
      await tester.enterText(usernameField, ' nv-moi ');
      await tester.ensureVisible(passwordField);
      await tester.enterText(passwordField, 'MatKhau123');
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: passwordField,
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        isTrue,
      );
      await tester.tap(find.byTooltip('Hiện mật khẩu'));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: passwordField,
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        isFalse,
      );
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(sentUsername, 'nv-moi');
      expect(sentPassword, 'MatKhau123');
      expect(sentEmployee?.toJson().containsKey('initialPassword'), isFalse);
      expect(sentEmployee?.toJson().toString(), isNot(contains('MatKhau123')));
      expect(find.byType(EmployeeEditorDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new employee can link an existing account without supplying credentials',
    (tester) async {
      var calls = 0;
      await openEditor(
        tester,
        save: (value) async => value,
        saveWithAccount: (value, {username, initialPassword}) async {
          calls++;
          expect(username, isNull);
          expect(initialPassword, isNull);
          return value;
        },
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Nhân viên có tài khoản',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'cu@example.com',
      );
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('typed invalid initial credentials are validated before saving', (
    tester,
  ) async {
    var calls = 0;
    await openEditor(
      tester,
      save: (value) async {
        calls++;
        return value;
      },
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'Nhân viên mới');
    await tester.enterText(find.byType(TextFormField).at(1), 'moi@example.com');
    final usernameField = find.byKey(const ValueKey('employee-username'));
    final passwordField = find.byKey(
      const ValueKey('employee-initial-password'),
    );
    await tester.ensureVisible(usernameField);
    await tester.enterText(usernameField, 'ab');
    await tester.ensureVisible(passwordField);
    await tester.enterText(passwordField, '123');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Tên đăng nhập phải từ 3 đến 40 ký tự.'), findsOneWidget);
    expect(find.text('Mật khẩu phải từ 8 đến 128 ký tự.'), findsOneWidget);
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing a profile does not expose account creation fields', (
    tester,
  ) async {
    await openEditor(
      tester,
      existing: employee(),
      save: (value) async => value,
    );
    expect(find.byKey(const ValueKey('employee-username')), findsNothing);
    expect(
      find.byKey(const ValueKey('employee-initial-password')),
      findsNothing,
    );
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'immediate save returns saved employee and survives reverse animation',
    (tester) async {
      Employee? received;
      Employee? returned;
      await openEditor(
        tester,
        existing: employee(),
        save: (value) async {
          received = value;
          return Employee(
            'Tên từ máy chủ',
            value.role,
            value.code,
            id: value.id,
            email: value.email,
            userId: value.userId,
          );
        },
        result: (value) => returned = value,
      );
      await tester.tap(find.text('Lưu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.byType(EmployeeEditorDialog), findsNothing);
      expect(received?.userId, 8);
      expect(returned?.name, 'Tên từ máy chủ');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending save shows progress and prevents duplicate submit or cancel',
    (tester) async {
      final pending = Completer<Employee>();
      var calls = 0;
      await openEditor(
        tester,
        existing: employee(),
        save: (_) {
          calls++;
          return pending.future;
        },
      );
      await tester.tap(find.text('Lưu'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Đang lưu thông tin, vui lòng chờ…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Hủy'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .every((field) => field.enabled == false),
        isTrue,
      );
      await tester.tap(find.text('Đang lưu…'));
      await tester.pump();
      expect(calls, 1);
      pending.complete(employee());
      await tester.pumpAndSettle();
      expect(find.byType(EmployeeEditorDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('server error keeps dialog open and preserves edits for retry', (
    tester,
  ) async {
    var calls = 0;
    await openEditor(
      tester,
      existing: employee(),
      save: (value) async {
        calls++;
        if (calls == 1) {
          throw Exception('Họ tên chưa khớp tài khoản có email này.');
        }
        return value;
      },
    );
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Tên đã chỉnh sửa',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.byType(EmployeeEditorDialog), findsOneWidget);
    expect(
      find.text('Họ tên chưa khớp tài khoản có email này.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller?.text,
      'Tên đã chỉnh sửa',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller?.text,
      'nhanvien@example.com',
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(EmployeeEditorDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing email is visible validation and does not call save', (
    tester,
  ) async {
    var calls = 0;
    await openEditor(
      tester,
      existing: employee(email: ''),
      save: (value) async {
        calls++;
        return value;
      },
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập email.'), findsOneWidget);
    expect(find.byType(EmployeeEditorDialog), findsOneWidget);
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cancel disposes safely and reopening starts from original data',
    (tester) async {
      Employee? result = employee();
      await openEditor(
        tester,
        existing: employee(),
        save: (value) async => value,
        result: (value) => result = value,
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'Chưa lưu');
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.byType(EmployeeEditorDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).at(0)).controller?.text,
        'Nhân viên mẫu',
      );
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
