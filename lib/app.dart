import 'package:flutter/material.dart';
import 'features/skeleton/skeleton_screen.dart';

class AjTudorApp extends StatelessWidget {
  const AjTudorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AJ Tudor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SkeletonScreen(),
    );
  }
}
