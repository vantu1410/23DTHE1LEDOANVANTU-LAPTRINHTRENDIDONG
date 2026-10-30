import 'dart:math' as math;

import 'package:flutter/material.dart';

class PressureSample {
  const PressureSample(this.time, this.value);
  final DateTime time;
  final double value;
}

class PressureDashboard extends StatelessWidget {
  const PressureDashboard({
    super.key,
    required this.readings,
    required this.current,
    required this.unavailable,
    required this.paused,
    required this.onPauseToggle,
    required this.onReset,
    this.statistics,
  });

  final List<PressureSample> readings;
  final double? current;
  final bool unavailable;
  final bool paused;
  final VoidCallback onPauseToggle;
  final VoidCallback onReset;
  final Map<String, dynamic>? statistics;

  static const _gold = Color(0xFFD2AE68);
  static const _green = Color(0xFF52C49A);
  static const _text = Color(0xFFF2F4F7);
  static const _muted = Color(0xFFA0A9B6);
  static const _surface = Color(0xFF171C24);
  static const _border = Color(0xFF2B333F);

  String _clock(DateTime time) {
    final t = time.toLocal();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final samples =
        readings.where((r) => r.value.isFinite && r.value > 0).toList()
          ..sort((a, b) => a.time.compareTo(b.time));
    final value = current != null && current!.isFinite && current! > 0
        ? current
        : null;
    final min =
        (statistics?['minimum'] as num?)?.toDouble() ??
        (samples.isEmpty ? null : samples.map((r) => r.value).reduce(math.min));
    final max =
        (statistics?['maximum'] as num?)?.toDouble() ??
        (samples.isEmpty ? null : samples.map((r) => r.value).reduce(math.max));
    final average =
        (statistics?['average'] as num?)?.toDouble() ??
        (samples.isEmpty
            ? null
            : samples.fold<double>(0, (sum, r) => sum + r.value) /
                  samples.length);
    final change = samples.length < 2
        ? null
        : samples.last.value - samples.first.value;
    final status = unavailable
        ? 'Chưa có cảm biến'
        : paused
        ? 'Đã tạm dừng'
        : value == null
        ? 'Đang kết nối'
        : 'Đang đo trực tiếp';
    final statusColor = unavailable
        ? _gold
        : paused
        ? _muted
        : _green;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        const Text(
          'MÔI TRƯỜNG LÀM VIỆC',
          style: TextStyle(
            color: _gold,
            fontSize: 11,
            letterSpacing: 1.7,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Theo dõi khí áp',
          style: TextStyle(
            color: _text,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Quan sát số đo và biến động theo thời gian.',
          style: TextStyle(color: _muted, height: 1.5),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _gold.withValues(alpha: .3)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF343023), Color(0xFF18232B)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.speed_rounded, color: _gold, size: 26),
                  const Text(
                    'Áp suất hiện tại',
                    style: TextStyle(color: _text, fontWeight: FontWeight.w700),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '●  $status',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Semantics(
                label: value == null
                    ? 'Chưa có số đo'
                    : 'Áp suất hiện tại ${value.toStringAsFixed(1)} hPa',
                child: ExcludeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            value?.toStringAsFixed(1) ?? '—',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 54,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                              letterSpacing: -1.5,
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 8, bottom: 5),
                        child: Text(
                          'hPa',
                          style: TextStyle(
                            color: _gold,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                samples.isEmpty
                    ? 'Đang chờ mẫu đầu tiên'
                    : 'Mẫu gần nhất · ${_clock(samples.last.time)}',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 18),
              Container(height: 1, color: Colors.white.withValues(alpha: .1)),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    change == null || change.abs() < .1
                        ? Icons.trending_flat
                        : change > 0
                        ? Icons.trending_up
                        : Icons.trending_down,
                    color: _gold,
                    size: 23,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      change == null
                          ? 'Cần thêm mẫu để theo dõi xu hướng'
                          : '${change.abs() < .1
                                ? 'Ít thay đổi'
                                : change > 0
                                ? 'Tăng'
                                : 'Giảm'} · ${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} hPa so với mẫu đầu',
                      style: const TextStyle(
                        color: _text,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Diễn biến áp suất',
                style: TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Tối đa 5 phút · ${samples.length} mẫu',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              if (samples.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 35),
                  child: Center(
                    child: Text(
                      unavailable
                          ? 'Chưa nhận được dữ liệu cảm biến.'
                          : paused
                          ? 'Tiếp tục đo để thu thập dữ liệu.'
                          : 'Biểu đồ sẽ xuất hiện khi có số đo.',
                      style: const TextStyle(color: _muted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else ...[
                SizedBox(
                  height: 145,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 45,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            FittedBox(
                              child: Text(
                                max!.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const Text(
                              'hPa',
                              style: TextStyle(color: _muted, fontSize: 10),
                            ),
                            FittedBox(
                              child: Text(
                                min!.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Semantics(
                          label:
                              'Biểu đồ từ ${_clock(samples.first.time)} đến ${_clock(samples.last.time)}',
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: _PressurePainter(samples, min, max, _gold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _clock(samples.first.time),
                          style: const TextStyle(color: _muted, fontSize: 10),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _clock(samples.last.time),
                          textAlign: TextAlign.end,
                          style: const TextStyle(color: _muted, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final metrics = [
              _metric(Icons.south_west, 'Thấp nhất', min, 'pressure-min'),
              _metric(Icons.north_east, 'Cao nhất', max, 'pressure-max'),
              _metric(
                Icons.equalizer,
                'Trung bình',
                average,
                'pressure-average',
              ),
            ];
            if (box.maxWidth < 300) {
              return Column(
                children: metrics
                    .map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: m,
                      ),
                    )
                    .toList(),
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < metrics.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: metrics[i]),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: onPauseToggle,
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: const Color(0xFF181A1E),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
              ),
              icon: Icon(
                paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              ),
              label: Text(paused ? 'Tiếp tục đo' : 'Tạm dừng'),
            ),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Đo lại'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _card(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.sensors, color: _green, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unavailable
                          ? 'Không nhận được cảm biến khí áp'
                          : 'Nguồn dữ liệu: cảm biến thiết bị',
                      style: const TextStyle(
                        color: _text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      unavailable
                          ? 'Thiết bị có thể không hỗ trợ cảm biến hoặc dữ liệu tạm gián đoạn. Thử đo lại.'
                          : 'Trên giả lập, số đo đến từ cảm biến mô phỏng. Có thể thay đổi tại Virtual sensors → Pressure.',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _border),
    ),
    child: child,
  );

  Widget _metric(IconData icon, String title, double? value, String key) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: _gold),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: _muted, fontSize: 11)),
            const SizedBox(height: 6),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value?.toStringAsFixed(1) ?? '—',
                key: ValueKey(key),
                style: const TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            const Text('hPa', style: TextStyle(color: _muted, fontSize: 10)),
          ],
        ),
      );
}

class _PressurePainter extends CustomPainter {
  _PressurePainter(this.samples, this.minimum, this.maximum, this.color);
  final List<PressureSample> samples;
  final double minimum;
  final double maximum;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || samples.isEmpty) return;
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .07)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = 8 + (size.height - 16) * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final range = maximum - minimum;
    final start = samples.first.time.microsecondsSinceEpoch;
    final span = samples.last.time.microsecondsSinceEpoch - start;
    final points = samples
        .map(
          (r) => Offset(
            span <= 0
                ? size.width / 2
                : 4 +
                      (size.width - 8) *
                          (r.time.microsecondsSinceEpoch - start) /
                          span,
            range < .0001
                ? size.height / 2
                : 8 + (size.height - 16) * (maximum - r.value) / range,
          ),
        )
        .toList();
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    if (points.length > 1) {
      final fill = Path.from(path)
        ..lineTo(points.last.dx, size.height)
        ..lineTo(points.first.dx, size.height)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: .25),
              color.withValues(alpha: .01),
            ],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.drawCircle(
      points.last,
      6,
      Paint()..color = color.withValues(alpha: .18),
    );
    canvas.drawCircle(points.last, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PressurePainter oldDelegate) => true;
}
