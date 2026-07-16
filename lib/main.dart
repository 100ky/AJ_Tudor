import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'providers/config_provider.dart';
import 'services/notifications/notification_service.dart';

/// Vstupní bod do aplikace Flutter.
void main() async {
  // Zajištění inicializace vazeb Flutteru před spuštěním asynchronních operací
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializace české lokalizace pro formátování dat a času
  await initializeDateFormatting('cs', null);
  
  // Spuštění služby pro místní upozornění
  await NotificationService.init();
  
  // Načtení SharedPreferences (lokální úložiště nastavení)
  final prefs = await SharedPreferences.getInstance();
  
  runApp(
    ProviderScope(
      overrides: [
        // Předání instance SharedPreferences do Riverpodu
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const AjTudorApp(),
    ),
  );
}
