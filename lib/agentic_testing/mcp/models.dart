import '../models/contract_context.dart';
import '../models/test_case_model.dart';
import '../models/workflow_context.dart';
import '../models/workflow_state.dart';
import 'app_resources.dart';

enum AgenticDecisionValue { approved, rejected }

enum AgenticBulkDecision { none, approveAll, rejectAll }

class GenerateTestsInput {
  const GenerateTestsInput({
    required this.sessionId,
    required this.endpoint,
    this.method = 'GET',
    this.headers = const <String, String>{},
    this.requestBody,
    this.generationPrompt,
    this.contractContext,
  });

  final String sessionId;
  final String endpoint;
  final String method;
  final Map<String, String> headers;
  final String? requestBody;
  final String? generationPrompt;
  final AgenticContractContext? contractContext;
}

class ReviewDecisionUpdate {
  const ReviewDecisionUpdate({
    required this.testId,
    required this.decision,
  });

  final String testId;
  final AgenticDecisionValue decision;
}

class ReviewDecisionInput {
  const ReviewDecisionInput({
    required this.sessionId,
    this.decisions = const <ReviewDecisionUpdate>[],
    this.bulkDecision = AgenticBulkDecision.none,
  });

  final String sessionId;
  final List<ReviewDecisionUpdate> decisions;
  final AgenticBulkDecision bulkDecision;
}

class RunApprovedInput {
  const RunApprovedInput({required this.sessionId});

  final String sessionId;
}

class GenerateHealingInput {
  const GenerateHealingInput({required this.sessionId});

  final String sessionId;
}

class HealingDecisionUpdate {
  const HealingDecisionUpdate({
    required this.testId,
    required this.decision,
  });

  final String testId;
  final AgenticDecisionValue decision;
}

class HealingDecisionInput {
  const HealingDecisionInput({
    required this.sessionId,
    this.decisions = const <HealingDecisionUpdate>[],
    this.bulkDecision = AgenticBulkDecision.none,
  });

  final String sessionId;
  final List<HealingDecisionUpdate> decisions;
  final AgenticBulkDecision bulkDecision;
}

class RerunHealedInput {
  const RerunHealedInput({
    required this.sessionId,
    this.skipIfNoApproved = true,
  });

  final String sessionId;
  final bool skipIfNoApproved;
}

class AgenticWorkflowSnapshotTest {
  const AgenticWorkflowSnapshotTest({
    required this.id,
    required this.title,
    required this.method,
    required this.endpoint,
    required this.decision,
    required this.executionStatus,
    required this.failureType,
    required this.healingDecision,
    required this.assertions,
    required this.healingAssertions,
    required this.assertionReport,
    this.description,
    this.expectedOutcome,
    this.executionSummary,
    this.healingSuggestion,
    this.responseStatusCode,
    this.responseTimeMs,
    this.confidence,
    this.healingIteration = 0,
  });

  final String id;
  final String title;
  final String method;
  final String endpoint;
  final String decision;
  final String executionStatus;
  final String failureType;
  final String healingDecision;
  final List<String> assertions;
  final List<String> healingAssertions;
  final List<String> assertionReport;
  final String? description;
  final String? expectedOutcome;
  final String? executionSummary;
  final String? healingSuggestion;
  final int? responseStatusCode;
  final int? responseTimeMs;
  final double? confidence;
  final int healingIteration;

  factory AgenticWorkflowSnapshotTest.fromTestCase(AgenticTestCase testCase) {
    return AgenticWorkflowSnapshotTest(
      id: testCase.id,
      title: testCase.title,
      method: testCase.method,
      endpoint: testCase.endpoint,
      decision: testCase.decision.name,
      executionStatus: testCase.executionStatus.name,
      failureType: testCase.failureType.code,
      healingDecision: testCase.healingDecision.code,
      assertions: testCase.assertions,
      healingAssertions: testCase.healingAssertions,
      assertionReport: testCase.assertionReport,
      description: testCase.description,
      expectedOutcome: testCase.expectedOutcome,
      executionSummary: testCase.executionSummary,
      healingSuggestion: testCase.healingSuggestion,
      responseStatusCode: testCase.responseStatusCode,
      responseTimeMs: testCase.responseTimeMs,
      confidence: testCase.confidence,
      healingIteration: testCase.healingIteration,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'method': method,
      'endpoint': endpoint,
      'description': description,
      'expectedOutcome': expectedOutcome,
      'decision': decision,
      'executionStatus': executionStatus,
      'executionSummary': executionSummary,
      'failureType': failureType,
      'healingDecision': healingDecision,
      'healingSuggestion': healingSuggestion,
      'assertions': assertions,
      'healingAssertions': healingAssertions,
      'assertionReport': assertionReport,
      'responseStatusCode': responseStatusCode,
      'responseTimeMs': responseTimeMs,
      'confidence': confidence,
      'healingIteration': healingIteration,
    };
  }
}

class AgenticWorkflowSnapshot {
  const AgenticWorkflowSnapshot({
    required this.sessionId,
    required this.workflowState,
    required this.generatedCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.pendingCount,
    required this.passedCount,
    required this.failedCount,
    required this.skippedCount,
    required this.notRunCount,
    required this.healPendingCount,
    required this.healApprovedCount,
    required this.healRejectedCount,
    required this.healAppliedCount,
    required this.tests,
    this.statusMessage,
    this.errorMessage,
    this.policy = 'strict_no_assertion_mutation',
    this.mcpAppResourceUri,
  });

  final String sessionId;
  final AgenticWorkflowState workflowState;
  final int generatedCount;
  final int approvedCount;
  final int rejectedCount;
  final int pendingCount;
  final int passedCount;
  final int failedCount;
  final int skippedCount;
  final int notRunCount;
  final int healPendingCount;
  final int healApprovedCount;
  final int healRejectedCount;
  final int healAppliedCount;
  final String? statusMessage;
  final String? errorMessage;
  final String policy;
  final String? mcpAppResourceUri;
  final List<AgenticWorkflowSnapshotTest> tests;

  factory AgenticWorkflowSnapshot.fromContext({
    required String sessionId,
    required AgenticWorkflowContext context,
  }) {
    return AgenticWorkflowSnapshot(
      sessionId: sessionId,
      workflowState: context.workflowState,
      generatedCount: context.generatedTests.length,
      approvedCount: context.approvedCount,
      rejectedCount: context.rejectedCount,
      pendingCount: context.pendingCount,
      passedCount: context.passedCount,
      failedCount: context.failedCount,
      skippedCount: context.skippedCount,
      notRunCount: context.notRunCount,
      healPendingCount: context.healPendingCount,
      healApprovedCount: context.healApprovedCount,
      healRejectedCount: context.healRejectedCount,
      healAppliedCount: context.healAppliedCount,
      statusMessage: context.statusMessage,
      errorMessage: context.errorMessage,
      mcpAppResourceUri: AgenticMcpAppResources.uriForWorkflowState(
        context.workflowState,
      ),
      tests: context.generatedTests
          .map(AgenticWorkflowSnapshotTest.fromTestCase)
          .toList(),
    );
  }

  factory AgenticWorkflowSnapshot.empty({required String sessionId}) {
    return const AgenticWorkflowSnapshot(
      sessionId: '',
      workflowState: AgenticWorkflowState.idle,
      generatedCount: 0,
      approvedCount: 0,
      rejectedCount: 0,
      pendingCount: 0,
      passedCount: 0,
      failedCount: 0,
      skippedCount: 0,
      notRunCount: 0,
      healPendingCount: 0,
      healApprovedCount: 0,
      healRejectedCount: 0,
      healAppliedCount: 0,
      tests: <AgenticWorkflowSnapshotTest>[],
    ).copyWith(sessionId: sessionId);
  }

  AgenticWorkflowSnapshot copyWith({
    String? sessionId,
    AgenticWorkflowState? workflowState,
    int? generatedCount,
    int? approvedCount,
    int? rejectedCount,
    int? pendingCount,
    int? passedCount,
    int? failedCount,
    int? skippedCount,
    int? notRunCount,
    int? healPendingCount,
    int? healApprovedCount,
    int? healRejectedCount,
    int? healAppliedCount,
    String? statusMessage,
    String? errorMessage,
    String? policy,
    String? mcpAppResourceUri,
    bool clearMcpAppResourceUri = false,
    List<AgenticWorkflowSnapshotTest>? tests,
  }) {
    return AgenticWorkflowSnapshot(
      sessionId: sessionId ?? this.sessionId,
      workflowState: workflowState ?? this.workflowState,
      generatedCount: generatedCount ?? this.generatedCount,
      approvedCount: approvedCount ?? this.approvedCount,
      rejectedCount: rejectedCount ?? this.rejectedCount,
      pendingCount: pendingCount ?? this.pendingCount,
      passedCount: passedCount ?? this.passedCount,
      failedCount: failedCount ?? this.failedCount,
      skippedCount: skippedCount ?? this.skippedCount,
      notRunCount: notRunCount ?? this.notRunCount,
      healPendingCount: healPendingCount ?? this.healPendingCount,
      healApprovedCount: healApprovedCount ?? this.healApprovedCount,
      healRejectedCount: healRejectedCount ?? this.healRejectedCount,
      healAppliedCount: healAppliedCount ?? this.healAppliedCount,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage ?? this.errorMessage,
      policy: policy ?? this.policy,
      mcpAppResourceUri: clearMcpAppResourceUri
          ? null
          : (mcpAppResourceUri ?? this.mcpAppResourceUri),
      tests: tests ?? this.tests,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'workflowState': workflowState.name,
      'generatedCount': generatedCount,
      'approvedCount': approvedCount,
      'rejectedCount': rejectedCount,
      'pendingCount': pendingCount,
      'passedCount': passedCount,
      'failedCount': failedCount,
      'skippedCount': skippedCount,
      'notRunCount': notRunCount,
      'healPendingCount': healPendingCount,
      'healApprovedCount': healApprovedCount,
      'healRejectedCount': healRejectedCount,
      'healAppliedCount': healAppliedCount,
      'statusMessage': statusMessage,
      'errorMessage': errorMessage,
      'policy': policy,
      'mcpAppResourceUri': mcpAppResourceUri,
      'tests': tests.map((item) => item.toJson()).toList(),
    };
  }
}
