import '../models/workflow_context.dart';
import '../models/workflow_state.dart';
import '../services/healing_planner.dart';
import '../services/state_machine.dart';
import '../services/test_executor.dart';
import '../services/test_generator.dart';
import '../services/workflow_checkpoint_storage.dart';
import 'models.dart';

abstract class AgenticTestingMcpAdapter {
  Future<AgenticWorkflowSnapshot> generateTests(GenerateTestsInput input);

  Future<AgenticWorkflowSnapshot> applyReviewDecision(
    ReviewDecisionInput input,
  );

  Future<AgenticWorkflowSnapshot> runApproved(RunApprovedInput input);

  Future<AgenticWorkflowSnapshot> generateHealing(GenerateHealingInput input);

  Future<AgenticWorkflowSnapshot> applyHealingDecision(
    HealingDecisionInput input,
  );

  Future<AgenticWorkflowSnapshot> rerunHealed(RerunHealedInput input);

  Future<AgenticWorkflowSnapshot> getSnapshot(String sessionId);

  Future<void> reset(String sessionId);
}

class AgenticTestingMcpAdapterImpl implements AgenticTestingMcpAdapter {
  AgenticTestingMcpAdapterImpl({
    required AgenticTestGenerator testGenerator,
    required AgenticTestExecutor testExecutor,
    required AgenticTestHealingPlanner healingPlanner,
  }) : _testGenerator = testGenerator,
       _testExecutor = testExecutor,
       _healingPlanner = healingPlanner;

  final AgenticTestGenerator _testGenerator;
  final AgenticTestExecutor _testExecutor;
  final AgenticTestHealingPlanner _healingPlanner;

  final Map<String, AgenticTestingStateMachine> _sessions =
      <String, AgenticTestingStateMachine>{};
  final Map<String, _SessionCheckpointStorage> _checkpointStores =
      <String, _SessionCheckpointStorage>{};

  @override
  Future<AgenticWorkflowSnapshot> generateTests(
    GenerateTestsInput input,
  ) async {
    final machine = _ensureSession(input.sessionId);
    await machine.startGeneration(
      endpoint: input.endpoint,
      method: input.method,
      headers: input.headers,
      requestBody: input.requestBody,
      generationPrompt: input.generationPrompt,
      contractContext: input.contractContext,
    );
    return _snapshot(input.sessionId, machine.state);
  }

  @override
  Future<AgenticWorkflowSnapshot> applyReviewDecision(
    ReviewDecisionInput input,
  ) async {
    final machine = _ensureSession(input.sessionId);

    switch (input.bulkDecision) {
      case AgenticBulkDecision.none:
        for (final update in input.decisions) {
          if (update.decision == AgenticDecisionValue.approved) {
            machine.approveTest(update.testId);
          } else {
            machine.rejectTest(update.testId);
          }
        }
        break;
      case AgenticBulkDecision.approveAll:
        machine.approveAll();
        break;
      case AgenticBulkDecision.rejectAll:
        machine.rejectAll();
        break;
    }

    return _snapshot(input.sessionId, machine.state);
  }

  @override
  Future<AgenticWorkflowSnapshot> runApproved(RunApprovedInput input) async {
    final machine = _ensureSession(input.sessionId);
    await machine.executeApprovedTests();
    return _snapshot(input.sessionId, machine.state);
  }

  @override
  Future<AgenticWorkflowSnapshot> generateHealing(
    GenerateHealingInput input,
  ) async {
    final machine = _ensureSession(input.sessionId);
    await machine.generateHealingPlans();
    return _snapshot(input.sessionId, machine.state);
  }

  @override
  Future<AgenticWorkflowSnapshot> applyHealingDecision(
    HealingDecisionInput input,
  ) async {
    final machine = _ensureSession(input.sessionId);

    switch (input.bulkDecision) {
      case AgenticBulkDecision.none:
        for (final update in input.decisions) {
          if (update.decision == AgenticDecisionValue.approved) {
            machine.approveHealing(update.testId);
          } else {
            machine.rejectHealing(update.testId);
          }
        }
        break;
      case AgenticBulkDecision.approveAll:
        machine.approveAllHealing();
        break;
      case AgenticBulkDecision.rejectAll:
        machine.rejectAllHealing();
        break;
    }

    return _snapshot(input.sessionId, machine.state);
  }

  @override
  Future<AgenticWorkflowSnapshot> rerunHealed(RerunHealedInput input) async {
    final machine = _ensureSession(input.sessionId);

    final shouldSkipToReport =
        input.skipIfNoApproved &&
        machine.state.workflowState ==
            AgenticWorkflowState.awaitingHealApproval &&
        machine.state.healApprovedCount == 0;

    if (shouldSkipToReport) {
      machine.skipHealingRerunToFinalReport();
    } else {
      await machine.reExecuteHealedTests();
    }

    return _snapshot(input.sessionId, machine.state);
  }

  @override
  Future<AgenticWorkflowSnapshot> getSnapshot(String sessionId) async {
    final machine = _sessions[sessionId];
    if (machine == null) {
      return AgenticWorkflowSnapshot.empty(sessionId: sessionId);
    }
    return _snapshot(sessionId, machine.state);
  }

  @override
  Future<void> reset(String sessionId) async {
    final machine = _sessions.remove(sessionId);
    final checkpointStorage = _checkpointStores.remove(sessionId);
    machine?.reset();
    if (checkpointStorage != null) {
      await checkpointStorage.clear();
    }
  }

  AgenticTestingStateMachine _ensureSession(String sessionId) {
    return _sessions.putIfAbsent(sessionId, () {
      final storage = _SessionCheckpointStorage();
      _checkpointStores[sessionId] = storage;
      return AgenticTestingStateMachine(
        testGenerator: _testGenerator,
        testExecutor: _testExecutor,
        healingPlanner: _healingPlanner,
        checkpointStorage: storage,
        checkpointSessionKey: sessionId,
      );
    });
  }

  AgenticWorkflowSnapshot _snapshot(
    String sessionId,
    AgenticWorkflowContext context,
  ) {
    return AgenticWorkflowSnapshot.fromContext(
      sessionId: sessionId,
      context: context,
    );
  }
}

class _SessionCheckpointStorage extends AgenticWorkflowCheckpointStorage {
  AgenticWorkflowContext? _saved;
  final Map<String, AgenticWorkflowContext> _scoped = {};

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
    _scoped.clear();
  }

  @override
  Future<void> saveForSession({
    required String sessionKey,
    required AgenticWorkflowContext context,
  }) async {
    _scoped[sessionKey] = context;
  }

  @override
  Future<AgenticWorkflowContext?> loadForSession({
    required String sessionKey,
  }) async {
    return _scoped[sessionKey];
  }

  @override
  Future<void> clearForSession({required String sessionKey}) async {
    _scoped.remove(sessionKey);
  }
}
