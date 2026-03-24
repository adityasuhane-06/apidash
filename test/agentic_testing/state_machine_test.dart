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

class _InMemoryCheckpointStorage extends AgenticWorkflowCheckpointStorage {
  AgenticWorkflowContext? _saved;

  @override
  Future<void> save(AgenticWorkflowContext context) async {
    _saved = context;
  }

  @override
  Future<AgenticWorkflowContext?> load() async {
    return _saved;
  }

  @override
  Future<void> clear() async {
    _saved = null;
  }
}

void main() {
  group('AgenticTestingStateMachine', () {
    test('moves to awaiting approval after generation', () async {
      final storage = _InMemoryCheckpointStorage();
      final machine = AgenticTestingStateMachine(
        testGenerator: _FakeGenerator([
          const AgenticTestCase(
            id: 't1',
            title: 'Status is 200',
            description: 'Basic success check',
            method: 'GET',
            endpoint: 'https://api.apidash.dev/users',
            expectedOutcome: 'Returns success',
            assertions: ['status_code equals 200'],
          ),
        ]),
        testExecutor: _FakeExecutor(
          ({required tests, required defaultHeaders, requestBody}) async =>
              tests,
        ),
        checkpointStorage: storage,
      );

      await machine.startGeneration(endpoint: 'https://api.apidash.dev/users');

      expect(
        machine.state.workflowState,
        AgenticWorkflowState.awaitingApproval,
      );
      expect(machine.state.generatedTests, hasLength(1));
      expect(machine.state.pendingCount, 1);
    });

    test('stores generation prompt in workflow context', () async {
      final storage = _InMemoryCheckpointStorage();
      final machine = AgenticTestingStateMachine(
        testGenerator: _FakeGenerator([
          const AgenticTestCase(
            id: 't1',
            title: 'Status is 200',
            description: 'Basic success check',
            method: 'GET',
            endpoint: 'https://api.apidash.dev/users',
            expectedOutcome: 'Returns success',
            assertions: ['status_code equals 200'],
          ),
        ]),
        testExecutor: _FakeExecutor(
          ({required tests, required defaultHeaders, requestBody}) async =>
              tests,
        ),
        checkpointStorage: storage,
      );

      await machine.startGeneration(
        endpoint: 'https://api.apidash.dev/users',
        generationPrompt: 'Focus on authentication and rate limits',
      );

      expect(
        machine.state.generationPrompt,
        'Focus on authentication and rate limits',
      );
    });

    test('executes approved tests and moves to results ready', () async {
      final storage = _InMemoryCheckpointStorage();
      final machine = AgenticTestingStateMachine(
        testGenerator: _FakeGenerator([
          const AgenticTestCase(
            id: 't1',
            title: 'Status is 200',
            description: 'Basic success check',
            method: 'GET',
            endpoint: 'https://api.apidash.dev/users',
            expectedOutcome: 'Returns success',
            assertions: ['status_code equals 200'],
          ),
          const AgenticTestCase(
            id: 't2',
            title: 'Body not empty',
            description: 'Ensure response payload exists',
            method: 'GET',
            endpoint: 'https://api.apidash.dev/users',
            expectedOutcome: 'Returns data',
            assertions: ['response body is not empty'],
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
                      executionSummary:
                          testCase.decision == TestReviewDecision.approved
                          ? 'Passed 1/1 checks.'
                          : 'Skipped because test is not approved.',
                    ),
                  )
                  .toList(),
        ),
        checkpointStorage: storage,
      );

      await machine.startGeneration(endpoint: 'https://api.apidash.dev/users');
      machine.approveAll();
      await machine.executeApprovedTests();

      expect(machine.state.workflowState, AgenticWorkflowState.resultsReady);
      expect(machine.state.approvedCount, 2);
      expect(machine.state.passedCount, 2);
      expect(machine.state.failedCount, 0);
    });

    test('shows error if executing without approved tests', () async {
      final storage = _InMemoryCheckpointStorage();
      final machine = AgenticTestingStateMachine(
        testGenerator: _FakeGenerator([
          const AgenticTestCase(
            id: 't1',
            title: 'Status is 200',
            description: 'Basic success check',
            method: 'GET',
            endpoint: 'https://api.apidash.dev/users',
            expectedOutcome: 'Returns success',
            assertions: ['status_code equals 200'],
          ),
        ]),
        testExecutor: _FakeExecutor(
          ({required tests, required defaultHeaders, requestBody}) async =>
              tests,
        ),
        checkpointStorage: storage,
      );

      await machine.startGeneration(endpoint: 'https://api.apidash.dev/users');
      await machine.executeApprovedTests();

      expect(
        machine.state.workflowState,
        AgenticWorkflowState.awaitingApproval,
      );
      expect(
        machine.state.errorMessage,
        contains('Approve at least one test case'),
      );
    });

    test('hydrates from checkpoint storage', () async {
      final storage = _InMemoryCheckpointStorage();
      await storage.save(
        const AgenticWorkflowContext(
          workflowState: AgenticWorkflowState.resultsReady,
          endpoint: 'https://api.apidash.dev/users',
          requestMethod: 'GET',
          generatedTests: <AgenticTestCase>[
            AgenticTestCase(
              id: 't1',
              title: 'Stored test',
              description: 'restored from checkpoint',
              method: 'GET',
              endpoint: 'https://api.apidash.dev/users',
              expectedOutcome: 'works',
              assertions: <String>['status_code equals 200'],
              decision: TestReviewDecision.approved,
              executionStatus: TestExecutionStatus.passed,
            ),
          ],
        ),
      );

      final machine = AgenticTestingStateMachine(
        testGenerator: _FakeGenerator(const <AgenticTestCase>[]),
        testExecutor: _FakeExecutor(
          ({required tests, required defaultHeaders, requestBody}) async =>
              tests,
        ),
        checkpointStorage: storage,
      );

      await machine.hydrateFromCheckpoint();

      expect(machine.state.workflowState, AgenticWorkflowState.resultsReady);
      expect(machine.state.endpoint, 'https://api.apidash.dev/users');
      expect(machine.state.generatedTests, hasLength(1));
      expect(
        machine.state.generatedTests.first.executionStatus,
        TestExecutionStatus.passed,
      );
    });
  });
}
