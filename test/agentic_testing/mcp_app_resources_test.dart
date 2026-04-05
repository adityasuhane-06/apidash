import 'package:apidash/agentic_testing/mcp/app_resources.dart';
import 'package:apidash/agentic_testing/models/workflow_state.dart';
import 'package:test/test.dart';

void main() {
  group('AgenticMcpAppResources', () {
    test('maps workflow states to expected MCP app URIs', () {
      expect(
        AgenticMcpAppResources.uriForWorkflowState(
          AgenticWorkflowState.awaitingApproval,
        ),
        AgenticMcpAppResources.testReviewUri,
      );
      expect(
        AgenticMcpAppResources.uriForWorkflowState(
          AgenticWorkflowState.resultsReady,
        ),
        AgenticMcpAppResources.executionResultsUri,
      );
      expect(
        AgenticMcpAppResources.uriForWorkflowState(
          AgenticWorkflowState.awaitingHealApproval,
        ),
        AgenticMcpAppResources.healingReviewUri,
      );
      expect(
        AgenticMcpAppResources.uriForWorkflowState(
          AgenticWorkflowState.finalReport,
        ),
        AgenticMcpAppResources.finalReportUri,
      );
      expect(
        AgenticMcpAppResources.uriForWorkflowState(AgenticWorkflowState.idle),
        isNull,
      );
    });

    test('returns HTML shell for every supported resource URI', () {
      for (final uri in AgenticMcpAppResources.supportedUris) {
        final html = AgenticMcpAppResources.htmlForUri(uri);
        expect(html, isNotNull);
        expect(html!.contains('<html>'), isTrue);
      }
    });
  });
}
