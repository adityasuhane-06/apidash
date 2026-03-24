import 'test_case_model.dart';
import 'workflow_state.dart';

class AgenticWorkflowContext {
  const AgenticWorkflowContext({
    this.workflowState = AgenticWorkflowState.idle,
    this.endpoint = '',
    this.requestMethod = 'GET',
    this.requestHeaders = const <String, String>{},
    this.requestBody,
    this.generatedTests = const <AgenticTestCase>[],
    this.statusMessage,
    this.errorMessage,
  });

  final AgenticWorkflowState workflowState;
  final String endpoint;
  final String requestMethod;
  final Map<String, String> requestHeaders;
  final String? requestBody;
  final List<AgenticTestCase> generatedTests;
  final String? statusMessage;
  final String? errorMessage;

  int get approvedCount => generatedTests
      .where((testCase) => testCase.decision == TestReviewDecision.approved)
      .length;

  int get rejectedCount => generatedTests
      .where((testCase) => testCase.decision == TestReviewDecision.rejected)
      .length;

  int get pendingCount => generatedTests
      .where((testCase) => testCase.decision == TestReviewDecision.pending)
      .length;

  int get passedCount => generatedTests
      .where(
        (testCase) => testCase.executionStatus == TestExecutionStatus.passed,
      )
      .length;

  int get failedCount => generatedTests
      .where(
        (testCase) => testCase.executionStatus == TestExecutionStatus.failed,
      )
      .length;

  int get skippedCount => generatedTests
      .where(
        (testCase) => testCase.executionStatus == TestExecutionStatus.skipped,
      )
      .length;

  int get notRunCount => generatedTests
      .where(
        (testCase) => testCase.executionStatus == TestExecutionStatus.notRun,
      )
      .length;

  AgenticWorkflowContext copyWith({
    AgenticWorkflowState? workflowState,
    String? endpoint,
    String? requestMethod,
    Map<String, String>? requestHeaders,
    String? requestBody,
    bool clearRequestBody = false,
    List<AgenticTestCase>? generatedTests,
    String? statusMessage,
    bool clearStatusMessage = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return AgenticWorkflowContext(
      workflowState: workflowState ?? this.workflowState,
      endpoint: endpoint ?? this.endpoint,
      requestMethod: requestMethod ?? this.requestMethod,
      requestHeaders: requestHeaders ?? this.requestHeaders,
      requestBody: clearRequestBody ? null : (requestBody ?? this.requestBody),
      generatedTests: generatedTests ?? this.generatedTests,
      statusMessage: clearStatusMessage
          ? null
          : (statusMessage ?? this.statusMessage),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}
