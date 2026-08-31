import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Liquid Quantum Glass Orb 2.0 – prémiový 3D skleněný hlasový orb.
///
/// Vlastnosti:
/// - Vícevrstvé 3D vnitřní plazmové jádro s organickým vlněním (10 kontrolních bodů)
/// - Skleněný Fresnel odlesk a specular highlight simulující tekutou skleněnou kouli
/// - 3-stupňový ambientní difuzní glow reagující na hlasitost v reálném čase
/// - Kvantové rotující částice a prstence pro stav 'thinking'
/// - Plynulá interpolace geometrie i barev mezi všemi 7 stavy tutora
class LiquidVoiceOrb extends StatefulWidget {
  /// Stream hlasitosti (0.0 – 1.0) z mikrofonu nebo přehrávání
  final Stream<double>? volumeStream;

  /// Cílová barva orbu dle aktuálního stavu
  final Color color;

  /// Popis stavu pro optimalizaci animace (idle, listening, thinking, speaking…)
  final String stateLabel;

  /// Průměr orbu v logických pixelech
  final double size;

  const LiquidVoiceOrb({
    super.key,
    this.volumeStream,
    required this.color,
    this.stateLabel = 'idle',
    this.size = 180,
  });

  @override
  State<LiquidVoiceOrb> createState() => _LiquidVoiceOrbState();
}

class _LiquidVoiceOrbState extends State<LiquidVoiceOrb>
    with TickerProviderStateMixin {
  /// Hlavní ticker pro kontinuální vlnění a dýchání
  late AnimationController _waveController;

  /// Ticker pro pomalou rotaci vnitřní energie a kvantových částic
  late AnimationController _spinController;

  /// Ticker pro plynulý přechod barev při změně stavu
  late AnimationController _colorController;
  late ColorTween _colorTween;
  late Animation<Color?> _colorAnimation;

  /// Aktuální hlasitost ze streamu
  double _currentVolume = 0.0;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: _durationForState(widget.stateLabel),
    )..repeat(reverse: true);

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _colorTween = ColorTween(begin: widget.color, end: widget.color);
    _colorAnimation = _colorTween.animate(
      CurvedAnimation(parent: _colorController, curve: Curves.easeInOutCubic),
    );
  }

  /// Vrátí délku cyklu vlnění dle stavu
  Duration _durationForState(String state) {
    switch (state) {
      case 'listening':
        return const Duration(milliseconds: 2000);
      case 'speaking':
        return const Duration(milliseconds: 1600);
      case 'thinking':
        return const Duration(milliseconds: 2400);
      case 'connecting':
      case 'reconnecting':
        return const Duration(milliseconds: 1400);
      case 'paused':
        return const Duration(seconds: 5);
      default: // idle, error
        return const Duration(seconds: 4);
    }
  }

  @override
  void didUpdateWidget(LiquidVoiceOrb oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.stateLabel != widget.stateLabel) {
      final newDuration = _durationForState(widget.stateLabel);
      if (_waveController.duration != newDuration) {
        _waveController.duration = newDuration;
        if (!_waveController.isAnimating) {
          _waveController.repeat(reverse: true);
        }
      }
    }

    if (oldWidget.color != widget.color) {
      _colorTween = ColorTween(
        begin: _colorAnimation.value ?? oldWidget.color,
        end: widget.color,
      );
      _colorAnimation = _colorTween.animate(
        CurvedAnimation(parent: _colorController, curve: Curves.easeInOutCubic),
      );
      _colorController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _spinController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: widget.volumeStream,
      initialData: 0.0,
      builder: (context, snapshot) {
        _currentVolume = (snapshot.data ?? 0.0).clamp(0.0, 1.0);

        return AnimatedBuilder(
          animation: Listenable.merge([
            _waveController,
            _spinController,
            _colorAnimation,
          ]),
          builder: (context, _) {
            final color = _colorAnimation.value ?? widget.color;
            final phase = _waveController.value * 2 * math.pi;
            final spinAngle = _spinController.value * 2 * math.pi;

            final isActive = widget.stateLabel == 'listening' ||
                widget.stateLabel == 'speaking';
            final isThinking = widget.stateLabel == 'thinking';
            final isPaused = widget.stateLabel == 'paused';

            double voiceAmp;
            if (isActive) {
              voiceAmp = _currentVolume * 0.38 + 0.02;
            } else if (isThinking) {
              voiceAmp = _waveController.value * 0.12 + 0.03;
            } else if (isPaused) {
              voiceAmp = _waveController.value * 0.02 + 0.005;
            } else {
              voiceAmp = _waveController.value * 0.06 + 0.01;
            }

            return SizedBox(
              width: widget.size + 80,
              height: widget.size + 80,
              child: CustomPaint(
                painter: _QuantumGlassOrbPainter(
                  color: color,
                  phase: phase,
                  spinAngle: spinAngle,
                  amplitude: voiceAmp,
                  radius: widget.size / 2,
                  stateLabel: widget.stateLabel,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _QuantumGlassOrbPainter extends CustomPainter {
  final Color color;
  final double phase;
  final double spinAngle;
  final double amplitude;
  final double radius;
  final String stateLabel;

  _QuantumGlassOrbPainter({
    required this.color,
    required this.phase,
    required this.spinAngle,
    required this.amplitude,
    required this.radius,
    required this.stateLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // ── 1. Vnější vrstvy Ambient Bloom ─────────────────────────────────────────
    final glowRadius = radius * (1.0 + amplitude * 1.4);

    // Vrstva 3 – ultra rozptýlená aura
    final glowPaint3 = Paint()
      ..color = color.withValues(alpha: 0.06 + amplitude * 0.08)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 0.95);
    canvas.drawCircle(center, glowRadius * 1.6, glowPaint3);

    // Vrstva 2 – saturovaný střední halo
    final glowPaint2 = Paint()
      ..color = color.withValues(alpha: 0.14 + amplitude * 0.16)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 0.55);
    canvas.drawCircle(center, glowRadius * 1.25, glowPaint2);

    // Vrstva 1 – kontaktní světelná koróna
    final glowPaint1 = Paint()
      ..color = color.withValues(alpha: 0.25 + amplitude * 0.22)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 0.25);
    canvas.drawCircle(center, glowRadius * 1.06, glowPaint1);

    // ── 2. Kvantové částice a prstence pro stav THINKING ───────────────────────
    if (stateLabel == 'thinking') {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = SweepGradient(
          colors: [
            Colors.transparent,
            color.withValues(alpha: 0.8),
            Colors.white.withValues(alpha: 0.9),
            color.withValues(alpha: 0.4),
            Colors.transparent,
          ],
          transform: GradientRotation(spinAngle * 2),
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.35));

      canvas.drawCircle(center, radius * 1.35, ringPaint);

      // Kvantové orbitující noduly
      for (int i = 0; i < 3; i++) {
        final nodeAngle = spinAngle * 2 + (i * 2 * math.pi / 3);
        final nodePos = Offset(
          center.dx + (radius * 1.35) * math.cos(nodeAngle),
          center.dy + (radius * 1.35) * math.sin(nodeAngle),
        );
        final nodeGlow = Paint()
          ..color = Colors.white
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(nodePos, 3.5, nodeGlow);
      }
    }

    // ── 3. Vnitřní organické tělo (10 kontrolních bodů) ───────────────────────
    const pointCount = 10;
    final angleStep = (2 * math.pi) / pointCount;

    final phaseOffsets = List.generate(
      pointCount,
      (i) => (i * 0.628 + i * i * 0.11) % (2 * math.pi),
    );
    final freqMultipliers = [1.0, 1.4, 0.9, 1.5, 1.1, 0.8, 1.3, 1.2, 1.6, 1.0];

    List<Offset> outerPoints = [];
    List<Offset> innerPoints = [];

    for (int i = 0; i < pointCount; i++) {
      final baseAngle = i * angleStep;
      final wave = math.sin(phase * freqMultipliers[i] + phaseOffsets[i]);
      final rOuter = radius * (1.0 + amplitude * wave);
      final rInner = radius * 0.82 * (1.0 + (amplitude * 0.6) * wave);

      outerPoints.add(Offset(
        center.dx + rOuter * math.cos(baseAngle),
        center.dy + rOuter * math.sin(baseAngle),
      ));

      innerPoints.add(Offset(
        center.dx + rInner * math.cos(baseAngle + spinAngle * 0.15),
        center.dy + rInner * math.sin(baseAngle + spinAngle * 0.15),
      ));
    }

    final outerPath = _buildBlobPath(outerPoints, pointCount);
    final innerPath = _buildBlobPath(innerPoints, pointCount);

    // ── 4. 3D Spherical Radial Shader výplň ──────────────────────────────────
    final outerGradient = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.42), // Světlo zleva shora
        radius: 1.05,
        colors: [
          Color.lerp(color, Colors.white, 0.55)!,
          color,
          Color.lerp(color, const Color(0xFF0F0B1E), 0.55)!,
        ],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.2));

    canvas.drawPath(outerPath, outerGradient);

    // ── 5. Vnitřní plazmová hloubka (druhý vír) ──────────────────────────────
    final innerGradient = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          -0.2 + math.cos(spinAngle) * 0.15,
          -0.3 + math.sin(spinAngle) * 0.15,
        ),
        radius: 0.9,
        colors: [
          Colors.white.withValues(alpha: 0.45),
          color.withValues(alpha: 0.25),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.9));

    canvas.drawPath(innerPath, innerGradient);

    // ── 6. Fresnel Rim & Skleněný odlesk (Liquid Glass Specular) ─────────────
    // Jemný vnitřní zrcadlový okraj
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.75),
          Colors.white.withValues(alpha: 0.15),
          Colors.transparent,
          color.withValues(alpha: 0.3),
        ],
        stops: const [0.0, 0.4, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawPath(outerPath, rimPaint);

    // Primární skleněný specular highlight (světelný bod zleva nahoře)
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(
      Offset(center.dx - radius * 0.32, center.dy - radius * 0.38),
      radius * 0.26,
      highlightPaint,
    );

    // Sekundární menší ostrý bod
    final sharpHighlight = Paint()..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawCircle(
      Offset(center.dx - radius * 0.34, center.dy - radius * 0.40),
      radius * 0.08,
      sharpHighlight,
    );
  }

  Path _buildBlobPath(List<Offset> points, int count) {
    final path = Path();

    for (int i = 0; i < count; i++) {
      final current = points[i];
      final next = points[(i + 1) % count];
      final prev = points[(i - 1 + count) % count];

      if (i == 0) {
        path.moveTo(current.dx, current.dy);
      }

      final cp1 = Offset(
        current.dx + (next.dx - prev.dx) * 0.2,
        current.dy + (next.dy - prev.dy) * 0.2,
      );

      final nextNext = points[(i + 2) % count];
      final cp2 = Offset(
        next.dx - (nextNext.dx - current.dx) * 0.2,
        next.dy - (nextNext.dy - current.dy) * 0.2,
      );

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, next.dx, next.dy);
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _QuantumGlassOrbPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.spinAngle != spinAngle ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.color != color ||
        oldDelegate.stateLabel != stateLabel;
  }
}

/// Pomocný widget: ikona stavu zobrazená přes orb
class OrbStateIcon extends StatelessWidget {
  final String stateLabel;
  final Color color;
  final double size;

  const OrbStateIcon({
    super.key,
    required this.stateLabel,
    required this.color,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (stateLabel) {
      case 'listening':
        icon = Icons.hearing_rounded;
        break;
      case 'thinking':
        icon = Icons.auto_awesome_rounded;
        break;
      case 'speaking':
        icon = Icons.volume_up_rounded;
        break;
      case 'error':
        icon = Icons.error_outline_rounded;
        break;
      case 'connecting':
      case 'reconnecting':
        icon = Icons.wifi_rounded;
        break;
      case 'paused':
        icon = Icons.pause_circle_outline_rounded;
        break;
      default: // idle
        icon = Icons.mic_none_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}
