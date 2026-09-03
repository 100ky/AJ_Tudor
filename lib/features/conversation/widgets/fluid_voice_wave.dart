import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// Siri / Gemini Fluid Voice Wave – prémiová vícevrstvá světelná zvuková vlna.
///
/// Vlastnosti:
/// - 4 navzájem se prolínající harmonické vrstvy (ambientní glow + hlavní a doplňkové křivky)
/// - Hann okenní funkce (hladké utlumení do ztracena na obou okrajích)
/// - Reaktivní amplituda na reálnou hlasitost (volumeStream) s plynulým vyhlazováním
/// - Speciální putující světelný impulz (sweep) pro stav 'thinking'
/// - Plynulá interpolace barev a rychlostí při změně stavu tutora
class FluidVoiceWave extends StatefulWidget {
  /// Stream hlasitosti (0.0 – 1.0) z mikrofonu nebo syntézy řeči
  final Stream<double>? volumeStream;

  /// Cílová barva vlny podle stavu tutora
  final Color color;

  /// Popis stavu (idle, listening, thinking, speaking, connecting, paused, error)
  final String stateLabel;

  /// Výška widgetu v logických pixelech
  final double height;

  /// Zda je vlna v kompaktním režimu (horní pruh) nebo hero režimu
  final bool isCompact;

  /// Zda vykreslit i ambientní podsvícení (glow)
  final bool showAmbientGlow;

  const FluidVoiceWave({
    super.key,
    this.volumeStream,
    required this.color,
    this.stateLabel = 'idle',
    this.height = 54,
    this.isCompact = false,
    this.showAmbientGlow = true,
  });

  @override
  State<FluidVoiceWave> createState() => _FluidVoiceWaveState();
}

class _FluidVoiceWaveState extends State<FluidVoiceWave>
    with TickerProviderStateMixin {
  /// Hlavní ticker pro kontinuální pohyb vln
  late AnimationController _phaseController;

  /// Ticker pro putující světelný sweep (pro stav thinking)
  late AnimationController _pulseController;

  /// Ticker pro plynulý přechod barev
  late AnimationController _colorController;
  late ColorTween _colorTween;
  late Animation<Color?> _colorAnimation;

  /// Vyhlazená hodnota hlasitosti pro prevenci skoků
  double _smoothVolume = 0.0;
  double _targetVolume = 0.0;

  @override
  void initState() {
    super.initState();

    _phaseController = AnimationController(
      vsync: this,
      duration: _speedForState(widget.stateLabel),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _colorTween = ColorTween(begin: widget.color, end: widget.color);
    _colorAnimation = _colorTween.animate(
      CurvedAnimation(parent: _colorController, curve: Curves.easeInOutCubic),
    );
  }

  /// Rychlost pohybu vln podle stavu
  Duration _speedForState(String state) {
    switch (state) {
      case 'listening':
        return const Duration(milliseconds: 1700);
      case 'speaking':
        return const Duration(milliseconds: 1300);
      case 'thinking':
        return const Duration(milliseconds: 2200);
      case 'connecting':
      case 'reconnecting':
        return const Duration(milliseconds: 1200);
      case 'paused':
        return const Duration(seconds: 5);
      default: // idle, error
        return const Duration(seconds: 4);
    }
  }

  @override
  void didUpdateWidget(FluidVoiceWave oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.stateLabel != widget.stateLabel) {
      final newDuration = _speedForState(widget.stateLabel);
      if (_phaseController.duration != newDuration) {
        _phaseController.duration = newDuration;
        if (!_phaseController.isAnimating) {
          _phaseController.repeat();
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
    _phaseController.dispose();
    _pulseController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: widget.volumeStream,
      initialData: 0.0,
      builder: (context, snapshot) {
        _targetVolume = (snapshot.data ?? 0.0).clamp(0.0, 1.0);

        return AnimatedBuilder(
          animation: Listenable.merge([
            _phaseController,
            _pulseController,
            _colorAnimation,
          ]),
          builder: (context, _) {
            // Jemné vyhlazení hlasitosti (lerp)
            _smoothVolume =
                lerpDouble(_smoothVolume, _targetVolume, 0.22) ?? 0.0;

            final activeColor = _colorAnimation.value ?? widget.color;
            final phase = _phaseController.value * 2 * math.pi;
            final pulseProgress = _pulseController.value;

            return SizedBox(
              height: widget.height,
              width: double.infinity,
              child: CustomPaint(
                painter: _FluidWavePainter(
                  color: activeColor,
                  stateLabel: widget.stateLabel,
                  phase: phase,
                  pulseProgress: pulseProgress,
                  volume: _smoothVolume,
                  isCompact: widget.isCompact,
                  showAmbientGlow: widget.showAmbientGlow,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// CustomPainter vykreslující vícevrstvé křivky světelné vlny
class _FluidWavePainter extends CustomPainter {
  final Color color;
  final String stateLabel;
  final double phase;
  final double pulseProgress;
  final double volume;
  final bool isCompact;
  final bool showAmbientGlow;

  _FluidWavePainter({
    required this.color,
    required this.stateLabel,
    required this.phase,
    required this.pulseProgress,
    required this.volume,
    required this.isCompact,
    required this.showAmbientGlow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final width = size.width;
    final height = size.height;
    final midY = height / 2;

    // Základní parametry dle režimu a stavu
    final isThinking = stateLabel == 'thinking';
    final isListening = stateLabel == 'listening';
    final isSpeaking = stateLabel == 'speaking';
    final isIdle = stateLabel == 'idle' || stateLabel == 'error';

    // Výška kmitu (amplituda)
    final double baseAmp = isCompact
        ? (isIdle ? 3.0 : 6.0)
        : (isIdle ? 6.0 : 12.0);

    final double maxBoost = isCompact ? 16.0 : 36.0;
    final double amp1 =
        (baseAmp + (volume * maxBoost)).clamp(2.0, height * 0.45);
    final double amp2 = amp1 * 0.72;
    final double amp3 = amp1 * 0.45;

    // 1. Ambientní difuzní záře (Glow aura)
    if (showAmbientGlow) {
      final glowPaint = Paint()
        ..color = color.withValues(
            alpha: isCompact ? 0.12 : 0.18 + (volume * 0.15))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isCompact ? 12 : 24);

      final glowRect = Rect.fromCenter(
        center: Offset(width / 2, midY),
        width: width * 0.85,
        height: height * 0.65,
      );
      canvas.drawOval(glowRect, glowPaint);
    }

    // Horizontální gradient pro plynulé zanoření křivek na krajích do ztracena
    final Shader waveShader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.35),
        color.withValues(alpha: 0.95),
        color.withValues(alpha: 1.0),
        color.withValues(alpha: 0.95),
        color.withValues(alpha: 0.35),
        color.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.12, 0.35, 0.5, 0.65, 0.88, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, width, height));

    // Speciální světelný sweep pro stav 'thinking'
    Shader activeShader = waveShader;
    if (isThinking) {
      final sweepCenter = pulseProgress;
      activeShader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          color.withValues(alpha: 0.1),
          color.withValues(alpha: 0.2),
          Colors.white,
          color.withValues(alpha: 0.9),
          color.withValues(alpha: 0.1),
        ],
        stops: [
          (sweepCenter - 0.25).clamp(0.0, 1.0),
          (sweepCenter - 0.10).clamp(0.0, 1.0),
          sweepCenter.clamp(0.0, 1.0),
          (sweepCenter + 0.10).clamp(0.0, 1.0),
          (sweepCenter + 0.25).clamp(0.0, 1.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));
    }

    // 2. Křivka 3: Terciární jemná vlna (vysokofrekvenční harmonie)
    _drawSineWave(
      canvas: canvas,
      width: width,
      midY: midY,
      amplitude: amp3,
      frequency: isSpeaking ? 3.4 : 2.6,
      phaseOffset: phase * 1.5 + 2.0,
      strokeWidth: isCompact ? 1.0 : 1.4,
      opacity: 0.35,
      shader: activeShader,
      blur: 1.5,
    );

    // 3. Křivka 2: Sekundární harmonická vlna (protisměrná)
    _drawSineWave(
      canvas: canvas,
      width: width,
      midY: midY,
      amplitude: amp2,
      frequency: isListening ? 2.2 : 2.8,
      phaseOffset: -phase * 0.85 + 1.2,
      strokeWidth: isCompact ? 1.5 : 2.0,
      opacity: 0.60,
      shader: activeShader,
      blur: 2.0,
    );

    // 4. Křivka 1: Primární rezonanční vlna (nejjasnější, hlavní nosná)
    _drawSineWave(
      canvas: canvas,
      width: width,
      midY: midY,
      amplitude: amp1,
      frequency: isSpeaking ? 2.0 : 1.8,
      phaseOffset: phase,
      strokeWidth: isCompact ? 2.4 : 3.2,
      opacity: 1.0,
      shader: activeShader,
      blur: isCompact ? 1.2 : 2.0,
      drawCoreHighlight: true,
    );

    // 5. Pokud je aktivní stav 'thinking', vykreslíme zářivý světelný bod (světlušku / energii)
    if (isThinking) {
      final pulseX = pulseProgress * width;
      final t = pulseProgress;
      // Hann envelope pro Y pozici bodu
      final window = math.sin(math.pi * t);
      final pulseY =
          midY + amp1 * window * math.sin(2 * math.pi * 1.8 * t + phase);

      final particlePaint = Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(
          Offset(pulseX, pulseY), isCompact ? 2.5 : 3.5, particlePaint);

      final particleAura = Paint()
        ..color = color.withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(
          Offset(pulseX, pulseY), isCompact ? 6.0 : 9.0, particleAura);
    }
  }

  /// Vykreslí plynulou sinusovku s Hann oknem
  void _drawSineWave({
    required Canvas canvas,
    required double width,
    required double midY,
    required double amplitude,
    required double frequency,
    required double phaseOffset,
    required double strokeWidth,
    required double opacity,
    required Shader shader,
    double blur = 0.0,
    bool drawCoreHighlight = false,
  }) {
    final path = Path();
    const int stepCount = 80; // Jemný krok pro křivku bez zubatosti
    final double step = width / stepCount;

    for (int i = 0; i <= stepCount; i++) {
      final x = i * step;
      final t = x / width; // Normalizovaný čas [0.0, 1.0]

      // Hann okenní funkce pro dokonalé zanoření do středu na okrajích
      final double window = math.pow(math.sin(math.pi * t), 1.6).toDouble();

      // Složená sinusovka se sekundární vibrací pro organický vzhled
      final double y = midY +
          amplitude *
              window *
              (math.sin(2 * math.pi * frequency * t + phaseOffset) +
                  0.18 * math.sin(4 * math.pi * frequency * t - phaseOffset));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Glow průchod (rozostření)
    if (blur > 0) {
      final glowPaint = Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

      canvas.drawPath(path, glowPaint);
    }

    // Ostrý nosný průchod
    final mainPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, mainPaint);

    // Vnitřní zářivý střed (bílé jádro pro pocit laseru / neonu)
    if (drawCoreHighlight && amplitude > 4.0) {
      final coreShader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.7),
          Colors.white,
          Colors.white.withValues(alpha: 0.7),
          Colors.transparent,
        ],
        stops: const [0.15, 0.4, 0.5, 0.6, 0.85],
      ).createShader(Rect.fromLTWH(0, 0, width, midY * 2));

      final corePaint = Paint()
        ..shader = coreShader
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.4
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FluidWavePainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.pulseProgress != pulseProgress ||
        oldDelegate.volume != volume ||
        oldDelegate.color != color ||
        oldDelegate.stateLabel != stateLabel ||
        oldDelegate.isCompact != isCompact;
  }
}

/// Stavová ikona pro hlasový modul
class WaveStateIcon extends StatelessWidget {
  final String stateLabel;
  final Color color;
  final double size;

  const WaveStateIcon({
    super.key,
    required this.stateLabel,
    required this.color,
    this.size = 20,
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
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Icon(icon, size: size, color: color),
    );
  }
}

