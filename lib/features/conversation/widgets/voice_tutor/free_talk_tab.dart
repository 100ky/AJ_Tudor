import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';

/// Podrobnosti „Volný pokec“: spontánní rozhovor bez scénáře.
class FreeTalkTab extends StatelessWidget {
  const FreeTalkTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Žádný scénář ani předem dané téma. Přirozený rozhovor v angličtině o tom, co tě zrovna napadne.',
      style: AppTheme.font(fontSize: 14, color: AppTheme.textSecondary, height: 1.45),
    );
  }
}
