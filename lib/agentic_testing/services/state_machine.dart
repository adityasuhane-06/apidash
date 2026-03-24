import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../models/test_case_model.dart';
import '../models/workflow_context.dart';
import '../models/workflow_state.dart';
import 'healing_planner.dart';
import 'test_executor.dart';
import 'test_generator.dart';
import 'workflow_checkpoint_storage.dart';

class InvalidWorkflowTransitionException implements Exception {
  const InvalidWorkflowTransitionException(this.from, this.to);

  final AgenticWorkflowState from;
  final AgenticWorkflowState to;

  @override
  String toString() {
    return 'Invalid transition from ${from.label} to ${to.label}';
  }
}

class AgenticTestingStateMachine extends StateNotifier<AgenticWorkflowContext> {
  AgenticTestingStateMachine({
    required AgenticTestGenerator testGenerator,
    required AgenticTestExecutor testExecutor,
    required AgenticTestHealingPlanner healingPlanner,
    required AgenticWorkflowCheckpointStorage checkpointStorage,
  }) : _testGenerator = testGenerator,
       _testExecutor = testExecutor,
       _healingPlanner = healingPlanner,
       _checkpointStorage = checkpointStorage,
       super(const AgenticWorkflowContext());

  final AgenticTestGenerator _testGenerator;
  final AgenticTestExecutor _testExecutor;
  final AgenticTestHealingPlanner _healingPlanner;
  final AgenticWorkflowCheckpointStorage _checkpointStorage;

  static const Map<AgenticWorkflowState, Set<AgenticWorkflowState>>
  _allowedTransitions = {
    AgenticWorkflowState.idle: {AgenticWorkflowState.generating},
    AgenticWorkflowState.generating: {
      AgenticWorkflowState.awaitingApproval,
      AgenticWorkflowState.idle,
    },
    AgenticWorkflowState.awaitingApproval: {
      AgenticWorkflowState.executing,
      AgenticWorkflowState.idle,
    },
    AgenticWorkflowState.executing: {
      AgenticWorkflowState.resultsReady,
      AgenticWorkflowState.awaitingApproval,
      AgenticWorkflowState.idle,
    },
    AgenticWorkflowState.resultsReady: {
      AgenticWorkflowState.analyzingFailures,
      AgenticWorkflowState.idle,
    },
    AgenticWorkflowState.analyzingFailures: {
      AgenticWorkflowState.awaitingHealApproval,
      AgenticWorkflowState.resultsReady,
      AgenticWorkflowState.idle,
    },
    AgenticWorkflowState.awaitingHealApproval: {
      AgenticWorkflowState.reExecuting,
      AgenticWorkflowState.resultsReady,
      AgenticWorkflowState.idle,
    },
    AgenticWorkflowState.reExecuting: {
      AgenticWorkflowState.finalReport,
      AgenticWorkflowState.awaitingHealApproval,
      AgenticWorkflowState.idle,
    },
    AgenticWorkflowState.finalReport: {
      AgenticWorkflowState.analyzingFailures,
      AgenticWorkflowState.idle,
    },
  };

  Future<void> hydrateFromCheckpoint() async {
    final checkpoint = await _checkpointStorage.load();
    if (checkpoint == null) {
      return;
    }
    _updateState(checkpoint);
  }

  Future<void> startGeneration({
    required String endpoint,
    String? method,
    Map<String, String>? headers,
    String? requestBody,
    String? generationPrompt,
  }) async {
    final normalizedEndpoint = endpoint.trim();
    final resolvedMethod = (method?.trim().isNotEmpty == true)
        ? method!.trim().toUpperCase()
        : 'GET';
    final normalizedPrompt = generationPrompt?.trim();

    if (normalizedEndpoint.isEmpty) {
      _updateState(
        state.copyWith(
          errorMessage: 'Please provide an endpoint before generating tests.',
          clearStatusMessage: true,
        ),
      );
      return;
    }

    if (state.workflowState != AgenticWorkflowState.idle) {
      _updateState(
        state.copyWith(
          errorMessage:
              'Cannot start generation while state is ${state.workflowState.label}.',
        ),
      );
      return;
    }

    _transitionTo(
      AgenticWorkflowState.generating,
      endpoint: normalizedEndpoint,
      requestMethod: resolvedMethod,
      requestHeaders: headers ?? const <String, String>{},
      requestBody: requestBody,
      generationPrompt: normalizedPrompt?.isEmpty == true
          ? null
          : normalizedPrompt,
      generatedTests: const <AgenticTestCase>[],
      statusMessage: 'Generating test cases...',
      clearErrorMessage: true,
    );

    try {
      final tests = await _testGenerator.generateTests(
        endpoint: normalizedEndpoint,
        method: resolvedMethod,
        headers: headers,
        requestBody: requestBody,
        generationPrompt: normalizedPrompt,
      );

      _transitionTo(
        AgenticWorkflowState.awaitingApproval,
        generatedTests: _resetExecutionAndHealing(tests),
        statusMessage:
            'Generated ${tests.length} test cases. Review and approve before execution.',
        clearErrorMessage: true,
      );
    } catch (e) {
      _transitionTo(
        AgenticWorkflowState.idle,
        generatedTests: const <AgenticTestCase>[],
        errorMessage: 'Failed to generate tests: $e',
        clearStatusMessage: true,
      );
    }
  }

  Future<void> executeApprovedTests() async {
    if (!_requireState(AgenticWorkflowState.awaitingApproval)) {
      return;
    }

    if (state.approvedCount == 0) {
      _updateState(
        state.copyWith(
          errorMessage: 'Approve at least one test case before execution.',
        ),
      );
      return;
    }

    _transitionTo(
      AgenticWorkflowState.executing,
      statusMessage: 'Executing ${state.approvedCount} approved test cases...',
      clearErrorMessage: true,
    );

    try {
      final executedTests = await _testExecutor.executeTests(
        tests: state.generatedTests,
        defaultHeaders: state.requestHeaders,
        requestBody: state.requestBody,
      );

      _transitionTo(
        AgenticWorkflowState.resultsReady,
        generatedTests: executedTests,
        statusMessage: _buildExecutionSummary(executedTests),
        clearErrorMessage: true,
      );
    } catch (e) {
      _transitionTo(
        AgenticWorkflowState.awaitingApproval,
        errorMessage: 'Failed to execute approved tests: $e',
        clearStatusMessage: true,
      );
    }
  }

  Future<void> generateHealingPlans() async {
    if (!(state.workflowState == AgenticWorkflowState.resultsReady ||
        state.workflowState == AgenticWorkflowState.finalReport)) {
      _updateState(
        state.copyWith(
          errorMessage:
              'Healing plans can be generated only after test execution results are available.',
        ),
      );
      return;
    }

    if (state.failedCount == 0) {
      _updateState(
        state.copyWith(
          errorMessage: 'No failed tests found. Healing is not required.',
        ),
      );
      return;
    }

    _transitionTo(
      AgenticWorkflowState.analyzingFailures,
      statusMessage: 'Analyzing failures and generating healing plans...',
      clearErrorMessage: true,
    );

    try {
      final planned = _healingPlanner.generateHealingPlans(
        tests: state.generatedTests,
      );
      _transitionTo(
        AgenticWorkflowState.awaitingHealApproval,
        generatedTests: planned,
        statusMessage:
            'Generated healing plans for failed tests. Approve or reject each plan.',
        clearErrorMessage: true,
      );
    } catch (e) {
      _transitionTo(
        AgenticWorkflowState.resultsReady,
        errorMessage: 'Failed to generate healing plans: $e',
        clearStatusMessage: true,
      );
    }
  }

  void approveHealing(String testId) {
    _setHealingDecision(testId, TestHealingDecision.approved);
  }

  void rejectHealing(String testId) {
    _setHealingDecision(testId, TestHealingDecision.rejected);
  }

  void approveAllHealing() {
    if (!_requireState(AgenticWorkflowState.awaitingHealApproval)) {
      return;
    }
    final updated = state.generatedTests.map((testCase) {
      if (testCase.healingDecision == TestHealingDecision.pending) {
        return testCase.copyWith(healingDecision: TestHealingDecision.approved);
      }
      return testCase;
    }).toList();

    _updateState(
      state.copyWith(
        generatedTests: updated,
        statusMessage:
            'Approved ${updated.where((t) => t.healingDecision == TestHealingDecision.approved).length} healing plans.',
        clearErrorMessage: true,
      ),
    );
  }

  void rejectAllHealing() {
    if (!_requireState(AgenticWorkflowState.awaitingHealApproval)) {
      return;
    }
    final updated = state.generatedTests.map((testCase) {
      if (testCase.healingDecision == TestHealingDecision.pending) {
        return testCase.copyWith(healingDecision: TestHealingDecision.rejected);
      }
      return testCase;
    }).toList();

    _updateState(
      state.copyWith(
        generatedTests: updated,
        statusMessage: 'Rejected all pending healing plans.',
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> reExecuteHealedTests() async {
    if (!_requireState(AgenticWorkflowState.awaitingHealApproval)) {
      return;
    }

    final candidates = state.generatedTests
        .where(
          (testCase) =>
              testCase.healingDecision == TestHealingDecision.approved,
        )
        .toList();

    if (candidates.isEmpty) {
      _updateState(
        state.copyWith(
          errorMessage:
              'Approve at least one healing plan before re-executing.',
        ),
      );
      return;
    }

    _transitionTo(
      AgenticWorkflowState.reExecuting,
      statusMessage: 'Re-executing ${candidates.length} healed tests...',
      clearErrorMessage: true,
    );

    try {
      final healedCandidates = candidates
          .map(
            (testCase) => testCase.copyWith(
              assertions: testCase.healingAssertions.isNotEmpty
                  ? testCase.healingAssertions
                  : testCase.assertions,
              healingDecision: TestHealingDecision.applied,
              healingIteration: testCase.healingIteration + 1,
              executionStatus: TestExecutionStatus.notRun,
              clearExecutionSummary: true,
              assertionReport: const <String>[],
              clearResponseStatusCode: true,
              clearResponseTimeMs: true,
              failureType: TestFailureType.none,
            ),
          )
          .toList();

      final reExecuted = await _testExecutor.executeTests(
        tests: healedCandidates,
        defaultHeaders: state.requestHeaders,
        requestBody: state.requestBody,
      );

      final merged = _mergeUpdatedTests(state.generatedTests, reExecuted);

      _transitionTo(
        AgenticWorkflowState.finalReport,
        generatedTests: merged,
        statusMessage:
            'Healing re-run complete. ${_buildExecutionSummary(merged)}',
        clearErrorMessage: true,
      );
    } catch (e) {
      _transitionTo(
        AgenticWorkflowState.awaitingHealApproval,
        errorMessage: 'Failed to re-execute healed tests: $e',
        clearStatusMessage: true,
      );
    }
  }

  void approveTest(String testId) {
    _setDecision(testId, TestReviewDecision.approved);
  }

  void rejectTest(String testId) {
    _setDecision(testId, TestReviewDecision.rejected);
  }

  void approveAll() {
    if (!_requireState(AgenticWorkflowState.awaitingApproval)) {
      return;
    }
    final reviewedTests = state.generatedTests
        .map(
          (testCase) =>
              testCase.copyWith(decision: TestReviewDecision.approved),
        )
        .toList();

    _updateState(
      state.copyWith(
        generatedTests: reviewedTests,
        statusMessage:
            'Approved ${reviewedTests.length} test cases. Run approved tests to execute.',
        clearErrorMessage: true,
      ),
    );
  }

  void rejectAll() {
    if (!_requireState(AgenticWorkflowState.awaitingApproval)) {
      return;
    }
    final reviewedTests = state.generatedTests
        .map(
          (testCase) =>
              testCase.copyWith(decision: TestReviewDecision.rejected),
        )
        .toList();

    _updateState(
      state.copyWith(
        generatedTests: reviewedTests,
        statusMessage:
            'Rejected ${reviewedTests.length} test cases. You can reset or re-generate.',
        clearErrorMessage: true,
      ),
    );
  }

  void reset() {
    if (state.workflowState == AgenticWorkflowState.generating ||
        state.workflowState == AgenticWorkflowState.executing ||
        state.workflowState == AgenticWorkflowState.analyzingFailures ||
        state.workflowState == AgenticWorkflowState.reExecuting) {
      return;
    }
    if (state.workflowState != AgenticWorkflowState.idle) {
      _transitionTo(
        AgenticWorkflowState.idle,
        generatedTests: const <AgenticTestCase>[],
        statusMessage: 'Workflow reset. Ready to generate again.',
        clearErrorMessage: true,
      );
      return;
    }
    _updateState(const AgenticWorkflowContext());
  }

  void _setDecision(String testId, TestReviewDecision decision) {
    if (!_requireState(AgenticWorkflowState.awaitingApproval)) {
      return;
    }
    final updatedTests = state.generatedTests.map((testCase) {
      if (testCase.id != testId) {
        return testCase;
      }
      return testCase.copyWith(decision: decision);
    }).toList();
    _updateState(
      state.copyWith(
        generatedTests: updatedTests,
        statusMessage:
            'Reviewed ${updatedTests.length - _pendingCount(updatedTests)} of ${updatedTests.length} tests.',
        clearErrorMessage: true,
      ),
    );
  }

  void _setHealingDecision(String testId, TestHealingDecision decision) {
    if (!_requireState(AgenticWorkflowState.awaitingHealApproval)) {
      return;
    }
    final updatedTests = state.generatedTests.map((testCase) {
      if (testCase.id != testId) {
        return testCase;
      }
      if (testCase.healingDecision != TestHealingDecision.pending &&
          testCase.healingDecision != TestHealingDecision.approved &&
          testCase.healingDecision != TestHealingDecision.rejected) {
        return testCase;
      }
      return testCase.copyWith(healingDecision: decision);
    }).toList();

    _updateState(
      state.copyWith(
        generatedTests: updatedTests,
        statusMessage:
            'Healing decisions updated. Approved: ${updatedTests.where((t) => t.healingDecision == TestHealingDecision.approved).length}, '
            'Rejected: ${updatedTests.where((t) => t.healingDecision == TestHealingDecision.rejected).length}',
        clearErrorMessage: true,
      ),
    );
  }

  List<AgenticTestCase> _mergeUpdatedTests(
    List<AgenticTestCase> original,
    List<AgenticTestCase> updates,
  ) {
    final updatesById = {for (final item in updates) item.id: item};
    return original.map((testCase) {
      return updatesById[testCase.id] ?? testCase;
    }).toList();
  }

  List<AgenticTestCase> _resetExecutionAndHealing(List<AgenticTestCase> tests) {
    return tests
        .map(
          (testCase) => testCase.copyWith(
            executionStatus: TestExecutionStatus.notRun,
            clearExecutionSummary: true,
            assertionReport: const <String>[],
            clearResponseStatusCode: true,
            clearResponseTimeMs: true,
            failureType: TestFailureType.none,
            clearHealingSuggestion: true,
            healingAssertions: const <String>[],
            healingDecision: TestHealingDecision.none,
            healingIteration: 0,
          ),
        )
        .toList();
  }

  String _buildExecutionSummary(List<AgenticTestCase> tests) {
    final passed = _countExecutionStatus(tests, TestExecutionStatus.passed);
    final failed = _countExecutionStatus(tests, TestExecutionStatus.failed);
    final skipped = _countExecutionStatus(tests, TestExecutionStatus.skipped);
    return 'Passed: $passed Failed: $failed Skipped: $skipped';
  }

  int _countExecutionStatus(
    List<AgenticTestCase> tests,
    TestExecutionStatus status,
  ) {
    return tests.where((testCase) => testCase.executionStatus == status).length;
  }

  int _pendingCount(List<AgenticTestCase> tests) {
    return tests
        .where((testCase) => testCase.decision == TestReviewDecision.pending)
        .length;
  }

  bool _requireState(AgenticWorkflowState expected) {
    if (state.workflowState != expected) {
      _updateState(
        state.copyWith(
          errorMessage:
              'Invalid action for current state ${state.workflowState.label}.',
        ),
      );
      return false;
    }
    return true;
  }

  void _updateState(AgenticWorkflowContext next) {
    state = next;
    unawaited(_checkpointStorage.save(next));
  }

  void _transitionTo(
    AgenticWorkflowState nextState, {
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
    final current = state.workflowState;
    if (current != nextState) {
      final allowed = _allowedTransitions[current] ?? const {};
      if (!allowed.contains(nextState)) {
        throw InvalidWorkflowTransitionException(current, nextState);
      }
    }

    _updateState(
      state.copyWith(
        workflowState: nextState,
        endpoint: endpoint,
        requestMethod: requestMethod,
        requestHeaders: requestHeaders,
        requestBody: requestBody,
        clearRequestBody: clearRequestBody,
        generationPrompt: generationPrompt,
        clearGenerationPrompt: clearGenerationPrompt,
        generatedTests: generatedTests,
        statusMessage: statusMessage,
        clearStatusMessage: clearStatusMessage,
        errorMessage: errorMessage,
        clearErrorMessage: clearErrorMessage,
      ),
    );
  }
}
