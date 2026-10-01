import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../data/data_providers.dart';
import '../../../data/repositories/profile_repository.dart';
import 'prepared_topic_card.dart';
import 'profile_summary_card.dart';
import 'settings_common.dart';
import 'user_facts_list.dart';

/// Profil studenta: paměť tutora, připravené téma a fakta „O mně“.
class ProfileMemorySection extends ConsumerWidget {
  const ProfileMemorySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return GlassContainer(
            child: Text('Zatím neproběhla žádná lekce.',
                style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.mutedTextColor(context))),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileSummaryCard(profile: profile),
            const SizedBox(height: 16),

            // ── Karta: Připravené téma do hlasu ─────────────────────────
            const SectionLabel('Připravené téma do hlasu'),
            const PreparedTopicCard(),
            const SizedBox(height: 16),

            // ── Fakta o mně ─────────────────────────────────────────────
            UserFactsList(facts: profile.userFactsList),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Chyba načítání profilu: $e'),
    );
  }
}
