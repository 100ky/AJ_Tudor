import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'providers/config_provider.dart';
import 'services/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await initializeDateFormatting('cs', null);
  await NotificationService.init();
  
  final prefs = await SharedPreferences.getInstance();
  
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const AjTudorApp(),
    ),
  );
}
