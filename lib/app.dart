import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/skeleton/skeleton_screen.dart';
import 'providers/notification_provider.dart';

class AjTudorApp extends ConsumerWidget {
  const AjTudorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Synchronizace notifikací
    ref.watch(notificationSyncProvider);

    return MaterialApp(
      title: 'AJ Tudor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SkeletonScreen(),
    );
  }
}
