import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/core/widgets/glass_container.dart';
import 'package:aj_tudor/core/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({
    required Widget child,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  group('GlassContainer Tests', () {
    testWidgets('renders child content properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const GlassContainer(
            child: Text('Glass Content Test'),
          ),
        ),
      );

      expect(find.text('Glass Content Test'), findsOneWidget);
      expect(find.byType(GlassContainer), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('applies explicit width, height and margin', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const GlassContainer(
            width: 200,
            height: 100,
            margin: EdgeInsets.all(12),
            child: Text('Size and Margin Test'),
          ),
        ),
      );

      final outerContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(GlassContainer),
          matching: find.byType(Container),
        ).first,
      );

      final constraints = outerContainer.constraints;
      expect(constraints?.minWidth, 200);
      expect(constraints?.maxWidth, 200);
      expect(constraints?.minHeight, 100);
      expect(constraints?.maxHeight, 100);
      expect(outerContainer.margin, const EdgeInsets.all(12));
    });

    testWidgets('uses specular rim border by default', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const GlassContainer(
            useSpecularBorder: true,
            borderWidth: 2.0,
            child: Text('Specular Rim'),
          ),
        ),
      );

      expect(find.text('Specular Rim'), findsOneWidget);
      // Specular rim introduces an outer border container with gradient decoration
      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(GlassContainer),
          matching: find.byType(Container),
        ),
      ).toList();

      final hasGradientContainer = containers.any((c) {
        final dec = c.decoration;
        return dec is BoxDecoration && dec.gradient != null;
      });
      expect(hasGradientContainer, isTrue);
    });

    testWidgets('uses custom border when specified instead of specular rim', (WidgetTester tester) async {
      const customBorder = Border.fromBorderSide(
        BorderSide(color: Colors.red, width: 3.0),
      );

      await tester.pumpWidget(
        buildTestWidget(
          child: const GlassContainer(
            border: customBorder,
            child: Text('Custom Border'),
          ),
        ),
      );

      expect(find.text('Custom Border'), findsOneWidget);

      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(GlassContainer),
          matching: find.byType(Container),
        ),
      );

      final hasCustomBorder = containers.any((c) {
        final dec = c.decoration;
        return dec is BoxDecoration && dec.border == customBorder;
      });

      expect(hasCustomBorder, isTrue);
    });

    testWidgets('renders cleanly in dark theme mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          themeMode: ThemeMode.dark,
          child: const GlassContainer(
            child: Text('Dark Mode Glass'),
          ),
        ),
      );

      expect(find.text('Dark Mode Glass'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('applies custom blur sigma to BackdropFilter', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const GlassContainer(
            blur: 24.0,
            child: Text('Blur Test'),
          ),
        ),
      );

      final backdropFilter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      expect(backdropFilter.filter, ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0));
    });
  });
}

