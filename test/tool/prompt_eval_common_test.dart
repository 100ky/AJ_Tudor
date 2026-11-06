import 'package:flutter_test/flutter_test.dart';

import '../../tool/prompt_eval/common.dart';

void main() {
  group('test promptu: pojistky spotřeby API', () {
    test('rozpočet zastaví běh na stropu požadavků', () {
      RequestBudget.start(2);
      RequestBudget.take();
      RequestBudget.take();
      expect(RequestBudget.take, throwsA(isA<BudgetExhausted>()));
      expect(RequestBudget.used, 2);
    });

    test('hláška o vyčerpané kvótě se pozná (4. 11.: Live API i REST)', () {
      expect(
        isQuotaMessage('You exceeded your current quota, please check your plan and billing details.'),
        isTrue,
      );
      expect(isQuotaMessage('{"error": {"code": 429, "status": "RESOURCE_EXHAUSTED"}}'), isTrue);
      expect(isQuotaMessage('The model is overloaded. Please try again later.'), isFalse);
    });

    test('kvóta i rozpočet běh zastaví, obojí je StopRun', () {
      expect(QuotaExceeded('x'), isA<StopRun>());
      expect(BudgetExhausted(1), isA<StopRun>());
    });

    test('neúspěšná automatická kontrola rozhoduje bez rozhodčího', () {
      expect(replyPassed([true, false], null), isFalse);
      expect(replyPassed([true, true], null), isTrue);
      expect(replyPassed([true], {'pass': false}), isFalse);
      expect(replyPassed([true], {'pass': true}), isTrue);
      // Rozhodčí neodpověděl: odpověď zůstane nehodnocená a nepočítá se
      expect(replyPassed([true], {'pass': null}), isNull);
    });

    test('běh bez stropu požadavků se nespustí, plán a porovnání strop nepotřebují', () {
      expect(() => EvalOptions.parse([], defaultLabel: 'x'), throwsArgumentError);
      expect(EvalOptions.parse(['--dry-run'], defaultLabel: 'x').dryRun, isTrue);
      expect(EvalOptions.parse(['--compare', 'a', 'b'], defaultLabel: 'x').compare, ('a', 'b'));
      final options = EvalOptions.parse(['--max-requests', '50'], defaultLabel: 'x');
      expect(options.maxRequests, 50);
      expect(options.runs, 2);
    });
  });
}
