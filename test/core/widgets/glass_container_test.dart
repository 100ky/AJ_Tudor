import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aj_tudor/core/widgets/glass_container.dart';
import 'package:aj_tudor/core/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({required Widget child}) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: Center(child: child)),
    );
  }

  BoxDecoration decorationOf(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.descendant(of: find.byType(GlassContainer), matching: find.byType(Container)).first,
    );
    return container.decoration! as BoxDecoration;
  }

  group('GlassContainer (plný povrch karty)', () {
    testWidgets('renders child content without blur', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(child: const GlassContainer(child: Text('Obsah karty'))));

      expect(find.text('Obsah karty'), findsOneWidget);
      // Sklo je pryč: žádné rozmazání pozadí ani stín
      expect(find.byType(BackdropFilter), findsNothing);
      expect(decorationOf(tester).color, AppTheme.surface);
      expect(decorationOf(tester).boxShadow, isNull);
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
        find.descendant(of: find.byType(GlassContainer), matching: find.byType(Container)).first,
      );
      final constraints = outerContainer.constraints;
      expect(constraints?.minWidth, 200);
      expect(constraints?.maxWidth, 200);
      expect(constraints?.minHeight, 100);
      expect(constraints?.maxHeight, 100);
      expect(outerContainer.margin, const EdgeInsets.all(12));
    });

    testWidgets('uses the given color and border', (WidgetTester tester) async {
      const customBorder = Border.fromBorderSide(BorderSide(color: Colors.red, width: 3.0));
      await tester.pumpWidget(
        buildTestWidget(
          child: const GlassContainer(
            color: AppTheme.surfaceRaised,
            border: customBorder,
            child: Text('Custom Border'),
          ),
        ),
      );

      expect(decorationOf(tester).color, AppTheme.surfaceRaised);
      expect(decorationOf(tester).border, customBorder);
    });

    testWidgets('a gradient replaces the plain fill', (WidgetTester tester) async {
      const gradient = LinearGradient(colors: [Colors.black, Colors.white]);
      await tester.pumpWidget(buildTestWidget(child: const GlassContainer(gradient: gradient, child: Text('Gradient'))));

      expect(decorationOf(tester).gradient, gradient);
      expect(decorationOf(tester).color, isNull);
    });
  });
}
