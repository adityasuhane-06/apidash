enum AgentLoopTextIntentType {
  none,
  proposePlan,
  approvePlan,
  rejectPlan,
  executeStep,
  skipStep,
  reviewDecision,
  healingDecision,
  executeOnlySelection,
  explainFailure,
  explainHealing,
  explainTestDetails,
  confirmSatisfaction,
  requestChanges,
}

enum AgentLoopDecisionOperation { approve, reject, skip }

class AgentLoopDecisionCommand {
  const AgentLoopDecisionCommand({
    required this.operation,
    this.references = const <int>[],
    this.applyToAll = false,
    this.only = false,
  });

  final AgentLoopDecisionOperation operation;
  final List<int> references;
  final bool applyToAll;
  final bool only;
}

class AgentLoopTextIntent {
  const AgentLoopTextIntent({
    required this.type,
    required this.rawInput,
    this.confidence = 0,
    this.references = const <int>[],
    this.decisions = const <AgentLoopDecisionCommand>[],
    this.requiresRiskConfirmation = false,
    this.notes,
  });

  final AgentLoopTextIntentType type;
  final String rawInput;
  final double confidence;
  final List<int> references;
  final List<AgentLoopDecisionCommand> decisions;
  final bool requiresRiskConfirmation;
  final String? notes;

  bool get isMatched => type != AgentLoopTextIntentType.none;
}
