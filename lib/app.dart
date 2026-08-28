import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_theme.dart';
import 'features/skeleton/skeleton_screen.dart';
import 'providers/notification_provider.dart';

/// Kořenový widget aplikace AJ Tudor.
///
/// Nastavuje globální téma dle centrálního [AppTheme] design systému
/// a základní navigaci.
class AjTudorApp extends ConsumerWidget {
  const AjTudorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sledování provideru pro synchronizaci notifikací (běží na pozadí aplikace)
    ref.watch(notificationSyncProvider);

    return MaterialApp(
      title: 'AJ Tudor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Výchozí obrazovka aplikace s navigací
      home: const SkeletonScreen(),
    );
  }
}
