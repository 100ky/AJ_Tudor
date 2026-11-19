import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/app_theme.dart';
import '../../../../services/agents/topic_preparation_agent.dart';

/// Podrobnosti „Téma z historie“: téma připravené agentem z minulých rozhovorů.
class HistoryTopicTab extends ConsumerWidget {
  const HistoryTopicTab({super.key});

  void _prepareNewTopic(WidgetRef ref, {bool isRandomTopic = false}) {
    HapticFeedback.lightImpact();
    ref
        .read(topicPreparationAgentProvider.notifier)
        .prepareTopic(force: true, isRandomTopic: isRandomTopic);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicState = ref.watch(topicPreparationAgentProvider);
    final topic = topicState.topic;
    final muted = AppTheme.font(fontSize: 14, color: AppTheme.textSecondary, height: 1.45);

    // Dosavadní téma zůstane vidět i během přípravy nového: hovor ho použije, dokud
    // nové nedorazí (při přetížených modelech příprava trvala skoro minutu)
    if (topicState.isLoading && topic == null) {
      return Row(
        key: const ValueKey('topic_loading'),
        children: [
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Text('Příprava tématu z historie...', style: muted),
        ],
      );
    }

    if (topic == null) {
      return Column(
        key: const ValueKey('topic_empty'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Zatím nemáš připravené téma.', style: muted),
          TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => _prepareNewTopic(ref),
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Připravit téma z historie'),
          ),
        ],
      );
    }

    return Column(
      key: const ValueKey('history_topic_card'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (topic.isRandomTopic)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text('Náhodné téma', style: AppTheme.font(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
          ),
        Text(
          topic.title,
          style: AppTheme.font(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, letterSpacing: -0.2),
        ),
        const SizedBox(height: 6),
        Text('„${topic.openerEn}“', style: muted.copyWith(fontStyle: FontStyle.italic)),
        if (topic.targetWordsCz.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Kartičky v tématu: ${topic.targetWordsCz.join(', ')}',
            style: AppTheme.font(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.primary,
            ),
          ),
        ],
        const SizedBox(height: 2),
        if (topicState.isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8)),
                const SizedBox(width: 10),
                Text('Připravuji nové…', style: AppTheme.font(fontSize: 14, color: AppTheme.textSecondary)),
              ],
            ),
          )
        else
          Wrap(
            spacing: 12,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => _prepareNewTopic(ref),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Jiné téma'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => _prepareNewTopic(ref, isRandomTopic: true),
                icon: const Icon(Icons.casino_outlined, size: 18),
                label: const Text('Náhodné téma'),
              ),
            ],
          ),
      ],
    );
  }
}
