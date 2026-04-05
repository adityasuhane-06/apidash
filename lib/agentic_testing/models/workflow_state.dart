enum AgenticWorkflowState {
  idle,
  generating,
  awaitingApproval,
  executing,
  resultsReady,
  analyzingFailures,
  awaitingHealApproval,
  reExecuting,
  finalReport,
}

extension AgenticWorkflowStateLabel on AgenticWorkflowState {
  String get label {
    switch (this) {
      case AgenticWorkflowState.idle:
        return 'IDLE';
      case AgenticWorkflowState.generating:
        return 'GENERATING';
      case AgenticWorkflowState.awaitingApproval:
        return 'AWAITING_APPROVAL';
      case AgenticWorkflowState.executing:
        return 'EXECUTING';
      case AgenticWorkflowState.resultsReady:
        return 'RESULTS_READY';
      case AgenticWorkflowState.analyzingFailures:
        return 'ANALYZING_FAILURES';
      case AgenticWorkflowState.awaitingHealApproval:
        return 'AWAITING_HEAL_APPROVAL';
      case AgenticWorkflowState.reExecuting:
        return 'RE_EXECUTING';
      case AgenticWorkflowState.finalReport:
        return 'FINAL_REPORT';
    }
  }
}
