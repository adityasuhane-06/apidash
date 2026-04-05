import 'dart:convert';

import 'package:apidash/agentic_testing/agentic_testing.dart';
import 'package:apidash/agentic_testing/providers/agentic_testing_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:apidash/dashbot/providers/providers.dart';
import 'package:apidash/dashbot/models/models.dart';
import 'package:apidash/dashbot/repository/repository.dart';
import 'package:apidash/dashbot/constants.dart';
import 'package:apidash/models/models.dart';
import 'package:apidash/dashbot/services/agent/prompt_builder.dart';
import 'package:apidash/providers/settings_providers.dart';
import 'package:apidash_core/apidash_core.dart';
import 'package:apidash/providers/collection_providers.dart';
import '../../../../providers/helpers.dart';

/// AI-enabled flow tests for ChatViewmodel.
///
/// This file contains tests specifically for AI-enabled chat functionality,
// A mock ChatRemoteRepository returning configurable responses
class MockChatRemoteRepository extends ChatRemoteRepository {
  String? mockResponse;
  Exception? mockError;
  int callCount = 0;

  @override
  Future<String?> sendChat({required AIRequestModel request}) async {
    callCount += 1;
    if (mockError != null) throw mockError!;
    return mockResponse;
  }
}

class _StaticGenerator extends AgenticTestGenerator {
  _StaticGenerator(this.tests) : super(readDefaultModel: () => const {});

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
    return tests
        .map(
          (testCase) => testCase.copyWith(
            endpoint: endpoint,
            method: method?.toUpperCase() ?? testCase.method,
          ),
        )
        .toList();
  }
}

class _PassthroughExecutor extends AgenticTestExecutor {
  @override
  Future<List<AgenticTestCase>> executeTests({
    required List<AgenticTestCase> tests,
    required Map<String, String> defaultHeaders,
    String? requestBody,
  }) async {
    return tests;
  }
}

class _MemoryCheckpointStorage extends AgenticWorkflowCheckpointStorage {
  AgenticWorkflowContext? _snapshot;
  final Map<String, AgenticWorkflowContext> _scoped = {};

  @override
  Future<void> clear() async {
    _snapshot = null;
    _scoped.clear();
  }

  @override
  Future<AgenticWorkflowContext?> load() async => _snapshot;

  @override
  Future<AgenticWorkflowContext?> loadForSession({
    required String sessionKey,
  }) async {
    return _scoped[sessionKey];
  }

  @override
  Future<void> save(AgenticWorkflowContext context) async {
    _snapshot = context;
  }

  @override
  Future<void> saveForSession({
    required String sessionKey,
    required AgenticWorkflowContext context,
  }) async {
    _scoped[sessionKey] = context;
  }

  @override
  Future<void> clearForSession({required String sessionKey}) async {
    _scoped.remove(sessionKey);
  }
}

class _PromptCaptureBuilder extends PromptBuilder {
  final PromptBuilder _inner;
  _PromptCaptureBuilder(this._inner);
  String? lastSystemPrompt;

  @override
  String buildSystemPrompt(
    RequestModel? req,
    ChatMessageType type, {
    String? overrideLanguage,
    String? priorRunSummary,
    List<ChatMessage> history = const [],
  }) {
    final r = _inner.buildSystemPrompt(
      req,
      type,
      overrideLanguage: overrideLanguage,
      priorRunSummary: priorRunSummary,
      history: history,
    );
    lastSystemPrompt = r;
    return r;
  }

  @override
  String? detectLanguage(String text) => _inner.detectLanguage(text);

  @override
  String getUserMessageForTask(ChatMessageType type) =>
      _inner.getUserMessageForTask(type);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late MockChatRemoteRepository mockRepo;
  late _PromptCaptureBuilder promptCapture;

  setUp(() async {
    await testSetUpTempDirForHive();
  });

  // Helper to obtain a default PromptBuilder by reading the real provider in a temp container
  PromptBuilder basePromptBuilder() {
    final temp = ProviderContainer();
    final pb = temp.read(promptBuilderProvider);
    temp.dispose();
    return pb;
  }

  ProviderContainer createTestContainer({
    String? aiExplanation,
    String? actionsJson,
    List<Override> overrides = const [],
    RequestModel? selectedRequest,
  }) {
    mockRepo = MockChatRemoteRepository();
    if (aiExplanation != null) {
      // Build a response optionally with actions
      final actionsPart = actionsJson ?? '[]';
      mockRepo.mockResponse =
          '{"explanation":"$aiExplanation","actions":$actionsPart}';
    }

    // Proper AI model JSON matching AIRequestModel.fromJson keys
    final aiModelJson = {
      'modelApiProvider': 'openai',
      'model': 'gpt-test',
      'apiKey': 'sk-test',
      'system_prompt': '',
      'user_prompt': '',
      'model_configs': [],
      'stream': false,
    };

    final baseSettings = SettingsModel(defaultAIModel: aiModelJson);
    promptCapture = _PromptCaptureBuilder(basePromptBuilder());

    return createContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(mockRepo),
        settingsProvider.overrideWith(
          (ref) => ThemeStateNotifier(settingsModel: baseSettings),
        ),
        selectedRequestModelProvider.overrideWith((ref) => selectedRequest),
        promptBuilderProvider.overrideWith((ref) => promptCapture),
        ...overrides,
      ],
    );
  }

  group('ChatViewmodel AI Enabled Flow', () {
    test('processes valid AI explanation + actions list', () async {
      container = createTestContainer(
        aiExplanation: 'Here is your code',
        actionsJson:
            '[{"action":"other","target":"code","field":"generated","value":"print(\\"hi\\")"}]',
      );
      final vm = container.read(chatViewmodelProvider.notifier);

      await vm.sendMessage(
        text: 'Generate code',
        type: ChatMessageType.generateCode,
      );

      final msgs = vm.currentMessages;
      // Expect exactly 2 messages: user + system response
      expect(msgs.length, equals(2));
      final user = msgs.first;
      final system = msgs.last;
      expect(user.role, MessageRole.user);
      expect(system.role, MessageRole.system);
      expect(system.actions, isNotNull);
      expect(system.actions!.length, equals(1));
      expect(system.content, contains('Here is your code'));
      expect(promptCapture.lastSystemPrompt, isNotNull);
      expect(promptCapture.lastSystemPrompt, contains('Generate'));
    });

    test('handles empty AI response (adds fallback message)', () async {
      container = createTestContainer();
      mockRepo.mockResponse = ''; // Explicit empty
      final vm = container.read(chatViewmodelProvider.notifier);

      await vm.sendMessage(
        text: 'Explain',
        type: ChatMessageType.explainResponse,
      );

      final msgs = vm.currentMessages;
      expect(msgs, isNotEmpty);
      expect(msgs.last.content, contains('No response'));
    });

    test('handles null AI response (adds fallback message)', () async {
      container = createTestContainer();
      mockRepo.mockResponse = null; // Explicit null
      final vm = container.read(chatViewmodelProvider.notifier);
      await vm.sendMessage(text: 'Debug', type: ChatMessageType.debugError);
      final msgs = vm.currentMessages;
      expect(msgs, isNotEmpty);
      expect(msgs.last.content, contains('No response'));
    });

    test('handles malformed actions field gracefully', () async {
      container = createTestContainer();
      mockRepo.mockResponse =
          '{"explanation":"Something","actions":"not-a-list"}';
      final vm = container.read(chatViewmodelProvider.notifier);
      await vm.sendMessage(
        text: 'Gen test',
        type: ChatMessageType.generateTest,
      );
      final msgs = vm.currentMessages;
      expect(msgs, isNotEmpty);
      final sys = msgs.last;
      expect(sys.content, contains('Something'));
    });

    test(
      'handles malformed top-level JSON gracefully (no crash, fallback)',
      () async {
        container = createTestContainer();
        // This will cause MessageJson.safeParse to catch and ignore malformed content
        mockRepo.mockResponse =
            '{"explanation":"ok","actions": [ { invalid json }';
        final vm = container.read(chatViewmodelProvider.notifier);
        await vm.sendMessage(
          text: 'Gen code',
          type: ChatMessageType.generateCode,
        );
        final msgs = vm.currentMessages;
        expect(msgs.length, equals(2)); // user + system with raw content
        expect(msgs.last.content, contains('explanation'));
      },
    );

    test(
      'handles missing explanation key (still stores raw response)',
      () async {
        container = createTestContainer();
        mockRepo.mockResponse = '{"note":"Just a note","actions": []}';
        final vm = container.read(chatViewmodelProvider.notifier);
        await vm.sendMessage(
          text: 'Explain',
          type: ChatMessageType.explainResponse,
        );
        final msgs = vm.currentMessages;
        expect(msgs.length, equals(2));
        expect(msgs.last.content, contains('note'));
      },
    );

    test(
      'catches repository exception and appends error system message',
      () async {
        container = createTestContainer();
        mockRepo.mockError = Exception('boom');
        final vm = container.read(chatViewmodelProvider.notifier);
        await vm.sendMessage(text: 'Doc', type: ChatMessageType.generateDoc);
        final msgs = vm.currentMessages;
        expect(msgs, isNotEmpty);
        expect(msgs.last.content, contains('Error:'));
      },
    );

    test(
      'agentic workflow response creates loop session with fallback plan',
      () async {
        container = createTestContainer();
        mockRepo.mockResponse =
            '{"explanation":"Plan ready","actions":[{"action":"approve_plan","target":"agentic_workflow","field":"","path":null,"value":null}]}';

        final vm = container.read(chatViewmodelProvider.notifier);
        await vm.sendMessage(
          text: 'Run an agentic testing workflow',
          type: ChatMessageType.agenticWorkflow,
        );

        final session = vm.currentLoopSession;
        expect(session, isNotNull);
        expect(session!.stage, AgentLoopStage.planReady);
        expect(session.plan, isNotNull);
        expect(session.plan!.steps, isNotEmpty);

        final msgs = vm.currentMessages;
        expect(msgs.last.messageType, ChatMessageType.agenticWorkflow);
        expect(msgs.last.content, contains('approve_plan'));
        expect(msgs.last.content, contains('ui://agentic/plan-review'));
      },
    );

    test('typed approve plan is handled as a workflow command', () async {
      container = createTestContainer();
      mockRepo.mockResponse =
          '{"explanation":"Plan ready","actions":[{"action":"approve_plan","target":"agentic_workflow","field":"","path":null,"value":null}]}';

      final vm = container.read(chatViewmodelProvider.notifier);
      await vm.sendMessage(
        text: 'Run an agentic testing workflow',
        type: ChatMessageType.agenticWorkflow,
      );
      expect(mockRepo.callCount, 1);

      await vm.sendMessage(text: 'approve plan', type: ChatMessageType.general);

      expect(mockRepo.callCount, 1);
      expect(vm.currentLoopSession?.stage, AgentLoopStage.awaitingApproval);
      expect(vm.currentMessages.last.content, contains('Plan approved'));
    });

    test('need changes resets stale tests before replanning', () async {
      final generated = <AgenticTestCase>[
        const AgenticTestCase(
          id: 't1',
          title: 'existing',
          description: 'd1',
          method: 'GET',
          endpoint: 'https://api.apidash.dev/users/1',
          expectedOutcome: 'ok',
          assertions: ['status 200'],
        ),
      ];

      container = createTestContainer(
        selectedRequest: RequestModel(
          id: 'r1',
          name: 'User by id',
          httpRequestModel: HttpRequestModel(
            method: HTTPVerb.get,
            url: 'https://api.apidash.dev/users/1',
          ),
        ),
        overrides: [
          agenticTestGeneratorProvider.overrideWithValue(
            _StaticGenerator(generated),
          ),
          agenticTestExecutorProvider.overrideWithValue(_PassthroughExecutor()),
          agenticWorkflowCheckpointStorageProvider.overrideWithValue(
            _MemoryCheckpointStorage(),
          ),
        ],
      );
      mockRepo.mockResponse =
          '{"explanation":"Plan ready","actions":[{"action":"approve_plan","target":"agentic_workflow","field":"","path":null,"value":null}]}';

      final vm = container.read(chatViewmodelProvider.notifier);
      await vm.sendMessage(
        text: 'Run an agentic testing workflow',
        type: ChatMessageType.agenticWorkflow,
      );
      await vm.sendMessage(text: 'approve plan', type: ChatMessageType.general);
      await vm.sendMessage(
        text: 'execute next step',
        type: ChatMessageType.general,
      );

      final before = container.read(agenticTestingStateMachineProvider);
      expect(before.workflowState, AgenticWorkflowState.awaitingApproval);
      expect(before.generatedTests.length, 1);

      await vm.sendMessage(
        text: 'need changes: add T2 for email regex validation',
        type: ChatMessageType.general,
      );

      final after = container.read(agenticTestingStateMachineProvider);
      expect(after.workflowState, AgenticWorkflowState.idle);
      expect(after.generatedTests, isEmpty);
      expect(vm.currentLoopSession?.stage, AgentLoopStage.planReady);
      expect(mockRepo.callCount, 2);
      expect(vm.currentMessages.last.content, contains('approve_plan'));
    });

    test(
      'inline update Tn command updates selected test without LLM roundtrip',
      () async {
        final generated = <AgenticTestCase>[
          const AgenticTestCase(
            id: 't1',
            title: 'status test',
            description: 'd1',
            method: 'GET',
            endpoint: 'https://api.apidash.dev/users/1',
            expectedOutcome: 'Status is 200',
            assertions: ['status is 200'],
          ),
          const AgenticTestCase(
            id: 't2',
            title: 'shape test',
            description: 'd2',
            method: 'GET',
            endpoint: 'https://api.apidash.dev/users/1',
            expectedOutcome: 'Body contains id',
            assertions: ['id exists'],
          ),
        ];

        container = createTestContainer(
          selectedRequest: RequestModel(
            id: 'r1',
            name: 'User by id',
            httpRequestModel: HttpRequestModel(
              method: HTTPVerb.get,
              url: 'https://api.apidash.dev/users/1',
            ),
          ),
          overrides: [
            agenticTestGeneratorProvider.overrideWithValue(
              _StaticGenerator(generated),
            ),
            agenticTestExecutorProvider.overrideWithValue(
              _PassthroughExecutor(),
            ),
            agenticWorkflowCheckpointStorageProvider.overrideWithValue(
              _MemoryCheckpointStorage(),
            ),
          ],
        );
        mockRepo.mockResponse =
            '{"explanation":"Plan ready","actions":[{"action":"approve_plan","target":"agentic_workflow","field":"","path":null,"value":null}]}';
        final vm = container.read(chatViewmodelProvider.notifier);

        await vm.sendMessage(
          text: 'Run an agentic testing workflow',
          type: ChatMessageType.agenticWorkflow,
        );
        await vm.sendMessage(
          text: 'approve plan',
          type: ChatMessageType.general,
        );
        await vm.sendMessage(
          text: 'execute next step',
          type: ChatMessageType.general,
        );

        final before = container.read(agenticTestingStateMachineProvider);
        expect(before.generatedTests[1].assertions, equals(['id exists']));
        expect(mockRepo.callCount, 1);

        await vm.sendMessage(
          text: 'update T2: add assertion: email matches regex',
          type: ChatMessageType.general,
        );

        final after = container.read(agenticTestingStateMachineProvider);
        expect(
          after.generatedTests[1].assertions,
          contains('email matches regex'),
        );
        expect(after.generatedTests[1].decision, TestReviewDecision.pending);
        expect(vm.currentMessages.last.content, contains('Updated T2'));
        expect(mockRepo.callCount, 1);
      },
    );

    test(
      'add test command appends a custom test draft without LLM roundtrip',
      () async {
        final generated = <AgenticTestCase>[
          const AgenticTestCase(
            id: 't1',
            title: 'status test',
            description: 'd1',
            method: 'GET',
            endpoint: 'https://api.apidash.dev/users/1',
            expectedOutcome: 'Status is 200',
            assertions: ['status is 200'],
          ),
          const AgenticTestCase(
            id: 't2',
            title: 'shape test',
            description: 'd2',
            method: 'GET',
            endpoint: 'https://api.apidash.dev/users/1',
            expectedOutcome: 'Body contains id',
            assertions: ['id exists'],
          ),
        ];

        container = createTestContainer(
          selectedRequest: RequestModel(
            id: 'r1',
            name: 'User by id',
            httpRequestModel: HttpRequestModel(
              method: HTTPVerb.get,
              url: 'https://api.apidash.dev/users/1',
            ),
          ),
          overrides: [
            agenticTestGeneratorProvider.overrideWithValue(
              _StaticGenerator(generated),
            ),
            agenticTestExecutorProvider.overrideWithValue(
              _PassthroughExecutor(),
            ),
            agenticWorkflowCheckpointStorageProvider.overrideWithValue(
              _MemoryCheckpointStorage(),
            ),
          ],
        );
        mockRepo.mockResponse =
            '{"explanation":"Plan ready","actions":[{"action":"approve_plan","target":"agentic_workflow","field":"","path":null,"value":null}]}';
        final vm = container.read(chatViewmodelProvider.notifier);

        await vm.sendMessage(
          text: 'Run an agentic testing workflow',
          type: ChatMessageType.agenticWorkflow,
        );
        await vm.sendMessage(
          text: 'approve plan',
          type: ChatMessageType.general,
        );
        await vm.sendMessage(
          text: 'execute next step',
          type: ChatMessageType.general,
        );

        final before = container.read(agenticTestingStateMachineProvider);
        expect(before.generatedTests, hasLength(2));
        expect(mockRepo.callCount, 1);

        await vm.sendMessage(
          text: 'add test: body should be array',
          type: ChatMessageType.general,
        );

        final after = container.read(agenticTestingStateMachineProvider);
        expect(after.generatedTests, hasLength(3));
        expect(
          after.generatedTests.last.assertions.join(' '),
          contains('body should be array'),
        );
        expect(vm.currentMessages.last.content, contains('Added T3'));
        expect(mockRepo.callCount, 1);
      },
    );

    test(
      'execute only selection updates decisions and waits for confirmation',
      () async {
        final generated = <AgenticTestCase>[
          const AgenticTestCase(
            id: 't1',
            title: 'one',
            description: 'd1',
            method: 'GET',
            endpoint: 'https://api.apidash.dev/users',
            expectedOutcome: 'ok',
            assertions: ['status 200'],
          ),
          const AgenticTestCase(
            id: 't2',
            title: 'two',
            description: 'd2',
            method: 'GET',
            endpoint: 'https://api.apidash.dev/users',
            expectedOutcome: 'ok',
            assertions: ['status 200'],
          ),
          const AgenticTestCase(
            id: 't3',
            title: 'three',
            description: 'd3',
            method: 'GET',
            endpoint: 'https://api.apidash.dev/users',
            expectedOutcome: 'ok',
            assertions: ['status 200'],
          ),
        ];

        container = createTestContainer(
          selectedRequest: RequestModel(
            id: 'r1',
            name: 'Users request',
            httpRequestModel: HttpRequestModel(
              method: HTTPVerb.get,
              url: 'https://api.apidash.dev/users',
            ),
          ),
          overrides: [
            agenticTestGeneratorProvider.overrideWithValue(
              _StaticGenerator(generated),
            ),
            agenticTestExecutorProvider.overrideWithValue(
              _PassthroughExecutor(),
            ),
            agenticWorkflowCheckpointStorageProvider.overrideWithValue(
              _MemoryCheckpointStorage(),
            ),
          ],
        );
        mockRepo.mockResponse =
            '{"explanation":"Plan ready","actions":[{"action":"approve_plan","target":"agentic_workflow","field":"","path":null,"value":null}]}';
        final vm = container.read(chatViewmodelProvider.notifier);

        await vm.sendMessage(
          text: 'Run an agentic testing workflow',
          type: ChatMessageType.agenticWorkflow,
        );
        await vm.sendMessage(
          text: 'approve plan',
          type: ChatMessageType.general,
        );
        await vm.sendMessage(
          text: 'execute next step',
          type: ChatMessageType.general,
        );

        await vm.sendMessage(
          text: 'execute only t1',
          type: ChatMessageType.general,
        );

        final workflow = container.read(agenticTestingStateMachineProvider);
        expect(workflow.approvedCount, 1);
        expect(workflow.rejectedCount, 2);
        expect(workflow.pendingCount, 0);
        expect(workflow.workflowState, AgenticWorkflowState.awaitingApproval);
        expect(
          vm.currentLoopSession?.plan?.currentStep?.type,
          AgentPlanStepType.execute,
        );
        expect(
          vm.currentMessages.last.content,
          contains('Prepared execute-only selection for T1'),
        );

        await vm.sendMessage(
          text: 'why t1 failed?',
          type: ChatMessageType.general,
        );
        expect(vm.currentMessages.last.content, contains('Not run yet'));
      },
    );

    test(
      'agentic workflow falls back to deterministic controls when proposed set is incomplete',
      () async {
        container = createTestContainer();
        mockRepo.mockResponse =
            '{"explanation":"Plan ready","actions":[{"action":"reject_plan","target":"agentic_workflow","field":"","path":null,"value":null},{"action":"execute_step","target":"agentic_workflow","field":"","path":null,"value":null}]}';

        final vm = container.read(chatViewmodelProvider.notifier);
        await vm.sendMessage(
          text: 'Run an agentic testing workflow',
          type: ChatMessageType.agenticWorkflow,
        );

        final msgs = vm.currentMessages;
        final parsed = jsonDecode(msgs.last.content) as Map<String, dynamic>;
        final actions = (parsed['actions'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        expect(
          actions.map((item) => item['action']).toList(),
          equals(['approve_plan', 'reject_plan']),
        );
      },
    );

    test(
      'agentic workflow falls back to deterministic controls when agent proposes invalid ones',
      () async {
        container = createTestContainer();
        mockRepo.mockResponse =
            '{"explanation":"Plan ready","actions":[{"action":"execute_step","target":"agentic_workflow","field":"","path":null,"value":null}]}';

        final vm = container.read(chatViewmodelProvider.notifier);
        await vm.sendMessage(
          text: 'Run an agentic testing workflow',
          type: ChatMessageType.agenticWorkflow,
        );

        final msgs = vm.currentMessages;
        final parsed = jsonDecode(msgs.last.content) as Map<String, dynamic>;
        final actions = (parsed['actions'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        expect(
          actions.map((item) => item['action']).toList(),
          equals(['approve_plan', 'reject_plan']),
        );
      },
    );
  });
}
