import 'package:apidash/agentic_testing/agentic_testing.dart';

import '../../models/agent_loop_session.dart';

class AgentLoopActionResult {
  const AgentLoopActionResult({required this.session, required this.message});

  final AgentLoopSession session;
  final String message;
}

abstract class AgentLoopCoordinator {
  AgentExecutionPlan createPlan({
    required String goal,
    AgentExecutionPlan? suggested,
    String source = 'fallback',
  });

  AgentLoopActionResult approvePlan({required AgentLoopSession session});

  AgentLoopActionResult rejectPlan({required AgentLoopSession session});

  Future<AgentLoopActionResult> executeNextStep({
    required AgentLoopSession session,
    required AgentLoopExecutionContext context,
    required AgenticTestingStateMachine machine,
  });

  Future<AgentLoopActionResult> skipCurrentStep({
    required AgentLoopSession session,
    required AgenticTestingStateMachine machine,
  });

  AgentLoopActionResult submitSatisfaction({
    required AgentLoopSession session,
    required bool satisfied,
    String? followUpPrompt,
  });
}

class AgentLoopCoordinatorImpl implements AgentLoopCoordinator {
  static const List<AgentPlanStepType> _orderedStepTypes = [
    AgentPlanStepType.generate,
    AgentPlanStepType.review,
    AgentPlanStepType.execute,
    AgentPlanStepType.analyze,
    AgentPlanStepType.healReview,
    AgentPlanStepType.rerun,
    AgentPlanStepType.report,
  ];

  @override
  AgentExecutionPlan createPlan({
    required String goal,
    AgentExecutionPlan? suggested,
    String source = 'fallback',
  }) {
    final normalizedGoal = goal.trim().isEmpty
        ? 'Run a safe agentic API testing workflow for the selected request.'
        : goal.trim();

    final suggestedByType = <AgentPlanStepType, AgentPlanStep>{};
    for (final step in suggested?.steps ?? const <AgentPlanStep>[]) {
      suggestedByType[step.type] = step;
    }

    final ordered = _orderedStepTypes.map((type) {
      final existing = suggestedByType[type];
      if (existing != null) {
        return existing.copyWith(
          status: AgentPlanStepStatus.pending,
          clearError: true,
        );
      }
      return AgentPlanStep(
        type: type,
        intent: _defaultIntent(type),
        risky: _defaultRisk(type),
      );
    }).toList();

    return AgentExecutionPlan(
      goal: suggested?.goal.trim().isNotEmpty == true
          ? suggested!.goal.trim()
          : normalizedGoal,
      steps: ordered,
      source: suggested?.source ?? source,
    );
  }

  @override
  AgentLoopActionResult approvePlan({required AgentLoopSession session}) {
    final nextStep =
        session.plan?.currentStep?.type ?? AgentPlanStepType.generate;
    final next = session.copyWith(
      stage: AgentLoopStage.awaitingApproval,
      clearLastError: true,
    );
    return AgentLoopActionResult(
      session: next,
      message:
          'Plan approved. Next: ${_stepLabel(nextStep)}. Execute when ready.',
    );
  }

  @override
  AgentLoopActionResult rejectPlan({required AgentLoopSession session}) {
    final next = session.copyWith(
      stage: AgentLoopStage.idle,
      clearPlan: true,
      clearLastError: true,
    );
    return AgentLoopActionResult(
      session: next,
      message:
          'Plan rejected. Share what to change and I will generate a revised plan.',
    );
  }

  @override
  Future<AgentLoopActionResult> executeNextStep({
    required AgentLoopSession session,
    required AgentLoopExecutionContext context,
    required AgenticTestingStateMachine machine,
  }) async {
    final plan = session.plan;
    if (plan == null) {
      final failed = session.copyWith(
        stage: AgentLoopStage.idle,
        lastError: 'No active plan found.',
      );
      return AgentLoopActionResult(
        session: failed,
        message: 'No active plan found. Start by generating a plan.',
      );
    }

    final nextIndex = plan.steps.indexWhere((step) => !step.isTerminal);
    if (nextIndex == -1) {
      final done = session.copyWith(
        stage: AgentLoopStage.awaitingSatisfaction,
        clearLastError: true,
      );
      return AgentLoopActionResult(
        session: done,
        message: 'All planned steps are complete. Did this solve your goal?',
      );
    }

    final runningPlan = _setStepStatus(
      plan,
      nextIndex,
      AgentPlanStepStatus.running,
      clearError: true,
    );
    var workingSession = session.copyWith(
      plan: runningPlan,
      stage: AgentLoopStage.executing,
      clearLastError: true,
    );

    try {
      final currentStep = runningPlan.steps[nextIndex];
      switch (currentStep.type) {
        case AgentPlanStepType.generate:
          if (machine.state.workflowState != AgenticWorkflowState.idle) {
            machine.reset();
          }
          if (machine.state.workflowState != AgenticWorkflowState.idle) {
            throw StateError(
              'Cannot generate tests while workflow is ${machine.state.workflowState.label}.',
            );
          }
          await machine.startGeneration(
            endpoint: context.endpoint,
            method: context.method,
            headers: context.headers,
            requestBody: context.requestBody,
            generationPrompt: context.generationPrompt,
            contractContext: context.contractContext,
          );
          if (machine.state.workflowState !=
              AgenticWorkflowState.awaitingApproval) {
            final generationError = machine.state.errorMessage?.trim();
            throw StateError(
              generationError?.isNotEmpty == true
                  ? generationError!
                  : 'Generation did not produce reviewable tests.',
            );
          }
          workingSession = _completeStep(
            workingSession,
            nextIndex,
            machine.state,
          );
          break;
        case AgentPlanStepType.review:
          if (machine.state.workflowState !=
              AgenticWorkflowState.awaitingApproval) {
            workingSession = _skipStep(
              workingSession,
              nextIndex,
              machine.state,
              note: 'Review step is not available in current workflow state.',
            );
            break;
          }
          if (machine.state.pendingCount > 0) {
            final resetPlan = _setStepStatus(
              workingSession.plan!,
              nextIndex,
              AgentPlanStepStatus.pending,
              clearError: true,
            );
            final waiting = workingSession.copyWith(
              plan: resetPlan,
              stage: AgentLoopStage.awaitingApproval,
              lastWorkflowSnapshot: machine.state,
              lastRunSummary: _summarize(machine.state),
              clearLastError: true,
            );
            return AgentLoopActionResult(
              session: waiting,
              message:
                  'Review is still pending for ${machine.state.pendingCount} test(s). Approve/reject tests first (chat or MCP card), then execute next step.',
            );
          }
          workingSession = _completeStep(
            workingSession,
            nextIndex,
            machine.state,
          );
          break;
        case AgentPlanStepType.execute:
          if (machine.state.workflowState !=
              AgenticWorkflowState.awaitingApproval) {
            throw StateError(
              'Execute step requires awaiting-approval state, found ${machine.state.workflowState.label}.',
            );
          }
          if (machine.state.approvedCount == 0) {
            throw StateError(
              'Approve at least one test case before execution.',
            );
          }
          await machine.executeApprovedTests();
          if (machine.state.workflowState !=
              AgenticWorkflowState.resultsReady) {
            final executionError = machine.state.errorMessage?.trim();
            throw StateError(
              executionError?.isNotEmpty == true
                  ? executionError!
                  : 'Execution did not produce results-ready state.',
            );
          }
          workingSession = _completeStep(
            workingSession,
            nextIndex,
            machine.state,
          );
          break;
        case AgentPlanStepType.analyze:
          if (!machine.state.hasAnalyzableFailures) {
            workingSession = _skipStep(
              workingSession,
              nextIndex,
              machine.state,
              note:
                  'No failed or unsupported-skipped tests found. Analysis skipped.',
            );
          } else {
            await machine.generateHealingPlans();
            workingSession = _completeStep(
              workingSession,
              nextIndex,
              machine.state,
            );
          }
          break;
        case AgentPlanStepType.healReview:
          if (machine.state.workflowState ==
              AgenticWorkflowState.awaitingHealApproval) {
            if (machine.state.healPendingCount > 0) {
              final resetPlan = _setStepStatus(
                workingSession.plan!,
                nextIndex,
                AgentPlanStepStatus.pending,
                clearError: true,
              );
              final waiting = workingSession.copyWith(
                plan: resetPlan,
                stage: AgentLoopStage.awaitingApproval,
                lastWorkflowSnapshot: machine.state,
                lastRunSummary: _summarize(machine.state),
                clearLastError: true,
              );
              return AgentLoopActionResult(
                session: waiting,
                message:
                    'Healing review is pending for ${machine.state.healPendingCount} test(s). Approve/reject healing first, then execute next step.',
              );
            }
            workingSession = _completeStep(
              workingSession,
              nextIndex,
              machine.state,
            );
          } else {
            workingSession = _skipStep(
              workingSession,
              nextIndex,
              machine.state,
              note: 'No healing approval required in current state.',
            );
          }
          break;
        case AgentPlanStepType.rerun:
          if (machine.state.workflowState ==
              AgenticWorkflowState.awaitingHealApproval) {
            if (machine.state.healApprovedCount > 0) {
              await machine.reExecuteHealedTests();
            } else {
              machine.skipHealingRerunToFinalReport();
            }
            workingSession = _completeStep(
              workingSession,
              nextIndex,
              machine.state,
            );
          } else {
            workingSession = _skipStep(
              workingSession,
              nextIndex,
              machine.state,
              note:
                  'Re-run skipped because workflow is not awaiting heal approval.',
            );
          }
          break;
        case AgentPlanStepType.report:
          workingSession = _completeStep(
            workingSession,
            nextIndex,
            machine.state,
          );
          break;
      }

      final nextPlan = workingSession.plan!;
      final hasPending = nextPlan.steps.any((step) => !step.isTerminal);
      final summary = _summarize(machine.state);
      final progressed = workingSession.copyWith(
        stage: hasPending
            ? AgentLoopStage.awaitingApproval
            : AgentLoopStage.awaitingSatisfaction,
        lastRunSummary: summary,
        lastWorkflowSnapshot: machine.state,
      );
      final completedStepLabel = _stepLabel(currentStep.type);
      final nextStep = progressed.plan?.currentStep?.type;
      final message = hasPending
          ? 'Completed: $completedStepLabel. Next: ${_stepLabel(nextStep ?? AgentPlanStepType.report)}.'
          : 'Workflow finished. Review final report and confirm if this solved your goal.';
      return AgentLoopActionResult(session: progressed, message: message);
    } catch (e) {
      final failedPlan = _setStepStatus(
        workingSession.plan!,
        nextIndex,
        AgentPlanStepStatus.failed,
        error: e.toString(),
      );
      final failed = workingSession.copyWith(
        plan: failedPlan,
        stage: AgentLoopStage.awaitingApproval,
        lastError: 'Step failed: $e',
        lastWorkflowSnapshot: machine.state,
      );
      return AgentLoopActionResult(
        session: failed,
        message: 'Execution failed for current step: $e',
      );
    }
  }

  @override
  Future<AgentLoopActionResult> skipCurrentStep({
    required AgentLoopSession session,
    required AgenticTestingStateMachine machine,
  }) async {
    final plan = session.plan;
    if (plan == null) {
      return AgentLoopActionResult(
        session: session.copyWith(lastError: 'No active plan to skip.'),
        message: 'No active plan to skip.',
      );
    }

    final nextIndex = plan.steps.indexWhere((step) => !step.isTerminal);
    if (nextIndex == -1) {
      final done = session.copyWith(stage: AgentLoopStage.awaitingSatisfaction);
      return AgentLoopActionResult(
        session: done,
        message: 'All steps already resolved. Did this solve your goal?',
      );
    }

    final step = plan.steps[nextIndex];
    if (step.type == AgentPlanStepType.rerun &&
        machine.state.workflowState ==
            AgenticWorkflowState.awaitingHealApproval) {
      machine.skipHealingRerunToFinalReport();
    }

    final skipped = _setStepStatus(
      plan,
      nextIndex,
      AgentPlanStepStatus.skipped,
      clearError: true,
    );

    final hasPending = skipped.steps.any((item) => !item.isTerminal);
    final skippedStepLabel = _stepLabel(step.type);
    final nextPendingStep = skipped.currentStep?.type;
    final updated = session.copyWith(
      plan: skipped,
      stage: hasPending
          ? AgentLoopStage.awaitingApproval
          : AgentLoopStage.awaitingSatisfaction,
      lastRunSummary: _summarize(machine.state),
      lastWorkflowSnapshot: machine.state,
      clearLastError: true,
    );

    return AgentLoopActionResult(
      session: updated,
      message: hasPending
          ? 'Skipped: $skippedStepLabel. Next: ${_stepLabel(nextPendingStep ?? AgentPlanStepType.report)}.'
          : 'All steps resolved. Did this solve your goal?',
    );
  }

  @override
  AgentLoopActionResult submitSatisfaction({
    required AgentLoopSession session,
    required bool satisfied,
    String? followUpPrompt,
  }) {
    if (satisfied) {
      final done = session.copyWith(
        stage: AgentLoopStage.completed,
        clearLastError: true,
        clearFollowUpPrompt: true,
      );
      return AgentLoopActionResult(
        session: done,
        message: 'Great. Workflow marked complete.',
      );
    }

    final revised = session.copyWith(
      stage: AgentLoopStage.idle,
      clearPlan: true,
      followUpPrompt: followUpPrompt?.trim().isNotEmpty == true
          ? followUpPrompt!.trim()
          : 'Please refine the previous plan.',
      clearLastError: true,
    );
    return AgentLoopActionResult(
      session: revised,
      message:
          'Understood. Share what to change and I will generate a revised plan while keeping prior results.',
    );
  }

  AgentLoopSession _completeStep(
    AgentLoopSession session,
    int index,
    AgenticWorkflowContext snapshot,
  ) {
    final updatedPlan = _setStepStatus(
      session.plan!,
      index,
      AgentPlanStepStatus.completed,
      clearError: true,
    );
    return session.copyWith(
      plan: updatedPlan,
      lastWorkflowSnapshot: snapshot,
      clearLastError: true,
    );
  }

  AgentLoopSession _skipStep(
    AgentLoopSession session,
    int index,
    AgenticWorkflowContext snapshot, {
    String? note,
  }) {
    final updatedPlan = _setStepStatus(
      session.plan!,
      index,
      AgentPlanStepStatus.skipped,
      clearError: true,
    );
    return session.copyWith(
      plan: updatedPlan,
      lastWorkflowSnapshot: snapshot,
      lastRunSummary: note ?? session.lastRunSummary,
      clearLastError: true,
    );
  }

  AgentExecutionPlan _setStepStatus(
    AgentExecutionPlan plan,
    int index,
    AgentPlanStepStatus status, {
    String? error,
    bool clearError = false,
  }) {
    final updated = [...plan.steps];
    if (index >= 0 && index < updated.length) {
      updated[index] = updated[index].copyWith(
        status: status,
        error: error,
        clearError: clearError,
      );
    }
    return plan.copyWith(steps: updated);
  }

  String _defaultIntent(AgentPlanStepType type) {
    switch (type) {
      case AgentPlanStepType.generate:
        return 'Generate contract-aware test candidates.';
      case AgentPlanStepType.review:
        return 'Apply human review decision (approve batch for MVP).';
      case AgentPlanStepType.execute:
        return 'Run approved tests against the selected API endpoint.';
      case AgentPlanStepType.analyze:
        return 'Analyze failures and produce healing recommendations.';
      case AgentPlanStepType.healReview:
        return 'Apply human approval for healing recommendations.';
      case AgentPlanStepType.rerun:
        return 'Re-run with unchanged assertions after approved healing.';
      case AgentPlanStepType.report:
        return 'Summarize execution outcomes and close the run.';
    }
  }

  bool _defaultRisk(AgentPlanStepType type) {
    return switch (type) {
      AgentPlanStepType.generate => false,
      AgentPlanStepType.review => true,
      AgentPlanStepType.execute => true,
      AgentPlanStepType.analyze => false,
      AgentPlanStepType.healReview => true,
      AgentPlanStepType.rerun => true,
      AgentPlanStepType.report => false,
    };
  }

  String _stepLabel(AgentPlanStepType type) {
    return switch (type) {
      AgentPlanStepType.generate => 'Generate tests',
      AgentPlanStepType.review => 'Review tests',
      AgentPlanStepType.execute => 'Execute approved tests',
      AgentPlanStepType.analyze => 'Analyze failures',
      AgentPlanStepType.healReview => 'Review healing actions',
      AgentPlanStepType.rerun => 'Re-run healed tests',
      AgentPlanStepType.report => 'Build final report',
    };
  }

  String _summarize(AgenticWorkflowContext state) {
    return 'State=${state.workflowState.label} | '
        'Approved=${state.approvedCount} Rejected=${state.rejectedCount} Pending=${state.pendingCount} | '
        'Passed=${state.passedCount} Failed=${state.failedCount} Skipped=${state.skippedCount} | '
        'HealPending=${state.healPendingCount} HealApproved=${state.healApprovedCount} HealApplied=${state.healAppliedCount}';
  }
}
