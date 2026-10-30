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
  ValueChanged<Employee?>? result,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 1200));
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
                  save: save,
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
