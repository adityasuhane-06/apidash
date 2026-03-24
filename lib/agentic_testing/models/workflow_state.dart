enum AgenticWorkflowState {
  idle,
  generating,
  awaitingApproval,
  executing,
  resultsReady,
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
    }
  }
}
