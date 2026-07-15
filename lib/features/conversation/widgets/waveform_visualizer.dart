import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/audio_provider.dart';

class WaveformVisualizer extends ConsumerWidget {
  final Color color;
  final bool isActive;
  
  const WaveformVisualizer({
    super.key, 
    this.color = Colors.blueAccent,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioCapture = ref.watch(audioCaptureServiceProvider);
    
    return StreamBuilder<double>(
      stream: audioCapture.volumeStream,
      initialData: 0.0,
      builder: (context, snapshot) {
        final volume = isActive ? (snapshot.data ?? 0.0) : 0.0;
        
        return Container(
          height: 100,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: CustomPaint(
            painter: _WavePainter(
              volume: volume, 
              color: color,
              isActive: isActive,
            ),
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double volume;
  final Color color;
  final bool isActive;
  
  _WavePainter({
    required this.volume, 
    required this.color,
    required this.isActive,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
      
    final center = size.height / 2;
    final maxBarHeight = size.height;
    
    const barCount = 40;
    final spacing = 4.0;
    final barWidth = (size.width - (barCount - 1) * spacing) / barCount;
    
    final random = math.Random(42); // Fixní seed pro stabilitu rozložení

    for (int i = 0; i < barCount; i++) {
      // Vytvoříme organický vzhled vln
      // Výška je kombinací hlasitosti a pozice (střed vyšší)
      final distanceFromCenter = (i - barCount / 2).abs() / (barCount / 2);
      final multiplier = 1.0 - distanceFromCenter * 0.7;
      
      // Přidáme trochu šumu pro živost
      final noise = 0.8 + random.nextDouble() * 0.4;
      
      final height = (volume * maxBarHeight * multiplier * noise).clamp(4.0, maxBarHeight);
      
      final x = i * (barWidth + spacing);
      
      canvas.drawRRect(
        RRect.fromLTRBR(
          x, 
          center - height / 2, 
          x + barWidth, 
          center + height / 2, 
          Radius.circular(barWidth / 2)
        ),
        paint
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.volume != volume || oldDelegate.isActive != isActive;
  }
}
