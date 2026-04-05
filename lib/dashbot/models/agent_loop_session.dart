import 'package:apidash/agentic_testing/models/contract_context.dart';

import '../../agentic_testing/models/workflow_context.dart';

/// High-level lifecycle stage of the chat-driven agent loop.
enum AgentLoopStage {
  idle,
  planReady,
  awaitingApproval,
  executing,
  awaitingSatisfaction,
  completed,
}

/// Canonical step types for the MVP workflow execution plan.
enum AgentPlanStepType {
  generate,
  review,
  execute,
  analyze,
  healReview,
  rerun,
  report,
}

enum AgentPlanStepStatus {
  pending,
  running,
  completed,
  skipped,
  failed,
}

class AgentPlanStep {
  const AgentPlanStep({
    required this.type,
    required this.intent,
    this.risky = false,
    this.status = AgentPlanStepStatus.pending,
    this.error,
  });

  final AgentPlanStepType type;
  final String intent;
  final bool risky;
  final AgentPlanStepStatus status;
  final String? error;

  bool get isTerminal =>
      status == AgentPlanStepStatus.completed ||
      status == AgentPlanStepStatus.skipped ||
      status == AgentPlanStepStatus.failed;

  AgentPlanStep copyWith({
    AgentPlanStepType? type,
    String? intent,
    bool? risky,
    AgentPlanStepStatus? status,
    String? error,
    bool clearError = false,
  }) {
    return AgentPlanStep(
      type: type ?? this.type,
      intent: intent ?? this.intent,
      risky: risky ?? this.risky,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'intent': intent,
      'risky': risky,
      'status': status.name,
      'error': error,
    };
  }

  factory AgentPlanStep.fromJson(Map<String, dynamic> json) {
    final typeRaw = (json['type'] as String?)?.trim();
    final statusRaw = (json['status'] as String?)?.trim();

    final type = AgentPlanStepType.values.firstWhere(
      (item) => item.name.toLowerCase() == typeRaw?.toLowerCase(),
      orElse: () => AgentPlanStepType.generate,
    );
    final status = AgentPlanStepStatus.values.firstWhere(
      (item) => item.name.toLowerCase() == statusRaw?.toLowerCase(),
      orElse: () => AgentPlanStepStatus.pending,
    );

    return AgentPlanStep(
      type: type,
      intent: (json['intent'] as String?)?.trim().isNotEmpty == true
          ? (json['intent'] as String).trim()
          : 'No intent provided.',
      risky: json['risky'] == true,
      status: status,
      error: (json['error'] as String?)?.trim(),
    );
  }
}

class AgentExecutionPlan {
  const AgentExecutionPlan({
    required this.goal,
    required this.steps,
    this.source = 'fallback',
  });

  final String goal;
  final List<AgentPlanStep> steps;
  final String source;

  int get pendingCount =>
      steps.where((step) => step.status == AgentPlanStepStatus.pending).length;

  int get completedCount => steps
      .where((step) => step.status == AgentPlanStepStatus.completed)
      .length;

  int get failedCount =>
      steps.where((step) => step.status == AgentPlanStepStatus.failed).length;

  AgentExecutionPlan copyWith({
    String? goal,
    List<AgentPlanStep>? steps,
    String? source,
  }) {
    return AgentExecutionPlan(
      goal: goal ?? this.goal,
      steps: steps ?? this.steps,
      source: source ?? this.source,
    );
  }

  AgentPlanStep? get currentStep {
    for (final step in steps) {
      if (!step.isTerminal) {
        return step;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'goal': goal,
      'source': source,
      'steps': steps.map((step) => step.toJson()).toList(),
    };
  }

  factory AgentExecutionPlan.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'];
    final parsedSteps = rawSteps is List
        ? rawSteps
              .whereType<Map>()
              .map((item) => AgentPlanStep.fromJson(Map<String, dynamic>.from(item)))
              .toList()
        : const <AgentPlanStep>[];

    return AgentExecutionPlan(
      goal: (json['goal'] as String?)?.trim().isNotEmpty == true
          ? (json['goal'] as String).trim()
          : 'Complete the requested API testing workflow.',
      steps: parsedSteps,
      source: (json['source'] as String?)?.trim().isNotEmpty == true
          ? (json['source'] as String).trim()
          : 'fallback',
    );
  }
}

class AgentLoopSession {
  const AgentLoopSession({
    required this.requestId,
    this.stage = AgentLoopStage.idle,
    this.goal,
    this.plan,
    this.lastRunSummary,
    this.lastError,
    this.followUpPrompt,
    this.lastWorkflowSnapshot,
  });

  final String requestId;
  final AgentLoopStage stage;
  final String? goal;
  final AgentExecutionPlan? plan;
  final String? lastRunSummary;
  final String? lastError;
  final String? followUpPrompt;
  final AgenticWorkflowContext? lastWorkflowSnapshot;

  AgentLoopSession copyWith({
    String? requestId,
    AgentLoopStage? stage,
    String? goal,
    bool clearGoal = false,
    AgentExecutionPlan? plan,
    bool clearPlan = false,
    String? lastRunSummary,
    bool clearLastRunSummary = false,
    String? lastError,
    bool clearLastError = false,
    String? followUpPrompt,
    bool clearFollowUpPrompt = false,
    AgenticWorkflowContext? lastWorkflowSnapshot,
    bool clearLastWorkflowSnapshot = false,
  }) {
    return AgentLoopSession(
      requestId: requestId ?? this.requestId,
      stage: stage ?? this.stage,
      goal: clearGoal ? null : (goal ?? this.goal),
      plan: clearPlan ? null : (plan ?? this.plan),
      lastRunSummary: clearLastRunSummary
          ? null
          : (lastRunSummary ?? this.lastRunSummary),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      followUpPrompt: clearFollowUpPrompt
          ? null
          : (followUpPrompt ?? this.followUpPrompt),
      lastWorkflowSnapshot: clearLastWorkflowSnapshot
          ? null
          : (lastWorkflowSnapshot ?? this.lastWorkflowSnapshot),
    );
  }
}

class AgentLoopExecutionContext {
  const AgentLoopExecutionContext({
    required this.endpoint,
    required this.method,
    required this.headers,
    this.requestBody,
    this.generationPrompt,
    this.contractContext,
  });

  final String endpoint;
  final String method;
  final Map<String, String> headers;
  final String? requestBody;
  final String? generationPrompt;
  final AgenticContractContext? contractContext;
}
