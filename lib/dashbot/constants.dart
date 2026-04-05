/// Role of a chat message author.
enum MessageRole { user, system }

enum ChatMessageType {
  explainResponse,
  debugError,
  generateTest,
  generateDoc,
  generateCode,
  importCurl,
  importOpenApi,
  agenticWorkflow,
  general
}

enum ChatActionType {
  updateField('update_field'),
  addHeader('add_header'),
  updateHeader('update_header'),
  deleteHeader('delete_header'),
  updateBody('update_body'),
  updateUrl('update_url'),
  updateMethod('update_method'),
  showLanguages('show_languages'),
  applyCurl('apply_curl'),
  applyOpenApi('apply_openapi'),
  downloadDoc('download_doc'),
  proposePlan('propose_plan'),
  approvePlan('approve_plan'),
  rejectPlan('reject_plan'),
  skipStep('skip_step'),
  executeStep('execute_step'),
  confirmSatisfaction('confirm_satisfaction'),
  requestChanges('request_changes'),
  other('other'),
  noAction('no_action'),
  uploadAsset('upload_asset');

  const ChatActionType(this.text);
  final String text;
}

enum ChatActionTarget {
  httpRequestModel,
  codegen,
  test,
  code,
  attachment,
  documentation,
  agenticWorkflow,
}

ChatActionType chatActionTypeFromString(String s) {
  return ChatActionType.values.firstWhere(
    (type) => type.text == s,
    orElse: () => ChatActionType.other,
  );
}

ChatActionTarget chatActionTargetFromString(String s) {
  final normalized = s.trim();
  if (normalized == 'agentic_workflow') {
    return ChatActionTarget.agenticWorkflow;
  }
  if (normalized == 'http_request_model') {
    return ChatActionTarget.httpRequestModel;
  }
  return ChatActionTarget.values.firstWhere(
    (target) => target.name == normalized,
    orElse: () => ChatActionTarget.httpRequestModel,
  );
}
