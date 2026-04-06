import '../models/test_case_model.dart';

class AgenticTestHealingPlanner {
  const AgenticTestHealingPlanner();

  List<AgenticTestCase> generateHealingPlans({
    required List<AgenticTestCase> tests,
  }) {
    return tests.map(_planForTest).toList();
  }

  AgenticTestCase _planForTest(AgenticTestCase testCase) {
    if (!_isHealingCandidate(testCase)) {
      return testCase.copyWith(
        healingDecision: TestHealingDecision.none,
        clearHealingSuggestion: true,
        healingAssertions: const <String>[],
      );
    }

    final plan = _buildPlan(testCase);
    return testCase.copyWith(
      healingSuggestion: plan.$1,
      healingAssertions: plan.$2,
      healingDecision: TestHealingDecision.pending,
    );
  }

  bool _isHealingCandidate(AgenticTestCase testCase) {
    if (testCase.executionStatus == TestExecutionStatus.failed) {
      return true;
    }
    return testCase.executionStatus == TestExecutionStatus.skipped &&
        testCase.failureType == TestFailureType.unsupportedAssertion;
  }

  (String, List<String>) _buildPlan(AgenticTestCase testCase) {
    switch (testCase.failureType) {
      case TestFailureType.networkError:
        return (
          'Network/connectivity failure detected. Fix environment or request setup, then re-run with the same assertion contract.',
          const <String>[
            'Verify endpoint reachability, DNS, and TLS/certificate setup.',
            'Check required auth headers/tokens and proxy configuration.',
            'Re-run after connectivity/setup fixes (without changing assertions).',
          ],
        );
      case TestFailureType.statusCodeMismatch:
        return (
          'Status-code mismatch detected. Treat observed status as signal for diagnosis, not as a new expected contract.',
          const <String>[
            'Verify request method, path, query, and authentication context.',
            'Check backend logs/error payload for root cause of unexpected status.',
            'If API contract intentionally changed, manually update test assertions after review.',
          ],
        );
      case TestFailureType.bodyValidationFailed:
        return (
          'Response body validation failed. Investigate payload contract or data readiness, then re-run unchanged tests.',
          const <String>[
            'Compare response payload with API schema/OpenAPI contract.',
            'Check test data fixtures/seeding and serialization behavior.',
            'Only change assertions manually if contract change is deliberate.',
          ],
        );
      case TestFailureType.responseTimeExceeded:
        return (
          'Response-time threshold exceeded. Investigate performance bottlenecks; do not auto-relax SLO assertions.',
          <String>[
            'Measured latency: ${testCase.responseTimeMs ?? 'unknown'} ms.',
            'Check server/resource load and cold-start effects.',
            'Adjust latency threshold manually only with explicit product/SRE agreement.',
          ],
        );
      case TestFailureType.unsupportedAssertion:
        return (
          'Some assertions are not machine-verifiable yet. Add explicit executor support instead of rewriting expectations.',
          const <String>[
            'Map unsupported assertion syntax to executable checks in executor.',
            'Preserve original assertion intent while implementing parser/evaluator support.',
            'Re-run once assertion-engine support is added.',
          ],
        );
      case TestFailureType.unknown:
      case TestFailureType.none:
        return (
          'Failure reason is ambiguous. Collect more diagnostics and re-run with the same assertions.',
          const <String>[
            'Capture response body, headers, and server logs for this request.',
            'Verify environment parity (base URL, auth, data state).',
            'Re-run after diagnostics-driven fixes.',
          ],
        );
    }
  }
}
