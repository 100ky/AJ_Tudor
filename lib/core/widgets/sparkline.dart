import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Malý spojnicový graf vývoje: čára s výplní, zvýrazněný poslední bod
/// a čárkovaná čára srovnávací hodnoty ([reference], např. průměr lekcí předtím).
class Sparkline extends StatelessWidget {
  /// Hodnoty od nejstarší po nejnovější.
  final List<double> values;

  /// Srovnávací hodnota, kreslí se čárkovaně; null = bez čáry.
  final double? reference;

  /// Barva čáry a výplně.
  final Color color;

  final double width;
  final double height;

  /// Popis grafu pro čtečku obrazovky.
  final String semanticsLabel;

  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    required this.semanticsLabel,
    this.reference,
    this.width = 128,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      image: true,
      child: CustomPaint(
        size: Size(width, height),
        painter: _SparklinePainter(values: values, reference: reference, color: color),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final double? reference;
  final Color color;

  _SparklinePainter({required this.values, required this.reference, required this.color});

  static const double _pad = 6;
  static const double _sidePad = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = Paint()
      ..color = AppTheme.hairline
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height - 0.5), Offset(size.width, size.height - 0.5), baseline);
    if (values.isEmpty) return;

    final all = [...values, ?reference];
    var lo = all.reduce((a, b) => a < b ? a : b);
    var hi = all.reduce((a, b) => a > b ? a : b);
    if (hi - lo < 1e-9) {
      lo -= 1;
      hi += 1;
    }
    double y(double v) => _pad + (1 - (v - lo) / (hi - lo)) * (size.height - 2 * _pad);
    double x(int i) => values.length == 1
        ? size.width - _sidePad
        : _sidePad + i * (size.width - 2 * _sidePad) / (values.length - 1);

    if (reference != null) {
      final dash = Paint()
        ..color = AppTheme.textTertiary
        ..strokeWidth = 1;
      final ry = y(reference!);
      for (double dx = 0; dx < size.width; dx += 6) {
        canvas.drawLine(Offset(dx, ry), Offset((dx + 3).clamp(0, size.width), ry), dash);
      }
    }

    final points = [for (var i = 0; i < values.length; i++) Offset(x(i), y(values[i]))];
    if (points.length > 1) {
      final line = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        line.lineTo(p.dx, p.dy);
      }
      final area = Path.from(line)
        ..lineTo(points.last.dx, size.height - 1)
        ..lineTo(points.first.dx, size.height - 1)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.24), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Poslední bod s lemem v barvě povrchu
    canvas.drawCircle(points.last, 5.5, Paint()..color = AppTheme.surface);
    canvas.drawCircle(points.last, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.color != color || old.reference != reference || !_same(old.values, values);

  static bool _same(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
