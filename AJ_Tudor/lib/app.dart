import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/conversation/conversation_screen.dart';
import 'features/progress/progress_screen.dart';
import 'features/history/history_screen.dart';
import 'features/settings/settings_screen.dart';

class AjTudorApp extends StatefulWidget {
  const AjTudorApp({super.key});

  @override
  State<AjTudorApp> createState() => _AjTudorAppState();
}

class _AjTudorAppState extends State<AjTudorApp> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ConversationScreen(),
    ProgressScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AJ Tudor',
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'Konverzace'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Pokrok'),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historie'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Nastavení'),
          ],
        ),
      ),
    );
  }
}
