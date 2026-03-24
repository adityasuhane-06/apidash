import 'package:flutter/material.dart';

import '../models/test_case_model.dart';

class TestReviewCard extends StatelessWidget {
  const TestReviewCard({
    super.key,
    required this.testCase,
    this.onApprove,
    this.onReject,
    this.onApproveHealing,
    this.onRejectHealing,
  });

  final AgenticTestCase testCase;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onApproveHealing;
  final VoidCallback? onRejectHealing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final decisionColor = switch (testCase.decision) {
      TestReviewDecision.pending => colorScheme.outline,
      TestReviewDecision.approved => Colors.green,
      TestReviewDecision.rejected => Colors.red,
    };
    final executionColor = switch (testCase.executionStatus) {
      TestExecutionStatus.notRun => colorScheme.outline,
      TestExecutionStatus.passed => Colors.green,
      TestExecutionStatus.failed => Colors.red,
      TestExecutionStatus.skipped => Colors.orange,
    };
    final shouldShowFailureType =
        testCase.failureType != TestFailureType.none &&
        (testCase.executionStatus == TestExecutionStatus.failed ||
            testCase.executionStatus == TestExecutionStatus.skipped);
    final healingDecisionColor = switch (testCase.healingDecision) {
      TestHealingDecision.none => colorScheme.outline,
      TestHealingDecision.pending => Colors.orange,
      TestHealingDecision.approved => Colors.green,
      TestHealingDecision.rejected => Colors.red,
      TestHealingDecision.applied => Colors.blue,
    };
    final canShowReviewActions = onApprove != null || onReject != null;
    final canShowHealingActions =
        onApproveHealing != null || onRejectHealing != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    testCase.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (testCase.confidence != null)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      '${(testCase.confidence! * 100).toStringAsFixed(0)}%',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(testCase.method),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(testCase.endpoint),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: decisionColor),
                  label: Text(testCase.decision.label),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: executionColor),
                  label: Text(testCase.executionStatus.label),
                ),
                if (shouldShowFailureType)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: Colors.redAccent),
                    label: Text(testCase.failureType.code),
                  ),
                if (testCase.healingDecision != TestHealingDecision.none)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: healingDecisionColor),
                    label: Text('Heal: ${testCase.healingDecision.label}'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(testCase.description),
            const SizedBox(height: 8),
            Text(
              'Expected Outcome',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(testCase.expectedOutcome),
            if (testCase.assertions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Assertions',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ...testCase.assertions.map(
                (assertion) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('- $assertion'),
                ),
              ),
            ],
            if (testCase.executionSummary != null) ...[
              const SizedBox(height: 8),
              Text(
                'Execution',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(testCase.executionSummary!),
              if (shouldShowFailureType)
                Text('Failure Type: ${testCase.failureType.label}'),
              if (testCase.responseStatusCode != null)
                Text('Response Status: ${testCase.responseStatusCode}'),
              if (testCase.responseTimeMs != null)
                Text('Response Time: ${testCase.responseTimeMs} ms'),
              if (testCase.assertionReport.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...testCase.assertionReport.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('- $line'),
                  ),
                ),
              ],
            ],
            if ((testCase.healingSuggestion ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Healing Recommendation',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(testCase.healingSuggestion!),
              if (testCase.healingAssertions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Manual checks (assertions are not auto-edited):',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                ...testCase.healingAssertions.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('- $line'),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 10),
            if (canShowReviewActions)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Approve'),
                  ),
                ],
              ),
            if (canShowHealingActions) ...[
              if (canShowReviewActions) const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: onRejectHealing,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject Heal'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onApproveHealing,
                    icon: const Icon(Icons.healing_outlined),
                    label: const Text('Approve Heal'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
