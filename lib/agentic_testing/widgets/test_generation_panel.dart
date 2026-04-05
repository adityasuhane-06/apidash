import 'package:apidash/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/test_case_model.dart';
import '../models/workflow_state.dart';
import '../providers/agentic_testing_providers.dart';
import '../services/workflow_checkpoint_storage.dart';
import 'test_review_card.dart';

class TestGenerationPanel extends ConsumerStatefulWidget {
  const TestGenerationPanel({super.key});

  @override
  ConsumerState<TestGenerationPanel> createState() =>
      _TestGenerationPanelState();
}

class _TestGenerationPanelState extends ConsumerState<TestGenerationPanel> {
  late final TextEditingController _endpointController;
  late final TextEditingController _promptController;

  String _currentCheckpointSessionKey() {
    return AgenticWorkflowCheckpointStorage.normalizeSessionKey(
      ref.read(selectedRequestModelProvider)?.id,
    );
  }

  @override
  void initState() {
    super.initState();
    final initialEndpoint = ref
        .read(selectedRequestModelProvider)
        ?.httpRequestModel
        ?.url;
    _endpointController = TextEditingController(text: initialEndpoint ?? '');
    _promptController = TextEditingController();
    Future.microtask(() async {
      final notifier = ref.read(agenticTestingStateMachineProvider.notifier);
      notifier.setCheckpointSessionKey(_currentCheckpointSessionKey());
      await notifier.hydrateFromCheckpoint();
      if (!mounted) {
        return;
      }
      final restored = ref.read(agenticTestingStateMachineProvider);
      if (restored.endpoint.trim().isNotEmpty) {
        _endpointController.text = restored.endpoint;
      }
      if ((restored.generationPrompt ?? '').trim().isNotEmpty) {
        _promptController.text = restored.generationPrompt!;
      }
    });
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _onGeneratePressed() async {
    final selectedRequest = ref.read(selectedRequestModelProvider);
    final notifier = ref.read(agenticTestingStateMachineProvider.notifier);
    notifier.setCheckpointSessionKey(_currentCheckpointSessionKey());
    final selectedContractContext = ref.read(
      agenticSelectedRequestContractContextProvider,
    );

    final endpoint = _endpointController.text.trim().isNotEmpty
        ? _endpointController.text.trim()
        : (selectedRequest?.httpRequestModel?.url ?? '');

    if (endpoint.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select or enter an endpoint before generating tests.'),
        ),
      );
      return;
    }

    final selectedRequestUrl = selectedRequest?.httpRequestModel?.url.trim();
    final shouldUseSelectedContract =
        selectedContractContext != null &&
        selectedRequestUrl != null &&
        selectedRequestUrl.isNotEmpty &&
        selectedRequestUrl == endpoint;

    await notifier.startGeneration(
      endpoint: endpoint,
      method: selectedRequest?.httpRequestModel?.method.name.toUpperCase(),
      headers: selectedRequest?.httpRequestModel?.headersMap,
      requestBody: selectedRequest?.httpRequestModel?.body,
      generationPrompt: _promptController.text.trim(),
      contractContext: shouldUseSelectedContract
          ? selectedContractContext
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final workflow = ref.watch(agenticTestingStateMachineProvider);
    final notifier = ref.read(agenticTestingStateMachineProvider.notifier);
    final selectedContractContext = ref.watch(
      agenticSelectedRequestContractContextProvider,
    );
    final isGenerating =
        workflow.workflowState == AgenticWorkflowState.generating;
    final isExecuting =
        workflow.workflowState == AgenticWorkflowState.executing;
    final isAnalyzing =
        workflow.workflowState == AgenticWorkflowState.analyzingFailures;
    final isReExecuting =
        workflow.workflowState == AgenticWorkflowState.reExecuting;
    final isBusy = isGenerating || isExecuting || isAnalyzing || isReExecuting;
    final canGenerate = workflow.workflowState == AgenticWorkflowState.idle;

    final stateColor = switch (workflow.workflowState) {
      AgenticWorkflowState.idle => Theme.of(context).colorScheme.outline,
      AgenticWorkflowState.generating => Colors.blue,
      AgenticWorkflowState.awaitingApproval => Colors.orange,
      AgenticWorkflowState.executing => Colors.purple,
      AgenticWorkflowState.resultsReady => Colors.green,
      AgenticWorkflowState.analyzingFailures => Colors.deepPurple,
      AgenticWorkflowState.awaitingHealApproval => Colors.teal,
      AgenticWorkflowState.reExecuting => Colors.indigo,
      AgenticWorkflowState.finalReport => Colors.green.shade700,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Agentic API Testing Prototype',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'State Machine: IDLE -> GENERATING -> AWAITING_APPROVAL -> EXECUTING -> RESULTS_READY -> ANALYZING_FAILURES -> AWAITING_HEAL_APPROVAL -> RE_EXECUTING -> FINAL_REPORT',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Strict mode: approved healing re-runs tests without auto-changing assertions.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Chip(
              side: BorderSide(color: stateColor),
              label: Text(workflow.workflowState.label),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                workflow.statusMessage ?? 'Ready to generate API test cases.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        if (workflow.errorMessage != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.errorContainer,
            ),
            child: Text(
              workflow.errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _endpointController,
                enabled: !isBusy,
                decoration: const InputDecoration(
                  labelText: 'Endpoint',
                  hintText: '/users or https://api.example.com/users',
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: isBusy || !canGenerate ? null : _onGeneratePressed,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Tests'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _promptController,
          enabled: !isBusy,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Prompt (Optional)',
            hintText:
                'Example: Focus on auth failures, pagination edge cases, and response-time checks.',
          ),
        ),
        if (selectedContractContext != null &&
            selectedContractContext.hasAnyHints) ...[
          const SizedBox(height: 8),
          Text(
            'Contract-aware generation available (${selectedContractContext.source}). It is applied when endpoint matches the selected request URL.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (isBusy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 12),
        if (workflow.generatedTests.isNotEmpty) ...[
          Text(
            'Approved: ${workflow.approvedCount}  Rejected: ${workflow.rejectedCount}  Pending: ${workflow.pendingCount}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Passed: ${workflow.passedCount}  Failed: ${workflow.failedCount}  Skipped: ${workflow.skippedCount}  Not Run: ${workflow.notRunCount}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Heal Pending: ${workflow.healPendingCount}  Heal Approved: ${workflow.healApprovedCount}  Heal Rejected: ${workflow.healRejectedCount}  Heal Applied: ${workflow.healAppliedCount}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: workflow.generatedTests.isEmpty
              ? Center(
                  child: Text(
                    'Generate tests to review them here.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : ListView.separated(
                  itemCount: workflow.generatedTests.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final testCase = workflow.generatedTests[index];
                    return TestReviewCard(
                      testCase: testCase,
                      onApprove:
                          workflow.workflowState ==
                              AgenticWorkflowState.awaitingApproval
                          ? () => notifier.approveTest(testCase.id)
                          : null,
                      onReject:
                          workflow.workflowState ==
                              AgenticWorkflowState.awaitingApproval
                          ? () => notifier.rejectTest(testCase.id)
                          : null,
                      onApproveHealing:
                          workflow.workflowState ==
                                  AgenticWorkflowState.awaitingHealApproval &&
                              testCase.healingDecision ==
                                  TestHealingDecision.pending
                          ? () => notifier.approveHealing(testCase.id)
                          : null,
                      onRejectHealing:
                          workflow.workflowState ==
                                  AgenticWorkflowState.awaitingHealApproval &&
                              testCase.healingDecision ==
                                  TestHealingDecision.pending
                          ? () => notifier.rejectHealing(testCase.id)
                          : null,
                    );
                  },
                ),
        ),
        if (workflow.workflowState ==
            AgenticWorkflowState.awaitingApproval) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton.icon(
                onPressed: workflow.generatedTests.isEmpty
                    ? null
                    : notifier.approveAll,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Approve All'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: workflow.generatedTests.isEmpty
                    ? null
                    : notifier.rejectAll,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Reject All'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: workflow.approvedCount == 0
                    ? null
                    : () => notifier.executeApprovedTests(),
                icon: const Icon(Icons.play_arrow_outlined),
                label: const Text('Run Approved'),
              ),
              const Spacer(),
              TextButton(onPressed: notifier.reset, child: const Text('Reset')),
            ],
          ),
        ] else if (workflow.workflowState ==
            AgenticWorkflowState.resultsReady) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton.icon(
                onPressed: workflow.failedCount == 0
                    ? null
                    : () => notifier.generateHealingPlans(),
                icon: const Icon(Icons.healing_outlined),
                label: const Text('Analyze Failed Tests'),
              ),
              const Spacer(),
              TextButton(
                onPressed: notifier.reset,
                child: const Text('Start Over'),
              ),
            ],
          ),
        ] else if (workflow.workflowState ==
            AgenticWorkflowState.awaitingHealApproval) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton.icon(
                onPressed: workflow.healPendingCount == 0
                    ? null
                    : notifier.approveAllHealing,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Approve All Heal'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: workflow.healPendingCount == 0
                    ? null
                    : notifier.rejectAllHealing,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Reject All Heal'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: workflow.healApprovedCount == 0
                    ? null
                    : () => notifier.reExecuteHealedTests(),
                icon: const Icon(Icons.play_arrow_outlined),
                label: const Text('Re-run (Keep Assertions)'),
              ),
              const Spacer(),
              TextButton(onPressed: notifier.reset, child: const Text('Reset')),
            ],
          ),
        ] else if (workflow.generatedTests.isNotEmpty &&
            workflow.workflowState == AgenticWorkflowState.finalReport) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton.icon(
                onPressed: workflow.failedCount == 0
                    ? null
                    : () => notifier.generateHealingPlans(),
                icon: const Icon(Icons.refresh),
                label: const Text('Run Another Healing Iteration'),
              ),
              const Spacer(),
              TextButton(
                onPressed: notifier.reset,
                child: const Text('Start Over'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
