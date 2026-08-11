import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';

/// Liquidní hlasový orb inspirovaný Siri / Google Assistant.
///
/// Jeden widget, který nahrazuje předchozí kombinaci AnimatedContainer orbu
/// a WaveformVisualizer. Plynule reaguje na volume stream, mění tvar
/// (organický blob) i barvu podle aktuálního stavu tutora.
///
/// Technika:
/// - [CustomPainter] kreslí blob pomocí kubických Bézierových křivek
/// - 6 kontrolních bodů na kružnici, každý s jinou fázovou sinusoidou
/// - Amplituda deformace = hlasitost ze streamu
/// - Vnější glow (MaskFilter) se škáluje s hlasitostí
/// - Barva se mění přes [ColorTween] animovaný [AnimationController]em
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
  /// Hlavní ticker pro kontinuální animaci (fáze vlny + idle dýchání)
  late AnimationController _waveController;

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
    )..repeat(reverse: true); // reverse=true: hladký přechod 0→1→0, žádný skok

    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _colorTween = ColorTween(begin: widget.color, end: widget.color);
    _colorAnimation = _colorTween.animate(
      CurvedAnimation(parent: _colorController, curve: Curves.easeInOut),
    );
  }

  /// Vrátí délku cyklu vlnění dle stavu.
  /// Aktivní stavy jsou rychlejší, klidné stavy pomalejší.
  Duration _durationForState(String state) {
    switch (state) {
      case 'listening':
        return const Duration(milliseconds: 2200);
      case 'speaking':
        return const Duration(milliseconds: 1800);
      case 'thinking':
        return const Duration(milliseconds: 2800);
      case 'connecting':
      case 'reconnecting':
        return const Duration(milliseconds: 1500);
      case 'paused':
        return const Duration(seconds: 5); // velmi pomalé dýchání
      default: // idle, error
        return const Duration(seconds: 4);
    }
  }

  @override
  void didUpdateWidget(LiquidVoiceOrb oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Změna rychlosti animace při změně stavu
    if (oldWidget.stateLabel != widget.stateLabel) {
      final newDuration = _durationForState(widget.stateLabel);
      if (_waveController.duration != newDuration) {
        // Plynulé zpomalení/zrychlení bez viditelného skoku
        _waveController.duration = newDuration;
        if (!_waveController.isAnimating) {
          _waveController.repeat(reverse: true);
        }
      }
    }

    // Přechod barvy
    if (oldWidget.color != widget.color) {
      _colorTween = ColorTween(
        begin: _colorAnimation.value ?? oldWidget.color,
        end: widget.color,
      );
      _colorAnimation = _colorTween.animate(
        CurvedAnimation(parent: _colorController, curve: Curves.easeInOut),
      );
      _colorController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
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
          animation: Listenable.merge([_waveController, _colorAnimation]),
          builder: (context, _) {
            final color = _colorAnimation.value ?? widget.color;
            // repeat(reverse:true) → _waveController.value jde 0→1→0 bez skoku
            // Vynásobíme 2π pro sinusoidu
            final phase = _waveController.value * 2 * math.pi;
            final isActive = widget.stateLabel == 'listening' ||
                widget.stateLabel == 'speaking';
            final isPaused = widget.stateLabel == 'paused';

            // Amplituda dle stavu:
            // - active (listening/speaking): plně reaguje na hlasitost
            // - thinking/connecting: mírné vlnění ve smyčce
            // - paused: minimální, едва viditelné dýchání
            // - idle/error: klidné pomalé dýchání
            double voiceAmp;
            if (isActive) {
              voiceAmp = _currentVolume * 0.35 + 0.02;
            } else if (isPaused) {
              voiceAmp = _waveController.value * 0.03 + 0.005; // skoro statický
            } else {
              // idle, thinking, connecting – jemné dýchání
              voiceAmp = _waveController.value * 0.07 + 0.01;
            }

            return SizedBox(
              width: widget.size + 60, // Místo pro glow
              height: widget.size + 60,
              child: CustomPaint(
                painter: _LiquidBlobPainter(
                  color: color,
                  phase: phase,
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

class _LiquidBlobPainter extends CustomPainter {
  final Color color;
  final double phase;
  final double amplitude;
  final double radius;
  final String stateLabel;

  _LiquidBlobPainter({
    required this.color,
    required this.phase,
    required this.amplitude,
    required this.radius,
    required this.stateLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // ── Počet kontrolních bodů blobu ──────────────────────────────────────────
    const pointCount = 8;
    final angleStep = (2 * math.pi) / pointCount;

    // Různé fázové offsety pro každý bod → organický, nepravidelný tvar
    final phaseOffsets = List.generate(
      pointCount,
      (i) => (i * 0.7 + i * i * 0.13) % (2 * math.pi),
    );

    // Frekvenční multiplikátory pro vlnění
    final freqMultipliers = [1.0, 1.3, 0.8, 1.5, 1.1, 0.9, 1.4, 1.2];

    // Výpočet pozic bodů blobu
    List<Offset> points = [];
    for (int i = 0; i < pointCount; i++) {
      final baseAngle = i * angleStep;
      final wave = math.sin(phase * freqMultipliers[i] + phaseOffsets[i]);
      final r = radius * (1.0 + amplitude * wave);
      points.add(Offset(
        center.dx + r * math.cos(baseAngle),
        center.dy + r * math.sin(baseAngle),
      ));
    }

    // ── Vykreslení vnějšího glow (vrstvy) ────────────────────────────────────
    final glowRadius = radius * (1.0 + amplitude * 1.5);

    // Glow vrstva 3 – nejrozptýlenější
    final glowPaint3 = Paint()
      ..color = color.withValues(alpha: 0.04 + amplitude * 0.06)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 0.9);
    canvas.drawCircle(center, glowRadius * 1.5, glowPaint3);

    // Glow vrstva 2
    final glowPaint2 = Paint()
      ..color = color.withValues(alpha: 0.08 + amplitude * 0.12)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 0.5);
    canvas.drawCircle(center, glowRadius * 1.2, glowPaint2);

    // Glow vrstva 1 – nejbližší
    final glowPaint1 = Paint()
      ..color = color.withValues(alpha: 0.15 + amplitude * 0.2)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 0.25);
    canvas.drawCircle(center, glowRadius * 1.05, glowPaint1);

    // ── Vykreslení samotného blobu (Bézierovy křivky) ─────────────────────────
    final path = _buildBlobPath(points, pointCount);

    // Gradient výplň – centrum světlejší, okraj tmavší pro 3D efekt
    final gradientPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4), // Světlo zleva nahoře
        radius: 1.0,
        colors: [
          Color.lerp(color, Colors.white, 0.35)!,
          color,
          Color.lerp(color, Colors.black, 0.25)!,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.2));

    canvas.drawPath(path, gradientPaint);

    // Jemný highlight nahoře vlevo pro plastický dojem
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(
      Offset(center.dx - radius * 0.25, center.dy - radius * 0.3),
      radius * 0.3,
      highlightPaint,
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

      // Kontrolní body pro plynulé přechody (Catmull-Rom → kubické Bézier)
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
  bool shouldRepaint(covariant _LiquidBlobPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.color != color;
  }
}

/// Pomocný widget: ikona stavu zobrazená přes orb
class OrbStateIcon extends StatelessWidget {
  final String stateLabel;
  final Color color;

  const OrbStateIcon({
    super.key,
    required this.stateLabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (stateLabel) {
      case 'listening':
        icon = Icons.hearing_rounded;
        break;
      case 'thinking':
        icon = Icons.more_horiz_rounded;
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

    return Icon(icon, size: 36, color: AppTheme.onPrimary);
  }
}
