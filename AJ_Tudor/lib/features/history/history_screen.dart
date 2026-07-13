import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historie konverzací')),
      body: const Center(
        child: Text('Seznam proběhlých konverzací'),
      ),
    );
  }
}
