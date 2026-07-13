import 'package:flutter/material.dart';

class ConversationScreen extends StatelessWidget {
  const ConversationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AJ Tudor')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Tady bude pulzující sféra a Voice Tutor', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
