import 'package:apidash/agentic_testing/agentic_testing.dart';
import 'package:test/test.dart';

typedef _ExecuteHandler =
    Future<List<AgenticTestCase>> Function({
      required List<AgenticTestCase> tests,
      required Map<String, String> defaultHeaders,
      String? requestBody,
    });

class _FakeGenerator extends AgenticTestGenerator {
  _FakeGenerator(this.output) : super(readDefaultModel: () => const {});

  final List<AgenticTestCase> output;

  @override
  Future<List<AgenticTestCase>> generateTests({
    required String endpoint,
    String? method,
    Map<String, String>? headers,
    String? requestBody,
    String? generationPrompt,
    AgenticContractContext? contractContext,
  }) async {
    return output;
  }
}

class _FakeExecutor extends AgenticTestExecutor {
  _FakeExecutor(this.handler);

  final _ExecuteHandler handler;

  @override
  Future<List<AgenticTestCase>> executeTests({
    required List<AgenticTestCase> tests,
    required Map<String, String> defaultHeaders,
    String? requestBody,
  }) {
    return handler(
      tests: tests,
      defaultHeaders: defaultHeaders,
      requestBody: requestBody,
    );
  }
}

class _FakeHealingPlanner extends AgenticTestHealingPlanner {
  @override
  List<AgenticTestCase> generateHealingPlans({
    required List<AgenticTestCase> tests,
  }) {
    return tests.map((testCase) {
      if (testCase.executionStatus != TestExecutionStatus.failed) {
        return testCase;
      }
      return testCase.copyWith(
        healingSuggestion: 'Investigate and retry with unchanged assertions.',
        healingAssertions: const <String>['status_code equals 200'],
        healingDecision: TestHealingDecision.pending,
      );
    }).toList();
  }
}

void main() {
  group('AgenticTestingMcpAdapter', () {
    test('runs generate -> review -> execute and returns app-aware snapshots',
        () async {
      final adapter = AgenticTestingMcpAdapterImpl(
        testGenerator: _FakeGenerator([
          const AgenticTestCase(
            id: 't1',
            title: 'Status is 200',
            description: 'Basic check',
            method: 'GET',
            endpoint: 'https://api.apidash.dev/users',
            expectedOutcome: 'Success',
            assertions: ['status_code equals 200'],
          ),
        ]),
        testExecutor: _FakeExecutor(
          ({required tests, required defaultHeaders, requestBody}) async =>
              tests
                  .map(
                    (testCase) => testCase.copyWith(
                      executionStatus:
                          testCase.decision == TestReviewDecision.approved
                          ? TestExecutionStatus.passed
                          : TestExecutionStatus.skipped,
                      failureType: TestFailureType.none,
                    ),
                  )
                  .toList(),
        ),
        healingPlanner: _FakeHealingPlanner(),
      );

      final generated = await adapter.generateTests(
        const GenerateTestsInput(
          sessionId: 'sess_a',
          endpoint: 'https://api.apidash.dev/users',
        ),
      );
      expect(generated.workflowState, AgenticWorkflowState.awaitingApproval);
      expect(generated.generatedCount, 1);
      expect(generated.mcpAppResourceUri, AgenticMcpAppResources.testReviewUri);

      final reviewed = await adapter.applyReviewDecision(
        const ReviewDecisionInput(
          sessionId: 'sess_a',
          bulkDecision: AgenticBulkDecision.approveAll,
        ),
      );
      expect(reviewed.approvedCount, 1);
      expect(reviewed.pendingCount, 0);

      final executed = await adapter.runApproved(
        const RunApprovedInput(sessionId: 'sess_a'),
      );
      expect(executed.workflowState, AgenticWorkflowState.resultsReady);
      expect(executed.passedCount, 1);
      expect(
        executed.mcpAppResourceUri,
        AgenticMcpAppResources.executionResultsUri,
      );
    });

    test(
      'supports healing flow and skip-to-final-report when no healed approvals',
      () async {
        final adapter = AgenticTestingMcpAdapterImpl(
          testGenerator: _FakeGenerator([
            const AgenticTestCase(
              id: 't1',
              title: 'Status is 200',
              description: 'Basic check',
              method: 'GET',
              endpoint: 'https://api.apidash.dev/users',
              expectedOutcome: 'Success',
              assertions: ['status_code equals 200'],
            ),
          ]),
          testExecutor: _FakeExecutor(
            ({required tests, required defaultHeaders, requestBody}) async =>
                tests
                    .map(
                      (testCase) => testCase.copyWith(
                        executionStatus: TestExecutionStatus.failed,
                        failureType: TestFailureType.statusCodeMismatch,
                        responseStatusCode: 500,
                      ),
                    )
                    .toList(),
          ),
          healingPlanner: _FakeHealingPlanner(),
        );

        await adapter.generateTests(
          const GenerateTestsInput(
            sessionId: 'sess_heal',
            endpoint: 'https://api.apidash.dev/users',
          ),
        );
        await adapter.applyReviewDecision(
          const ReviewDecisionInput(
            sessionId: 'sess_heal',
            bulkDecision: AgenticBulkDecision.approveAll,
          ),
        );
        await adapter.runApproved(const RunApprovedInput(sessionId: 'sess_heal'));

        final healing = await adapter.generateHealing(
          const GenerateHealingInput(sessionId: 'sess_heal'),
        );
        expect(healing.workflowState, AgenticWorkflowState.awaitingHealApproval);
        expect(healing.healPendingCount, 1);
        expect(healing.mcpAppResourceUri, AgenticMcpAppResources.healingReviewUri);

        await adapter.applyHealingDecision(
          const HealingDecisionInput(
            sessionId: 'sess_heal',
            bulkDecision: AgenticBulkDecision.rejectAll,
          ),
        );
        final rerun = await adapter.rerunHealed(
          const RerunHealedInput(sessionId: 'sess_heal', skipIfNoApproved: true),
        );

        expect(rerun.workflowState, AgenticWorkflowState.finalReport);
        expect(rerun.policy, 'strict_no_assertion_mutation');
        expect(rerun.mcpAppResourceUri, AgenticMcpAppResources.finalReportUri);
      },
    );

    test('keeps sessions isolated and supports reset', () async {
      final adapter = AgenticTestingMcpAdapterImpl(
        testGenerator: _FakeGenerator([
          const AgenticTestCase(
            id: 't1',
            title: 'Status is 200',
            description: 'Basic check',
            method: 'GET',
            endpoint: 'https://api.apidash.dev/users',
            expectedOutcome: 'Success',
            assertions: ['status_code equals 200'],
          ),
        ]),
        testExecutor: _FakeExecutor(
          ({required tests, required defaultHeaders, requestBody}) async =>
              tests,
        ),
        healingPlanner: _FakeHealingPlanner(),
      );

      await adapter.generateTests(
        const GenerateTestsInput(
          sessionId: 'sess_1',
          endpoint: 'https://api.apidash.dev/users',
        ),
      );
      await adapter.generateTests(
        const GenerateTestsInput(
          sessionId: 'sess_2',
          endpoint: 'https://api.apidash.dev/users',
        ),
      );
      await adapter.applyReviewDecision(
        const ReviewDecisionInput(
          sessionId: 'sess_1',
          bulkDecision: AgenticBulkDecision.approveAll,
        ),
      );

      final s1 = await adapter.getSnapshot('sess_1');
      final s2 = await adapter.getSnapshot('sess_2');
      expect(s1.approvedCount, 1);
      expect(s2.approvedCount, 0);
      expect(s2.pendingCount, 1);

      await adapter.reset('sess_1');
      final resetS1 = await adapter.getSnapshot('sess_1');
      expect(resetS1.workflowState, AgenticWorkflowState.idle);
      expect(resetS1.generatedCount, 0);

      final untouchedS2 = await adapter.getSnapshot('sess_2');
      expect(untouchedS2.generatedCount, 1);
      expect(untouchedS2.pendingCount, 1);
    });
  });
}
