import 'package:apidash/agentic_testing/agentic_testing.dart';
import 'package:apidash/dashbot/models/agent_loop_session.dart';
import 'package:apidash/dashbot/services/agent/agent_loop_coordinator.dart';
import 'package:test/test.dart';

typedef _ExecuteHandler =
    Future<List<AgenticTestCase>> Function({
      required List<AgenticTestCase> tests,
      required Map<String, String> defaultHeaders,
      String? requestBody,
    });

class _FakeGenerator extends AgenticTestGenerator {
  _FakeGenerator({this.tests = const <AgenticTestCase>[]})
    : super(readDefaultModel: () => const {});

  final List<AgenticTestCase> tests;

  @override
  Future<List<AgenticTestCase>> generateTests({
    required String endpoint,
    String? method,
    Map<String, String>? headers,
    String? requestBody,
    String? generationPrompt,
    AgenticContractContext? contractContext,
  }) async {
    return tests;
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
    return tests;
  }
}

class _InMemoryCheckpointStorage extends AgenticWorkflowCheckpointStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<AgenticWorkflowContext?> load() async => null;

  @override
  Future<void> save(AgenticWorkflowContext context) async {}
}

void main() {
  group('AgentLoopCoordinator', () {
    final coordinator = AgentLoopCoordinatorImpl();

    test('createPlan returns canonical ordered steps', () {
      final suggested = AgentExecutionPlan(
        goal: 'custom goal',
        source: 'llm',
        steps: const [
          AgentPlanStep(
            type: AgentPlanStepType.execute,
            intent: 'run tests',
            risky: true,
          ),
          AgentPlanStep(
            type: AgentPlanStepType.generate,
            intent: 'generate first',
          ),
        ],
      );

      final plan = coordinator.createPlan(
        goal: 'fallback goal',
        suggested: suggested,
        source: 'fallback',
      );

      expect(plan.goal, 'custom goal');
      expect(plan.steps.map((s) => s.type).toList(), [
        AgentPlanStepType.generate,
        AgentPlanStepType.review,
        AgentPlanStepType.execute,
        AgentPlanStepType.analyze,
        AgentPlanStepType.healReview,
        AgentPlanStepType.rerun,
        AgentPlanStepType.report,
      ]);
      expect(plan.steps.first.intent, 'generate first');
      expect(plan.steps[2].intent, 'run tests');
      expect(
        plan.steps.every((step) => step.status == AgentPlanStepStatus.pending),
        isTrue,
      );
    });

    test('approve and reject update stage correctly', () {
      final base = AgentLoopSession(
        requestId: 'r1',
        stage: AgentLoopStage.planReady,
        plan: coordinator.createPlan(goal: 'goal'),
      );

      final approved = coordinator.approvePlan(session: base);
      expect(approved.session.stage, AgentLoopStage.awaitingApproval);

      final rejected = coordinator.rejectPlan(session: base);
      expect(rejected.session.stage, AgentLoopStage.idle);
      expect(rejected.session.plan, isNull);
    });

    test('submitSatisfaction yes completes, no resets with follow-up', () {
      final base = AgentLoopSession(
        requestId: 'r1',
        stage: AgentLoopStage.awaitingSatisfaction,
        plan: coordinator.createPlan(goal: 'goal'),
      );

      final yes = coordinator.submitSatisfaction(
        session: base,
        satisfied: true,
      );
      expect(yes.session.stage, AgentLoopStage.completed);
      expect(yes.session.plan, isNotNull);

      final no = coordinator.submitSatisfaction(
        session: base,
        satisfied: false,
        followUpPrompt: 'Need better failure analysis',
      );
      expect(no.session.stage, AgentLoopStage.idle);
      expect(no.session.plan, isNull);
      expect(no.session.followUpPrompt, 'Need better failure analysis');
    });

    test('skipCurrentStep marks current step skipped', () async {
      final machine = AgenticTestingStateMachine(
        testGenerator: _FakeGenerator(),
        testExecutor: _FakeExecutor(
          ({required tests, required defaultHeaders, requestBody}) async =>
              tests,
        ),
        healingPlanner: _FakeHealingPlanner(),
        checkpointStorage: _InMemoryCheckpointStorage(),
      );

      final session = AgentLoopSession(
        requestId: 'r1',
        stage: AgentLoopStage.awaitingApproval,
        plan: coordinator.createPlan(goal: 'goal'),
      );

      final result = await coordinator.skipCurrentStep(
        session: session,
        machine: machine,
      );

      expect(result.session.plan, isNotNull);
      expect(
        result.session.plan!.steps.first.status,
        AgentPlanStepStatus.skipped,
      );
      expect(result.session.stage, AgentLoopStage.awaitingApproval);
    });

    test(
      'executeNextStep blocks review step when pending tests remain',
      () async {
        final machine = AgenticTestingStateMachine(
          testGenerator: _FakeGenerator(
            tests: const [
              AgenticTestCase(
                id: 't1',
                title: 'T1',
                description: 'desc',
                method: 'GET',
                endpoint: '/users',
                expectedOutcome: 'ok',
                assertions: ['status 200'],
              ),
            ],
          ),
          testExecutor: _FakeExecutor(
            ({required tests, required defaultHeaders, requestBody}) async =>
                tests,
          ),
          healingPlanner: _FakeHealingPlanner(),
          checkpointStorage: _InMemoryCheckpointStorage(),
        );

        await machine.startGeneration(
          endpoint: 'https://api.apidash.dev/users',
        );

        final initialPlan = coordinator.createPlan(goal: 'goal');
        final plan = initialPlan.copyWith(
          steps: [
            initialPlan.steps[0].copyWith(
              status: AgentPlanStepStatus.completed,
            ),
            ...initialPlan.steps.sublist(1),
          ],
        );
        final session = AgentLoopSession(
          requestId: 'r1',
          stage: AgentLoopStage.awaitingApproval,
          plan: plan,
        );

        final result = await coordinator.executeNextStep(
          session: session,
          context: const AgentLoopExecutionContext(
            endpoint: 'https://api.apidash.dev/users',
            method: 'GET',
            headers: {},
          ),
          machine: machine,
        );

        expect(result.message, contains('Review is still pending'));
        expect(
          result.session.plan?.currentStep?.type,
          AgentPlanStepType.review,
        );
        expect(
          result.session.plan?.currentStep?.status,
          AgentPlanStepStatus.pending,
        );
      },
    );

    test(
      'executeNextStep generate step resets non-idle workflow before regenerating',
      () async {
        final machine = AgenticTestingStateMachine(
          testGenerator: _FakeGenerator(
            tests: const [
              AgenticTestCase(
                id: 'regen',
                title: 'regenerated',
                description: 'new suite',
                method: 'GET',
                endpoint: '/users/1',
                expectedOutcome: 'ok',
                assertions: ['status 200'],
              ),
            ],
          ),
          testExecutor: _FakeExecutor(
            ({required tests, required defaultHeaders, requestBody}) async =>
                tests,
          ),
          healingPlanner: _FakeHealingPlanner(),
          checkpointStorage: _InMemoryCheckpointStorage(),
        );

        await machine.startGeneration(
          endpoint: 'https://api.apidash.dev/users',
        );
        expect(
          machine.state.workflowState,
          AgenticWorkflowState.awaitingApproval,
        );
        expect(machine.state.generatedTests.length, 1);

        final session = AgentLoopSession(
          requestId: 'r1',
          stage: AgentLoopStage.awaitingApproval,
          plan: coordinator.createPlan(goal: 'regenerate tests'),
        );

        final result = await coordinator.executeNextStep(
          session: session,
          context: const AgentLoopExecutionContext(
            endpoint: 'https://api.apidash.dev/users/1',
            method: 'GET',
            headers: {},
          ),
          machine: machine,
        );

        expect(
          result.session.plan?.steps.first.status,
          AgentPlanStepStatus.completed,
        );
        expect(
          machine.state.workflowState,
          AgenticWorkflowState.awaitingApproval,
        );
        expect(machine.state.generatedTests.length, 1);
        expect(machine.state.endpoint, 'https://api.apidash.dev/users/1');
        expect(machine.state.generatedTests.first.endpoint, '/users/1');
      },
    );

    test('execute step fails when no approved tests are selected', () async {
      final machine = AgenticTestingStateMachine(
        testGenerator: _FakeGenerator(
          tests: const [
            AgenticTestCase(
              id: 't1',
              title: 'pending review',
              description: 'desc',
              method: 'GET',
              endpoint: '/users',
              expectedOutcome: 'ok',
              assertions: ['status 200'],
            ),
          ],
        ),
        testExecutor: _FakeExecutor(
          ({required tests, required defaultHeaders, requestBody}) async =>
              tests,
        ),
        healingPlanner: _FakeHealingPlanner(),
        checkpointStorage: _InMemoryCheckpointStorage(),
      );

      await machine.startGeneration(endpoint: 'https://api.apidash.dev/users');
      expect(
        machine.state.workflowState,
        AgenticWorkflowState.awaitingApproval,
      );
      expect(machine.state.approvedCount, 0);

      final basePlan = coordinator.createPlan(goal: 'goal');
      final executePlan = basePlan.copyWith(
        steps: [
          basePlan.steps[0].copyWith(status: AgentPlanStepStatus.completed),
          basePlan.steps[1].copyWith(status: AgentPlanStepStatus.completed),
          ...basePlan.steps.sublist(2),
        ],
      );
      final session = AgentLoopSession(
        requestId: 'r1',
        stage: AgentLoopStage.awaitingApproval,
        plan: executePlan,
      );

      final result = await coordinator.executeNextStep(
        session: session,
        context: const AgentLoopExecutionContext(
          endpoint: 'https://api.apidash.dev/users',
          method: 'GET',
          headers: {},
        ),
        machine: machine,
      );

      expect(result.message, contains('Approve at least one test case'));
      expect(result.session.plan?.steps[2].status, AgentPlanStepStatus.failed);
      expect(result.session.stage, AgentLoopStage.awaitingApproval);
      expect(
        machine.state.workflowState,
        AgenticWorkflowState.awaitingApproval,
      );
    });
  });
}
