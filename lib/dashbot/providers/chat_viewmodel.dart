import 'dart:convert';
import 'package:apidash/agentic_testing/mcp/mcp.dart';
import 'package:apidash/agentic_testing/models/test_case_model.dart';
import 'package:apidash/agentic_testing/models/workflow_context.dart';
import 'package:apidash/agentic_testing/models/workflow_state.dart';
import 'package:apidash/agentic_testing/providers/agentic_testing_providers.dart';
import 'package:apidash/agentic_testing/services/state_machine.dart';
import 'package:apidash_core/apidash_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:apidash/providers/providers.dart';
import 'package:apidash/models/models.dart';
import 'package:apidash/utils/utils.dart';
import '../constants.dart';
import '../models/models.dart';
import '../prompts/prompts.dart' as dash;
import '../repository/repository.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import 'dashbot_active_route_provider.dart';
import 'service_providers.dart';

final chatViewmodelProvider = StateNotifierProvider<ChatViewmodel, ChatState>((
  ref,
) {
  return ChatViewmodel(ref);
});

class ChatViewmodel extends StateNotifier<ChatState> {
  ChatViewmodel(this._ref) : super(const ChatState());

  final Ref _ref;

  ChatRemoteRepository get _repo => _ref.read(chatRepositoryProvider);
  RequestModel? get _currentRequest => _ref.read(selectedRequestModelProvider);
  HttpRequestModel? get _currentSubstitutedHttpRequestModel =>
      _ref.read(selectedSubstitutedHttpRequestModelProvider);
  AIRequestModel? get _selectedAIModel {
    final json = _ref.read(settingsProvider).defaultAIModel;
    if (json == null) return null;
    try {
      return AIRequestModel.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  List<ChatMessage> get currentMessages {
    final id = _currentRequest?.id ?? 'global';
    final messages = state.chatSessions[id] ?? const [];
    return messages;
  }

  AgentLoopSession? get currentLoopSession {
    final id = _currentRequest?.id ?? 'global';
    return state.loopSessions[id];
  }

  Future<void> sendMessage({
    required String text,
    ChatMessageType type = ChatMessageType.general,
    bool countAsUser = true,
  }) async {
    final ai = _selectedAIModel;
    if (text.trim().isEmpty && countAsUser) return;
    final trimmedText = text.trim();
    final loopSession = currentLoopSession;
    final requestId = _currentRequest?.id ?? 'global';

    if (countAsUser) {
      _addMessage(
        requestId,
        ChatMessage(
          id: getNewUuid(),
          content: text,
          role: MessageRole.user,
          timestamp: DateTime.now(),
          messageType: type,
        ),
      );
    }

    if (countAsUser &&
        type == ChatMessageType.general &&
        loopSession != null &&
        trimmedText.isNotEmpty) {
      final handled = await _handleAgentLoopTextCommand(
        requestId: requestId,
        session: loopSession,
        userText: trimmedText,
      );
      if (handled) {
        return;
      }
    }

    if (countAsUser &&
        type == ChatMessageType.general &&
        loopSession != null &&
        loopSession.stage == AgentLoopStage.idle &&
        loopSession.plan == null &&
        (loopSession.followUpPrompt?.trim().isNotEmpty == true) &&
        trimmedText.isNotEmpty) {
      await _handleLoopFollowUpPrompt(trimmedText);
      return;
    }

    if (ai == null &&
        type != ChatMessageType.importCurl &&
        type != ChatMessageType.importOpenApi) {
      debugPrint('[Chat] No AI model configured');
      _appendSystem('AI model is not configured. Please set one.', type);
      return;
    }

    final existingMessages = state.chatSessions[requestId] ?? const [];

    final lastSystemImport = existingMessages.lastWhere(
      (m) =>
          m.role == MessageRole.system &&
          m.messageType == ChatMessageType.importCurl,
      orElse: () => ChatMessage(
        id: '',
        content: '',
        role: MessageRole.system,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    final importFlowActive = lastSystemImport.id.isNotEmpty;
    if (text.trim().startsWith('curl ') &&
        (type == ChatMessageType.importCurl || importFlowActive)) {
      await handlePotentialCurlPaste(text);
      return;
    }

    // Detect OpenAPI import flow: if the last system message was an OpenAPI import prompt,
    // then treat pasted URL or raw spec as part of the import flow.
    final lastSystemOpenApi = existingMessages.lastWhere(
      (m) =>
          m.role == MessageRole.system &&
          m.messageType == ChatMessageType.importOpenApi,
      orElse: () => ChatMessage(
        id: '',
        content: '',
        role: MessageRole.system,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    final openApiFlowActive = lastSystemOpenApi.id.isNotEmpty;
    if ((_looksLikeOpenApi(text) || _looksLikeUrl(text)) &&
        (type == ChatMessageType.importOpenApi || openApiFlowActive)) {
      if (_looksLikeOpenApi(text)) {
        await handlePotentialOpenApiPaste(text);
      } else {
        await handlePotentialOpenApiUrl(text);
      }
      return;
    }

    final promptBuilder = _ref.read(promptBuilderProvider);
    // Prepare a substituted copy of current request for prompt context
    final currentReq = _currentRequest;
    final substitutedReq = (currentReq?.httpRequestModel != null)
        ? currentReq!.copyWith(
            httpRequestModel: _currentSubstitutedHttpRequestModel?.copyWith(),
          )
        : currentReq;
    final priorRunSummary = loopSession?.lastRunSummary;
    String systemPrompt;
    if (type == ChatMessageType.generateCode) {
      final detectedLang = promptBuilder.detectLanguage(text);
      systemPrompt = promptBuilder.buildSystemPrompt(
        substitutedReq,
        type,
        overrideLanguage: detectedLang,
        priorRunSummary: priorRunSummary,
        history: currentMessages,
      );
    } else if (type == ChatMessageType.importCurl) {
      final rqId = _currentRequest?.id ?? 'global';
      // Briefly toggle loading to indicate processing of the import flow prompt
      state = state.copyWith(isGenerating: true, currentStreamingResponse: '');
      _addMessage(
        rqId,
        ChatMessage(
          id: getNewUuid(),
          content:
              '{"explanation":"Let\'s import a cURL request. Paste your complete cURL command below.","actions":[]}',
          role: MessageRole.system,
          timestamp: DateTime.now(),
          messageType: ChatMessageType.importCurl,
        ),
      );
      state = state.copyWith(isGenerating: false, currentStreamingResponse: '');
      return;
    } else if (type == ChatMessageType.importOpenApi) {
      final rqId = _currentRequest?.id ?? 'global';
      state = state.copyWith(isGenerating: true, currentStreamingResponse: '');
      final uploadAction = ChatAction.fromJson({
        'action': 'upload_asset',
        'target': 'attachment',
        'field': 'openapi_spec',
        'path': null,
        'value': {
          'purpose': 'OpenAPI specification',
          'accepted_types': [
            'application/json',
            'application/yaml',
            'application/x-yaml',
            'text/yaml',
            'text/x-yaml',
          ],
        },
      });
      _addMessage(
        rqId,
        ChatMessage(
          id: getNewUuid(),
          content:
              '{"explanation":"Upload your OpenAPI (JSON or YAML) specification, paste the full spec text, or paste a URL to a spec (e.g., https://api.apidash.dev/openapi.json).","actions":[${jsonEncode(uploadAction.toJson())}]}',
          role: MessageRole.system,
          timestamp: DateTime.now(),
          messageType: ChatMessageType.importOpenApi,
          actions: [uploadAction],
        ),
      );
      if (_looksLikeOpenApi(text)) {
        await handlePotentialOpenApiPaste(text);
      } else if (_looksLikeUrl(text)) {
        await handlePotentialOpenApiUrl(text);
      }
      state = state.copyWith(isGenerating: false, currentStreamingResponse: '');
      return;
    } else {
      systemPrompt = promptBuilder.buildSystemPrompt(
        substitutedReq,
        type,
        priorRunSummary: priorRunSummary,
        history: currentMessages,
      );
    }
    final userPrompt = (text.trim().isEmpty && !countAsUser)
        ? 'Please complete the task based on the provided context.'
        : text;
    final enriched = ai!.copyWith(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      stream: false,
    );

    state = state.copyWith(isGenerating: true, currentStreamingResponse: '');
    try {
      final response = await _repo.sendChat(request: enriched);
      if (response != null && response.isNotEmpty) {
        List<ChatAction>? actions;
        Map<String, dynamic>? parsed;
        try {
          debugPrint('[Chat] Parsing non-streaming response');
          parsed = MessageJson.safeParse(response);
          if (parsed.containsKey('actions') && parsed['actions'] is List) {
            actions = (parsed['actions'] as List)
                .whereType<Map<String, dynamic>>()
                .map(ChatAction.fromJson)
                .toList();
            debugPrint('[Chat] Parsed actions list: ${actions.length}');
          }
        } catch (e) {
          debugPrint('[Chat] Error parsing action: $e');
        }

        var responseContent = response;
        if (type == ChatMessageType.agenticWorkflow) {
          final planning = _buildLoopPlanFromResponse(
            parsedResponse: parsed,
            userGoal: trimmedText,
            requestId: requestId,
          );
          _upsertLoopSession(requestId, planning.$1);
          actions = planning.$2;
          final mcpApp = _buildMcpAppPayload(planning.$1);
          responseContent = jsonEncode({
            'explanation': _extractExplanation(parsed, response),
            'plan': planning.$1.plan?.toJson(),
            'actions': actions.map((item) => item.toJson()).toList(),
            if (mcpApp != null) 'mcp_app': mcpApp,
          });
        }

        _addMessage(
          requestId,
          ChatMessage(
            id: getNewUuid(),
            content: responseContent,
            role: MessageRole.system,
            timestamp: DateTime.now(),
            messageType: type,
            actions: actions,
          ),
        );
      } else {
        final activeLoop = state.loopSessions[requestId];
        if (type == ChatMessageType.general && activeLoop != null) {
          _appendLoopStageGuidance(
            session: activeLoop,
            explanation:
                'I did not receive a model response for that message. Please retry, or use workflow commands (for example: approve T1 T2, execute next step, why T1 failed).',
          );
        } else {
          _appendSystem('No response received from the AI.', type);
        }
      }
    } catch (e) {
      debugPrint('[Chat] sendChat error: $e');
      _appendSystem('Error: $e', type);
    } finally {
      state = state.copyWith(isGenerating: false, currentStreamingResponse: '');
    }
  }

  void cancel() {
    state = state.copyWith(isGenerating: false);
  }

  void clearCurrentChat() {
    final id = _currentRequest?.id ?? 'global';
    final newSessions = {...state.chatSessions};
    final newLoopSessions = {...state.loopSessions};
    newSessions[id] = [];
    newLoopSessions.remove(id);
    state = state.copyWith(
      chatSessions: newSessions,
      loopSessions: newLoopSessions,
      isGenerating: false,
      currentStreamingResponse: '',
    );
    // Reset to base route (unpins chat) after clearing messages.
    _ref.read(dashbotActiveRouteProvider.notifier).resetToBaseRoute();
  }

  Future<void> sendTaskMessage(ChatMessageType type) async {
    final promptBuilder = _ref.read(promptBuilderProvider);
    final userMessage = promptBuilder.getUserMessageForTask(type);

    final requestId = _currentRequest?.id ?? 'global';

    _addMessage(
      requestId,
      ChatMessage(
        id: getNewUuid(),
        content: userMessage,
        role: MessageRole.user,
        timestamp: DateTime.now(),
        messageType: ChatMessageType.general,
      ),
    );

    await sendMessage(text: '', type: type, countAsUser: false);
  }

  Future<void> applyAgentLoopAction(ChatAction action) async {
    final requestId = _currentRequest?.id ?? 'global';
    final session = state.loopSessions[requestId];
    if (session == null) {
      _appendSystem(
        '{"explanation":"No active agent loop session found. Start a workflow plan first.","actions":[]}',
        ChatMessageType.agenticWorkflow,
      );
      return;
    }

    final coordinator = _ref.read(agentLoopCoordinatorProvider);
    final machine = _syncMachineToLoopSession(session);
    final shouldShowWorkingState =
        action.actionType != ChatActionType.proposePlan;

    if (shouldShowWorkingState) {
      state = state.copyWith(
        isGenerating: true,
        currentStreamingResponse: _buildLoopWorkingMessage(
          action.actionType,
          session,
        ),
      );
    }

    try {
      AgentLoopActionResult result;
      switch (action.actionType) {
        case ChatActionType.proposePlan:
          final prompt = (session.followUpPrompt?.trim().isNotEmpty == true)
              ? session.followUpPrompt!.trim()
              : (session.goal?.trim().isNotEmpty == true)
              ? session.goal!.trim()
              : 'Plan and execute an agentic API testing workflow for this request.';
          await sendMessage(
            text: prompt,
            type: ChatMessageType.agenticWorkflow,
            countAsUser: false,
          );
          return;
        case ChatActionType.approvePlan:
          result = coordinator.approvePlan(session: session);
          break;
        case ChatActionType.rejectPlan:
          result = coordinator.rejectPlan(session: session);
          break;
        case ChatActionType.executeStep:
          result = await coordinator.executeNextStep(
            session: session,
            context: _buildLoopExecutionContext(session),
            machine: machine,
          );
          break;
        case ChatActionType.skipStep:
          result = await coordinator.skipCurrentStep(
            session: session,
            machine: machine,
          );
          break;
        case ChatActionType.confirmSatisfaction:
          result = coordinator.submitSatisfaction(
            session: session,
            satisfied: true,
          );
          break;
        case ChatActionType.requestChanges:
          result = coordinator.submitSatisfaction(
            session: session,
            satisfied: false,
          );
          break;
        default:
          return;
      }

      _upsertLoopSession(requestId, result.session);
      final nextActionPayloads = _actionsForLoopSession(result.session);
      final mcpApp = _buildMcpAppPayload(result.session);
      _appendSystem(
        jsonEncode({
          'explanation': result.message,
          'actions': nextActionPayloads,
          if (mcpApp != null) 'mcp_app': mcpApp,
        }),
        ChatMessageType.agenticWorkflow,
        actions: nextActionPayloads.map(ChatAction.fromJson).toList(),
      );
    } catch (e) {
      final retryActionPayloads = _actionsForLoopSession(session);
      final mcpApp = _buildMcpAppPayload(session);
      _appendSystem(
        jsonEncode({
          'explanation': 'Agent workflow action failed: $e',
          'actions': retryActionPayloads,
          if (mcpApp != null) 'mcp_app': mcpApp,
        }),
        ChatMessageType.agenticWorkflow,
        actions: retryActionPayloads.map(ChatAction.fromJson).toList(),
      );
    } finally {
      if (shouldShowWorkingState) {
        state = state.copyWith(
          isGenerating: false,
          currentStreamingResponse: '',
        );
      }
    }
  }

  Future<void> applyAutoFix(ChatAction action) async {
    try {
      if (action.actionType == ChatActionType.applyOpenApi) {
        await _applyOpenApi(action);
        return;
      }
      if (action.actionType == ChatActionType.applyCurl) {
        await _applyCurl(action);
        return;
      }

      final msg = await _ref.read(autoFixServiceProvider).apply(action);
      if (msg != null && msg.isNotEmpty) {
        final t = ChatMessageType.general;
        _appendSystem(msg, t);
      }
      if (action.actionType == ChatActionType.other) {
        await _applyOtherAction(action);
      }
    } catch (e) {
      debugPrint('[Chat] Error applying auto-fix: $e');
      _appendSystem('Failed to apply auto-fix: $e', ChatMessageType.general);
    }
  }

  Future<void> _applyOtherAction(ChatAction action) async {
    final requestId = _currentRequest?.id;
    if (requestId == null) return;

    switch (action.target) {
      case 'test':
        await _applyTestToPostScript(action);
        break;
      case 'httpRequestModel':
        if (action.actionType == ChatActionType.applyCurl) {
          await _applyCurl(action);
          break;
        }
        if (action.actionType == ChatActionType.applyOpenApi ||
            action.field == 'select_operation') {
          await _applyOpenApi(action);
          break;
        }
        // Unsupported other action
        debugPrint('[Chat] Unsupported other action target: ${action.target}');
        break;
      default:
        debugPrint('[Chat] Unsupported other action target: ${action.target}');
    }
  }

  Future<void> _applyOpenApi(ChatAction action) async {
    final collection = _ref.read(collectionStateNotifierProvider.notifier);
    final payload = action.value is Map<String, dynamic>
        ? (action.value as Map<String, dynamic>)
        : <String, dynamic>{};

    String methodStr = (payload['method'] as String?)?.toLowerCase() ?? 'get';
    final method = HTTPVerb.values.firstWhere(
      (m) => m.name == methodStr,
      orElse: () => HTTPVerb.get,
    );
    final url = payload['url'] as String? ?? '';
    final baseUrl = payload['baseUrl'] as String? ?? _inferBaseUrl(url);
    // Derive a human-readable route path for naming
    String routePath;
    if (baseUrl.isNotEmpty && url.startsWith(baseUrl)) {
      routePath = url.substring(baseUrl.length);
    } else {
      try {
        final u = Uri.parse(url);
        routePath = u.path.isEmpty ? '/' : u.path;
      } catch (_) {
        routePath = url;
      }
    }
    if (!routePath.startsWith('/')) routePath = '/$routePath';

    final headersMap =
        (payload['headers'] as Map?)?.cast<String, dynamic>() ?? {};
    final headers = headersMap.entries
        .map((e) => NameValueModel(name: e.key, value: e.value.toString()))
        .toList();

    final body = payload['body'] as String?;
    final formFlag = payload['form'] == true;
    final formDataListRaw = (payload['formData'] as List?)?.cast<dynamic>();
    final formData = formDataListRaw == null
        ? <FormDataModel>[]
        : formDataListRaw
              .whereType<Map>()
              .map(
                (e) => FormDataModel(
                  name: (e['name'] as String?) ?? '',
                  value: (e['value'] as String?) ?? '',
                  type: (() {
                    final t = (e['type'] as String?) ?? 'text';
                    try {
                      return FormDataType.values.firstWhere(
                        (ft) => ft.name == t,
                      );
                    } catch (_) {
                      return FormDataType.text;
                    }
                  })(),
                ),
              )
              .toList();

    ContentType bodyContentType;
    if (formFlag || formData.isNotEmpty) {
      bodyContentType = ContentType.formdata;
    } else if ((body ?? '').trim().isEmpty) {
      bodyContentType = ContentType.text;
    } else {
      try {
        jsonDecode(body!);
        bodyContentType = ContentType.json;
      } catch (_) {
        bodyContentType = ContentType.text;
      }
    }

    String sourceTitle = (payload['sourceName'] as String?) ?? '';
    if (sourceTitle.trim().isEmpty) {
      final specObj = payload['spec'];
      if (specObj is OpenApi) {
        try {
          final t = specObj.info.title.trim();
          if (t.isNotEmpty) sourceTitle = t;
        } catch (_) {}
      }
    }
    debugPrint('[OpenAPI] baseUrl="$baseUrl" title="$sourceTitle" url="$url"');
    final withEnvUrl = await _maybeSubstituteBaseUrlForOpenApi(
      url,
      baseUrl,
      sourceTitle,
    );
    debugPrint('[OpenAPI] withEnvUrl="$withEnvUrl');
    if (action.field == 'apply_to_new') {
      debugPrint('[OpenAPI] withEnvUrl="$withEnvUrl');
      final model = HttpRequestModel(
        method: method,
        url: withEnvUrl,
        headers: headers,
        isHeaderEnabledList: List<bool>.filled(headers.length, true),
        body: body,
        bodyContentType: bodyContentType,
        formData: formData.isEmpty ? null : formData,
      );
      final displayName = '${method.name.toUpperCase()} $routePath';
      collection.addRequestModel(model, name: displayName);
      _appendSystem(
        'Created a new request from the OpenAPI operation.',
        ChatMessageType.importOpenApi,
      );
    }
  }

  Future<void> _applyTestToPostScript(ChatAction action) async {
    final requestId = _currentRequest?.id;
    if (requestId == null) return;

    final collectionNotifier = _ref.read(
      collectionStateNotifierProvider.notifier,
    );
    final testCode = action.value is String ? action.value as String : '';
    final currentPostScript = _currentRequest?.postRequestScript ?? '';
    final newPostScript = currentPostScript.trim().isEmpty
        ? testCode
        : '$currentPostScript\n\n// Generated Test\n$testCode';

    collectionNotifier.update(postRequestScript: newPostScript, id: requestId);

    debugPrint('[Chat] Test code added to post-request script');
    _appendSystem(
      'Test code has been successfully added to the post-response script.',
      ChatMessageType.generateTest,
    );
  }

  // Parse a pasted cURL and present actions to apply to current or new request
  Future<void> handlePotentialCurlPaste(String text) async {
    // quick check
    final trimmed = text.trim();
    if (!trimmed.startsWith('curl ')) return;
    // Show loading while parsing and generating insights
    state = state.copyWith(isGenerating: true, currentStreamingResponse: '');
    try {
      debugPrint('[cURL] Original: $trimmed');
      final curl = Curl.tryParse(trimmed);
      if (curl == null) {
        _appendSystem(
          'I couldn\'t parse that cURL command. Please check that it:\n- Starts with `curl `\n- Has balanced quotes (wrap JSON bodies in single quotes)\n- Uses backslashes for multi-line commands (if any)\n\nFix the command and paste it again below.\n\nExample:\n\ncurl -X POST https://api.apidash.dev/users \\\n  -H \'Content-Type: application/json\'',
          ChatMessageType.importCurl,
        );
        return;
      }
      final currentSubstitutedHttpRequestJson =
          _currentSubstitutedHttpRequestModel?.toJson();
      final payload = convertCurlToHttpRequestModel(curl).toJson();
      // Prepare base message first (without AI insights)
      var built = CurlImportService.buildResponseFromParsed(
        payload,
        currentJson: currentSubstitutedHttpRequestJson,
      );
      var msg = jsonDecode(built.jsonMessage) as Map<String, dynamic>;

      // Ask AI for cURL insights
      try {
        final ai = _selectedAIModel;
        if (ai != null) {
          final diff = jsonDecode(built.jsonMessage)['meta']['diff'] as String;
          final sys = dash.DashbotPrompts().curlInsightsPrompt(
            diff: diff,
            newReq: payload,
          );
          final res = await _repo.sendChat(
            request: ai.copyWith(systemPrompt: sys, stream: false),
          );
          String? insights;
          if (res != null && res.isNotEmpty) {
            try {
              final parsed = MessageJson.safeParse(res);
              if (parsed['explanation'] is String) {
                insights = parsed['explanation'];
              }
            } catch (_) {
              insights = res;
            }
          }
          if (insights != null && insights.isNotEmpty) {
            // Rebuild message including insights in explanation
            final payload = (msg['actions'] as List).isNotEmpty
                ? (((msg['actions'] as List).first as Map)['value']
                      as Map<String, dynamic>)
                : <String, dynamic>{};
            final enriched = CurlImportService.buildActionMessageFromPayload(
              payload,
              current: currentSubstitutedHttpRequestJson,
              insights: insights,
            );
            msg = enriched;
            built = (
              jsonMessage: jsonEncode(enriched),
              actions: (enriched['actions'] as List)
                  .whereType<Map<String, dynamic>>()
                  .toList(),
            );
          }
        }
      } catch (e) {
        debugPrint('[cURL] insights error: $e');
      }
      final rqId = _currentRequest?.id ?? 'global';
      _addMessage(
        rqId,
        ChatMessage(
          id: getNewUuid(),
          content: jsonEncode(msg),
          role: MessageRole.system,
          timestamp: DateTime.now(),
          messageType: ChatMessageType.importCurl,
          actions: (msg['actions'] as List)
              .whereType<Map<String, dynamic>>()
              .map(ChatAction.fromJson)
              .toList(),
        ),
      );
    } catch (e) {
      debugPrint('[cURL] Exception: $e');
      final safe = e.toString().replaceAll('"', "'");
      _appendSystem(
        'Parsing failed: $safe. Please adjust the command (ensure it starts with `curl ` and quotes/escapes are correct) and paste it again.',
        ChatMessageType.importCurl,
      );
    } finally {
      state = state.copyWith(isGenerating: false, currentStreamingResponse: '');
    }
  }

  Map<String, dynamic>? _currentRequestContext() {
    final originalRq = _currentSubstitutedHttpRequestModel;
    if (originalRq == null) return null;
    return originalRq.toJson();
  }

  Future<void> handleOpenApiAttachment(ChatAttachment att) async {
    try {
      final content = utf8.decode(att.data);
      await handlePotentialOpenApiPaste(content);
    } catch (e) {
      final safe = e.toString().replaceAll('"', "'");
      _appendSystem(
        '{"explanation":"Failed to read attachment: $safe","actions":[]}',
        ChatMessageType.importOpenApi,
      );
    }
  }

  bool _looksLikeUrl(String input) {
    final t = input.trim();
    if (t.isEmpty) return false;
    return t.startsWith('http://') || t.startsWith('https://');
  }

  Future<void> handlePotentialOpenApiUrl(String text) async {
    final trimmed = text.trim();
    if (!_looksLikeUrl(trimmed)) return;
    state = state.copyWith(isGenerating: true, currentStreamingResponse: '');
    try {
      // Build a simple GET using existing networking stack
      final httpModel = HttpRequestModel(
        method: HTTPVerb.get,
        url: trimmed,
        headers: const [
          // Hint servers that we can accept JSON or YAML
          NameValueModel(
            name: 'Accept',
            value: 'application/json, application/yaml, text/yaml, */*',
          ),
        ],
        isHeaderEnabledList: const [true],
      );

      final (resp, _, err) = await sendHttpRequest(
        getNewUuid(),
        APIType.rest,
        httpModel,
      );

      if (err != null) {
        final safe = err.replaceAll('"', "'");
        _appendSystem(
          '{"explanation":"Failed to fetch URL: $safe","actions":[]}',
          ChatMessageType.importOpenApi,
        );
        return;
      }
      if (resp == null) {
        _appendSystem(
          '{"explanation":"No response received when fetching the URL.","actions":[]}',
          ChatMessageType.importOpenApi,
        );
        return;
      }

      final body = resp.body;
      if (body.trim().isEmpty) {
        _appendSystem(
          '{"explanation":"The fetched URL returned an empty body.","actions":[]}',
          ChatMessageType.importOpenApi,
        );
        return;
      }

      // Try to parse fetched content as OpenAPI
      final spec = OpenApiImportService.tryParseSpec(body);
      if (spec == null) {
        _appendSystem(
          '{"explanation":"The fetched content does not look like a valid OpenAPI spec (JSON or YAML).","actions":[]}',
          ChatMessageType.importOpenApi,
        );
        return;
      }

      // Build insights and show picker (reuse local method)
      String? insights;
      try {
        final ai = _selectedAIModel;
        if (ai != null) {
          final summary = OpenApiImportService.summaryForSpec(spec);
          final meta = OpenApiImportService.extractSpecMeta(spec);
          final sys = dash.DashbotPrompts().openApiInsightsPrompt(
            specSummary: summary,
            specMeta: meta,
          );
          final res = await _repo.sendChat(
            request: ai.copyWith(
              systemPrompt: sys,
              userPrompt:
                  'Provide concise, actionable insights about these endpoints.',
              stream: false,
            ),
          );
          if (res != null && res.isNotEmpty) {
            try {
              final map = MessageJson.safeParse(res);
              if (map['explanation'] is String) insights = map['explanation'];
            } catch (_) {
              insights = res;
            }
          }
        }
      } catch (e) {
        debugPrint('[OpenAPI URL] insights error: $e');
      }

      final picker = OpenApiImportService.buildOperationPicker(
        spec,
        insights: insights,
      );
      final rqId = _currentRequest?.id ?? 'global';
      _addMessage(
        rqId,
        ChatMessage(
          id: getNewUuid(),
          content: jsonEncode(picker),
          role: MessageRole.system,
          timestamp: DateTime.now(),
          messageType: ChatMessageType.importOpenApi,
          actions: (picker['actions'] as List)
              .whereType<Map<String, dynamic>>()
              .map(ChatAction.fromJson)
              .toList(),
        ),
      );
    } catch (e) {
      final safe = e.toString().replaceAll('"', "'");
      _appendSystem(
        '{"explanation":"Failed to fetch or parse OpenAPI from URL: $safe","actions":[]}',
        ChatMessageType.importOpenApi,
      );
    } finally {
      state = state.copyWith(isGenerating: false, currentStreamingResponse: '');
    }
  }

  Future<void> handlePotentialOpenApiPaste(String text) async {
    final trimmed = text.trim();
    if (!_looksLikeOpenApi(trimmed)) return;
    // Show loading while parsing and generating insights
    state = state.copyWith(isGenerating: true, currentStreamingResponse: '');
    try {
      debugPrint('[OpenAPI] Original length: ${trimmed.length}');
      final spec = OpenApiImportService.tryParseSpec(trimmed);
      if (spec == null) {
        _appendSystem(
          '{"explanation":"Sorry, I couldn\'t parse that OpenAPI spec. Ensure it\'s valid JSON or YAML.","actions":[]}',
          ChatMessageType.importOpenApi,
        );
        return;
      }
      // Build a short summary + structured meta for the insights prompt
      final summary = OpenApiImportService.summaryForSpec(spec);

      String? insights;
      try {
        final ai = _selectedAIModel;
        if (ai != null) {
          final meta = OpenApiImportService.extractSpecMeta(spec);
          final sys = dash.DashbotPrompts().openApiInsightsPrompt(
            specSummary: summary,
            specMeta: meta,
          );
          final res = await _repo.sendChat(
            request: ai.copyWith(
              systemPrompt: sys,
              userPrompt:
                  'Provide concise, actionable insights about these endpoints.',
              stream: false,
            ),
          );
          if (res != null && res.isNotEmpty) {
            // Ensure we only pass the explanation string to embed into explanation
            try {
              final map = MessageJson.safeParse(res);
              if (map['explanation'] is String) insights = map['explanation'];
            } catch (_) {
              insights = res; // fallback raw text
            }
          }
        }
      } catch (e) {
        debugPrint('[OpenAPI] insights error: $e');
      }

      final picker = OpenApiImportService.buildOperationPicker(
        spec,
        insights: insights,
      );
      final rqId = _currentRequest?.id ?? 'global';
      _addMessage(
        rqId,
        ChatMessage(
          id: getNewUuid(),
          content: jsonEncode(picker),
          role: MessageRole.system,
          timestamp: DateTime.now(),
          messageType: ChatMessageType.importOpenApi,
          actions: (picker['actions'] as List)
              .whereType<Map<String, dynamic>>()
              .map(ChatAction.fromJson)
              .toList(),
        ),
      );
      // Do not generate a separate insights prompt; summary is inline now.
    } catch (e) {
      debugPrint('[OpenAPI] Exception: $e');
      final safe = e.toString().replaceAll('"', "'");
      _appendSystem(
        '{"explanation":"Parsing failed: $safe","actions":[]}',
        ChatMessageType.importOpenApi,
      );
    } finally {
      state = state.copyWith(isGenerating: false, currentStreamingResponse: '');
    }
  }

  Future<void> _applyCurl(ChatAction action) async {
    try {
      final requestId = _currentRequest?.id;
      final payload = action.value is Map<String, dynamic>
          ? (action.value as Map<String, dynamic>)
          : <String, dynamic>{};
      final httpRequestModel = HttpRequestModel.fromJson(payload);
      final baseUrl = _inferBaseUrl(httpRequestModel.url);
      final withEnvUrl = await _maybeSubstituteBaseUrl(
        httpRequestModel.url,
        baseUrl,
      );

      if (action.field == 'apply_to_selected') {
        if (requestId == null) return;
        _ref
            .read(collectionStateNotifierProvider.notifier)
            .update(
              method: httpRequestModel.method,
              url: withEnvUrl,
              headers: httpRequestModel.headers,
              isHeaderEnabledList: List<bool>.filled(
                httpRequestModel.headers?.length ?? 0,
                true,
              ),
              body: httpRequestModel.body,
              bodyContentType: httpRequestModel.bodyContentType,
              formData: httpRequestModel.formData,
              params: httpRequestModel.params,
              isParamEnabledList: List<bool>.filled(
                httpRequestModel.params?.length ?? 0,
                true,
              ),
              authModel: null,
            );
        _appendSystem(
          'Applied cURL to the selected request.',
          ChatMessageType.importCurl,
        );
      } else if (action.field == 'apply_to_new') {
        final model = httpRequestModel.copyWith(url: withEnvUrl);
        _ref
            .read(collectionStateNotifierProvider.notifier)
            .addRequestModel(model, name: 'Imported cURL');
        _appendSystem(
          'Created a new request from the cURL.',
          ChatMessageType.importCurl,
        );
      }
    } catch (e) {
      _appendSystem(
        'Error encountered while importing cURL - $e',
        ChatMessageType.importCurl,
      );
    }
  }

  Future<void> _handleLoopFollowUpPrompt(String followUp) async {
    final requestId = _currentRequest?.id ?? 'global';
    final current = state.loopSessions[requestId];
    if (current == null) {
      return;
    }

    _upsertLoopSession(
      requestId,
      current.copyWith(
        stage: AgentLoopStage.idle,
        followUpPrompt: followUp,
        clearLastError: true,
      ),
    );

    await sendMessage(
      text: followUp,
      type: ChatMessageType.agenticWorkflow,
      countAsUser: false,
    );
  }

  AgentLoopSession _prepareSessionForReplan(AgentLoopSession session) {
    final machine = _syncMachineToLoopSession(session);
    final previousSnapshot = machine.state;
    machine.reset();
    final resetSnapshot = machine.state;
    final retainedSummary = (session.lastRunSummary ?? '').trim().isNotEmpty
        ? session.lastRunSummary
        : _summarizeWorkflowSnapshot(previousSnapshot);
    return session.copyWith(
      lastWorkflowSnapshot: resetSnapshot,
      lastRunSummary: retainedSummary,
      clearLastError: true,
    );
  }

  AgenticTestingStateMachine _syncMachineToLoopSession(
    AgentLoopSession session,
  ) {
    final machine = _ref.read(agenticTestingStateMachineProvider.notifier);
    machine.setCheckpointSessionKey(session.requestId);
    machine.restoreFromSnapshot(
      session.lastWorkflowSnapshot ?? const AgenticWorkflowContext(),
    );
    return machine;
  }

  Future<bool> _handleAgentLoopTextCommand({
    required String requestId,
    required AgentLoopSession session,
    required String userText,
  }) async {
    final updatedInline = _tryApplyInlineTestUpdate(
      requestId: requestId,
      session: session,
      userText: userText,
    );
    if (updatedInline) {
      return true;
    }
    final addedCustomTest = _tryAddCustomTestCommand(
      requestId: requestId,
      session: session,
      userText: userText,
    );
    if (addedCustomTest) {
      return true;
    }

    final parser = _ref.read(agentLoopCommandParserProvider);
    final intent = parser.parse(userText);
    if (!intent.isMatched) {
      if (session.stage == AgentLoopStage.awaitingSatisfaction) {
        await _handleLoopFollowUpPrompt(userText);
        return true;
      }
      return false;
    }

    switch (intent.type) {
      case AgentLoopTextIntentType.none:
        return false;
      case AgentLoopTextIntentType.proposePlan:
        await _applyLoopActionType(ChatActionType.proposePlan);
        return true;
      case AgentLoopTextIntentType.approvePlan:
        if (session.stage != AgentLoopStage.planReady) {
          _appendLoopStageGuidance(
            session: session,
            explanation:
                'Plan approval is only available when a plan is ready to review.',
          );
          return true;
        }
        await _applyLoopActionType(ChatActionType.approvePlan);
        return true;
      case AgentLoopTextIntentType.rejectPlan:
        if (session.stage != AgentLoopStage.planReady) {
          _appendLoopStageGuidance(
            session: session,
            explanation:
                'Plan rejection is only available when a plan is ready to review.',
          );
          return true;
        }
        await _applyLoopActionType(ChatActionType.rejectPlan);
        return true;
      case AgentLoopTextIntentType.executeStep:
        if (session.stage != AgentLoopStage.awaitingApproval) {
          _appendLoopStageGuidance(
            session: session,
            explanation:
                'Execute is available during workflow execution stages only.',
          );
          return true;
        }
        final currentStepType = session.plan?.currentStep?.type;
        if (currentStepType == AgentPlanStepType.execute ||
            currentStepType == AgentPlanStepType.rerun) {
          final stepName = currentStepType == null
              ? 'Execute'
              : _stepLabel(currentStepType);
          _appendLoopStageGuidance(
            session: session,
            explanation:
                'Risky step detected ($stepName). Please confirm by tapping Execute Next Step.',
          );
          return true;
        }
        await _applyLoopActionType(ChatActionType.executeStep);
        return true;
      case AgentLoopTextIntentType.skipStep:
        if (session.stage != AgentLoopStage.awaitingApproval) {
          _appendLoopStageGuidance(
            session: session,
            explanation: 'Skip step is not available in the current stage.',
          );
          return true;
        }
        await _applyLoopActionType(ChatActionType.skipStep);
        return true;
      case AgentLoopTextIntentType.reviewDecision:
      case AgentLoopTextIntentType.healingDecision:
        await _applyDecisionIntent(
          requestId: requestId,
          session: session,
          intent: intent,
        );
        return true;
      case AgentLoopTextIntentType.executeOnlySelection:
        await _applyExecuteOnlyIntent(
          requestId: requestId,
          session: session,
          intent: intent,
        );
        return true;
      case AgentLoopTextIntentType.explainFailure:
      case AgentLoopTextIntentType.explainHealing:
      case AgentLoopTextIntentType.explainTestDetails:
        _applyDiagnosticIntent(session: session, intent: intent);
        return true;
      case AgentLoopTextIntentType.confirmSatisfaction:
        if (session.stage != AgentLoopStage.awaitingSatisfaction) {
          _appendLoopStageGuidance(
            session: session,
            explanation:
                'Satisfaction confirmation is only available after final report.',
          );
          return true;
        }
        await _applyLoopActionType(ChatActionType.confirmSatisfaction);
        return true;
      case AgentLoopTextIntentType.requestChanges:
        if (session.stage == AgentLoopStage.awaitingSatisfaction) {
          final coordinator = _ref.read(agentLoopCoordinatorProvider);
          final result = coordinator.submitSatisfaction(
            session: session,
            satisfied: false,
            followUpPrompt: userText,
          );
          final resetSession = _prepareSessionForReplan(result.session);
          _upsertLoopSession(requestId, resetSession);
          _appendLoopStageGuidance(
            session: resetSession,
            explanation: result.message,
          );
          await sendMessage(
            text: resetSession.followUpPrompt ?? userText,
            type: ChatMessageType.agenticWorkflow,
            countAsUser: false,
          );
          return true;
        }
        if (session.stage == AgentLoopStage.planReady ||
            session.stage == AgentLoopStage.awaitingApproval ||
            session.stage == AgentLoopStage.completed) {
          final coordinator = _ref.read(agentLoopCoordinatorProvider);
          final result = coordinator.submitSatisfaction(
            session: session,
            satisfied: false,
            followUpPrompt: userText,
          );
          final resetSession = _prepareSessionForReplan(result.session);
          _upsertLoopSession(requestId, resetSession);
          _appendLoopStageGuidance(
            session: resetSession,
            explanation:
                'Captured your change request. I will re-plan with this update: "$userText".',
          );
          await sendMessage(
            text: resetSession.followUpPrompt ?? userText,
            type: ChatMessageType.agenticWorkflow,
            countAsUser: false,
          );
          return true;
        }
        if (session.stage == AgentLoopStage.idle &&
            session.plan == null &&
            (session.followUpPrompt?.trim().isNotEmpty == true)) {
          await _handleLoopFollowUpPrompt(userText);
          return true;
        }
        _appendLoopStageGuidance(
          session: session,
          explanation:
              'Need changes is only available after final report in this flow.',
        );
        return true;
    }
  }

  bool _tryApplyInlineTestUpdate({
    required String requestId,
    required AgentLoopSession session,
    required String userText,
  }) {
    final commandMatch = RegExp(
      r'^\s*(update|edit|modify)\s+(?:test\s*)?t?\s*(\d+)\s*[:\-]?\s*(.+)\s*$',
      caseSensitive: false,
    ).firstMatch(userText);
    if (commandMatch == null) {
      return false;
    }

    final machine = _syncMachineToLoopSession(session);
    if (session.stage != AgentLoopStage.awaitingApproval ||
        machine.state.workflowState != AgenticWorkflowState.awaitingApproval) {
      _appendLoopStageGuidance(
        session: session,
        explanation:
            'Test updates are available during test review only. Use this after generation and before execution.',
      );
      return true;
    }

    final ref = int.tryParse(commandMatch.group(2) ?? '');
    if (ref == null || ref <= 0) {
      _appendLoopStageGuidance(
        session: session,
        explanation:
            'Could not identify the test reference. Use labels like T1.',
      );
      return true;
    }

    final tests = machine.state.generatedTests;
    if (ref > tests.length) {
      _appendLoopStageGuidance(
        session: session,
        explanation:
            'Test reference T$ref is out of range. Available labels: T1-T${tests.length}.',
      );
      return true;
    }

    final payload = (commandMatch.group(3) ?? '').trim();
    if (payload.isEmpty) {
      _appendLoopStageGuidance(
        session: session,
        explanation:
            'Provide update details after the test reference. Example: update T2: add assertion body is array.',
      );
      return true;
    }

    final update = _parseInlineTestUpdatePayload(payload);
    machine.updateTestCaseDraft(
      testId: tests[ref - 1].id,
      title: update.title,
      description: update.description,
      expectedOutcome: update.expectedOutcome,
      assertions: update.assertions,
      appendAssertions: update.appendAssertions,
    );

    var updatedSession = session.copyWith(
      stage: AgentLoopStage.awaitingApproval,
      lastWorkflowSnapshot: machine.state,
      lastRunSummary: _summarizeWorkflowSnapshot(machine.state),
      clearLastError: true,
    );
    updatedSession = _reopenReviewStep(updatedSession);
    _upsertLoopSession(requestId, updatedSession);

    final fields = <String>[];
    if (update.title != null) fields.add('title');
    if (update.description != null) fields.add('description');
    if (update.expectedOutcome != null) fields.add('expected outcome');
    if ((update.assertions ?? const <String>[]).isNotEmpty) {
      fields.add(
        update.appendAssertions ? 'assertions (appended)' : 'assertions',
      );
    }
    final changed = fields.isEmpty ? 'details' : fields.join(', ');
    _appendLoopStageGuidance(
      session: updatedSession,
      explanation:
          'Updated T$ref ($changed). Review decisions were reset for this test; approve/reject again when ready.',
    );
    return true;
  }

  bool _tryAddCustomTestCommand({
    required String requestId,
    required AgentLoopSession session,
    required String userText,
  }) {
    final commandMatch = RegExp(
      r'^\s*(add|create|append)\s+(?:the\s+)?(?:new\s+)?(?:test|t)(?:\s*t?\s*(\d+))?\s*[:\-]?\s*(.*)\s*$',
      caseSensitive: false,
    ).firstMatch(userText);
    if (commandMatch == null) {
      return false;
    }

    final machine = _syncMachineToLoopSession(session);
    if (session.stage != AgentLoopStage.awaitingApproval ||
        machine.state.workflowState != AgenticWorkflowState.awaitingApproval) {
      _appendLoopStageGuidance(
        session: session,
        explanation:
            'Adding custom tests is available during test review only (after generation, before execution).',
      );
      return true;
    }

    final payload = (commandMatch.group(3) ?? '').trim();
    if (payload.isEmpty) {
      _appendLoopStageGuidance(
        session: session,
        explanation:
            'Please describe the test after the command. Example: add test: body should be array.',
      );
      return true;
    }

    final parsed = _parseCustomTestPayload(
      payload: payload,
      fallbackIndex: machine.state.generatedTests.length + 1,
    );
    machine.addTestCaseDraft(
      title: parsed.title,
      description: parsed.description,
      expectedOutcome: parsed.expectedOutcome,
      assertions: parsed.assertions,
    );

    var updatedSession = session.copyWith(
      stage: AgentLoopStage.awaitingApproval,
      lastWorkflowSnapshot: machine.state,
      lastRunSummary: _summarizeWorkflowSnapshot(machine.state),
      clearLastError: true,
    );
    updatedSession = _reopenReviewStep(updatedSession);
    _upsertLoopSession(requestId, updatedSession);

    final label = 'T${machine.state.generatedTests.length}';
    _appendLoopStageGuidance(
      session: updatedSession,
      explanation:
          'Added $label "${parsed.title}" with ${parsed.assertions.length} assertion(s). Approve/reject it before execution.',
    );
    return true;
  }

  ({
    String title,
    String description,
    String expectedOutcome,
    List<String> assertions,
  })
  _parseCustomTestPayload({
    required String payload,
    required int fallbackIndex,
  }) {
    final normalized = payload.replaceAll(RegExp(r'\s+'), ' ').trim();
    final titleMatch = RegExp(
      r'(?:^|[;\n])\s*title\s*:\s*([^;\n]+)',
      caseSensitive: false,
    ).firstMatch(payload);
    final descriptionMatch = RegExp(
      r'(?:^|[;\n])\s*description\s*:\s*([^;\n]+)',
      caseSensitive: false,
    ).firstMatch(payload);
    final expectedMatch = RegExp(
      r'(?:^|[;\n])\s*(?:expected|outcome|expected outcome)\s*:\s*([^;\n]+)',
      caseSensitive: false,
    ).firstMatch(payload);
    final assertionsMatch = RegExp(
      r'(?:^|[;\n])\s*(?:assertion|assertions)\s*:\s*(.+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(payload);

    final assertions = assertionsMatch != null
        ? _splitAssertionPayload(assertionsMatch.group(1) ?? '')
        : _splitAssertionPayload(normalized);

    final title = titleMatch != null
        ? _normalizeCustomTestTitle(
            titleMatch.group(1) ?? '',
            fallbackIndex: fallbackIndex,
          )
        : _normalizeCustomTestTitle(normalized, fallbackIndex: fallbackIndex);
    final description = descriptionMatch != null
        ? (descriptionMatch.group(1) ?? '').trim()
        : 'User-defined test: $normalized';
    final expected = expectedMatch != null
        ? (expectedMatch.group(1) ?? '').trim()
        : (assertions.isNotEmpty
              ? 'API satisfies custom assertion(s): ${assertions.join('; ')}'
              : 'API satisfies the custom test expectations.');

    return (
      title: title,
      description: description.isEmpty
          ? 'User-defined test case.'
          : description,
      expectedOutcome: expected,
      assertions: assertions.isNotEmpty
          ? assertions
          : <String>['Status code is 200'],
    );
  }

  String _normalizeCustomTestTitle(String raw, {required int fallbackIndex}) {
    var cleaned = raw
        .replaceFirst(RegExp(r'^(for|about)\s+', caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty) {
      return 'Custom test $fallbackIndex';
    }
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length > 60) {
      cleaned = '${cleaned.substring(0, 57)}...';
    }
    return 'Custom: ${cleaned[0].toUpperCase()}${cleaned.substring(1)}';
  }

  AgentLoopSession _reopenReviewStep(AgentLoopSession session) {
    final plan = session.plan;
    if (plan == null) {
      return session;
    }
    final reviewIndex = plan.steps.indexWhere(
      (step) => step.type == AgentPlanStepType.review,
    );
    if (reviewIndex == -1) {
      return session;
    }
    final reviewStep = plan.steps[reviewIndex];
    if (reviewStep.status == AgentPlanStepStatus.pending) {
      return session;
    }
    final updatedSteps = [...plan.steps];
    updatedSteps[reviewIndex] = reviewStep.copyWith(
      status: AgentPlanStepStatus.pending,
      clearError: true,
    );
    return session.copyWith(plan: plan.copyWith(steps: updatedSteps));
  }

  ({
    String? title,
    String? description,
    String? expectedOutcome,
    List<String>? assertions,
    bool appendAssertions,
  })
  _parseInlineTestUpdatePayload(String payload) {
    String? title;
    String? description;
    String? expectedOutcome;
    List<String>? assertions;
    var appendAssertions = true;

    String extractValue(String raw) {
      final idx = raw.indexOf(':');
      if (idx == -1) {
        return raw.trim();
      }
      return raw.substring(idx + 1).trim();
    }

    final normalized = payload.trim();
    final lower = normalized.toLowerCase();

    if (lower.startsWith('title:')) {
      title = extractValue(normalized);
    } else if (lower.startsWith('description:')) {
      description = extractValue(normalized);
    } else if (lower.startsWith('expected:') ||
        lower.startsWith('expected outcome:') ||
        lower.startsWith('outcome:')) {
      expectedOutcome = extractValue(normalized);
    } else if (lower.startsWith('replace assertions:')) {
      assertions = _splitAssertionPayload(extractValue(normalized));
      appendAssertions = false;
    } else if (lower.startsWith('assertions:') ||
        lower.startsWith('add assertion:') ||
        lower.startsWith('assertion:')) {
      assertions = _splitAssertionPayload(extractValue(normalized));
      appendAssertions = true;
    } else {
      assertions = _splitAssertionPayload(normalized);
      appendAssertions = true;
    }

    return (
      title: title,
      description: description,
      expectedOutcome: expectedOutcome,
      assertions: assertions,
      appendAssertions: appendAssertions,
    );
  }

  List<String> _splitAssertionPayload(String payload) {
    final normalized = payload
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    if (normalized.isEmpty) {
      return const <String>[];
    }
    final chunks = normalized
        .split(RegExp(r';|\n'))
        .map((line) => line.replaceFirst(RegExp(r'^\s*[-*]\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return chunks.isEmpty ? <String>[normalized] : chunks;
  }

  Future<void> _applyDecisionIntent({
    required String requestId,
    required AgentLoopSession session,
    required AgentLoopTextIntent intent,
  }) async {
    final machine = _syncMachineToLoopSession(session);
    final workflowState = machine.state.workflowState;
    final isReviewState =
        workflowState == AgenticWorkflowState.awaitingApproval;
    final isHealingState =
        workflowState == AgenticWorkflowState.awaitingHealApproval;

    if (session.stage != AgentLoopStage.awaitingApproval ||
        (!isReviewState && !isHealingState)) {
      _appendLoopStageGuidance(
        session: session,
        explanation:
            'Per-test decisions are available only in review/healing approval stages.',
      );
      return;
    }

    final tests = machine.state.generatedTests;
    if (tests.isEmpty) {
      _appendLoopStageGuidance(
        session: session,
        explanation: 'No tests are available to review in this run.',
      );
      return;
    }

    final operationByTestId = <String, AgentLoopDecisionOperation>{};
    final unresolvedRefs = <int>{};

    for (final command in intent.decisions) {
      final refs = command.applyToAll
          ? List<int>.generate(tests.length, (index) => index + 1)
          : command.references;
      if (refs.isEmpty) {
        continue;
      }

      final selectedIds = <String>{};
      for (final ref in refs) {
        if (ref < 1 || ref > tests.length) {
          unresolvedRefs.add(ref);
          continue;
        }
        final id = tests[ref - 1].id;
        selectedIds.add(id);
        operationByTestId[id] = command.operation;
      }

      if (command.only && selectedIds.isNotEmpty) {
        for (final testCase in tests) {
          if (!selectedIds.contains(testCase.id)) {
            operationByTestId[testCase.id] = AgentLoopDecisionOperation.reject;
          }
        }
      }
    }

    if (operationByTestId.isEmpty) {
      _appendLoopStageGuidance(
        session: session,
        explanation:
            'I could not map that command to tests. Try references like T1, T2, or "approve all".',
      );
      return;
    }

    for (final entry in operationByTestId.entries) {
      if (isHealingState) {
        if (entry.value == AgentLoopDecisionOperation.approve) {
          machine.approveHealing(entry.key);
        } else {
          machine.rejectHealing(entry.key);
        }
      } else {
        if (entry.value == AgentLoopDecisionOperation.approve) {
          machine.approveTest(entry.key);
        } else {
          machine.rejectTest(entry.key);
        }
      }
    }

    var updatedSession = session.copyWith(
      lastWorkflowSnapshot: machine.state,
      lastRunSummary: _summarizeWorkflowSnapshot(machine.state),
      clearLastError: true,
    );

    final currentStepType = updatedSession.plan?.currentStep?.type;
    if (isReviewState &&
        currentStepType == AgentPlanStepType.review &&
        machine.state.pendingCount == 0) {
      updatedSession = _completeCurrentPlanStep(
        updatedSession,
        expectedStep: AgentPlanStepType.review,
      );
    } else if (isHealingState &&
        currentStepType == AgentPlanStepType.healReview &&
        machine.state.healPendingCount == 0) {
      updatedSession = _completeCurrentPlanStep(
        updatedSession,
        expectedStep: AgentPlanStepType.healReview,
      );
    }

    _upsertLoopSession(requestId, updatedSession);

    final touched = operationByTestId.length;
    final pendingLine = isHealingState
        ? 'Healing pending: ${machine.state.healPendingCount}.'
        : 'Review pending: ${machine.state.pendingCount}.';
    final unresolvedLine = unresolvedRefs.isEmpty
        ? ''
        : ' Unresolved refs: ${unresolvedRefs.toList()..sort()}.';
    final skipNote =
        operationByTestId.values.contains(AgentLoopDecisionOperation.skip)
        ? ' Skip is treated as reject for this run.'
        : '';

    final nextStep = updatedSession.plan?.currentStep?.type;
    final nextLine = nextStep == null
        ? ''
        : ' Next step: ${_stepLabel(nextStep)}.';

    _appendLoopStageGuidance(
      session: updatedSession,
      explanation:
          'Applied decisions to $touched test(s). $pendingLine$unresolvedLine$skipNote$nextLine',
    );
  }

  Future<void> _applyExecuteOnlyIntent({
    required String requestId,
    required AgentLoopSession session,
    required AgentLoopTextIntent intent,
  }) async {
    final machine = _syncMachineToLoopSession(session);
    if (session.stage != AgentLoopStage.awaitingApproval ||
        machine.state.workflowState != AgenticWorkflowState.awaitingApproval) {
      _appendLoopStageGuidance(
        session: session,
        explanation:
            'Execute-only selection is available during test review only.',
      );
      return;
    }

    final tests = machine.state.generatedTests;
    if (tests.isEmpty) {
      _appendLoopStageGuidance(
        session: session,
        explanation: 'No generated tests are available yet.',
      );
      return;
    }
    if (intent.references.isEmpty) {
      _appendLoopStageGuidance(
        session: session,
        explanation:
            'Please specify test references, for example: "execute only T1 T2".',
      );
      return;
    }

    final selectedRefs = <int>{};
    final invalidRefs = <int>{};
    for (final ref in intent.references) {
      if (ref < 1 || ref > tests.length) {
        invalidRefs.add(ref);
      } else {
        selectedRefs.add(ref);
      }
    }
    if (selectedRefs.isEmpty) {
      _appendLoopStageGuidance(
        session: session,
        explanation:
            'None of the requested test references were valid. Available range is T1-T${tests.length}.',
      );
      return;
    }

    machine.rejectAll();
    for (final ref in selectedRefs) {
      machine.approveTest(tests[ref - 1].id);
    }

    var updatedSession = session.copyWith(
      lastWorkflowSnapshot: machine.state,
      lastRunSummary: _summarizeWorkflowSnapshot(machine.state),
      clearLastError: true,
    );

    if (updatedSession.plan?.currentStep?.type == AgentPlanStepType.review &&
        machine.state.pendingCount == 0) {
      updatedSession = _completeCurrentPlanStep(
        updatedSession,
        expectedStep: AgentPlanStepType.review,
      );
    }

    _upsertLoopSession(requestId, updatedSession);

    final selectedLabels = selectedRefs.toList()..sort();
    final invalidLine = invalidRefs.isEmpty
        ? ''
        : ' Invalid refs ignored: ${invalidRefs.toList()..sort()}.';
    _appendLoopStageGuidance(
      session: updatedSession,
      explanation:
          'Prepared execute-only selection for ${selectedLabels.map((value) => 'T$value').join(', ')}.$invalidLine Confirm risky execution by tapping Execute Next Step.',
    );
  }

  void _applyDiagnosticIntent({
    required AgentLoopSession session,
    required AgentLoopTextIntent intent,
  }) {
    final snapshot = session.lastWorkflowSnapshot;
    if (snapshot == null || snapshot.generatedTests.isEmpty) {
      _appendLoopStageGuidance(
        session: session,
        explanation: 'No workflow snapshot is available yet for diagnostics.',
      );
      return;
    }

    final tests = snapshot.generatedTests;
    final selected = _resolveTestsByReference(
      tests: tests,
      references: intent.references,
      fallbackForFailure: intent.type == AgentLoopTextIntentType.explainFailure,
    );

    if (selected.isEmpty) {
      _appendLoopStageGuidance(
        session: session,
        explanation:
            'I could not find the referenced tests. Try labels like T1, T2, T3.',
      );
      return;
    }

    final lines = <String>[];
    for (final item in selected) {
      final label = 'T${item.$1}';
      final testCase = item.$2;
      switch (intent.type) {
        case AgentLoopTextIntentType.explainFailure:
          lines.add(_buildFailureExplanation(label: label, testCase: testCase));
          break;
        case AgentLoopTextIntentType.explainHealing:
          lines.add(_buildHealingExplanation(label: label, testCase: testCase));
          break;
        case AgentLoopTextIntentType.explainTestDetails:
          lines.add(_buildTestDetails(label: label, testCase: testCase));
          break;
        default:
          break;
      }
    }

    _appendLoopStageGuidance(session: session, explanation: lines.join('\n\n'));
  }

  List<(int, AgenticTestCase)> _resolveTestsByReference({
    required List<AgenticTestCase> tests,
    required List<int> references,
    bool fallbackForFailure = false,
  }) {
    final selected = <(int, AgenticTestCase)>[];
    if (references.isEmpty && fallbackForFailure) {
      for (var i = 0; i < tests.length; i++) {
        final testCase = tests[i];
        if (testCase.executionStatus == TestExecutionStatus.failed ||
            testCase.executionStatus == TestExecutionStatus.skipped) {
          selected.add((i + 1, testCase));
        }
      }
      if (selected.isNotEmpty) {
        return selected;
      }
    }

    final seen = <int>{};
    for (final ref in references) {
      if (ref < 1 || ref > tests.length || !seen.add(ref)) {
        continue;
      }
      selected.add((ref, tests[ref - 1]));
    }
    return selected;
  }

  AgentLoopSession _completeCurrentPlanStep(
    AgentLoopSession session, {
    required AgentPlanStepType expectedStep,
  }) {
    final plan = session.plan;
    if (plan == null) {
      return session;
    }
    final index = plan.steps.indexWhere((step) => !step.isTerminal);
    if (index == -1) {
      return session;
    }
    final current = plan.steps[index];
    if (current.type != expectedStep) {
      return session;
    }
    final updatedSteps = [...plan.steps];
    updatedSteps[index] = current.copyWith(
      status: AgentPlanStepStatus.completed,
      clearError: true,
    );
    return session.copyWith(plan: plan.copyWith(steps: updatedSteps));
  }

  Future<void> _applyLoopActionType(ChatActionType type) async {
    await applyAgentLoopAction(
      ChatAction.fromJson(_workflowActionPayload(type)),
    );
  }

  void _appendLoopStageGuidance({
    required AgentLoopSession session,
    required String explanation,
  }) {
    final actionPayloads = _actionsForLoopSession(session);
    final mcpApp = _buildMcpAppPayload(session);
    _appendSystem(
      jsonEncode({
        'explanation': explanation,
        'actions': actionPayloads,
        if (mcpApp != null) 'mcp_app': mcpApp,
      }),
      ChatMessageType.agenticWorkflow,
      actions: actionPayloads.map(ChatAction.fromJson).toList(),
    );
  }

  String _buildFailureExplanation({
    required String label,
    required AgenticTestCase testCase,
  }) {
    if (testCase.executionStatus == TestExecutionStatus.passed) {
      return '$label ${testCase.title}: Passed. No failure detected.';
    }
    if (testCase.executionStatus == TestExecutionStatus.notRun) {
      return '$label ${testCase.title}: Not run yet. Execute tests first to inspect failures.';
    }

    final summary = (testCase.executionSummary ?? '').trim();
    final summaryText = summary.isEmpty
        ? 'No execution summary available.'
        : summary;
    final statusText = testCase.responseStatusCode == null
        ? 'N/A'
        : testCase.responseStatusCode.toString();
    final timeText = testCase.responseTimeMs == null
        ? 'N/A'
        : '${testCase.responseTimeMs} ms';
    final report = testCase.assertionReport.isEmpty
        ? '- No assertion-level report captured.'
        : testCase.assertionReport.map((line) => '- $line').join('\n');

    return '$label ${testCase.title}\n'
        '- Failure type: ${testCase.failureType.label}\n'
        '- Execution summary: $summaryText\n'
        '- Response status: $statusText\n'
        '- Response time: $timeText\n'
        '- Assertion report:\n$report';
  }

  String _buildHealingExplanation({
    required String label,
    required AgenticTestCase testCase,
  }) {
    final suggestion = (testCase.healingSuggestion ?? '').trim();
    final suggestionText = suggestion.isEmpty
        ? 'No healing recommendation is available for this test.'
        : suggestion;
    final manualChecks = testCase.healingAssertions.isEmpty
        ? '- No manual healing checks listed.'
        : testCase.healingAssertions.map((line) => '- $line').join('\n');
    return '$label ${testCase.title}\n'
        '- Healing decision: ${testCase.healingDecision.label}\n'
        '- Suggested fix: $suggestionText\n'
        '- Manual checks:\n$manualChecks';
  }

  String _buildTestDetails({
    required String label,
    required AgenticTestCase testCase,
  }) {
    return '$label ${testCase.title}\n'
        '- Review: ${testCase.decision.label}\n'
        '- Execution: ${testCase.executionStatus.label}\n'
        '- Failure type: ${testCase.failureType.label}\n'
        '- Healing: ${testCase.healingDecision.label}\n'
        '- Expected: ${testCase.expectedOutcome}';
  }

  String _summarizeWorkflowSnapshot(AgenticWorkflowContext workflow) {
    return 'State=${workflow.workflowState.label} | '
        'Approved=${workflow.approvedCount} Rejected=${workflow.rejectedCount} Pending=${workflow.pendingCount} | '
        'Passed=${workflow.passedCount} Failed=${workflow.failedCount} Skipped=${workflow.skippedCount} | '
        'HealPending=${workflow.healPendingCount} HealApproved=${workflow.healApprovedCount} HealApplied=${workflow.healAppliedCount}';
  }

  (AgentLoopSession, List<ChatAction>) _buildLoopPlanFromResponse({
    required Map<String, dynamic>? parsedResponse,
    required String userGoal,
    required String requestId,
  }) {
    final coordinator = _ref.read(agentLoopCoordinatorProvider);
    final existing = state.loopSessions[requestId];
    final suggested = _parseSuggestedPlan(parsedResponse);
    final goal = userGoal.trim().isNotEmpty
        ? userGoal.trim()
        : (parsedResponse?['goal'] as String?)?.trim().isNotEmpty == true
        ? (parsedResponse!['goal'] as String).trim()
        : existing?.goal ??
              'Run an agentic API testing workflow for this request.';

    final plan = coordinator.createPlan(
      goal: goal,
      suggested: suggested,
      source: suggested != null ? 'llm' : 'fallback',
    );

    final nextSession = (existing ?? AgentLoopSession(requestId: requestId))
        .copyWith(
          stage: AgentLoopStage.planReady,
          goal: goal,
          plan: plan,
          clearLastError: true,
          clearFollowUpPrompt: true,
        );

    final finalActions = _resolveWorkflowActions(
      session: nextSession,
      parsedResponse: parsedResponse,
    );

    return (nextSession, finalActions);
  }

  AgentExecutionPlan? _parseSuggestedPlan(
    Map<String, dynamic>? parsedResponse,
  ) {
    final rawPlan = parsedResponse?['plan'];
    if (rawPlan is! Map) {
      return null;
    }

    try {
      final map = Map<String, dynamic>.from(rawPlan);
      if (map['steps'] is! List) {
        return null;
      }
      return AgentExecutionPlan.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  String _extractExplanation(Map<String, dynamic>? parsed, String fallback) {
    final exp = parsed?['explanation'];
    if (exp is String && exp.trim().isNotEmpty) {
      return exp.trim();
    }
    final extracted = _tryExtractExplanationFromJsonLike(fallback);
    if (extracted != null) {
      return extracted;
    }
    final trimmed = fallback.trim();
    if (trimmed.isNotEmpty) {
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        return 'Plan response received, but it was not in the expected structured format. Please retry.';
      }
      return trimmed;
    }
    return 'Proposed plan ready for approval.';
  }

  String? _tryExtractExplanationFromJsonLike(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final match = RegExp(
      r'"explanation"\s*:\s*"((?:\\.|[^"\\])*)"',
    ).firstMatch(trimmed);
    if (match == null) {
      return null;
    }
    final captured = match.group(1);
    if (captured == null || captured.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode('"$captured"');
      if (decoded is String && decoded.trim().isNotEmpty) {
        return decoded.trim();
      }
    } catch (_) {}
    final bestEffort = captured
        .replaceAll(r'\"', '"')
        .replaceAll(r'\n', '\n')
        .trim();
    return bestEffort.isEmpty ? null : bestEffort;
  }

  List<ChatAction> _extractWorkflowActions(Map<String, dynamic>? parsed) {
    final rawActions = parsed?['actions'];
    if (rawActions is! List) {
      return const <ChatAction>[];
    }

    final actions = rawActions
        .whereType<Map>()
        .map((item) => ChatAction.fromJson(Map<String, dynamic>.from(item)))
        .where(
          (action) => action.targetType == ChatActionTarget.agenticWorkflow,
        )
        .toList();
    return actions;
  }

  List<ChatAction> _resolveWorkflowActions({
    required AgentLoopSession session,
    required Map<String, dynamic>? parsedResponse,
  }) {
    final fallbackActions = _actionsForLoopSession(
      session,
    ).map(ChatAction.fromJson).toList();
    if (fallbackActions.isEmpty) {
      return const <ChatAction>[];
    }

    final allowedTypes = fallbackActions
        .map((action) => action.actionType)
        .toSet();
    final proposedActions = _extractWorkflowActions(parsedResponse);

    final dedupedProposed = <ChatAction>[];
    final seenTypes = <ChatActionType>{};
    for (final action in proposedActions) {
      if (!allowedTypes.contains(action.actionType)) {
        continue;
      }
      if (!seenTypes.add(action.actionType)) {
        continue;
      }
      dedupedProposed.add(action);
    }

    if (dedupedProposed.length == fallbackActions.length) {
      return dedupedProposed;
    }
    return fallbackActions;
  }

  void _upsertLoopSession(String requestId, AgentLoopSession session) {
    final updated = Map<String, AgentLoopSession>.from(state.loopSessions);
    updated[requestId] = session;
    state = state.copyWith(loopSessions: updated);
  }

  AgentLoopExecutionContext _buildLoopExecutionContext(
    AgentLoopSession session,
  ) {
    final request = _currentRequest?.httpRequestModel;
    final endpoint = request?.url.trim().isNotEmpty == true
        ? request!.url.trim()
        : (session.lastWorkflowSnapshot?.endpoint ?? '');
    final method =
        request?.method.name.toUpperCase() ??
        session.lastWorkflowSnapshot?.requestMethod ??
        'GET';
    final headers =
        request?.headersMap ??
        session.lastWorkflowSnapshot?.requestHeaders ??
        const <String, String>{};
    final body = request?.body ?? session.lastWorkflowSnapshot?.requestBody;
    final contractContext = _ref.read(
      agenticSelectedRequestContractContextProvider,
    );

    return AgentLoopExecutionContext(
      endpoint: endpoint,
      method: method,
      headers: headers,
      requestBody: body,
      generationPrompt: session.followUpPrompt ?? session.goal,
      contractContext: contractContext,
    );
  }

  List<Map<String, dynamic>> _actionsForLoopSession(AgentLoopSession session) {
    if (session.stage == AgentLoopStage.planReady &&
        (session.followUpPrompt ?? '').trim().isNotEmpty &&
        session.plan == null) {
      return const <Map<String, dynamic>>[];
    }

    switch (session.stage) {
      case AgentLoopStage.idle:
        if ((session.followUpPrompt ?? '').trim().isNotEmpty) {
          return const <Map<String, dynamic>>[];
        }
        return <Map<String, dynamic>>[
          _workflowActionPayload(ChatActionType.proposePlan),
        ];
      case AgentLoopStage.planReady:
        return <Map<String, dynamic>>[
          _workflowActionPayload(ChatActionType.approvePlan),
          _workflowActionPayload(ChatActionType.rejectPlan),
        ];
      case AgentLoopStage.awaitingApproval:
        return <Map<String, dynamic>>[
          _workflowActionPayload(ChatActionType.executeStep),
          _workflowActionPayload(ChatActionType.skipStep),
        ];
      case AgentLoopStage.executing:
        return const <Map<String, dynamic>>[];
      case AgentLoopStage.awaitingSatisfaction:
        return <Map<String, dynamic>>[
          _workflowActionPayload(ChatActionType.confirmSatisfaction),
          _workflowActionPayload(ChatActionType.requestChanges),
        ];
      case AgentLoopStage.completed:
        return const <Map<String, dynamic>>[];
    }
  }

  Map<String, dynamic> _workflowActionPayload(ChatActionType type) {
    return <String, dynamic>{
      'action': type.text,
      'target': 'agentic_workflow',
      'field': '',
      'path': null,
      'value': null,
    };
  }

  Map<String, dynamic>? _buildMcpAppPayload(AgentLoopSession session) {
    final workflow =
        session.lastWorkflowSnapshot ?? const AgenticWorkflowContext();
    final snapshot = AgenticWorkflowSnapshot.fromContext(
      sessionId: session.requestId,
      context: workflow,
    );
    var resourceUri = snapshot.mcpAppResourceUri;
    if (session.plan != null &&
        (session.stage == AgentLoopStage.planReady ||
            (session.stage == AgentLoopStage.awaitingApproval &&
                workflow.generatedTests.isEmpty))) {
      resourceUri = AgenticMcpAppResources.planReviewUri;
    }
    if (resourceUri == null) {
      return null;
    }
    final modelContext = snapshot.toJson();
    if ((session.goal ?? '').trim().isNotEmpty) {
      modelContext['goal'] = session.goal!.trim();
    }
    modelContext['loopStage'] = session.stage.name;
    if (session.plan != null) {
      modelContext['plan'] = session.plan!.toJson();
      final currentStep = session.plan!.currentStep;
      if (currentStep != null) {
        modelContext['currentPlanStep'] = currentStep.toJson();
      }
    }
    if ((session.lastRunSummary ?? '').trim().isNotEmpty) {
      modelContext['lastRunSummary'] = session.lastRunSummary!.trim();
    }
    return <String, dynamic>{
      'resourceUri': resourceUri,
      'modelContext': modelContext,
    };
  }

  String _buildLoopWorkingMessage(
    ChatActionType actionType,
    AgentLoopSession session,
  ) {
    switch (actionType) {
      case ChatActionType.approvePlan:
        return 'Applying your plan approval...';
      case ChatActionType.rejectPlan:
        return 'Applying your plan rejection...';
      case ChatActionType.executeStep:
        return _messageForPlanStep(session.plan?.currentStep?.type);
      case ChatActionType.skipStep:
        final step = session.plan?.currentStep?.type;
        if (step == null) {
          return 'Skipping current step...';
        }
        return 'Skipping ${_stepLabel(step)}...';
      case ChatActionType.confirmSatisfaction:
        return 'Finalizing workflow...';
      case ChatActionType.requestChanges:
        return 'Preparing revised plan context...';
      default:
        return 'DashBot is working...';
    }
  }

  String _messageForPlanStep(AgentPlanStepType? step) {
    switch (step) {
      case AgentPlanStepType.generate:
        return 'Generating contract-aware tests...';
      case AgentPlanStepType.review:
        return 'Applying review decisions...';
      case AgentPlanStepType.execute:
        return 'Executing approved tests on the API...';
      case AgentPlanStepType.analyze:
        return 'Analyzing failures and preparing healing plans...';
      case AgentPlanStepType.healReview:
        return 'Applying healing approvals...';
      case AgentPlanStepType.rerun:
        return 'Re-running healed tests (assertions unchanged)...';
      case AgentPlanStepType.report:
        return 'Compiling final report...';
      default:
        return 'Executing next workflow step...';
    }
  }

  String _stepLabel(AgentPlanStepType step) {
    switch (step) {
      case AgentPlanStepType.generate:
        return 'Generate';
      case AgentPlanStepType.review:
        return 'Review';
      case AgentPlanStepType.execute:
        return 'Execute';
      case AgentPlanStepType.analyze:
        return 'Analyze';
      case AgentPlanStepType.healReview:
        return 'Heal Review';
      case AgentPlanStepType.rerun:
        return 'Rerun';
      case AgentPlanStepType.report:
        return 'Report';
    }
  }

  // Helpers
  void _addMessage(String requestId, ChatMessage m) {
    final msgs = state.chatSessions[requestId] ?? const [];
    final updatedSessions = Map<String, List<ChatMessage>>.from(
      state.chatSessions,
    );
    updatedSessions[requestId] = [...msgs, m];
    state = state.copyWith(chatSessions: updatedSessions);
  }

  void _appendSystem(
    String text,
    ChatMessageType type, {
    List<ChatAction>? actions,
  }) {
    final id = _currentRequest?.id ?? 'global';
    _addMessage(
      id,
      ChatMessage(
        id: getNewUuid(),
        content: text,
        role: MessageRole.system,
        timestamp: DateTime.now(),
        messageType: type,
        actions: actions,
      ),
    );
  }

  // Prompt helper methods moved to PromptBuilder service.

  bool _looksLikeOpenApi(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    if (t.startsWith('{')) {
      try {
        final m = jsonDecode(t);
        if (m is Map &&
            (m.containsKey('openapi') || m.containsKey('swagger'))) {
          return true;
        }
      } catch (_) {}
    }
    return t.contains('openapi:') || t.contains('swagger:');
  }

  String _inferBaseUrl(String url) =>
      _ref.read(urlEnvServiceProvider).inferBaseUrl(url);

  Future<String> _ensureBaseUrlEnv(String baseUrl) async {
    final svc = _ref.read(urlEnvServiceProvider);
    return svc.ensureBaseUrlEnv(
      baseUrl,
      readEnvs: () => _ref.read(environmentsStateNotifierProvider),
      readActiveEnvId: () => _ref.read(activeEnvironmentIdStateProvider),
      updateEnv: (id, {values}) => _ref
          .read(environmentsStateNotifierProvider.notifier)
          .updateEnvironment(id, values: values),
    );
  }

  Future<String> _maybeSubstituteBaseUrl(String url, String baseUrl) async {
    final svc = _ref.read(urlEnvServiceProvider);
    return svc.maybeSubstituteBaseUrl(
      url,
      baseUrl,
      ensure: (b) => _ensureBaseUrlEnv(b),
    );
  }

  Future<String> _maybeSubstituteBaseUrlForOpenApi(
    String url,
    String baseUrl,
    String title,
  ) async {
    final svc = _ref.read(urlEnvServiceProvider);
    return svc.maybeSubstituteBaseUrl(
      url,
      baseUrl,
      ensure: (b) => svc.ensureBaseUrlEnvForOpenApi(
        b,
        title: title,
        readEnvs: () => _ref.read(environmentsStateNotifierProvider),
        readActiveEnvId: () => _ref.read(activeEnvironmentIdStateProvider),
        updateEnv: (id, {values}) => _ref
            .read(environmentsStateNotifierProvider.notifier)
            .updateEnvironment(id, values: values),
      ),
    );
  }
}
