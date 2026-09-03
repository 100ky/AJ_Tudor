import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/database_provider.dart';
import '../../providers/gemini_provider.dart';
import '../../data/repositories/session_repository.dart';
import '../gemini/gemini_batch_client.dart';
import '../../core/utils/logger.dart';
import '../prompt/system_prompt_builder.dart';

/// Reprezentuje připravené téma pro hlasovou konverzaci.
class PreparedTopic {
  final String title;
  final String openerEn;
  final String rationale;
  final DateTime preparedAt;

  PreparedTopic({
    required this.title,
    required this.openerEn,
    required this.rationale,
    required this.preparedAt,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'openerEn': openerEn,
        'rationale': rationale,
        'preparedAt': preparedAt.toIso8601String(),
      };

  factory PreparedTopic.fromJson(Map<String, dynamic> json) => PreparedTopic(
        title: json['title'] ?? '',
        openerEn: json['openerEn'] ?? '',
        rationale: json['rationale'] ?? '',
        preparedAt: json['preparedAt'] != null
            ? DateTime.tryParse(json['preparedAt']) ?? DateTime.now()
            : DateTime.now(),
      );
}

/// Stav agenta pro přípravu témat.
class TopicPreparationState {
  final bool isLoading;
  final PreparedTopic? topic;
  final String? errorMessage;

  const TopicPreparationState({
    this.isLoading = false,
    this.topic,
    this.errorMessage,
  });

  TopicPreparationState copyWith({
    bool? isLoading,
    PreparedTopic? topic,
    String? errorMessage,
  }) {
    return TopicPreparationState(
      isLoading: isLoading ?? this.isLoading,
      topic: topic ?? this.topic,
      errorMessage: errorMessage,
    );
  }
}

/// Agent, který se probouzí po startu aplikace nebo po ukončení hovoru,
/// analyzuje historii minulých konverzací a profil studenta ("O mně")
/// a připravuje svěží konverzační téma s úvodním háčkem pro Voice Tutora.
class TopicPreparationAgent extends Notifier<TopicPreparationState> {
  @override
  TopicPreparationState build() {
    // Asynchronní načtení již uloženého tématu z databáze při inicializaci
    Future.microtask(() async {
      try {
        final repo = ref.read(sessionRepositoryProvider);
        final user = await repo.getUserProfile();
        if (user?.preparedTopic != null && user!.preparedTopic!.isNotEmpty) {
          final data = jsonDecode(user.preparedTopic!);
          state = state.copyWith(topic: PreparedTopic.fromJson(data));
        }
      } catch (e) {
        L.w('Chyba při načítání uloženého připraveného tématu: $e');
      }
    });

    return const TopicPreparationState();
  }

  /// Připraví nové téma pro příští hlasovou lekci.
  ///
  /// Pokud [force] je false a téma již existuje a je novější než 12 hodin,
  /// ponechá stávající téma bez zbytečného volání Gemini.
  Future<void> prepareTopic({bool force = false}) async {
    if (state.isLoading) return;

    final repo = ref.read(sessionRepositoryProvider);
    final gemini = ref.read(geminiBatchClientProvider);

    if (gemini == null) {
      L.i('TopicPreparationAgent: Chybí API klíč, přeskočeno.');
      return;
    }

    // Pokud nevynucujeme obnovu, zkontrolujeme existenci a čerstvost tématu
    if (!force && state.topic != null) {
      final age = DateTime.now().difference(state.topic!.preparedAt);
      if (age.inHours < 12) {
        L.i('TopicPreparationAgent: Téma "${state.topic!.title}" je čerstvé (${age.inHours}h staré), nepřeplánovávám.');
        return;
      }
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    L.i('TopicPreparationAgent: Začínám připravovat nové konverzační téma z historie...');

    try {
      var profile = await repo.getUserProfile();

      // Pokud je sekce "O mně" dosud prázdná, projdeme zpětně historii všech dosavadních promluv
      // studenta a automaticky z nich vytáhneme fakta (mazlíčci, koníčky, profese), o kterých už mluvil.
      if (profile?.userFacts == null ||
          profile!.userFacts.isEmpty ||
          profile.userFacts == '[]') {
        await _bootstrapUserFactsIfEmpty(repo, gemini);
        profile = await repo.getUserProfile();
      }

      final sessions = await repo.watchAllSessions().first;

      // Získání transkriptů z posledních rozhovorů, aby agent věděl, co se skutečně říkalo
      final recentTranscripts = await repo.getRecentTranscripts(sessionLimit: 3);
      final recentTranscriptsSnippet = recentTranscripts.isNotEmpty
          ? recentTranscripts
              .take(40)
              .map((t) =>
                  '${t.speaker == 'user' ? 'Student' : 'Tudor'}: ${t.content}')
              .join('\n')
          : '';

      // Získání shrnutí posledních témat z historie
      final recentSummaries = sessions
          .take(5)
          .map((s) => s.topicSummary)
          .where((s) => s != null && s.isNotEmpty && s != 'Bez popisu')
          .cast<String>()
          .join('; ');

      final prompt = SystemPromptBuilder.buildTopicPreparationPrompt(
        targetLevel: profile?.targetLevel ?? 'B1',
        userFacts: profile?.userFacts,
        recentTopics: recentSummaries.isNotEmpty
            ? recentSummaries
            : profile?.topicPreferences,
        recentTranscriptsSnippet: recentTranscriptsSnippet,
        memoryBriefing: profile?.memoryBriefing,
      );

      final result = await gemini.sendMessage(
        'Navrhni 1 smysluplné, přirozené konverzační téma a úvodní háček, které logicky navazuje na historii a profil studenta.',
        systemPrompt: prompt,
        responseSchema: SystemPromptBuilder.getTopicPreparationResponseSchema(),
      );

      final data = jsonDecode(result);
      final prepared = PreparedTopic(
        title: data['topicTitle']?.toString() ?? 'Zajímavosti ze života',
        openerEn: data['openerEn']?.toString() ??
            "Hello! I was thinking earlier about travel and weekend getaways. Do you like exploring new places?",
        rationale: data['rationale']?.toString() ?? '',
        preparedAt: DateTime.now(),
      );

      await repo.savePreparedTopic(jsonEncode(prepared.toJson()));
      state = state.copyWith(isLoading: false, topic: prepared);
      L.i('TopicPreparationAgent: Nové téma připraveno: "${prepared.title}" (důvod: ${prepared.rationale})');
    } catch (e, stack) {
      L.e('Chyba při přípravě konverzačního tématu', e, stack);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Nepodařilo se připravit téma: $e',
      );
    }
  }

  /// Zpětně projde zprávy studenta ze všech dosavadních konverzací
  /// a jednorázově naplní paměť "O mně" (mazlíčci, koníčky, profese),
  /// aby se Tudor nemusel ptát na to, co už student dříve zmínil.
  Future<void> _bootstrapUserFactsIfEmpty(
      SessionRepository repo, GeminiBatchClient gemini) async {
    try {
      final userTranscripts = await repo.getAllUserTranscripts(limit: 60);
      if (userTranscripts.isEmpty) return;

      L.i('TopicPreparationAgent: Nalezeno ${userTranscripts.length} starších zpráv studenta. Extrahuji fakta pro "O mně"...');
      final historyText =
          userTranscripts.reversed.map((t) => t.content).join('\n');
      if (historyText.trim().isEmpty) return;

      final prompt =
          SystemPromptBuilder.buildFactExtractionFromHistoryPrompt();
      final response = await gemini.sendMessage(
        'Zde jsou autentické zprávy studenta z předchozích rozhovorů:\n\n$historyText',
        systemPrompt: prompt,
        responseSchema: SystemPromptBuilder.getFactExtractionSchema(),
      );

      final data = jsonDecode(response);
      if (data['facts'] != null && data['facts'] is List) {
        final List<String> extracted = (data['facts'] as List)
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        if (extracted.isNotEmpty) {
          await repo.updateUserFacts(extracted);
          L.i('TopicPreparationAgent: Úspěšně zpětně extrahováno ${extracted.length} faktů do "O mně": $extracted');
        }
      }
    } catch (e) {
      L.w('TopicPreparationAgent: Zpětná extrakce faktů z historie byla přeskočena: $e');
    }
  }

  /// Označí téma za spotřebované / vymaže ho (např. po proběhlé lekci).
  Future<void> consumeTopic() async {
    final repo = ref.read(sessionRepositoryProvider);
    await repo.clearPreparedTopic();
    state = state.copyWith(topic: null);
  }
}

/// Globální provider pro [TopicPreparationAgent].
final topicPreparationAgentProvider =
    NotifierProvider<TopicPreparationAgent, TopicPreparationState>(
  TopicPreparationAgent.new,
);

