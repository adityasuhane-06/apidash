import 'dart:async';

import 'package:apidash/agentic_testing/models/test_case_model.dart';
import 'package:apidash/agentic_testing/widgets/test_review_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants.dart';
import '../models/models.dart';
import '../providers/providers.dart';

class DashbotAgenticMcpAppView extends ConsumerWidget {
  const DashbotAgenticMcpAppView({super.key, required this.payload});

  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resourceUri = _readResourceUri(payload);
    final modelContext = _readModelContext(payload);
    if (resourceUri == null || modelContext.isEmpty) {
      return const SizedBox.shrink();
    }

    final plan = _readPlan(modelContext);
    final tests = _readTestCases(modelContext);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MCP App: ${_titleFor(resourceUri)}',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _buildWorkflowOverview(context, modelContext, plan),
          const SizedBox(height: 10),
          _buildContent(context, ref, resourceUri, modelContext, tests),
        ],
      ),
    );
  }

  Widget _buildWorkflowOverview(
    BuildContext context,
    Map<String, dynamic> modelContext,
    AgentExecutionPlan? plan,
  ) {
    final workflowState = _readString(modelContext, 'workflowState');
    final loopStage = _readString(modelContext, 'loopStage');
    final statusMessage = _readString(modelContext, 'statusMessage');
    final goal = _readString(modelContext, 'goal');
    final lastRunSummary = _readString(modelContext, 'lastRunSummary');
    final currentPlanStep = plan?.currentStep;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workflow Overview',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStateChip(
                context,
                label:
                    'State: ${_humanizeKey(workflowState ?? 'unknown').toUpperCase()}',
              ),
              if (loopStage != null && loopStage.isNotEmpty)
                _buildStateChip(
                  context,
                  label: 'Loop: ${_humanizeKey(loopStage).toUpperCase()}',
                ),
              if (currentPlanStep != null)
                _buildStateChip(
                  context,
                  label: 'Current: ${_stepLabel(currentPlanStep.type)}',
                ),
            ],
          ),
          if (goal != null && goal.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(goal, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (statusMessage != null && statusMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(statusMessage, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (lastRunSummary != null && lastRunSummary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(lastRunSummary, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (plan != null && plan.steps.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Plan Steps',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ...plan.steps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _stepStatusIcon(step.status),
                      size: 16,
                      color: _stepStatusColor(context, step.status),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_stepLabel(step.type)} (${step.status.name})',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    String resourceUri,
    Map<String, dynamic> modelContext,
    List<AgenticTestCase> tests,
  ) {
    return switch (resourceUri) {
      'ui://agentic/plan-review' => _buildPlanReviewContent(
        context,
        modelContext,
      ),
      'ui://agentic/test-review' => _buildTestReviewContent(
        context,
        ref,
        modelContext,
        tests,
      ),
      'ui://agentic/execution-results' => _buildExecutionResultsContent(
        context,
        ref,
        modelContext,
        tests,
      ),
      'ui://agentic/healing-review' => _buildHealingReviewContent(
        context,
        ref,
        modelContext,
        tests,
      ),
      'ui://agentic/final-report' => _buildFinalReportContent(
        context,
        ref,
        modelContext,
        tests,
      ),
      _ => Text('Unsupported MCP app resource: $resourceUri'),
    };
  }

  Widget _buildPlanReviewContent(
    BuildContext context,
    Map<String, dynamic> modelContext,
  ) {
    final goal = _readString(modelContext, 'goal');
    final currentStepRaw = modelContext['currentPlanStep'];
    AgentPlanStep? currentStep;
    if (currentStepRaw is Map) {
      try {
        currentStep = AgentPlanStep.fromJson(
          Map<String, dynamic>.from(currentStepRaw),
        );
      } catch (_) {}
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plan is ready. Review steps below, then approve or reject.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (goal != null && goal.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Goal: $goal', style: Theme.of(context).textTheme.bodySmall),
        ],
        if (currentStep != null) ...[
          const SizedBox(height: 8),
          Text(
            'Current step: ${_stepLabel(currentStep.type)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _buildTestReviewContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> modelContext,
    List<AgenticTestCase> tests,
  ) {
    final approved = _readInt(modelContext, 'approvedCount');
    final rejected = _readInt(modelContext, 'rejectedCount');
    final pending = _readInt(modelContext, 'pendingCount');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review generated tests before execution.'),
        const SizedBox(height: 6),
        Text('Approved: $approved  Rejected: $rejected  Pending: $pending'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: tests.isEmpty
                  ? null
                  : () => _sendWorkflowCommand(ref, 'approve all'),
              child: const Text('Approve All'),
            ),
            OutlinedButton(
              onPressed: tests.isEmpty
                  ? null
                  : () => _sendWorkflowCommand(ref, 'reject all'),
              child: const Text('Reject All'),
            ),
            OutlinedButton(
              onPressed: tests.isEmpty
                  ? null
                  : () => _sendWorkflowCommand(ref, 'skip all'),
              child: const Text('Skip All'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Use T1/T2/T3 in chat commands (labels are stable by card order).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        _buildTestCards(
          context,
          ref,
          tests,
          actionMode: _McpCardActionMode.review,
        ),
      ],
    );
  }

  Widget _buildExecutionResultsContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> modelContext,
    List<AgenticTestCase> tests,
  ) {
    final passed = _readInt(modelContext, 'passedCount');
    final failed = _readInt(modelContext, 'failedCount');
    final skipped = _readInt(modelContext, 'skippedCount');
    final notRun = _readInt(modelContext, 'notRunCount');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Execution summary: Passed $passed  Failed $failed  Skipped $skipped  Not Run $notRun',
        ),
        const SizedBox(height: 6),
        Text(
          'Each card includes pass/fail reason, response status/time, and assertion-level results.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        _buildTestCards(
          context,
          ref,
          tests,
          actionMode: _McpCardActionMode.none,
        ),
      ],
    );
  }

  Widget _buildHealingReviewContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> modelContext,
    List<AgenticTestCase> tests,
  ) {
    final pending = _readInt(modelContext, 'healPendingCount');
    final approved = _readInt(modelContext, 'healApprovedCount');
    final rejected = _readInt(modelContext, 'healRejectedCount');
    final applied = _readInt(modelContext, 'healAppliedCount');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Healing summary: Pending $pending  Approved $approved  Rejected $rejected  Applied $applied',
        ),
        const SizedBox(height: 6),
        Text(
          'Strict mode: healing is diagnostic-only; assertions are never auto-mutated.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _buildFailureAnalysisSection(context, tests),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: tests.isEmpty
                  ? null
                  : () => _sendWorkflowCommand(ref, 'approve healing all'),
              child: const Text('Approve Healing All'),
            ),
            OutlinedButton(
              onPressed: tests.isEmpty
                  ? null
                  : () => _sendWorkflowCommand(ref, 'reject healing all'),
              child: const Text('Reject Healing All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildTestCards(
          context,
          ref,
          tests,
          actionMode: _McpCardActionMode.healing,
        ),
      ],
    );
  }

  Widget _buildFinalReportContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> modelContext,
    List<AgenticTestCase> tests,
  ) {
    final generated = _readInt(modelContext, 'generatedCount');
    final approved = _readInt(modelContext, 'approvedCount');
    final passed = _readInt(modelContext, 'passedCount');
    final failed = _readInt(modelContext, 'failedCount');
    final skipped = _readInt(modelContext, 'skippedCount');
    final healed = _readInt(modelContext, 'healAppliedCount');
    final reportGeneratedAt = DateTime.now().toUtc();
    final markdown = _buildFinalReportMarkdown(
      generatedAtUtc: reportGeneratedAt,
      modelContext: modelContext,
      tests: tests,
      generated: generated,
      approved: approved,
      passed: passed,
      failed: failed,
      skipped: skipped,
      healed: healed,
    );
    final evaluated = passed + failed + skipped;
    final passRate = evaluated == 0 ? 0.0 : (passed / evaluated) * 100.0;
    final unsupportedSkipped = tests
        .where(
          (testCase) =>
              testCase.executionStatus == TestExecutionStatus.skipped &&
              testCase.failureType == TestFailureType.unsupportedAssertion,
        )
        .length;
    final overallStatus = failed > 0
        ? 'FAILED'
        : (unsupportedSkipped > 0 ? 'PASSED WITH WARNINGS' : 'PASSED');
    final findings = _buildKeyFindings(tests);
    final actions = _buildRecommendedActions(
      failed: failed,
      unsupportedSkipped: unsupportedSkipped,
      healed: healed,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Test Execution Report',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report metadata',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Generated at (UTC): ${reportGeneratedAt.toIso8601String()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Policy: strict_no_assertion_mutation',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Overall status: $overallStatus',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                'Summary',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Generated: $generated  Approved: $approved  Passed: $passed  Failed: $failed  Skipped: $skipped  Healed: $healed',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                'Pass rate (evaluated tests): ${passRate.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (tests.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Scope',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Endpoints: ${_collectDistinctEndpoints(tests).join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Methods: ${_collectDistinctMethods(tests).join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Key findings',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ...findings.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '- $line',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Recommended actions',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ...actions.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '- $line',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: markdown));
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Final report copied as Markdown.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy Markdown Report'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Detailed test results',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _buildTestCards(
          context,
          ref,
          tests,
          actionMode: _McpCardActionMode.none,
        ),
      ],
    );
  }

  Widget _buildTestCards(
    BuildContext context,
    WidgetRef ref,
    List<AgenticTestCase> tests, {
    required _McpCardActionMode actionMode,
  }) {
    if (tests.isEmpty) {
      return Text(
        'No test cases available in this step yet.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Column(
      children: [
        for (var i = 0; i < tests.length; i++) ...[
          TestReviewCard(
            testCase: tests[i],
            referenceLabel: 'T${i + 1}',
            onApprove: actionMode == _McpCardActionMode.review
                ? () => _sendWorkflowCommand(ref, 'approve T${i + 1}')
                : null,
            onReject: actionMode == _McpCardActionMode.review
                ? () => _sendWorkflowCommand(ref, 'reject T${i + 1}')
                : null,
            onApproveHealing: actionMode == _McpCardActionMode.healing
                ? () => _sendWorkflowCommand(ref, 'approve healing T${i + 1}')
                : null,
            onRejectHealing: actionMode == _McpCardActionMode.healing
                ? () => _sendWorkflowCommand(ref, 'reject healing T${i + 1}')
                : null,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  void _sendWorkflowCommand(WidgetRef ref, String command) {
    unawaited(
      ref
          .read(chatViewmodelProvider.notifier)
          .sendMessage(
            text: command,
            type: ChatMessageType.general,
            countAsUser: true,
          ),
    );
  }

  String _titleFor(String resourceUri) {
    return switch (resourceUri) {
      'ui://agentic/plan-review' => 'Plan Review',
      'ui://agentic/test-review' => 'Test Review',
      'ui://agentic/execution-results' => 'Execution Results',
      'ui://agentic/healing-review' => 'Healing Review',
      'ui://agentic/final-report' => 'Final Report',
      _ => 'Agentic UI',
    };
  }

  String? _readResourceUri(Map<String, dynamic> payload) {
    final uri = payload['resourceUri'] ?? payload['resource_uri'];
    if (uri is String && uri.trim().isNotEmpty) {
      return uri.trim();
    }
    return null;
  }

  Map<String, dynamic> _readModelContext(Map<String, dynamic> payload) {
    final raw = payload['modelContext'] ?? payload['model_context'];
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const <String, dynamic>{};
  }

  AgentExecutionPlan? _readPlan(Map<String, dynamic> modelContext) {
    final rawPlan = modelContext['plan'];
    if (rawPlan is! Map) {
      return null;
    }
    try {
      return AgentExecutionPlan.fromJson(Map<String, dynamic>.from(rawPlan));
    } catch (_) {
      return null;
    }
  }

  List<AgenticTestCase> _readTestCases(Map<String, dynamic> modelContext) {
    final rawTests = _readTests(modelContext);
    if (rawTests.isEmpty) {
      return const <AgenticTestCase>[];
    }
    final fallbackEndpoint = _readString(modelContext, 'endpoint') ?? '';
    final fallbackMethod = (_readString(modelContext, 'requestMethod') ?? 'GET')
        .toUpperCase();

    final tests = <AgenticTestCase>[];
    for (var i = 0; i < rawTests.length; i++) {
      final normalized = _normalizeSnapshotTest(rawTests[i]);
      tests.add(
        AgenticTestCase.fromJson(
          normalized,
          fallbackId: 'mcp_test_$i',
          fallbackEndpoint: fallbackEndpoint,
          fallbackMethod: fallbackMethod,
        ),
      );
    }
    return tests;
  }

  Map<String, dynamic> _normalizeSnapshotTest(Map<String, dynamic> raw) {
    final normalized = Map<String, dynamic>.from(raw);
    normalized['expected_outcome'] ??= raw['expectedOutcome'];
    normalized['execution_status'] ??= raw['executionStatus'];
    normalized['execution_summary'] ??= raw['executionSummary'];
    normalized['assertion_report'] ??= raw['assertionReport'];
    normalized['response_status_code'] ??= raw['responseStatusCode'];
    normalized['response_time_ms'] ??= raw['responseTimeMs'];
    normalized['failure_type'] ??= raw['failureType'];
    normalized['healing_suggestion'] ??= raw['healingSuggestion'];
    normalized['healing_assertions'] ??= raw['healingAssertions'];
    normalized['healing_decision'] ??= raw['healingDecision'];
    normalized['healing_iteration'] ??= raw['healingIteration'];
    return normalized;
  }

  List<Map<String, dynamic>> _readTests(Map<String, dynamic> modelContext) {
    final raw = modelContext['tests'];
    if (raw is! List) {
      return const <Map<String, dynamic>>[];
    }
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  int _readInt(Map<String, dynamic> modelContext, String key) {
    final value = modelContext[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  String? _readString(Map<String, dynamic> modelContext, String key) {
    final value = modelContext[key];
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  Widget _buildStateChip(BuildContext context, {required String label}) {
    return Chip(visualDensity: VisualDensity.compact, label: Text(label));
  }

  String _humanizeKey(String value) {
    final cleaned = value.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) {
      return value;
    }
    return cleaned
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _stepLabel(AgentPlanStepType type) {
    return switch (type) {
      AgentPlanStepType.generate => 'Generate tests',
      AgentPlanStepType.review => 'Review tests',
      AgentPlanStepType.execute => 'Execute approved tests',
      AgentPlanStepType.analyze => 'Analyze failures',
      AgentPlanStepType.healReview => 'Review healing',
      AgentPlanStepType.rerun => 'Re-run healed tests',
      AgentPlanStepType.report => 'Final report',
    };
  }

  IconData _stepStatusIcon(AgentPlanStepStatus status) {
    return switch (status) {
      AgentPlanStepStatus.pending => Icons.radio_button_unchecked,
      AgentPlanStepStatus.running => Icons.autorenew_rounded,
      AgentPlanStepStatus.completed => Icons.check_circle_outline,
      AgentPlanStepStatus.skipped => Icons.fast_forward_outlined,
      AgentPlanStepStatus.failed => Icons.error_outline,
    };
  }

  Color _stepStatusColor(BuildContext context, AgentPlanStepStatus status) {
    return switch (status) {
      AgentPlanStepStatus.pending => Theme.of(context).colorScheme.outline,
      AgentPlanStepStatus.running => Colors.blue,
      AgentPlanStepStatus.completed => Colors.green,
      AgentPlanStepStatus.skipped => Colors.orange,
      AgentPlanStepStatus.failed => Theme.of(context).colorScheme.error,
    };
  }

  List<String> _collectDistinctEndpoints(List<AgenticTestCase> tests) {
    final endpoints =
        tests
            .map((testCase) => testCase.endpoint.trim())
            .where((endpoint) => endpoint.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return endpoints;
  }

  List<String> _collectDistinctMethods(List<AgenticTestCase> tests) {
    final methods =
        tests
            .map((testCase) => testCase.method.trim().toUpperCase())
            .where((method) => method.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return methods;
  }

  List<String> _buildKeyFindings(List<AgenticTestCase> tests) {
    final passed = tests
        .where(
          (testCase) => testCase.executionStatus == TestExecutionStatus.passed,
        )
        .length;
    final failed = tests
        .where(
          (testCase) => testCase.executionStatus == TestExecutionStatus.failed,
        )
        .toList();
    final unsupported = tests
        .where(
          (testCase) =>
              testCase.executionStatus == TestExecutionStatus.skipped &&
              testCase.failureType == TestFailureType.unsupportedAssertion,
        )
        .toList();

    final lines = <String>[
      '$passed test(s) passed across the approved execution set.',
    ];
    if (failed.isNotEmpty) {
      final top = failed
          .take(3)
          .map((testCase) => '${testCase.title} [${testCase.failureType.code}]')
          .join('; ');
      lines.add('${failed.length} test(s) failed: $top');
    } else {
      lines.add('No hard failures were observed in this run.');
    }
    if (unsupported.isNotEmpty) {
      lines.add(
        '${unsupported.length} test(s) were skipped because assertions are not auto-verifiable yet.',
      );
    }
    return lines;
  }

  List<String> _buildRecommendedActions({
    required int failed,
    required int unsupportedSkipped,
    required int healed,
  }) {
    if (failed == 0 && unsupportedSkipped == 0) {
      return const <String>[
        'Archive this report as a baseline run.',
        'Promote high-confidence tests into CI automation.',
      ];
    }

    final actions = <String>[];
    if (failed > 0) {
      actions.add(
        'Triage failed tests first (status/body/latency mismatch) using response payload and server logs.',
      );
    }
    if (unsupportedSkipped > 0) {
      actions.add(
        'Convert unsupported assertion syntax to supported executor syntax (for example, response.json().get(...)).',
      );
    }
    if (healed > 0) {
      actions.add(
        'Re-run healed tests after environment/config fixes; assertion contract remains unchanged.',
      );
    }
    actions.add('Attach this report to PR/issue for auditability.');
    return actions;
  }

  Widget _buildFailureAnalysisSection(
    BuildContext context,
    List<AgenticTestCase> tests,
  ) {
    final analyzable = tests
        .asMap()
        .entries
        .where((entry) => _isAnalyzableFailure(entry.value))
        .toList();
    if (analyzable.isEmpty) {
      return Text(
        'No analyzable failures in this run.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final hardFailed = analyzable
        .where(
          (entry) => entry.value.executionStatus == TestExecutionStatus.failed,
        )
        .length;
    final unsupportedSkipped = analyzable
        .where(
          (entry) =>
              entry.value.executionStatus == TestExecutionStatus.skipped &&
              entry.value.failureType == TestFailureType.unsupportedAssertion,
        )
        .length;
    final failureReportMarkdown = _buildFailureAnalysisMarkdown(
      generatedAtUtc: DateTime.now().toUtc(),
      tests: tests,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Failure Analysis Report',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Hard failures: $hardFailed  Unsupported-skipped: $unsupportedSkipped',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ...analyzable.map((entry) {
            final testRef = 'T${entry.key + 1}';
            final testCase = entry.value;
            final reason = _primaryFailureReason(testCase);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        testCase.executionStatus == TestExecutionStatus.failed
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$testRef - ${testCase.title}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Failure type: ${testCase.failureType.code}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Why: $reason',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Response status/time: ${testCase.responseStatusCode ?? '-'} / ${testCase.responseTimeMs ?? '-'} ms',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Recommended fix: ${_recommendedActionForFailure(testCase)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }),
          FilledButton.tonalIcon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: failureReportMarkdown),
              );
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failure analysis copied as Markdown report.'),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy Failure Analysis'),
          ),
        ],
      ),
    );
  }

  bool _isAnalyzableFailure(AgenticTestCase testCase) {
    if (testCase.executionStatus == TestExecutionStatus.failed) {
      return true;
    }
    return testCase.executionStatus == TestExecutionStatus.skipped &&
        testCase.failureType == TestFailureType.unsupportedAssertion;
  }

  String _primaryFailureReason(AgenticTestCase testCase) {
    for (final line in testCase.assertionReport) {
      final trimmed = line.trim();
      if (trimmed.startsWith('FAIL:')) {
        return trimmed.replaceFirst('FAIL:', '').trim();
      }
      if (trimmed.startsWith('SKIP:')) {
        return trimmed.replaceFirst('SKIP:', '').trim();
      }
      if (trimmed.startsWith('- FAIL:')) {
        return trimmed.replaceFirst('- FAIL:', '').trim();
      }
      if (trimmed.startsWith('- SKIP:')) {
        return trimmed.replaceFirst('- SKIP:', '').trim();
      }
    }
    final summary = testCase.executionSummary?.trim();
    if (summary != null && summary.isNotEmpty) {
      return summary;
    }
    return testCase.failureType == TestFailureType.none
        ? 'No explicit failure reason reported.'
        : testCase.failureType.label;
  }

  String _recommendedActionForFailure(AgenticTestCase testCase) {
    return switch (testCase.failureType) {
      TestFailureType.networkError =>
        'Verify endpoint reachability, DNS/TLS, and auth headers before rerun.',
      TestFailureType.statusCodeMismatch =>
        'Validate method/path/auth context and compare observed status with API contract.',
      TestFailureType.bodyValidationFailed =>
        'Compare response payload against schema and ensure expected fields/types are present.',
      TestFailureType.responseTimeExceeded =>
        'Investigate performance bottlenecks; keep latency assertion unchanged unless agreed.',
      TestFailureType.unsupportedAssertion =>
        'Convert to supported executor syntax (e.g., response.json().get(...)) and rerun.',
      TestFailureType.unknown || TestFailureType.none =>
        'Collect response/log diagnostics and rerun after targeted fixes.',
    };
  }

  String _buildFailureAnalysisMarkdown({
    required DateTime generatedAtUtc,
    required List<AgenticTestCase> tests,
  }) {
    final analyzable = tests
        .asMap()
        .entries
        .where((entry) => _isAnalyzableFailure(entry.value))
        .toList();
    final hardFailed = analyzable
        .where(
          (entry) => entry.value.executionStatus == TestExecutionStatus.failed,
        )
        .length;
    final unsupportedSkipped = analyzable
        .where(
          (entry) =>
              entry.value.executionStatus == TestExecutionStatus.skipped &&
              entry.value.failureType == TestFailureType.unsupportedAssertion,
        )
        .length;
    final details = analyzable
        .map((entry) {
          final idx = entry.key + 1;
          final testCase = entry.value;
          return '''
### T$idx - ${testCase.title}
- Method: ${testCase.method}
- Endpoint: ${testCase.endpoint}
- Execution Status: ${testCase.executionStatus.label}
- Failure Type: ${testCase.failureType.code}
- Why: ${_primaryFailureReason(testCase)}
- Response Status: ${testCase.responseStatusCode ?? '-'}
- Response Time (ms): ${testCase.responseTimeMs ?? '-'}
- Recommended Fix: ${_recommendedActionForFailure(testCase)}
''';
        })
        .join('\n');

    return '''
# Agentic API Failure Analysis Report

## Metadata
- Generated At (UTC): ${generatedAtUtc.toIso8601String()}
- Analyzable Tests: ${analyzable.length}
- Hard Failures: $hardFailed
- Unsupported-Skipped: $unsupportedSkipped

## Failure Details
${details.isEmpty ? '- No analyzable failures in this run.' : details}
''';
  }

  String _buildFinalReportMarkdown({
    required DateTime generatedAtUtc,
    required Map<String, dynamic> modelContext,
    required List<AgenticTestCase> tests,
    required int generated,
    required int approved,
    required int passed,
    required int failed,
    required int skipped,
    required int healed,
  }) {
    final evaluated = passed + failed + skipped;
    final passRate = evaluated == 0 ? 0.0 : (passed / evaluated) * 100.0;
    final workflowState =
        _readString(modelContext, 'workflowState') ?? 'unknown';
    final endpoints = _collectDistinctEndpoints(tests);
    final methods = _collectDistinctMethods(tests);
    final findings = _buildKeyFindings(tests);
    final actions = _buildRecommendedActions(
      failed: failed,
      unsupportedSkipped: tests
          .where(
            (testCase) =>
                testCase.executionStatus == TestExecutionStatus.skipped &&
                testCase.failureType == TestFailureType.unsupportedAssertion,
          )
          .length,
      healed: healed,
    );

    final testLines = tests
        .asMap()
        .entries
        .map((entry) {
          final idx = entry.key + 1;
          final testCase = entry.value;
          return '- T$idx ${testCase.title} | ${testCase.executionStatus.label} | failure: ${testCase.failureType.code} | status: ${testCase.responseStatusCode ?? '-'} | time_ms: ${testCase.responseTimeMs ?? '-'}';
        })
        .join('\n');

    return '''
# Agentic API Testing Final Report

## Metadata
- Generated At (UTC): ${generatedAtUtc.toIso8601String()}
- Workflow State: ${_humanizeKey(workflowState).toUpperCase()}
- Policy: strict_no_assertion_mutation

## Scope
- Methods: ${methods.isEmpty ? '-' : methods.join(', ')}
- Endpoints: ${endpoints.isEmpty ? '-' : endpoints.join(', ')}

## Summary
- Generated: $generated
- Approved: $approved
- Passed: $passed
- Failed: $failed
- Skipped: $skipped
- Healed: $healed
- Pass Rate (evaluated tests): ${passRate.toStringAsFixed(1)}%

## Key Findings
${findings.map((line) => '- $line').join('\n')}

## Recommended Actions
${actions.map((line) => '- $line').join('\n')}

## Test Results
$testLines
''';
  }
}

enum _McpCardActionMode { none, review, healing }
