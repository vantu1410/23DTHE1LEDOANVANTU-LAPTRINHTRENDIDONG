import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledoanvantu2/pressure_dashboard.dart';

void main() {
  final start = DateTime(2026, 10, 30, 9);
  final samples = [
    PressureSample(start, 1000),
    PressureSample(start.add(const Duration(seconds: 10)), 1010),
    PressureSample(start.add(const Duration(seconds: 30)), 1020),
  ];

  Widget screen({
    List<PressureSample>? readings,
    double? current = 1020,
    bool paused = false,
    bool unavailable = false,
    VoidCallback? pause,
    VoidCallback? reset,
    double scale = 1,
  }) => MaterialApp(
    theme: ThemeData.dark(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: PressureDashboard(
        readings: readings ?? samples,
        current: current,
        paused: paused,
        unavailable: unavailable,
        onPauseToggle: pause ?? () {},
        onReset: reset ?? () {},
      ),
    ),
  );

  testWidgets(
    'renders measured current pressure with high contrast and actual statistics',
    (tester) async {
      await tester.pumpWidget(screen());
      expect(find.text('1020.0').first, findsOneWidget);
      final currentText = tester.widget<Text>(find.text('1020.0').first);
      expect(currentText.style?.color, Colors.white);
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('pressure-min'))).data,
        '1000.0',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('pressure-max'))).data,
        '1020.0',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('pressure-average')))
            .data,
        '1010.0',
      );
      expect(find.text('Tối đa 5 phút · 3 mẫu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty readings show waiting state instead of invented data', (
    tester,
  ) async {
    await tester.pumpWidget(screen(readings: [], current: null));
    expect(find.text('Đang chờ mẫu đầu tiên'), findsOneWidget);
    expect(find.text('1020.0'), findsNothing);
    expect(find.textContaining('Cần thêm mẫu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable and paused states are explicit', (tester) async {
    await tester.pumpWidget(
      screen(unavailable: true, readings: [], current: null),
    );
    expect(find.text('●  Chưa có cảm biến'), findsOneWidget);
    await tester.pumpWidget(screen(paused: true));
    expect(find.text('●  Đã tạm dừng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pause and reset controls invoke their callbacks', (
    tester,
  ) async {
    var pauseCalls = 0;
    var resetCalls = 0;
    await tester.pumpWidget(
      screen(
        paused: true,
        pause: () => pauseCalls++,
        reset: () => resetCalls++,
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Tiếp tục đo'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Tiếp tục đo'));
    await tester.tap(find.text('Đo lại'));
    expect(pauseCalls, 1);
    expect(resetCalls, 1);
  });

  testWidgets('flat samples paint safely on narrow screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      screen(
        scale: 1.4,
        current: 1013.3,
        readings: [
          PressureSample(start, 1013.3),
          PressureSample(start.add(const Duration(seconds: 10)), 1013.3),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'one sample with identical timestamps paints without division by zero',
    (tester) async {
      await tester.pumpWidget(
        screen(readings: [PressureSample(start, 1013.3)], current: 1013.3),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
