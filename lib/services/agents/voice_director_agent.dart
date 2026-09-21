import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/logger.dart';
import '../../data/models/chat_message.dart';
import '../../providers/database_provider.dart';
import '../../providers/gemini_provider.dart';

import '../prompt/system_prompt_builder.dart';

/// Stav konverzačního režiséra na pozadí (Voice Director).
class VoiceDirectorState {
  /// Zda právě probíhá asynchronní analýza na pozadí.
  final bool isAnalyzing;

  /// Krátký vizuální tip / nápověda pro studenta (zobrazuje se v UI).
  final String? currentTip;

  /// Živý akumulovaný souhrn hovoru (Rolling Episodic Summary) pro prevenci amnézie.
  final String rollingSummary;

  /// Fakta o studentovi nově odhalená během aktuálního sezení.
  final List<String> sessionFacts;

  /// Index poslední analyzované zprávy v transkriptu.
  final int lastAnalyzedTurnIndex;

  /// Skóre vitality a hloubky tématu (1–10).
  final int lastHealthScore;

  /// Vytvoří stav Voice Directora.
  const VoiceDirectorState({
    this.isAnalyzing = false,
    this.currentTip,
    this.rollingSummary = '',
    this.sessionFacts = const [],
    this.lastAnalyzedTurnIndex = 0,
    this.lastHealthScore = 10,
  });

  /// Vytvoří kopii stavu s modifikovanými hodnotami.
  VoiceDirectorState copyWith({
    bool? isAnalyzing,
    String? currentTip,
    bool clearTip = false,
    String? rollingSummary,
    List<String>? sessionFacts,
    int? lastAnalyzedTurnIndex,
    int? lastHealthScore,
  }) {
    return VoiceDirectorState(
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      currentTip: clearTip ? null : (currentTip ?? this.currentTip),
      rollingSummary: rollingSummary ?? this.rollingSummary,
      sessionFacts: sessionFacts ?? this.sessionFacts,
      lastAnalyzedTurnIndex: lastAnalyzedTurnIndex ?? this.lastAnalyzedTurnIndex,
      lastHealthScore: lastHealthScore ?? this.lastHealthScore,
    );
  }
}

/// Asynchronní konverzační režisér a pedagogický supervisor (Director).
///
/// Běží na pozadí hlasového hovoru (Dual-Agent architektura).
/// Monitoruje živý transkript každých několik tahů, aniž by blokoval audio smyčku.
/// Našeptává instrukce Voice Tutorovi (`[DIRECTOR WHISPER]`), udržuje akumulovaný
/// kontext hovoru (Rolling Episodic Summary) pro zamezení amnézie při reconnectu
/// a poskytuje volitelné nápovědy pro studenta do UI.
class VoiceDirectorAgent extends Notifier<VoiceDirectorState> {
  DateTime? _lastAnalysisTime;
  Timer? _tipDismissTimer;

  // Minimální odstup mezi analýzami (cooldown pro prevenci spamování API)
  static const Duration _minAnalysisCooldown = Duration(seconds: 40);

  // Počet nových replik studenta potřebných pro spuštění režie
  static const int _minUserTurnsForAnalysis = 3;

  @override
  VoiceDirectorState build() {
    ref.onDispose(() {
      _tipDismissTimer?.cancel();
    });
    return const VoiceDirectorState();
  }

  /// Resetuje stav režiséra pro novou session.
  void reset() {
    _tipDismissTimer?.cancel();
    _lastAnalysisTime = null;
    if (ref.mounted) {
      state = const VoiceDirectorState();
    }
  }

  /// Zavře aktivní nápovědu pro studenta.
  void dismissTip() {
    _tipDismissTimer?.cancel();
    if (ref.mounted && state.currentTip != null) {
      state = state.copyWith(clearTip: true);
    }
  }

  /// Sestaví bohatý přehled dosavadního hovoru pro bezešvý reconnect (při limitu 25k tokenů).
  ///
  /// Zabraňuje amnézii tím, že novému spojení předá nejen posledních pár replik,
  /// ale i živý souhrn a veškerá fakta ustanovená v průběhu uplynulých 15–45 minut.
  String getExecutiveBriefingForReconnect({
    required List<ChatMessage> recentMessages,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('[SESSION CONTEXT RECOVERY - EXECUTIVE LIVING BRIEFING]');
    
    if (state.rollingSummary.isNotEmpty) {
      buffer.writeln('Call Summary So Far: ${state.rollingSummary}');
    }
    
    if (state.sessionFacts.isNotEmpty) {
      buffer.writeln('Established Facts in This Session: ${state.sessionFacts.join("; ")}');
    }

    if (recentMessages.isNotEmpty) {
      final recentSlice = recentMessages.length > 6
          ? recentMessages.sublist(recentMessages.length - 6)
          : recentMessages;
      final recentFormatted = recentSlice
          .map((m) => '${m.isUser ? "Student" : "AJ Tudor"}: ${m.text}')
          .join('\n');
      buffer.writeln('Recent Exchanges:\n$recentFormatted');
    }

    buffer.writeln(
      'CRITICAL INSTRUCTION: Continue conversation seamlessly as AJ Tudor from where we left off. '
      'Do NOT introduce yourself, do NOT ask generic introductory questions. Respect all established context.',
    );

    return buffer.toString();
  }

  /// Volá se po dokončení tahu tutora (`onTurnComplete`).
  ///
  /// Vyhodnotí, zda je vhodný čas pro spuštění asynchronní režijní analýzy,
  /// a v případě potřeby odešle whisper instrukci do živého hovoru.
  Future<void> onTurnCompleted({
    required int sessionId,
    required List<ChatMessage> messages,
    required String targetLevel,
    required String? userFacts,
    required String? recentTopics,
    required void Function(String whisper) onWhisperReady,
  }) async {
    if (state.isAnalyzing) return;

    // Spočítáme počet nových replik studenta od minulé analýzy
    final unanalyzedMessages = messages.sublist(
      state.lastAnalyzedTurnIndex.clamp(0, messages.length),
    );
    final newUserTurns = unanalyzedMessages.where((m) => m.isUser).length;

    if (newUserTurns < _minUserTurnsForAnalysis) {
      L.d('VoiceDirector: Čekám na další tahy studenta ($newUserTurns/$_minUserTurnsForAnalysis replik od minulé režie).');
      return;
    }

    // Kontrola cooldownu (pokud není topicHealth kriticky nízké <= 3)
    final now = DateTime.now();
    if (_lastAnalysisTime != null && state.lastHealthScore > 3) {
      final elapsed = now.difference(_lastAnalysisTime!);
      if (elapsed < _minAnalysisCooldown) {
        L.d('VoiceDirector: Cooldown aktivní (${elapsed.inSeconds}s/${_minAnalysisCooldown.inSeconds}s), přeskakuji.');
        return;
      }
    }

    // Máme dostatek nových dat a cooldown vypršel -> spouštíme asynchronní analýzu
    state = state.copyWith(isAnalyzing: true);
    _lastAnalysisTime = now;

    try {
      final directorClient = ref.read(geminiDirectorClientProvider);
      if (directorClient == null) {
        state = state.copyWith(isAnalyzing: false);
        return;
      }

      // Sestavení textu transkriptu pro analýzu
      // Použijeme posledních max 12 zpráv pro udržení rychlosti a nízké ceny
      final analysisSlice = messages.length > 12
          ? messages.sublist(messages.length - 12)
          : messages;
      final transcriptText = analysisSlice
          .map((m) => '${m.isUser ? "Student" : "AJ Tudor"}: ${m.text}')
          .join('\n');
      final wrappedTranscript = '<transcript>\n$transcriptText\n</transcript>';

      final prompt = SystemPromptBuilder.buildDirectorPrompt(
        targetLevel: targetLevel,
        userFacts: userFacts,
        recentTopics: recentTopics,
        rollingSummary: state.rollingSummary,
      );

      L.director('Spouštím asynchronní analýzu transkriptu přes Gemini 3.8 Flash...');


      final rawResponse = await directorClient.sendMessage(
        wrappedTranscript,
        systemPrompt: prompt,
        responseSchema: SystemPromptBuilder.getDirectorResponseSchema(),
        temperature: 0.4,
      );

      final cleanJson = rawResponse
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
          .trim();

      final data = jsonDecode(cleanJson) as Map<String, dynamic>;

      final topicHealth = (data['topicHealth'] as num?)?.toInt() ?? 8;
      final needsPivot = data['needsPivot'] as bool? ?? false;
      final whisper = data['whisperToTutor']?.toString().trim();
      final tip = data['studentHint']?.toString().trim();
      final newFactsRaw = data['newLearnedFacts'] as List?;
      final newFacts = newFactsRaw
              ?.map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList() ??
          <String>[];
      final incSummary = data['incrementalSummary']?.toString().trim() ?? '';

      // ─── STRUKTUROVANÝ TERMINÁLOVÝ VÝSTUP REŽISÉRA ───
      final directorLog = StringBuffer();
      directorLog.writeln('🔋 Vitalita tématu (Health): $topicHealth/10 | Změna směru (Pivot): ${needsPivot ? "DOPORUČENA" : "není nutná"}');
      if (whisper != null && whisper.isNotEmpty) {
        directorLog.writeln('🤫 Našeptáno tutorovi: "$whisper"');
      }
      if (tip != null && tip.isNotEmpty) {
        directorLog.writeln('💡 Nápověda na displej: "$tip"');
      }
      if (newFacts.isNotEmpty) {
        directorLog.writeln('🧑 Nově odhalená fakta: ${newFacts.join(", ")}');
      }
      if (incSummary.isNotEmpty) {
        directorLog.writeln('📝 Přírůstek do souhrnu: "$incSummary"');
      }
      L.block('DIRECTOR', 'Režijní zásah do konverzace', directorLog.toString());



      // 1. Aktualizace Rolling Summary
      String updatedSummary = state.rollingSummary;
      if (incSummary.isNotEmpty) {
        if (updatedSummary.isEmpty) {
          updatedSummary = incSummary;
        } else {
          updatedSummary = '$updatedSummary; $incSummary';
        }
        // Pokud summary přesáhne cca 600 znaků, zkrátíme starší část pro úspornost
        if (updatedSummary.length > 650) {
          final parts = updatedSummary.split('; ');
          if (parts.length > 3) {
            updatedSummary = parts.sublist(parts.length - 3).join('; ');
          }
        }
      }

      // 2. Uložení nových faktů o studentovi do databáze i do lokálního stavu
      final updatedSessionFacts = List<String>.from(state.sessionFacts);
      if (newFacts.isNotEmpty) {
        final repo = ref.read(sessionRepositoryProvider);
        for (final fact in newFacts) {
          if (!updatedSessionFacts.contains(fact)) {
            updatedSessionFacts.add(fact);
            await repo.addUserFact(fact);
          }
        }
      }

      // 3. Našeptání do živého hlasového hovoru
      if (whisper != null && whisper.isNotEmpty) {
        onWhisperReady(whisper);
      }

      // 4. Zobrazení tipu pro studenta v UI (pokud je smysluplný)
      _tipDismissTimer?.cancel();
      if (tip != null && tip.isNotEmpty) {
        _tipDismissTimer = Timer(const Duration(seconds: 22), () {
          dismissTip();
        });
      }

      if (ref.mounted) {
        state = state.copyWith(
          isAnalyzing: false,
          lastHealthScore: topicHealth,
          lastAnalyzedTurnIndex: messages.length,
          rollingSummary: updatedSummary,
          sessionFacts: updatedSessionFacts,
          currentTip: (tip != null && tip.isNotEmpty) ? tip : null,
          clearTip: tip == null || tip.isEmpty,
        );
      }
    } catch (e) {
      L.w('VoiceDirector: Asynchronní analýza selhala (neovlivňuje hlasový hovor): $e');
      if (ref.mounted) {
        state = state.copyWith(isAnalyzing: false);
      }
    }
  }
}

/// Poskytuje globální instanci [VoiceDirectorAgent] pro správu režie hlasového hovoru.
final voiceDirectorAgentProvider =
    NotifierProvider<VoiceDirectorAgent, VoiceDirectorState>(
  VoiceDirectorAgent.new,
);
