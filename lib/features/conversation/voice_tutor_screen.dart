import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/agents/voice_tutor_agent.dart';

class VoiceTutorScreen extends ConsumerStatefulWidget {
  const VoiceTutorScreen({super.key});

  @override
  ConsumerState<VoiceTutorScreen> createState() => _VoiceTutorScreenState();
}

class _VoiceTutorScreenState extends ConsumerState<VoiceTutorScreen> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tutorState = ref.watch(voiceTutorAgentProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AJ Tudor - Hlasový mód'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Horní lišta s Ambient Orbem a stavem
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: Colors.black12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _getOrbSize(tutorState.status) * 0.6, // Zmenšený orb
                  height: _getOrbSize(tutorState.status) * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getOrbColor(tutorState.status),
                    boxShadow: [
                      BoxShadow(
                        color: _getOrbColor(tutorState.status).withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: Icon(
                    _getOrbIcon(tutorState.status),
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _getStatusText(tutorState.status),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          if (tutorState.errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                tutorState.errorMessage,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
            
          // Historie konverzace
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: tutorState.messages.length + (tutorState.currentTranscript.isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == tutorState.messages.length) {
                  // Probíhající transkripce
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[800]?.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Text(
                        '${tutorState.currentTranscript} ...',
                        style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                      ),
                    ),
                  );
                }
                
                final msg = tutorState.messages[index];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: msg.isUser ? Colors.blueAccent.withOpacity(0.2) : Colors.grey[800],
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Text(msg.text, style: const TextStyle(fontSize: 16)),
                  ),
                );
              },
            ),
          ),

          // Spodní lišta - pouze obrovské tlačítko mikrofonu (čistě hlasový mód)
          Padding(
            padding: const EdgeInsets.only(bottom: 32.0, top: 16.0),
            child: SizedBox(
              width: 80,
              height: 80,
              child: FloatingActionButton(
                heroTag: 'mic_btn',
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
                  size: 36,
                ),
              ),
            ),
          ),
        ],
      ),
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
