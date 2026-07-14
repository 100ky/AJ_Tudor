import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/agents/voice_tutor_agent.dart';

class VoiceTutorScreen extends ConsumerWidget {
  const VoiceTutorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tutorState = ref.watch(voiceTutorAgentProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AJ Tudor - Hlasový mód'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ambient Orb placeholder
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _getOrbSize(tutorState.status),
              height: _getOrbSize(tutorState.status),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getOrbColor(tutorState.status),
                boxShadow: [
                  BoxShadow(
                    color: _getOrbColor(tutorState.status).withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 10,
                  )
                ],
              ),
              child: Icon(
                _getOrbIcon(tutorState.status),
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              _getStatusText(tutorState.status),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (tutorState.errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  tutorState.errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            if (tutorState.currentTranscript.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  tutorState.currentTranscript,
                  style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final notifier = ref.read(voiceTutorAgentProvider.notifier);
          if (tutorState.status == TutorState.idle || tutorState.status == TutorState.error) {
            notifier.startSession();
          } else {
            notifier.stopSession();
          }
        },
        backgroundColor: tutorState.status == TutorState.idle || tutorState.status == TutorState.error
            ? Colors.blueAccent
            : Colors.redAccent,
        child: Icon(
          tutorState.status == TutorState.idle || tutorState.status == TutorState.error
              ? Icons.mic
              : Icons.stop,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  double _getOrbSize(TutorState status) {
    switch (status) {
      case TutorState.listening:
        return 120.0;
      case TutorState.thinking:
        return 100.0;
      case TutorState.speaking:
        return 140.0;
      case TutorState.idle:
      case TutorState.connecting:
      case TutorState.error:
        return 100.0;
    }
  }

  Color _getOrbColor(TutorState status) {
    switch (status) {
      case TutorState.connecting:
        return Colors.orangeAccent;
      case TutorState.listening:
        return Colors.greenAccent;
      case TutorState.thinking:
        return Colors.blueAccent;
      case TutorState.speaking:
        return Colors.purpleAccent;
      case TutorState.error:
        return Colors.redAccent;
      case TutorState.idle:
        return Colors.grey;
    }
  }

  IconData _getOrbIcon(TutorState status) {
    switch (status) {
      case TutorState.listening:
        return Icons.hearing;
      case TutorState.thinking:
        return Icons.more_horiz;
      case TutorState.speaking:
        return Icons.volume_up;
      case TutorState.error:
        return Icons.error_outline;
      case TutorState.connecting:
        return Icons.wifi;
      case TutorState.idle:
        return Icons.mic_off;
    }
  }

  String _getStatusText(TutorState status) {
    switch (status) {
      case TutorState.connecting:
        return 'Připojování...';
      case TutorState.listening:
        return 'Tutor poslouchá...';
      case TutorState.thinking:
        return 'Tutor přemýšlí...';
      case TutorState.speaking:
        return 'Tutor mluví...';
      case TutorState.error:
        return 'Chyba spojení';
      case TutorState.idle:
        return 'Připraven. Stiskni mikrofon.';
    }
  }
}
