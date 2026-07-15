import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/agents/voice_tutor_agent.dart';
import 'widgets/waveform_visualizer.dart';

class VoiceTutorScreen extends ConsumerStatefulWidget {
  const VoiceTutorScreen({super.key});

  @override
  ConsumerState<VoiceTutorScreen> createState() => _VoiceTutorScreenState();
}

class _VoiceTutorScreenState extends ConsumerState<VoiceTutorScreen> with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _textController.dispose();
    _pulseController.dispose();
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
          // Horní lišta s Ambient Orbem / Waveform a stavem
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                if (tutorState.status == TutorState.listening)
                  WaveformVisualizer(
                    isActive: true,
                    color: _getOrbColor(tutorState.status),
                  )
                else
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final pulse = (tutorState.status == TutorState.speaking)
                          ? _pulseController.value * 15
                          : 0.0;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: _getOrbSize(tutorState.status),
                        height: _getOrbSize(tutorState.status),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getOrbColor(tutorState.status),
                          boxShadow: [
                            BoxShadow(
                              color: _getOrbColor(tutorState.status).withValues(alpha: 0.4),
                              blurRadius: 20 + pulse,
                              spreadRadius: 5 + pulse / 2,
                            )
                          ],
                        ),
                        child: Icon(
                          _getOrbIcon(tutorState.status),
                          size: 32,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
                Text(
                  _getStatusText(tutorState.status),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
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
              itemCount: _getVisibleItemCount(tutorState),
              itemBuilder: (context, index) {
                final visibleMessages = _getVisibleMessages(tutorState);

                // Pokud máme transkripci a jsme na konci listu
                if (index == visibleMessages.length) {
                  return _buildLiveTranscript(tutorState.currentTranscript);
                }

                final msg = visibleMessages[index];

                // Výpočet opacity pro efekt slábnutí starších zpráv
                // Poslední prvek (index length-1) má opacity 1.0, starší klesají
                final totalItems = visibleMessages.length + (tutorState.currentTranscript.isNotEmpty ? 1 : 0);
                final relativeIndex = index + (totalItems - visibleMessages.length);
                final opacity = (relativeIndex + 1) / totalItems;

                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: opacity.clamp(0.2, 1.0),
                  child: _buildMessageBubble(msg),
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
        return 140.0;
      case TutorState.thinking:
        return 120.0;
      case TutorState.speaking:
        return 160.0;
      case TutorState.idle:
      case TutorState.connecting:
      case TutorState.reconnecting:
      case TutorState.error:
        return 120.0;
    }
  }

  Color _getOrbColor(TutorState status) {
    switch (status) {
      case TutorState.connecting:
      case TutorState.reconnecting:
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
      case TutorState.reconnecting:
        return Icons.wifi;
      case TutorState.idle:
        return Icons.mic_off;
    }
  }

  String _getStatusText(TutorState status) {
    switch (status) {
      case TutorState.connecting:
        return 'Připojování...';
      case TutorState.reconnecting:
        return 'Obnovování spojení...';
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

  // Pomocné metody pro dynamické UI zpráv

  List<LiveChatMessage> _getVisibleMessages(VoiceTutorState state) {
    if (state.messages.length <= 5) return state.messages;
    return state.messages.sublist(state.messages.length - 5);
  }

  int _getVisibleItemCount(VoiceTutorState state) {
    final msgCount = state.messages.length > 5 ? 5 : state.messages.length;
    return msgCount + (state.currentTranscript.isNotEmpty ? 1 : 0);
  }

  Widget _buildLiveTranscript(String transcript) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: Colors.deepPurpleAccent.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurpleAccent),
                ),
                SizedBox(width: 8),
                Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurpleAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$transcript...',
              style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(LiveChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(12.0),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: msg.isUser
              ? Colors.cyanAccent.withValues(alpha: 0.15)
              : Colors.deepPurple.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: msg.isUser
                ? Colors.cyanAccent.withValues(alpha: 0.2)
                : Colors.deepPurpleAccent.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            fontSize: 16,
            color: msg.isUser ? Colors.cyan[50] : Colors.deepPurple[50],
          ),
        ),
      ),
    );
  }
}
