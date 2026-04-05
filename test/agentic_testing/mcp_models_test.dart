import 'package:apidash/agentic_testing/agentic_testing.dart';
import 'package:test/test.dart';

void main() {
  group('AgenticWorkflowSnapshot', () {
    test('fromContext includes MCP app URI for mapped workflow state', () {
      const context = AgenticWorkflowContext(
        workflowState: AgenticWorkflowState.awaitingApproval,
        generatedTests: <AgenticTestCase>[
          AgenticTestCase(
            id: 't1',
            title: 'Status is 200',
            description: 'Basic happy path check',
            method: 'GET',
            endpoint: 'https://api.apidash.dev/users',
            expectedOutcome: 'Status code is 200',
            assertions: <String>['status_code equals 200'],
          ),
        ],
      );

      final snapshot = AgenticWorkflowSnapshot.fromContext(
        sessionId: 'sess-model-1',
        context: context,
      );

      expect(snapshot.sessionId, 'sess-model-1');
      expect(snapshot.workflowState, AgenticWorkflowState.awaitingApproval);
      expect(snapshot.generatedCount, 1);
      expect(snapshot.mcpAppResourceUri, AgenticMcpAppResources.testReviewUri);
      expect(snapshot.tests, hasLength(1));
    });

    test('empty keeps the passed session id', () {
      final snapshot = AgenticWorkflowSnapshot.empty(sessionId: 'sess-empty-1');

      expect(snapshot.sessionId, 'sess-empty-1');
      expect(snapshot.workflowState, AgenticWorkflowState.idle);
      expect(snapshot.generatedCount, 0);
      expect(snapshot.mcpAppResourceUri, isNull);
    });
  });
}
