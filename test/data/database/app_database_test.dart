import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:aj_tudor/data/database/app_database.dart';

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('aj_tudor_db_');
    dbFile = File(p.join(tempDir.path, 'db.sqlite'));
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<int> insertCard(AppDatabase db, String backText, double mastery) {
    final now = DateTime.now();
    return db.into(db.flashcards).insert(
          FlashcardsCompanion.insert(
            frontText: 'Zadání $backText',
            backText: backText,
            explanation: 'Vysvětlení',
            masteryScore: Value(mastery),
            nextReviewAt: now,
            createdAt: now,
          ),
        );
  }

  group('AppDatabase - opravy při otevření', () {
    test('reopening keeps distinct cards and removes only duplicates', () async {
      final first = AppDatabase.forTesting(NativeDatabase(dbFile));
      await insertCard(first, 'grass', 0.2);
      await insertCard(first, 'house', 0.5);
      final bestGrass = await insertCard(first, 'Grass ', 0.9);
      await insertCard(first, 'dog', 0.1);
      await first.close();

      // Druhé otevření odpovídá dalšímu startu aplikace, beforeOpen proběhne znovu.
      final second = AppDatabase.forTesting(NativeDatabase(dbFile));
      try {
        final cards = await second.select(second.flashcards).get();

        expect(cards.map((c) => c.backText.trim().toLowerCase()),
            unorderedEquals(['grass', 'house', 'dog']));
        final grass = cards.singleWhere((c) => c.backText.trim().toLowerCase() == 'grass');
        expect(grass.id, bestGrass);
        expect(grass.masteryScore, 0.9);
      } finally {
        await second.close();
      }
    });
  });
}
