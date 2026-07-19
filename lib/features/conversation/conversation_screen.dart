import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/gemini_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/agents/voice_tutor_agent.dart';
import '../../services/agents/scenario_planner_agent.dart';
import '../../services/prompt/system_prompt_builder.dart';
import '../../data/database/app_database.dart';
import '../../data/models/chat_message.dart';

/// Obrazovka pro textovou konverzaci s AI a výběr scénářů.
/// 
/// Umožňuje uživateli psát si s Gemini (Batch režim) a vybírat si
/// personalizované scénáře pro následný hlasový trénink.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isGrammarDrill = false;

  /// Přepne režim chatu na gramatický drill nebo běžný rozhovor.
  void _toggleGrammarDrill(bool value) {
    setState(() {
      _isGrammarDrill = value;
      _messages.clear();
      if (_isGrammarDrill) {
        _messages.add(ChatMessage(
          'Ahoj! Vítej v gramatickém drilu. Podívám se na tvé minulé chyby a připravím pro tebe překladová cvičení. Napiš cokoliv (např. "start" nebo "začít") pro spuštění!',
          isUser: false,
        ));
      }
    });
  }

  /// Odešle textovou zprávu do Gemini a přidá odpověď do seznamu.
  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final client = ref.read(geminiBatchClientProvider);
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chybí API klíč! Nastavte ho v Settings.')),
      );
      return;
    }

    setState(() {
      _messages.add(ChatMessage(text, isUser: true));
      _isLoading = true;
      _textController.clear();
    });

    String? systemPrompt;
    if (_isGrammarDrill) {
      final profile = ref.read(userProfileProvider).value;
      if (profile != null) {
        systemPrompt = SystemPromptBuilder.buildGrammarDrillPrompt(
          recurringErrors: profile.recurringErrors,
          targetLevel: profile.targetLevel,
          vocabulary: profile.vocabulary,
        );
      }
    }

    // Volání asynchronní metody pro získání odpovědi od AI
    final response = await client.sendMessage(text, systemPrompt: systemPrompt);

    setState(() {
      _messages.add(ChatMessage(response, isUser: false));
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(sessionRepositoryProvider);
    
    // Posloucháme změny modelu – pokud se změní model, vymažeme historii (kontext se mění)
    ref.listen(modelProvider, (previous, next) {
      if (previous != next) {
        setState(() {
          _messages.clear();
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('AJ Tudor'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Volba režimu (Segmented Button)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.chat_bubble_outline),
                        label: Text('Běžný rozhovor'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.psychology_alt_outlined),
                        label: Text('Gramatický dril'),
                      ),
                    ],
                    selected: {_isGrammarDrill},
                    onSelectionChanged: (newSelection) {
                      _toggleGrammarDrill(newSelection.first);
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Sekce Doporučené Scénáře (Scenario Planner) - zobrazíme jen v běžném rozhovoru
          if (!_isGrammarDrill)
            StreamBuilder<List<Scenario>>(
            stream: repo.watchAvailableScenarios(),
            builder: (context, snapshot) {
              final scenarios = snapshot.data ?? [];
              
              // Pokud nejsou dostupné žádné scénáře, nabídneme jejich vygenerování
              if (scenarios.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: OutlinedButton.icon(
                    onPressed: () => ref.read(scenarioPlannerAgentProvider).planScenarios(),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Vygenerovat scénáře na míru'),
                  ),
                );
              }
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Doporučené scénáře na míru:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                  ),
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: scenarios.length,
                      itemBuilder: (context, index) {
                        final s = scenarios[index];
                        return _buildScenarioCard(s);
                      },
                    ),
                  ),
                  const Divider(),
                ],
              );
            },
          ),
          
          // Seznam zpráv v chatu
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: msg.isUser ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.grey[800],
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Text(msg.text, style: const TextStyle(fontSize: 16)),
                  ),
                );
              },
            ),
          ),
          
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
            
          // Vstupní pole pro text
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Napiš anglicky (nebo česky)...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sestaví kartu s náhledem scénáře.
  Widget _buildScenarioCard(Scenario s) {
    return Container(
      width: 200,
      margin: const EdgeInsets.all(4),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () {
            // Výběr scénáře a přepnutí instrukcí pro Voice Tutor agenta
            ref.read(voiceTutorAgentProvider.notifier).selectScenario(s.id, s.tutorInstruction);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Scénář "${s.title}" vybrán. Přepněte na Voice.'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.blueAccent,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        s.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildDifficultyBadge(s.difficulty),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    s.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pomocný widget pro zobrazení obtížnosti scénáře.
  Widget _buildDifficultyBadge(String difficulty) {
    Color color;
    switch (difficulty.toLowerCase()) {
      case 'easy': color = Colors.green; break;
      case 'medium': color = Colors.orange; break;
      case 'hard': color = Colors.red; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        difficulty.toUpperCase(),
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }
}
