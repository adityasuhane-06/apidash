import 'package:apidash/dashbot/models/models.dart';
import 'package:apidash/dashbot/services/agent/agent_loop_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentLoopCommandParser', () {
    final parser = AgentLoopCommandParserImpl();

    test('parses mixed per-test review decisions', () {
      final intent = parser.parse('approve case one and two and skip three');
      expect(intent.type, AgentLoopTextIntentType.reviewDecision);
      expect(intent.decisions.length, 2);
      expect(
        intent.decisions.first.operation,
        AgentLoopDecisionOperation.approve,
      );
      expect(intent.decisions.first.references, [1, 2]);
      expect(intent.decisions.last.operation, AgentLoopDecisionOperation.skip);
      expect(intent.decisions.last.references, [3]);
    });

    test('parses execute-only selection by references', () {
      final intent = parser.parse('execute only T1 T2');
      expect(intent.type, AgentLoopTextIntentType.executeOnlySelection);
      expect(intent.references, [1, 2]);
      expect(intent.requiresRiskConfirmation, isTrue);
    });

    test('parses failure and healing diagnostic questions', () {
      final failIntent = parser.parse('why test 1 failed?');
      expect(failIntent.type, AgentLoopTextIntentType.explainFailure);
      expect(failIntent.references, [1]);

      final healIntent = parser.parse('how to heal T2');
      expect(healIntent.type, AgentLoopTextIntentType.explainHealing);
      expect(healIntent.references, [2]);
    });

    test('parses plan approval and request changes', () {
      final approvePlan = parser.parse('approve plan');
      expect(approvePlan.type, AgentLoopTextIntentType.approvePlan);

      final requestChanges = parser.parse('need changes in this report');
      expect(requestChanges.type, AgentLoopTextIntentType.requestChanges);
    });

    test('parses negative satisfaction phrases as request changes', () {
      final intent = parser.parse('not solved yet, add one more test');
      expect(intent.type, AgentLoopTextIntentType.requestChanges);
    });

    test('does not treat status/error codes as test references', () {
      final intent = parser.parse('why did test fail with status 401?');
      expect(intent.type, AgentLoopTextIntentType.explainFailure);
      expect(intent.references, isEmpty);
    });

    test('parses healing decision with all keyword', () {
      final intent = parser.parse('approve healing all');
      expect(intent.type, AgentLoopTextIntentType.healingDecision);
      expect(intent.decisions, hasLength(1));
      expect(intent.decisions.single.applyToAll, isTrue);
    });
  });
}
