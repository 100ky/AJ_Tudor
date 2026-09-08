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
  final bool isRandomTopic;

  PreparedTopic({
    required this.title,
    required this.openerEn,
    required this.rationale,
    required this.preparedAt,
    this.isRandomTopic = false,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'openerEn': openerEn,
        'rationale': rationale,
        'preparedAt': preparedAt.toIso8601String(),
        'isRandomTopic': isRandomTopic,
      };

  factory PreparedTopic.fromJson(Map<String, dynamic> json) => PreparedTopic(
        title: json['title'] ?? '',
        openerEn: json['openerEn'] ?? '',
        rationale: json['rationale'] ?? '',
        preparedAt: json['preparedAt'] != null
            ? DateTime.tryParse(json['preparedAt']) ?? DateTime.now()
            : DateTime.now(),
        isRandomTopic: json['isRandomTopic'] as bool? ?? false,
      );
}

/// Stav agenta pro přípravu témat.
class TopicPreparationState {
  final bool isLoading;
  final PreparedTopic? topic;
  final String? errorMessage;
  final int refreshCount;

  const TopicPreparationState({
    this.isLoading = false,
    this.topic,
    this.errorMessage,
    this.refreshCount = 0,
  });

  TopicPreparationState copyWith({
    bool? isLoading,
    PreparedTopic? topic,
    String? errorMessage,
    int? refreshCount,
  }) {
    return TopicPreparationState(
      isLoading: isLoading ?? this.isLoading,
      topic: topic ?? this.topic,
      errorMessage: errorMessage,
      refreshCount: refreshCount ?? this.refreshCount,
    );
  }
}

/// Agent, který se probouzí po startu aplikace nebo po ukončení hovoru,
/// analyzuje historii minulých konverzací a profil studenta ("O mně")
/// a připravuje svěží konverzační téma s úvodním háčkem pro Voice Tutora.
class TopicPreparationAgent extends Notifier<TopicPreparationState> {
  final List<String> _recentlyProposedTitles = [];
  int _refreshCounter = 0;

  int get refreshCount => _refreshCounter;

  void resetRefreshCounter() {
    _refreshCounter = 0;
  }

  @override
  TopicPreparationState build() {
    // Asynchronní načtení již uloženého tématu z databáze při inicializaci
    Future.microtask(() async {
      try {
        final repo = ref.read(sessionRepositoryProvider);
        final user = await repo.getUserProfile();
        if (user?.preparedTopic != null && user!.preparedTopic!.isNotEmpty) {
          final data = jsonDecode(user.preparedTopic!);
          final loadedTopic = PreparedTopic.fromJson(data);
          if (loadedTopic.title.isNotEmpty && !_recentlyProposedTitles.contains(loadedTopic.title)) {
            _recentlyProposedTitles.add(loadedTopic.title);
          }
          state = state.copyWith(topic: loadedTopic);
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
  ///
  /// Pokud [force] je true, inkrementuje počítadlo obnovení témat.
  /// Na každé 3. obnovení (3., 6., 9...) nebo pokud [isRandomTopic] je true,
  /// vygeneruje ZCELA NÁHODNÉ téma (divokou kartu) nepocházející z historie ani profilu studenta.
  Future<void> prepareTopic({
    bool force = false,
    bool resetCounter = false,
    bool? isRandomTopic,
  }) async {
    if (state.isLoading) return;

    if (resetCounter) {
      _refreshCounter = 0;
    }

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

    if (force) {
      _refreshCounter++;
    }

    final bool generateRandom = isRandomTopic ?? (_refreshCounter > 0 && _refreshCounter % 3 == 0);

    state = state.copyWith(isLoading: true, errorMessage: null);
    L.i('TopicPreparationAgent: Začínám připravovat nové konverzační téma (obnovení #$_refreshCounter, náhodné téma: $generateRandom)...');

    try {
      final profile = await repo.getUserProfile();

      // Shromáždíme témata k vynechání (stávající téma i nedávno navržená témata)
      final currentTitle = state.topic?.title;
      final avoidTopics = <String>{
        ..._recentlyProposedTitles,
        if (currentTitle != null && currentTitle.isNotEmpty) currentTitle,
      }.toList();

      if (generateRandom) {
        // Generování ZCELA NÁHODNÉHO tématu (Divoká karta) mimo historii i fakta studenta
        final prompt = SystemPromptBuilder.buildRandomTopicPreparationPrompt(
          targetLevel: profile?.targetLevel ?? 'B1',
          avoidTopics: avoidTopics,
        );

        final userMessage = avoidTopics.isNotEmpty
            ? 'Vygeneruj 1 ZCELA NÁHODNÉ, originální a zábavné konverzační téma (divokou kartu) a úvodní háček. ZCELA IGNORUJ historii a osobní fakta studenta. POUZE se vyhni těmto nedávno navrženým tématům: ${avoidTopics.map((t) => '"$t"').join(', ')}.'
            : 'Vygeneruj 1 ZCELA NÁHODNÉ, originální a zábavné konverzační téma (divokou kartu) a úvodní háček. ZCELA IGNORUJ historii a osobní fakta studenta.';

        final result = await gemini.sendMessage(
          userMessage,
          systemPrompt: prompt,
          responseSchema: SystemPromptBuilder.getTopicPreparationResponseSchema(),
          temperature: 0.95,
        );

        final data = jsonDecode(result);
        final prepared = PreparedTopic(
          title: data['topicTitle']?.toString() ?? 'Zajímavá dilemata',
          openerEn: data['openerEn']?.toString() ??
              "Hey! If you could have any superpower for just one day, which one would you choose and why?",
          rationale: data['rationale']?.toString() ??
              'Divoká karta (náhodné téma na přání): odlehčená konverzace mimo dosavadní historii.',
          preparedAt: DateTime.now(),
          isRandomTopic: true,
        );

        _recentlyProposedTitles.add(prepared.title);
        if (_recentlyProposedTitles.length > 8) {
          _recentlyProposedTitles.removeAt(0);
        }

        await repo.savePreparedTopic(jsonEncode(prepared.toJson()));
        state = state.copyWith(
          isLoading: false,
          topic: prepared,
          refreshCount: _refreshCounter,
        );
        L.i('TopicPreparationAgent: Nové NÁHODNÉ téma připraveno (#$_refreshCounter): "${prepared.title}" (důvod: ${prepared.rationale})');
        return;
      }

      // Standardní příprava tématu navazujícího na historii a profil studenta
      var currentProfile = profile;
      if (currentProfile?.userFacts == null ||
          currentProfile!.userFacts.isEmpty ||
          currentProfile.userFacts == '[]') {
        await _bootstrapUserFactsIfEmpty(repo, gemini);
        currentProfile = await repo.getUserProfile();
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
        targetLevel: currentProfile?.targetLevel ?? 'B1',
        userFacts: currentProfile?.userFacts,
        recentTopics: recentSummaries.isNotEmpty
            ? recentSummaries
            : currentProfile?.topicPreferences,
        recentTranscriptsSnippet: recentTranscriptsSnippet,
        memoryBriefing: currentProfile?.memoryBriefing,
        avoidTopics: avoidTopics,
      );

      final userMessage = avoidTopics.isNotEmpty
          ? 'Navrhni 1 nové, svěží konverzační téma a úvodní háček ze života studenta. ZCELA SE VYHNI dříve navrženým tématům: ${avoidTopics.map((t) => '"$t"').join(', ')}.'
          : 'Navrhni 1 smysluplné, přirozené konverzační téma a úvodní háček, které logicky navazuje na historii a profil studenta.';

      final result = await gemini.sendMessage(
        userMessage,
        systemPrompt: prompt,
        responseSchema: SystemPromptBuilder.getTopicPreparationResponseSchema(),
        temperature: 0.85,
      );

      final data = jsonDecode(result);
      final prepared = PreparedTopic(
        title: data['topicTitle']?.toString() ?? 'Zajímavosti ze života',
        openerEn: data['openerEn']?.toString() ??
            "Hello! I was thinking earlier about travel and weekend getaways. Do you like exploring new places?",
        rationale: data['rationale']?.toString() ?? '',
        preparedAt: DateTime.now(),
        isRandomTopic: false,
      );

      _recentlyProposedTitles.add(prepared.title);
      if (_recentlyProposedTitles.length > 8) {
        _recentlyProposedTitles.removeAt(0);
      }

      await repo.savePreparedTopic(jsonEncode(prepared.toJson()));
      state = state.copyWith(
        isLoading: false,
        topic: prepared,
        refreshCount: _refreshCounter,
      );
      L.i('TopicPreparationAgent: Nové téma připraveno: "${prepared.title}" (důvod: ${prepared.rationale})');
    } catch (e, stack) {
      L.e('Chyba při přípravě konverzačního tématu', e, stack);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Nepodařilo se připravit téma: $e',
        refreshCount: _refreshCounter,
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

