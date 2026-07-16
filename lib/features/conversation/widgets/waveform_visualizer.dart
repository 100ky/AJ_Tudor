import 'dart:math' as math;
import 'package:flutter/material.dart';

class WaveformVisualizer extends StatelessWidget {
  final Color color;
  final bool isActive;
  final Stream<double> volumeStream;
  
  const WaveformVisualizer({
    super.key, 
    required this.volumeStream,
    this.color = Colors.blueAccent,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: volumeStream,
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
      final multiplier = 1.0 - math.pow(distanceFromCenter, 2); // Parabolištější tvar
      
      // Přidáme trochu šumu pro živost, ale vázaného na hlasitost
      final noise = 0.6 + random.nextDouble() * 0.8;
      
      // Základní výška i při tichu, aby sféra pulzovala
      final minHeight = isActive ? 6.0 : 0.0;
      final height = (volume * maxBarHeight * multiplier * noise).clamp(minHeight, maxBarHeight);
      
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
