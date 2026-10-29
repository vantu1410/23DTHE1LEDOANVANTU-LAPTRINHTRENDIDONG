import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledoanvantu2/main.dart';

void main() {
  testWidgets('login screen starts with empty credentials', (tester) async {
    await tester.pumpWidget(const ChamCongApp());

    expect(find.text('Chấm công\nthật dễ dàng.'), findsOneWidget);
    expect(find.text('Tên đăng nhập'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('Tiếp tục  →'), findsOneWidget);

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, hasLength(2));
    expect(fields.every((field) => field.controller?.text.isEmpty ?? true), isTrue);
  });

  testWidgets('registration mode shows name and email fields', (tester) async {
    await tester.pumpWidget(const ChamCongApp());
    final registerLink = find.text('Chưa có tài khoản? Đăng ký');
    await tester.ensureVisible(registerLink);
    await tester.tap(registerLink);
    await tester.pumpAndSettle();

    expect(find.text('Họ và tên'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Tạo tài khoản  →'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(4));
  });
}
