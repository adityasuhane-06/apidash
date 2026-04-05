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
        healingSuggestion: 'Retry after fixes; keep assertions unchanged',
        healingAssertions: const <String>['status code equals 200'],
        healingDecision: TestHealingDecision.pending,
      );
    }).toList();
  }
}

class _InMemoryCheckpointStorage extends AgenticWorkflowCheckpointStorage {
  AgenticWorkflowContext? _saved;
  final Map<String, AgenticWorkflowContext> _scoped = {};

  @override
  Future<void> save(AgenticWorkflowContext context) async {
    _saved = context;
  }

  @override
  Future<void> saveForSession({
    required String sessionKey,
    required AgenticWorkflowContext context,
  }) async {
    _scoped[sessionKey] = context;
  }

  @override
  Future<AgenticWorkflowContext?> load() async {
    return _saved;
  }

  @override
  Future<AgenticWorkflowContext?> loadForSession({
    required String sessionKey,
  }) async {
    return _scoped[sessionKey];
  }

  @override
  Future<void> clear() async {
    _saved = null;
    _scoped.clear();
  }

  @override
  Future<void> clearForSession({required String sessionKey}) async {
    _scoped.remove(sessionKey);
  }
}

void main() {
  group('AgenticTestingStateMachine', () {
    AgenticTestingStateMachine buildMachine({
      required _FakeGenerator generator,
      required _FakeExecutor executor,
      _FakeHealingPlanner? planner,
      _InMemoryCheckpointStorage? storage,
      String checkpointSessionKey =
          AgenticWorkflowCheckpointStorage.defaultSessionKey,
    }) {
      return AgenticTestingStateMachine(
        testGenerator: generator,
        testExecutor: executor,
        healingPlanner: planner ?? _FakeHealingPlanner(),
        checkpointStorage: storage ?? _InMemoryCheckpointStorage(),
        checkpointSessionKey: checkpointSessionKey,
      );
    }

    test('moves to awaiting approval after generation', () async {
      final machine = buildMachine(
        generator: _FakeGenerator([
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
        executor: _FakeExecutor(
          ({required tests, required defaultHeaders, requestBody}) async =>
              tests,
        ),
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
      final machine = buildMachine(
        generator: _FakeGenerator([
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
        executor: _FakeExecutor(
          ({required tests, required defaultHeaders, requestBody}) async =>
              tests,
        ),
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
      final machine = buildMachine(
        generator: _FakeGenerator([
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
        executor: _FakeExecutor(
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
      final machine = buildMachine(
        generator: _FakeGenerator([
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
        executor: _FakeExecutor(
          ({required tests, required defaultHeaders, requestBody}) async =>
              tests,
        ),
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

    test('adds custom test draft during awaiting approval', () async {
      final machine = buildMachine(
        generator: _FakeGenerator([
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
        executor: _FakeExecutor(
          ({required tests, required defaultHeaders, requestBody}) async =>
              tests,
        ),
      );

      await machine.startGeneration(endpoint: 'https://api.apidash.dev/users');
      machine.addTestCaseDraft(
        title: 'Custom email format',
        assertions: const ['email should match regex'],
      );

      expect(machine.state.generatedTests.length, 2);
      expect(machine.state.generatedTests.last.title, 'Custom email format');
      expect(
        machine.state.generatedTests.last.decision,
        TestReviewDecision.pending,
      );
      expect(machine.state.statusMessage, contains('Added custom test case'));
    });

    test('hydrates from checkpoint storage', () async {
      final storage = _InMemoryCheckpointStorage();
      await storage.saveForSession(
        sessionKey: 'r1',
        context: const AgenticWorkflowContext(
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

      final machine = buildMachine(
        generator: _FakeGenerator(const <AgenticTestCase>[]),
        executor: _FakeExecutor(
          ({required tests, required defaultHeaders, requestBody}) async =>
              tests,
        ),
        storage: storage,
        checkpointSessionKey: 'r1',
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

    test('checkpoint scope is isolated per session key', () async {
      final storage = _InMemoryCheckpointStorage();
      await storage.saveForSession(
        sessionKey: 'rA',
        context: const AgenticWorkflowContext(
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

      final machineA = buildMachine(
        generator: _FakeGenerator(const <AgenticTestCase>[]),
        executor: _FakeExecutor(
          ({required tests, required defaultHeaders, requestBody}) async =>
              tests,
        ),
        storage: storage,
        checkpointSessionKey: 'rA',
      );

      final machineB = buildMachine(
        generator: _FakeGenerator(const <AgenticTestCase>[]),
        executor: _FakeExecutor(
          ({required tests, required defaultHeaders, requestBody}) async =>
              tests,
        ),
        storage: storage,
        checkpointSessionKey: 'rB',
      );

      await machineA.hydrateFromCheckpoint();
      await machineB.hydrateFromCheckpoint();

      expect(machineA.state.workflowState, AgenticWorkflowState.resultsReady);
      expect(machineB.state.workflowState, AgenticWorkflowState.idle);
    });

    test('generates healing plans for failed tests', () async {
      final machine = buildMachine(
        generator: _FakeGenerator([
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
        executor: _FakeExecutor(
          ({required tests, required defaultHeaders, requestBody}) async =>
              tests
                  .map(
                    (t) => t.copyWith(
                      executionStatus: TestExecutionStatus.failed,
                      failureType: TestFailureType.statusCodeMismatch,
                      responseStatusCode: 500,
                    ),
                  )
                  .toList(),
        ),
      );

      await machine.startGeneration(endpoint: 'https://api.apidash.dev/users');
      machine.approveAll();
      await machine.executeApprovedTests();
      await machine.generateHealingPlans();

      expect(
        machine.state.workflowState,
        AgenticWorkflowState.awaitingHealApproval,
      );
      expect(machine.state.healPendingCount, 1);
    });

    test(
      're-executes approved healed tests without mutating assertions',
      () async {
        var firstRun = true;
        List<AgenticTestCase>? secondRunInput;
        final machine = buildMachine(
          generator: _FakeGenerator([
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
          executor: _FakeExecutor(({
            required tests,
            required defaultHeaders,
            requestBody,
          }) async {
            if (firstRun) {
              firstRun = false;
              return tests
                  .map(
                    (t) => t.copyWith(
                      executionStatus: TestExecutionStatus.failed,
                      failureType: TestFailureType.statusCodeMismatch,
                      responseStatusCode: 500,
                    ),
                  )
                  .toList();
            }
            secondRunInput = tests;
            return tests
                .map(
                  (t) => t.copyWith(
                    executionStatus: TestExecutionStatus.passed,
                    failureType: TestFailureType.none,
                    responseStatusCode: 200,
                  ),
                )
                .toList();
          }),
        );

        await machine.startGeneration(
          endpoint: 'https://api.apidash.dev/users',
        );
        machine.approveAll();
        await machine.executeApprovedTests();
        await machine.generateHealingPlans();
        machine.approveAllHealing();
        await machine.reExecuteHealedTests();

        expect(machine.state.workflowState, AgenticWorkflowState.finalReport);
        expect(machine.state.passedCount, 1);
        expect(machine.state.healAppliedCount, 1);
        expect(secondRunInput, isNotNull);
        expect(secondRunInput!.single.assertions, ['status_code equals 200']);
        expect(
          secondRunInput!.single.assertions,
          isNot(equals(secondRunInput!.single.healingAssertions)),
        );
      },
    );

    test('allows skipping healing rerun directly to final report', () async {
      final machine = buildMachine(
        generator: _FakeGenerator([
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
        executor: _FakeExecutor(
          ({required tests, required defaultHeaders, requestBody}) async =>
              tests
                  .map(
                    (t) => t.copyWith(
                      executionStatus: TestExecutionStatus.failed,
                      failureType: TestFailureType.statusCodeMismatch,
                      responseStatusCode: 500,
                    ),
                  )
                  .toList(),
        ),
      );

      await machine.startGeneration(endpoint: 'https://api.apidash.dev/users');
      machine.approveAll();
      await machine.executeApprovedTests();
      await machine.generateHealingPlans();
      machine.skipHealingRerunToFinalReport();

      expect(machine.state.workflowState, AgenticWorkflowState.finalReport);
      expect(
        machine.state.statusMessage,
        contains('Healing re-run skipped by user'),
      );
    });
  });
}
