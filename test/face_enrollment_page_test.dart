import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledoanvantu2/face_enrollment_page.dart';

void main() {
  testWidgets(
    'employee registers verifies and disables their face without role restrictions',
    (tester) async {
      bool enabled = false;
      int enrollments = 0;
      int verifications = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: FaceEnrollmentPage(
            name: 'Nhân viên kiểm tra',
            username: 'employee',
            checkEnabled: () async => enabled,
            enroll: () async {
              enrollments++;
              enabled = true;
              return true;
            },
            verify: () async {
              verifications++;
              return true;
            },
            disable: () async {
              enabled = false;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nhân viên kiểm tra'), findsOneWidget);
      expect(find.text('@employee'), findsOneWidget);
      expect(find.text('CHƯA ĐĂNG KÝ KHUÔN MẶT'), findsOneWidget);
      final enroll = find.text('Quét mặt và đăng ký');
      await tester.ensureVisible(enroll);
      await tester.tap(enroll);
      await tester.pumpAndSettle();
      expect(enrollments, 1);
      expect(find.text('ĐÃ ĐĂNG KÝ TRÊN THIẾT BỊ NÀY'), findsOneWidget);
      final verify = find.text('Kiểm tra khuôn mặt');
      await tester.ensureVisible(verify);
      await tester.tap(verify);
      await tester.pumpAndSettle();
      expect(verifications, 1);
      final disable = find.text('Tắt đăng nhập khuôn mặt');
      await tester.ensureVisible(disable);
      await tester.tap(disable);
      await tester.pumpAndSettle();
      expect(enabled, false);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('cancelled camera never reports successful enrollment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FaceEnrollmentPage(
          name: 'Nhân viên',
          username: 'employee',
          checkEnabled: () async => false,
          enroll: () async => false,
          verify: () async => false,
          disable: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final enroll = find.text('Quét mặt và đăng ký');
    await tester.ensureVisible(enroll);
    await tester.tap(enroll);
    await tester.pumpAndSettle();
    expect(find.text('Đã hủy quét khuôn mặt.'), findsOneWidget);
    expect(find.text('Kiểm tra khuôn mặt'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
