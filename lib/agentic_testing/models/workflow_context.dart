import 'test_case_model.dart';
import 'workflow_state.dart';

class AgenticWorkflowContext {
  const AgenticWorkflowContext({
    this.workflowState = AgenticWorkflowState.idle,
    this.endpoint = '',
    this.requestMethod = 'GET',
    this.requestHeaders = const <String, String>{},
    this.requestBody,
    this.generationPrompt,
    this.generatedTests = const <AgenticTestCase>[],
    this.statusMessage,
    this.errorMessage,
  });

  final AgenticWorkflowState workflowState;
  final String endpoint;
  final String requestMethod;
  final Map<String, String> requestHeaders;
  final String? requestBody;
  final String? generationPrompt;
  final List<AgenticTestCase> generatedTests;
  final String? statusMessage;
  final String? errorMessage;

  factory AgenticWorkflowContext.fromJson(Map<String, dynamic> json) {
    final workflowStateRaw =
        (json['workflow_state'] as String?)?.trim().toLowerCase() ?? '';
    final workflowState = AgenticWorkflowState.values.firstWhere(
      (state) => state.name.toLowerCase() == workflowStateRaw,
      orElse: () => AgenticWorkflowState.idle,
    );

    final requestHeadersRaw = json['request_headers'];
    final requestHeaders = requestHeadersRaw is Map
        ? requestHeadersRaw.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : const <String, String>{};

    final generatedTestsRaw = json['generated_tests'];
    final generatedTests = generatedTestsRaw is List
        ? generatedTestsRaw
              .whereType<Map>()
              .map(
                (item) => AgenticTestCase.fromJson(
                  Map<String, dynamic>.from(item),
                  fallbackId: '',
                  fallbackEndpoint: (json['endpoint'] as String?) ?? '',
                  fallbackMethod: (json['request_method'] as String?) ?? 'GET',
                ),
              )
              .toList()
        : const <AgenticTestCase>[];

    return AgenticWorkflowContext(
      workflowState: workflowState,
      endpoint: (json['endpoint'] as String?) ?? '',
      requestMethod: (json['request_method'] as String?) ?? 'GET',
      requestHeaders: requestHeaders,
      requestBody: json['request_body'] as String?,
      generationPrompt: json['generation_prompt'] as String?,
      generatedTests: generatedTests,
      statusMessage: json['status_message'] as String?,
      errorMessage: json['error_message'] as String?,
    );
  }

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

  int get healPendingCount => generatedTests
      .where(
        (testCase) => testCase.healingDecision == TestHealingDecision.pending,
      )
      .length;

  int get healApprovedCount => generatedTests
      .where(
        (testCase) => testCase.healingDecision == TestHealingDecision.approved,
      )
      .length;

  int get healRejectedCount => generatedTests
      .where(
        (testCase) => testCase.healingDecision == TestHealingDecision.rejected,
      )
      .length;

  int get healAppliedCount => generatedTests
      .where(
        (testCase) => testCase.healingDecision == TestHealingDecision.applied,
      )
      .length;

  AgenticWorkflowContext copyWith({
    AgenticWorkflowState? workflowState,
    String? endpoint,
    String? requestMethod,
    Map<String, String>? requestHeaders,
    String? requestBody,
    bool clearRequestBody = false,
    String? generationPrompt,
    bool clearGenerationPrompt = false,
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
      generationPrompt: clearGenerationPrompt
          ? null
          : (generationPrompt ?? this.generationPrompt),
      generatedTests: generatedTests ?? this.generatedTests,
      statusMessage: clearStatusMessage
          ? null
          : (statusMessage ?? this.statusMessage),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workflow_state': workflowState.name,
      'endpoint': endpoint,
      'request_method': requestMethod,
      'request_headers': requestHeaders,
      'request_body': requestBody,
      'generation_prompt': generationPrompt,
      'generated_tests': generatedTests
          .map((testCase) => testCase.toJson())
          .toList(),
      'status_message': statusMessage,
      'error_message': errorMessage,
    };
  }
}
