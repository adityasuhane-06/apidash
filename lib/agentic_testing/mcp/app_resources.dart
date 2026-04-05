import '../models/workflow_state.dart';

class AgenticMcpAppResources {
  static const String planReviewUri = 'ui://agentic/plan-review';
  static const String testReviewUri = 'ui://agentic/test-review';
  static const String executionResultsUri = 'ui://agentic/execution-results';
  static const String healingReviewUri = 'ui://agentic/healing-review';
  static const String finalReportUri = 'ui://agentic/final-report';

  static const List<String> supportedUris = <String>[
    planReviewUri,
    testReviewUri,
    executionResultsUri,
    healingReviewUri,
    finalReportUri,
  ];

  static String? uriForWorkflowState(AgenticWorkflowState state) {
    return switch (state) {
      AgenticWorkflowState.awaitingApproval => testReviewUri,
      AgenticWorkflowState.resultsReady => executionResultsUri,
      AgenticWorkflowState.awaitingHealApproval => healingReviewUri,
      AgenticWorkflowState.finalReport => finalReportUri,
      _ => null,
    };
  }

  static String? htmlForUri(String uri) {
    return switch (uri) {
      planReviewUri => _planReviewHtml,
      testReviewUri => _testReviewHtml,
      executionResultsUri => _executionResultsHtml,
      healingReviewUri => _healingReviewHtml,
      finalReportUri => _finalReportHtml,
      _ => null,
    };
  }
}

const String _planReviewHtml = '''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Agentic Plan Review</title>
  </head>
  <body>
    <h2>Plan Review</h2>
    <p>Review and approve the proposed workflow plan before execution.</p>
    <div id="plan-root"></div>
  </body>
</html>
''';

const String _testReviewHtml = '''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Agentic Test Review</title>
  </head>
  <body>
    <h2>Agentic Test Review</h2>
    <p>Approve or reject generated tests before execution.</p>
    <div id="table-root"></div>
  </body>
</html>
''';

const String _executionResultsHtml = '''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Agentic Execution Results</title>
  </head>
  <body>
    <h2>Execution Results</h2>
    <p>Pass/fail/skipped summary with failure classification.</p>
    <div id="results-root"></div>
  </body>
</html>
''';

const String _healingReviewHtml = '''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Agentic Healing Review</title>
  </head>
  <body>
    <h2>Healing Review</h2>
    <p>Strict mode: assertions are unchanged; only diagnostic actions are reviewed.</p>
    <div id="healing-root"></div>
  </body>
</html>
''';

const String _finalReportHtml = '''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Agentic Final Report</title>
  </head>
  <body>
    <h2>Final Report</h2>
    <p>Lifecycle summary and next recommended actions.</p>
    <div id="report-root"></div>
  </body>
</html>
''';
