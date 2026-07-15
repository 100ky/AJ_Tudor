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
  final _scrollController = ScrollController();
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
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tutorState = ref.watch(voiceTutorAgentProvider);
    
    // Automatický scroll při změně zpráv nebo transkriptu
    ref.listen(voiceTutorAgentProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length || 
          previous?.currentTranscript != next.currentTranscript) {
        _scrollToBottom();
      }
    });

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
                if (tutorState.selectedScenarioId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Chip(
                      label: const Text('Aktivní scénář Role-Play'),
                      backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        ref.read(voiceTutorAgentProvider.notifier).selectScenario(0, '');
                      },
                    ),
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

          // Historie konverzace s efektem mizení (ShaderMask)
          Expanded(
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.white, Colors.white],
                  stops: [0.0, 0.2, 1.0], // Horních 20% plynule mizí
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 16), // Větší top padding pro efekt mizení
                itemCount: _getVisibleItemCount(tutorState),
                itemBuilder: (context, index) {
                  final visibleMessages = _getVisibleMessages(tutorState);

                  // Pokud máme transkripci a jsme na konci listu
                  if (index == visibleMessages.length) {
                    return _buildLiveTranscript(tutorState.currentTranscript);
                  }

                  final msg = visibleMessages[index];

                  // Dynamická opacity podle vzdálenosti od konce
                  final distanceContent = visibleMessages.length - index;
                  final double opacity = (1.0 - (distanceContent * 0.15)).clamp(0.05, 1.0);

                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 500),
                    opacity: opacity,
                    child: _buildMessageBubble(msg),
                  );
                },
              ),
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
    // Zobrazíme celou historii aktuální session, auto-scroll se postará o zbytek
    return state.messages;
  }

  int _getVisibleItemCount(VoiceTutorState state) {
    return state.messages.length + (state.currentTranscript.isNotEmpty ? 1 : 0);
  }

  Widget _buildLiveTranscript(String transcript) {
    if (transcript.isEmpty) return const SizedBox.shrink();

    // Logika pro zobrazení pouze posledních ~3 vět, pokud je transkript dlouhý
    final sentences = transcript.split(RegExp(r'(?<=[.!?])\s+'));
    final displayTranscript = sentences.length > 3 
        ? '... ${sentences.sublist(sentences.length - 3).join(' ')}' 
        : transcript;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(color: Colors.deepPurpleAccent.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurpleAccent.withValues(alpha: 0.05),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurpleAccent),
                ),
                const SizedBox(width: 8),
                Text(
                  'TUTOR IS SPEAKING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.deepPurpleAccent.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              displayTranscript,
              style: const TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.w400,
                color: Colors.white,
                height: 1.4,
              ),
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
