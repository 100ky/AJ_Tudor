import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/skeleton/skeleton_screen.dart';
import 'providers/notification_provider.dart';

/// Kořenový widget aplikace AJ Tudor.
/// 
/// Nastavuje globální téma (Material 3, tmavý režim) a základní navigaci.
class AjTudorApp extends ConsumerWidget {
  const AjTudorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sledování provideru pro synchronizaci notifikací (běží na pozadí aplikace)
    ref.watch(notificationSyncProvider);

    return MaterialApp(
      title: 'AJ Tudor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark, // Aplikace je primárně v tmavém režimu
        ),
        useMaterial3: true,
      ),
      // Výchozí obrazovka aplikace s navigací
      home: const SkeletonScreen(),
    );
  }
}
